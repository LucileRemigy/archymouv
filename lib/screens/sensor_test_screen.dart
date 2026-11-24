import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/axis_mapping.dart';
import '../core/format.dart';
import '../core/motion_source.dart';
import '../services/beeper.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// « Test Flutter gyroscope » : valeurs brutes, fréquences réelles,
/// conversion vers le repère arc, viseur en direct et détection de la
/// position du téléphone par la gravité.
class SensorTestScreen extends StatefulWidget {
  const SensorTestScreen({super.key});

  @override
  State<SensorTestScreen> createState() => _SensorTestScreenState();
}

class _SensorTestScreenState extends State<SensorTestScreen> {
  final app = AppState.instance;
  late MotionSource _src;
  late AxisMapper _mapper;
  StreamSubscription<RawEvent>? _gs, _as;
  Timer? _ui;
  Object? _error;

  RawEvent? _g, _a;
  int _gCount = 0, _aCount = 0;
  double _gHz = 0, _aHz = 0;
  DateTime _rateStart = DateTime.now();

  double _rx = 0, _ry = 0, _rz = 0;
  int? _lastGUs;
  int _lastTrailUs = 0;
  final List<Offset> _trail = [];
  final List<(double, double, double, double)> _hist = [];
  double _lx = 0, _ly = 0, _lz = 0;
  Timer? _zeroTimer;
  int? _countdown;

  @override
  void initState() {
    super.initState();
    _startSensors();
    _ui = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final dt = DateTime.now().difference(_rateStart).inMilliseconds / 1000;
      if (dt >= 1) {
        _gHz = _gCount / dt;
        _aHz = _aCount / dt;
        _gCount = 0;
        _aCount = 0;
        _rateStart = DateTime.now();
      }
      if (mounted) setState(() {});
    });
  }

  void _startSensors() {
    final s = app.settings;
    _mapper = AxisMapper(s.phonePosition, s.handedness);
    _src = app.createSource();
    final p = Duration(milliseconds: s.periodMs);
    _gs = _src.gyro(p).listen(_onGyro, onError: (Object e) => _error = e);
    _as = _src.accel(p).listen(_onAcc, onError: (Object e) => _error = e);
  }

  void _stopSensors() {
    _gs?.cancel();
    _as?.cancel();
    _src.dispose();
  }

  void _onGyro(RawEvent e) {
    _g = e;
    _gCount++;
    final b = _mapper.toBow(e.x, e.y, e.z);
    final last = _lastGUs;
    _lastGUs = e.tUs;
    if (last != null) {
      final dt = (e.tUs - last) / 1e6;
      if (dt > 0 && dt < 0.5) {
        _rx += b[0] * dt;
        _ry += b[1] * dt;
        _rz += b[2] * dt;
      }
    }
    if (e.tUs - _lastTrailUs >= 20000) {
      _lastTrailUs = e.tUs;
      final d = app.settings.distanceM * 100;
      _trail.add(Offset(-d * tan(_ry.clamp(-1.4, 1.4)), d * tan(_rz.clamp(-1.4, 1.4))));
      if (_trail.length > 150) _trail.removeAt(0);
      final t = e.tUs / 1e6;
      _hist.add((t, b[0] * 180 / pi, b[1] * 180 / pi, b[2] * 180 / pi));
      while (_hist.isNotEmpty && t - _hist.first.$1 > 5) {
        _hist.removeAt(0);
      }
    }
  }

  void _onAcc(RawEvent e) {
    _a = e;
    _aCount++;
    const k = 0.05;
    _lx += (e.x - _lx) * k;
    _ly += (e.y - _ly) * k;
    _lz += (e.z - _lz) * k;
  }

  void _resetAim() {
    _rx = 0;
    _ry = 0;
    _rz = 0;
    _trail.clear();
  }

  /// Zéro différé de 3 s (un bip par seconde) : le temps de reprendre l'arc
  /// et de viser. Toucher pendant le décompte = zéro immédiat.
  void _startZero() {
    _zeroTimer?.cancel();
    if (_countdown != null) {
      _countdown = null;
      _resetAim();
      Beeper.recording();
      setState(() {});
      return;
    }
    _countdown = 3;
    Beeper.armed();
    _zeroTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final c = (_countdown ?? 1) - 1;
      if (c <= 0) {
        t.cancel();
        _countdown = null;
        _resetAim();
        Beeper.recording();
      } else {
        _countdown = c;
        Beeper.armed();
      }
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _applyPosition(String id) async {
    await app.update((s) => s.phonePosition = id);
    _stopSensors();
    _resetAim();
    _startSensors();
  }

  @override
  void dispose() {
    _ui?.cancel();
    _zeroTimer?.cancel();
    _stopSensors();
    super.dispose();
  }

  Widget _vecTable(String title, List<String> axes, List<double>? g, List<double>? a,
      {required bool deg}) {
    final tt = Theme.of(context).textTheme;
    String f(double? v, int d) => v == null ? '–' : fmtSigned(v, d);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tt.titleSmall),
          const SizedBox(height: 6),
          Table(
            columnWidths: const {0: FlexColumnWidth(1.6)},
            children: [
              TableRow(children: [
                const Text(''),
                Text(deg ? 'Gyro (°/s)' : 'Gyro (rad/s)', style: tt.labelSmall),
                Text('Accél. (m/s²)', style: tt.labelSmall),
              ]),
              for (var i = 0; i < 3; i++)
                TableRow(children: [
                  Text(axes[i]),
                  Text(f(g == null ? null : g[i] * (deg ? 180 / pi : 1), deg ? 1 : 3),
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                  Text(f(a?[i], 2),
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                ]),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    final g = _g, a = _a;
    final gDev = g == null ? null : [g.x, g.y, g.z];
    final aDev = a == null ? null : [a.x, a.y, a.z];
    final gBow = g == null ? null : _mapper.toBow(g.x, g.y, g.z);
    final aBow = a == null ? null : _mapper.toBow(a.x, a.y, a.z);
    final detected = a == null ? null : PhonePosition.detectFromGravity(_lx, _ly, _lz);
    final target = 1000 / s.periodMs;
    final tt = Theme.of(context).textTheme;
    final hist = _hist.toList();
    final ht = [for (final h in hist) h.$1 - (hist.isEmpty ? 0 : hist.last.$1)];

    return Scaffold(
      appBar: AppBar(title: const Text('Test des capteurs')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (app.demo) const DemoBanner(),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Capteur indisponible'),
                subtitle: Text('$_error'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Unités (paquet sensors_plus)', style: tt.titleSmall),
                const SizedBox(height: 4),
                const Text('Gyroscope : rad/s (1 rad/s = 57,3 °/s). '
                    'Accéléromètre : m/s², gravité incluse (≈ 9,81 au repos).'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  StatTile('Fréq. gyroscope', '${fmtNum(_gHz, 0)} Hz',
                      hint: 'demandé ${fmtNum(target, 0)} Hz', width: 150),
                  StatTile('Fréq. accéléro.', '${fmtNum(_aHz, 0)} Hz',
                      hint: 'demandé ${fmtNum(target, 0)} Hz', width: 150),
                ]),
              ]),
            ),
          ),
          _vecTable('Repère téléphone (brut)', const ['x', 'y', 'z'], gDev, aDev, deg: false),
          _vecTable('Repère arc (${PhonePosition.byId(s.phonePosition).label.replaceAll(' – défaut', '')}, '
              '${s.handedness.label.toLowerCase()})',
              const ['X tir', 'Y vertical', 'Z latéral'], gBow, aBow, deg: true),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Position du téléphone (gravité)', style: tt.titleSmall),
                const SizedBox(height: 4),
                Text(detected == null
                    ? (a == null ? 'En attente de mesures…' : 'Téléphone à plat : position non prévue.')
                    : 'Détectée : ${PhonePosition.byId(detected).label}'),
                if (detected != null && detected != s.phonePosition)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FilledButton.tonal(
                      onPressed: () => _applyPosition(detected),
                      child: const Text('Utiliser cette position'),
                    ),
                  ),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Viseur en direct (${fmtNum(s.distanceM, 0)} m)', style: tt.titleSmall),
                const SizedBox(height: 4),
                const Text(
                    'Pas de caméra : l\'appli ne voit pas la cible, elle mesure seulement '
                    'de combien l\'arc tourne depuis le « zéro ».\n'
                    '1. Touchez « Zéro dans 3 s ».\n'
                    '2. Visez la cible (ou un point fixe) avec le viseur de l\'arc et '
                    'tenez la visée jusqu\'au bip aigu.\n'
                    '3. Visez plus à droite, plus haut… : le tracé doit partir du même côté.\n'
                    'Pendant un vrai tir, le zéro est automatique : c\'est la position '
                    'juste avant le lâcher.'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _startZero,
                    icon: const Icon(Icons.center_focus_strong),
                    label: Text(_countdown == null
                        ? 'Zéro dans 3 s'
                        : 'Zéro dans $_countdown s… (toucher = tout de suite)'),
                  ),
                ),
                const SizedBox(height: 8),
                PlaneChart(
                  series: [PlaneSeries(points: _trail.toList(), color: Colors.deepPurple)],
                  blasonCm: s.blasonCm.toDouble(),
                  fit: true,
                  xLabel: 'Latéral Z',
                  yLabel: 'Vertical Y',
                  unit: 'cm',
                ),
                const SizedBox(height: 4),
                Text('Rotations cumulées : X ${fmtSigned(_rx * 180 / pi)}°, '
                    'Y ${fmtSigned(_ry * 180 / pi)}°, Z ${fmtSigned(_rz * 180 / pi)}°',
                    style: tt.bodySmall),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gyroscope repère arc – 5 dernières secondes', style: tt.titleSmall),
                const SizedBox(height: 8),
                TimeChart(
                  series: [
                    TimeSeries('X', const Color(0xFFE53935), ht, [for (final h in hist) h.$2]),
                    TimeSeries('Y', const Color(0xFF43A047), ht, [for (final h in hist) h.$3]),
                    TimeSeries('Z', const Color(0xFF1E88E5), ht, [for (final h in hist) h.$4]),
                  ],
                  xMin: -5,
                  xMax: 0,
                  yLabel: '°/s',
                ),
                const ChartLegend([
                  ('X tir', Color(0xFFE53935)),
                  ('Y vertical', Color(0xFF43A047)),
                  ('Z latéral', Color(0xFF1E88E5)),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
