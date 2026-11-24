import 'package:archymouv/core/analysis.dart';
import 'package:archymouv/core/axis_mapping.dart';
import 'package:archymouv/core/motion_source.dart';
import 'package:archymouv/core/recorder.dart';
import 'package:archymouv/core/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Génère les événements bruts (repère téléphone) d'un tir simulé à 200 Hz.
(List<RawEvent>, List<RawEvent>) simulate(AxisMapper m, {int seed = 3}) {
  final shot = SimulatedShot(seed);
  final g = <RawEvent>[], a = <RawEvent>[];
  for (var us = 0; us <= 18000000; us += 5000) {
    final t = us / 1e6;
    final gb = shot.gyroBow(t), ab = shot.accBow(t);
    final gd = m.toDevice(gb[0], gb[1], gb[2]);
    final ad = m.toDevice(ab[0], ab[1], ab[2]);
    g.add(RawEvent(us, gd[0], gd[1], gd[2]));
    a.add(RawEvent(us, ad[0], ad[1], ad[2]));
  }
  return (g, a);
}

void main() {
  test('mapping téléphone -> arc réversible pour toutes les positions', () {
    for (final p in PhonePosition.all) {
      for (final h in Handedness.values) {
        final m = AxisMapper(p.id, h);
        final b = m.toBow(1, 2, 3);
        final d = m.toDevice(b[0], b[1], b[2]);
        expect(d, [1.0, 2.0, 3.0], reason: '${p.id} $h');
      }
    }
  });

  test('détection de la position par la gravité', () {
    expect(PhonePosition.detectFromGravity(0.3, 9.7, 0.5), 'portrait');
    expect(PhonePosition.detectFromGravity(0.3, -9.7, 0.5), 'portrait_inverse');
    expect(PhonePosition.detectFromGravity(-9.7, 0.3, 0.5), 'paysage_cible');
    expect(PhonePosition.detectFromGravity(9.7, 0.3, 0.5), 'paysage_archer');
    expect(PhonePosition.detectFromGravity(0.3, 0.3, 9.8), isNull);
    // cohérence avec le mapping : la gravité doit tomber sur +Y arc
    for (final p in PhonePosition.all) {
      final d = AxisMapper(p.id, Handedness.droitier).toDevice(0, 9.81, 0);
      expect(PhonePosition.detectFromGravity(d[0], d[1], d[2]), p.id);
    }
  });

  test('déclenchement : arc baissé puis remonté -> point bas + 200 ms', () {
    final m = AxisMapper('portrait', Handedness.droitier);
    final (g, _) = simulate(m);
    final det = TriggerDetector(dropDeg: 5, riseDeg: 5);
    int? trigUs;
    for (final e in g) {
      final b = m.toBow(e.x, e.y, e.z);
      if (det.addGyro(e.tUs, b[2])) {
        trigUs = e.tUs;
        break;
      }
    }
    expect(trigUs, isNotNull);
    // point bas simulé à 1,2 s (lowUs = début de la remontée)
    expect(det.lowUs! / 1e6, closeTo(1.2, 0.15));
    expect(trigUs! / 1e6, lessThan(1.8));
  });

  test('ré-échantillonnage 20 ms sur 15 s', () {
    final m = AxisMapper('portrait', Handedness.droitier);
    final (g, a) = simulate(m);
    final s = ArrowRecorder.resample(g, a, 1400000, 20, 15);
    expect(s.length, 751);
    expect(s.first[0], 0);
    expect(s.last[0], 15000);
    expect(s.every((r) => r.length == 7), isTrue);
  });

  for (final pos in PhonePosition.all) {
    for (final h in Handedness.values) {
      test('analyse : lâcher détecté et viseur stable (${pos.id}, ${h.name})',
          () {
        final m = AxisMapper(pos.id, h);
        final (g, a) = simulate(m);
        const t0 = 1400000; // 1,2 s (point bas) + 200 ms
        final s = ArrowRecorder.resample(g, a, t0, 20, 15);
        final an = ShotAnalysis.compute(s, m, 18);
        // lâcher simulé à 8,7 s -> 7,3 s après t0
        expect(an.releaseT, closeTo(7.3, 0.05));
        expect(an.phaseAt(an.releaseIdx! - 1), 'C');
        expect(an.phaseAt(an.releaseIdx!), 'D');
        // à la référence, le viseur est au centre
        expect(an.aimH[an.refIdx], closeTo(0, 1e-9));
        expect(an.aimV[an.refIdx], closeTo(0, 1e-9));
        // en phase C le viseur bouge de quelques cm à 18 m
        expect(an.holdSpreadCm, isNotNull);
        expect(an.holdSpreadCm!, lessThan(15));
        // la gravité est bien sur +Y arc au repos
        expect(an.ay[an.refIdx], greaterThan(9));
        // pic d'accélération X positif (l'arc part vers la cible)
        expect(an.accExtremes[0].peak, greaterThan(12));
      });
    }
  }
}
