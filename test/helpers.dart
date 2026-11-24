import 'package:archymouv/core/axis_mapping.dart';
import 'package:archymouv/core/models.dart';
import 'package:archymouv/core/motion_source.dart';
import 'package:archymouv/core/recorder.dart';
import 'package:archymouv/core/simulation.dart';

/// Une flèche simulée (tir type, lâcher à 7,3 s), comme l'enregistrerait l'appli.
Arrow simulatedArrow(int n, AppSettings s, {int seed = 0}) {
  final m = AxisMapper(s.phonePosition, s.handedness);
  final shot = SimulatedShot(seed == 0 ? n : seed);
  final g = <RawEvent>[], a = <RawEvent>[];
  for (var us = 0; us <= 18000000; us += 5000) {
    final t = us / 1e6;
    final gb = shot.gyroBow(t), ab = shot.accBow(t);
    final gd = m.toDevice(gb[0], gb[1], gb[2]), ad = m.toDevice(ab[0], ab[1], ab[2]);
    g.add(RawEvent(us, gd[0], gd[1], gd[2]));
    a.add(RawEvent(us, ad[0], ad[1], ad[2]));
  }
  final now = DateTime(2026, 11, 24, 14, 30, n * 20);
  return Arrow(
    number: n,
    armedAt: now,
    triggeredAt: now.add(const Duration(milliseconds: 1400)),
    triggerMode: 'auto',
    periodMs: s.periodMs,
    samples: ArrowRecorder.resample(g, a, 1400000, s.periodMs, s.durationS),
    gyroHz: 200,
    accHz: 200,
  );
}

Training sampleTraining({int volees = 2, int arrows = 3, AppSettings? settings}) {
  final s = settings ?? AppSettings();
  final t = Training(id: 'test', startedAt: DateTime(2026, 11, 24, 14, 30), settings: s);
  for (var v = 1; v <= volees; v++) {
    final vol = Volee(
        number: v, startedAt: DateTime(2026, 11, 24, 14, 30 + v), plannedArrows: arrows);
    for (var k = 1; k <= arrows; k++) {
      vol.arrows.add(simulatedArrow(k, s, seed: v * 10 + k));
    }
    t.volees.add(vol);
  }
  return t;
}
