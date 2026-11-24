import 'dart:async';
import 'dart:math';

import 'axis_mapping.dart';
import 'motion_source.dart';

/// Tir simulé (repère arc) pour tester l'appli sans téléphone ni arc.
///
/// t = secondes depuis que l'archer a touché l'écran :
///  0,0 – 0,5 s  arc au repos, un peu baissé
///  0,5 – 1,2 s  l'arc est baissé (point bas)       → déclenchement à 1,2 + 0,2 s
///  1,2 – 2,7 s  phase A : élévation de l'arc
///  2,7 – 5,7 s  phase B : armement (3 s)
///  5,7 – 8,7 s  phase C : visée, passage du clicker (3 s)
///  8,7 s        lâcher : choc vers l'avant, l'arc bascule (phase D)
class SimulatedShot {
  SimulatedShot([int seed = 1]) : _rnd = Random(seed) {
    double r(double a) => (_rnd.nextDouble() * 2 - 1) * a;
    _pitchK = [
      (0.0, -10.0),
      (0.5, -10.0),
      (1.2, -35.0 + r(4)),
      (2.7, 2.0 + r(1.5)),
      (5.7, 0.25 + r(0.15)),
      (releaseT, 0.0),
      (11.5, 0.0),
      (14.0, -20.0),
    ];
    _yawK = [
      (0.0, 6.0),
      (1.2, 9.0 + r(3)),
      (2.7, 1.0 + r(1.5)),
      (5.7, 0.2 + r(0.15)),
      (releaseT, 0.0),
    ];
    _cant = r(2.5);
    _drop = 50 + r(10);
    _yawSwing = r(15);
    _phases = List.generate(9, (_) => _rnd.nextDouble() * 2 * pi);
    _tremor = 0.8 + _rnd.nextDouble() * 0.6;
  }

  static const releaseT = 8.7;
  static const g0 = 9.80665;

  final Random _rnd;
  late final List<(double, double)> _pitchK;
  late final List<(double, double)> _yawK;
  late final double _cant, _drop, _yawSwing, _tremor;
  late final List<double> _phases;

  static double _interp(List<(double, double)> k, double t) {
    if (t <= k.first.$1) return k.first.$2;
    for (var i = 1; i < k.length; i++) {
      if (t <= k[i].$1) {
        final (t0, v0) = k[i - 1];
        final (t1, v1) = k[i];
        var f = (t - t0) / (t1 - t0);
        f = f * f * (3 - 2 * f);
        return v0 + (v1 - v0) * f;
      }
    }
    return k.last.$2;
  }

  /// Amplitude du tremblement (degrés) selon la phase.
  double _amp(double t) {
    if (t < 2.7) return 0.25;
    if (t < 5.7) return 0.2 * _tremor;
    if (t < releaseT) {
      final f = (t - 5.7) / 3;
      return (0.1 - 0.05 * f) * _tremor;
    }
    return 0;
  }

  double _wobble(double t, int k) {
    final p = _phases;
    return sin(2 * pi * 0.7 * t + p[k]) +
        0.6 * sin(2 * pi * 2.3 * t + p[k + 1]) +
        0.3 * sin(2 * pi * 7.0 * t + p[k + 2]);
  }

  double _after(double t, double tau) =>
      t <= releaseT ? 0 : 1 - exp(-(t - releaseT) / tau);

  /// Inclinaison avant/arrière (rotation autour de Z), degrés, + = nez vers le haut.
  double pitch(double t) =>
      _interp(_pitchK, t) + _amp(t) * _wobble(t, 0) - _drop * _after(t, 0.15);

  /// Rotation autour de la verticale Y, degrés, + = visée vers la gauche.
  double yaw(double t) =>
      _interp(_yawK, t) + 1.2 * _amp(t) * _wobble(t, 3) + _yawSwing * _after(t, 0.25);

  /// Rotation autour de l'axe de tir X (verticalité), degrés.
  double roll(double t) =>
      _cant + 0.6 * _amp(t) * _wobble(t, 6) + 6 * _after(t, 0.2);

  /// Gyroscope repère arc, rad/s.
  List<double> gyroBow(double t) {
    const h = 0.001;
    double d(double Function(double) f) =>
        (f(t + h) - f(t - h)) / (2 * h) * pi / 180;
    return [
      d(roll) + _noise(0.004),
      d(yaw) + _noise(0.004),
      d(pitch) + _noise(0.004),
    ];
  }

  /// Accéléromètre repère arc, m/s² (gravité incluse).
  List<double> accBow(double t) {
    final th = pitch(t) * pi / 180;
    final ph = roll(t) * pi / 180;
    var ax = -g0 * sin(th);
    var ay = g0 * cos(th) * cos(ph);
    var az = -g0 * cos(th) * sin(ph);
    final dt = t - releaseT;
    if (dt >= 0 && dt < 0.25) {
      // choc du lâcher : l'arc part vers la cible
      ax += 60 * exp(-dt / 0.015) - 12 * exp(-dt / 0.06) * sin(dt / 0.03);
      ay += -15 * exp(-dt / 0.02);
      az += 6 * exp(-dt / 0.03) * sin(dt / 0.01);
    }
    final dc = t - (releaseT + 0.8);
    if (dc >= 0 && dc < 0.2) {
      // l'arc est rattrapé (dragonne)
      ax += -14 * exp(-dc / 0.04);
    }
    return [ax + _noise(0.06), ay + _noise(0.06), az + _noise(0.06)];
  }

  double _noise(double a) => (_rnd.nextDouble() * 2 - 1) * a;
}

/// Source de mesures simulées : rejoue un tir à chaque fois que l'archer
/// touche l'écran (et en boucle sinon). Fréquence interne : 200 Hz.
class SimulatedMotionSource extends MotionSource {
  SimulatedMotionSource(this.mapper, {this.cycleS = 18});

  final AxisMapper mapper;
  final double cycleS;
  final _g = StreamController<RawEvent>.broadcast();
  final _a = StreamController<RawEvent>.broadcast();
  Timer? _timer;
  int _lastUs = 0;
  int _originUs = 0;
  int _seed = 1;
  SimulatedShot _shot = SimulatedShot(1);

  static const _stepUs = 5000;

  void _ensureRunning() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 10), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_lastUs == 0) {
      _lastUs = now;
      _originUs = now;
    }
    while (_lastUs + _stepUs <= now) {
      _lastUs += _stepUs;
      var t = (_lastUs - _originUs) / 1e6;
      if (t > cycleS) {
        _originUs = _lastUs;
        _shot = SimulatedShot(++_seed);
        t = 0;
      }
      final gb = _shot.gyroBow(t);
      final ab = _shot.accBow(t);
      final gd = mapper.toDevice(gb[0], gb[1], gb[2]);
      final ad = mapper.toDevice(ab[0], ab[1], ab[2]);
      _g.add(RawEvent(_lastUs, gd[0], gd[1], gd[2]));
      _a.add(RawEvent(_lastUs, ad[0], ad[1], ad[2]));
    }
  }

  @override
  Stream<RawEvent> gyro(Duration period) {
    _ensureRunning();
    return _g.stream;
  }

  @override
  Stream<RawEvent> accel(Duration period) {
    _ensureRunning();
    return _a.stream;
  }

  @override
  void onArmed() {
    _originUs = _lastUs;
    _shot = SimulatedShot(++_seed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _g.close();
    _a.close();
  }
}
