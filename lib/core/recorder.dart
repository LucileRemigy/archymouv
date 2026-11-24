import 'dart:async';
import 'dart:math';

import 'axis_mapping.dart';
import 'models.dart';
import 'motion_source.dart';

/// Détecte « l'arc est baissé puis remonté » à partir de la vitesse de
/// rotation autour de l'axe latéral Z (repère arc).
///
/// On intègre la rotation depuis le toucher de l'écran :
///  1. l'arc doit descendre d'au moins [dropDeg] degrés ;
///  2. on suit le point bas ;
///  3. dès qu'il est remonté de [riseDeg] degrés au-dessus du point bas,
///     le déclenchement est confirmé. Le départ de l'enregistrement est
///     fixé à [lowUs] + délai (200 ms par défaut), [lowUs] étant le dernier
///     instant passé près du point bas (= début de la remontée).
class TriggerDetector {
  TriggerDetector({required this.dropDeg, required this.riseDeg});

  final double dropDeg;
  final double riseDeg;

  /// Inclinaison intégrée depuis le toucher, degrés (+ = nez vers le haut).
  double theta = 0;
  bool dropped = false;
  int? lowUs;

  double _max = 0;
  double _min = double.infinity;
  int? _lastUs;

  /// Renvoie true quand la remontée est confirmée.
  bool addGyro(int tUs, double pitchRateRadS) {
    final last = _lastUs;
    _lastUs = tUs;
    if (last != null) {
      final dt = (tUs - last) / 1e6;
      if (dt > 0 && dt < 0.5) theta += pitchRateRadS * dt * 180 / pi;
    }
    if (!dropped) {
      if (theta > _max) _max = theta;
      if (_max - theta >= dropDeg) dropped = true;
    }
    if (dropped) {
      if (theta < _min) _min = theta;
      if (theta <= _min + 0.5) lowUs = tUs;
      if (theta - _min >= riseDeg) return true;
    }
    return false;
  }
}

enum RecState { idle, armed, recording, done }

class RecordedArrow {
  RecordedArrow({
    required this.armedAt,
    required this.triggeredAt,
    required this.mode,
    required this.samples,
    required this.gyroHz,
    required this.accHz,
  });

  final DateTime armedAt;
  final DateTime triggeredAt;
  final String mode;
  final List<List<double>> samples;
  final double gyroHz;
  final double accHz;

  Arrow toArrow(int number, int periodMs) => Arrow(
        number: number,
        armedAt: armedAt,
        triggeredAt: triggeredAt,
        triggerMode: mode,
        periodMs: periodMs,
        samples: samples,
        gyroHz: gyroHz,
        accHz: accHz,
      );
}

/// Enregistre une flèche : écoute en continu les capteurs, attend le
/// déclenchement puis garde [AppSettings.durationS] secondes de mesures,
/// ré-échantillonnées toutes les [AppSettings.periodMs] ms.
class ArrowRecorder {
  ArrowRecorder({required this.source, required this.settings, this.onTrigger})
      : mapper = AxisMapper(settings.phonePosition, settings.handedness);

  final MotionSource source;
  final AppSettings settings;
  final AxisMapper mapper;
  final void Function()? onTrigger;

  final List<RawEvent> _gyro = [];
  final List<RawEvent> _acc = [];
  StreamSubscription<RawEvent>? _gs, _as;
  RecState _state = RecState.idle;
  TriggerDetector? _detector;
  int _lastUs = 0;
  int? _t0Us;
  DateTime? _armedAt;
  String _mode = 'auto';
  Completer<RecordedArrow>? _completer;
  Timer? _safety;
  Object? error;

  RecState get state => _state;
  double get pitchDeg => _detector?.theta ?? 0;
  bool get dropDetected => _detector?.dropped ?? false;
  bool get sensorsAlive => _lastUs != 0;
  int get _durUs => settings.durationS * 1000000;

  double get progress {
    final t0 = _t0Us;
    if (_state != RecState.recording || t0 == null) return 0;
    return ((_lastUs - t0) / _durUs).clamp(0.0, 1.0);
  }

  double get remainingS {
    final t0 = _t0Us;
    if (t0 == null) return settings.durationS.toDouble();
    return max(0, (t0 + _durUs - _lastUs) / 1e6);
  }

  /// Démarre l'écoute des capteurs (à faire dès l'ouverture de l'écran).
  void start() {
    final p = Duration(milliseconds: settings.periodMs);
    _gs = source.gyro(p).listen(_onGyro, onError: (Object e) => error = e);
    _as = source.accel(p).listen(_onAcc, onError: (Object e) => error = e);
  }

  /// L'archer a touché l'écran. Le Future se termine à la fin de
  /// l'enregistrement.
  Future<RecordedArrow> arm() {
    _gyro.clear();
    _acc.clear();
    _t0Us = null;
    _armedAt = DateTime.now();
    _completer = Completer<RecordedArrow>();
    source.onArmed();
    _state = RecState.armed;
    if (settings.autoTrigger) {
      _detector = TriggerDetector(
          dropDeg: settings.triggerDropDeg, riseDeg: settings.triggerRiseDeg);
    } else {
      _detector = null;
      triggerNow();
    }
    return _completer!.future;
  }

  /// Démarrage manuel immédiat (second toucher de l'écran).
  void triggerNow() {
    if (_state != RecState.armed) return;
    _trigger(_lastUs == 0 ? DateTime.now().microsecondsSinceEpoch : _lastUs,
        'manuel');
  }

  void cancel() {
    _safety?.cancel();
    _state = RecState.idle;
  }

  void dispose() {
    _safety?.cancel();
    _gs?.cancel();
    _as?.cancel();
  }

  void _trigger(int t0, String mode) {
    _t0Us = t0;
    _mode = mode;
    _state = RecState.recording;
    final keepFrom = t0 - 200000;
    _gyro.removeWhere((e) => e.tUs < keepFrom);
    _acc.removeWhere((e) => e.tUs < keepFrom);
    _safety?.cancel();
    _safety = Timer(Duration(microseconds: _durUs + 3000000), _finish);
    onTrigger?.call();
    _checkEnd();
  }

  void _onGyro(RawEvent e) {
    if (e.tUs > _lastUs) _lastUs = e.tUs;
    if (_state == RecState.armed || _state == RecState.recording) _gyro.add(e);
    if (_state == RecState.armed) {
      final d = _detector;
      if (d != null) {
        final b = mapper.toBow(e.x, e.y, e.z);
        if (d.addGyro(e.tUs, b[2])) {
          _trigger((d.lowUs ?? e.tUs) + settings.triggerDelayMs * 1000, 'auto');
          return;
        }
      }
      _prune();
    }
    _checkEnd();
  }

  void _onAcc(RawEvent e) {
    if (e.tUs > _lastUs) _lastUs = e.tUs;
    if (_state == RecState.armed || _state == RecState.recording) _acc.add(e);
    _checkEnd();
  }

  /// Pendant l'attente, on ne garde que les 10 dernières secondes.
  void _prune() {
    if (_gyro.length < 4000) return;
    final limit = _lastUs - 10000000;
    _gyro.removeWhere((e) => e.tUs < limit);
    _acc.removeWhere((e) => e.tUs < limit);
  }

  void _checkEnd() {
    final t0 = _t0Us;
    if (_state == RecState.recording && t0 != null && _lastUs >= t0 + _durUs) {
      _finish();
    }
  }

  void _finish() {
    if (_state != RecState.recording) return;
    _safety?.cancel();
    _state = RecState.done;
    final t0 = _t0Us!;
    final end = t0 + _durUs;
    double rate(List<RawEvent> l) =>
        l.where((e) => e.tUs >= t0 && e.tUs <= end).length / settings.durationS;
    _completer?.complete(RecordedArrow(
      armedAt: _armedAt ?? DateTime.now(),
      triggeredAt: DateTime.fromMicrosecondsSinceEpoch(t0),
      mode: _mode,
      samples: resample(_gyro, _acc, t0, settings.periodMs, settings.durationS),
      gyroHz: rate(_gyro),
      accHz: rate(_acc),
    ));
  }

  /// Ré-échantillonne les deux capteurs sur une grille régulière
  /// (interpolation linéaire) : t = 0, période, 2×période… jusqu'à la durée.
  /// Ligne = [t (ms), gx, gy, gz, ax, ay, az] repère téléphone.
  static List<List<double>> resample(List<RawEvent> gyro, List<RawEvent> acc,
      int t0Us, int periodMs, int durationS) {
    final n = (durationS * 1000 / periodMs).floor() + 1;
    final out = <List<double>>[];
    var gi = 0, ai = 0;
    for (var k = 0; k < n; k++) {
      final t = t0Us + k * periodMs * 1000;
      final (g, ngi) = _interp(gyro, t, gi);
      final (a, nai) = _interp(acc, t, ai);
      gi = ngi;
      ai = nai;
      out.add([(k * periodMs).toDouble(), g[0], g[1], g[2], a[0], a[1], a[2]]);
    }
    return out;
  }

  static (List<double>, int) _interp(List<RawEvent> l, int t, int start) {
    if (l.isEmpty) return (const [0.0, 0.0, 0.0], 0);
    var i = start;
    while (i < l.length - 1 && l[i + 1].tUs <= t) {
      i++;
    }
    final e0 = l[i];
    if (t <= e0.tUs || i == l.length - 1) return ([e0.x, e0.y, e0.z], i);
    final e1 = l[i + 1];
    final f = (t - e0.tUs) / (e1.tUs - e0.tUs);
    return (
      [
        e0.x + (e1.x - e0.x) * f,
        e0.y + (e1.y - e0.y) * f,
        e0.z + (e1.z - e0.z) * f,
      ],
      i
    );
  }
}
