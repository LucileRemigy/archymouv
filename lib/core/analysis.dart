import 'dart:math';

import 'axis_mapping.dart';
import 'models.dart';

enum AimWindow {
  c('Visée C'),
  bc('B + C'),
  all('Tir complet');

  const AimWindow(this.label);
  final String label;
}

class AxisExtremes {
  const AxisExtremes(this.max, this.tMax, this.min, this.tMin);
  final double max, tMax, min, tMin;

  /// Valeur (signée) la plus grande en valeur absolue.
  double get peak => max.abs() >= min.abs() ? max : min;
  double get tPeak => max.abs() >= min.abs() ? tMax : tMin;
}

/// Analyse simple d'un tir (une flèche), dans le repère arc.
///
/// Phases :
///  - lâcher = début du choc d'accélération (ou, à défaut, du pic de rotation) ;
///  - fin de phase C = échantillon juste avant le lâcher = position de
///    référence (viseur supposé au centre du blason : z = 0, y = 0) ;
///  - C = 3 s avant le lâcher, B = 3 s avant C (durées nominales),
///    A = du début de l'enregistrement à B ;
///  - D = du lâcher jusqu'à ce que l'arc soit rattrapé (rotation faible).
class ShotAnalysis {
  ShotAnalysis._({
    required this.t,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.ax,
    required this.ay,
    required this.az,
    required this.dynAcc,
    required this.angX,
    required this.angY,
    required this.angZ,
    required this.aimH,
    required this.aimV,
    required this.cant,
    required this.releaseIdx,
    required this.refIdx,
    required this.bStart,
    required this.cStart,
    required this.dEnd,
    required this.accExtremes,
    required this.dynMax,
    required this.tDynMax,
    required this.holdSpreadCm,
    required this.holdGyroDegS,
  });

  static const g0 = 9.80665;
  static const nominalPhaseS = 3.0;

  /// Temps en secondes depuis le début de l'enregistrement.
  final List<double> t;

  /// Gyroscope repère arc (rad/s).
  final List<double> gx, gy, gz;

  /// Accéléromètre repère arc (m/s², gravité incluse).
  final List<double> ax, ay, az;

  /// Accélération dynamique | |a| − g | (m/s²).
  final List<double> dynAcc;

  /// Angles intégrés depuis t = 0 (degrés).
  final List<double> angX, angY, angZ;

  /// Position estimée du viseur sur le blason (cm), origine = fin de phase C.
  /// aimH = latéral (+ à droite), aimV = vertical (+ en haut).
  final List<double> aimH, aimV;

  /// Inclinaison de l'arc autour de l'axe de tir, calculée par la gravité
  /// (degrés, + = haut de l'arc penché à droite).
  final List<double> cant;

  final int? releaseIdx;
  final int refIdx;
  final int? bStart, cStart, dEnd;

  /// Extrêmes d'accélération X, Y, Z.
  final List<AxisExtremes> accExtremes;
  final double dynMax, tDynMax;

  /// Dispersion RMS du viseur pendant la phase C (cm).
  final double? holdSpreadCm;

  /// Rotation moyenne (Y, Z) pendant la phase C (°/s).
  final double? holdGyroDegS;

  int get n => t.length;
  double? get releaseT => releaseIdx == null ? null : t[releaseIdx!];

  /// Indices (début, fin) de la fenêtre affichée sur le blason.
  /// Pour C et B+C, on garde 0,1 s après le lâcher.
  (int, int) windowFor(AimWindow w) {
    final r = releaseIdx;
    if (r == null || w == AimWindow.all) return (0, n - 1);
    final end = min(n - 1, r + (0.1 / _dt).round());
    return (w == AimWindow.c ? cStart! : bStart!, end);
  }

  double get _dt => n > 1 ? (t.last - t.first) / (n - 1) : 0.02;

  String phaseAt(int i) {
    final r = releaseIdx;
    if (r == null) return '';
    if (i < bStart!) return 'A';
    if (i < cStart!) return 'B';
    if (i < r) return 'C';
    if (i <= dEnd!) return 'D';
    return 'fin';
  }

  static ShotAnalysis forArrow(Arrow a, AppSettings s) => ShotAnalysis.compute(
      a.samples, AxisMapper(s.phonePosition, s.handedness), s.distanceM);

  factory ShotAnalysis.compute(
      List<List<double>> samples, AxisMapper mapper, double distanceM) {
    final n = samples.length;
    List<double> z() => List<double>.filled(n, 0);
    final t = z(), gx = z(), gy = z(), gz = z(), ax = z(), ay = z(), az = z();
    final dyn = z(), cant = z(), gNorm = z(), gYZ = z();
    for (var i = 0; i < n; i++) {
      final s = samples[i];
      t[i] = s[0] / 1000;
      final g = mapper.toBow(s[1], s[2], s[3]);
      final a = mapper.toBow(s[4], s[5], s[6]);
      gx[i] = g[0];
      gy[i] = g[1];
      gz[i] = g[2];
      ax[i] = a[0];
      ay[i] = a[1];
      az[i] = a[2];
      dyn[i] = (sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]) - g0).abs();
      cant[i] = atan2(-a[2], a[1]) * 180 / pi;
      gNorm[i] = sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
      gYZ[i] = sqrt(g[1] * g[1] + g[2] * g[2]);
    }

    // Intégration des rotations (trapèzes), radians.
    final rx = z(), ry = z(), rz = z();
    for (var i = 1; i < n; i++) {
      final dt = t[i] - t[i - 1];
      rx[i] = rx[i - 1] + (gx[i] + gx[i - 1]) / 2 * dt;
      ry[i] = ry[i - 1] + (gy[i] + gy[i - 1]) / 2 * dt;
      rz[i] = rz[i - 1] + (gz[i] + gz[i - 1]) / 2 * dt;
    }

    // Extrêmes d'accélération.
    AxisExtremes ext(List<double> v) {
      var iMax = 0, iMin = 0;
      for (var i = 1; i < n; i++) {
        if (v[i] > v[iMax]) iMax = i;
        if (v[i] < v[iMin]) iMin = i;
      }
      return n == 0
          ? const AxisExtremes(0, 0, 0, 0)
          : AxisExtremes(v[iMax], t[iMax], v[iMin], t[iMin]);
    }

    var iDyn = 0;
    for (var i = 1; i < n; i++) {
      if (dyn[i] > dyn[iDyn]) iDyn = i;
    }
    final dynMax = n == 0 ? 0.0 : dyn[iDyn];

    // Lâcher.
    int? release;
    if (n > 2 && dynMax >= 12) {
      final first = dyn.indexWhere((v) => v >= 0.5 * dynMax);
      final thr = max(3.0, 0.2 * dynMax);
      var r = first;
      while (r > 0 && dyn[r - 1] > thr) {
        r--;
      }
      release = r;
    } else if (n > 2) {
      final gMax = gYZ.reduce(max);
      if (gMax > 2) {
        final thr = max(1.5, 0.3 * gMax);
        release = gYZ.indexWhere((v) => v > thr);
      }
    }
    final ref = release == null ? max(0, n - 1) : max(0, release - 1);

    // Viseur sur le blason.
    final dCm = distanceM * 100;
    double clampRad(double v) => v.clamp(-1.4, 1.4);
    final aimH = z(), aimV = z();
    if (n > 0) {
      for (var i = 0; i < n; i++) {
        aimH[i] = -dCm * tan(clampRad(ry[i] - ry[ref]));
        aimV[i] = dCm * tan(clampRad(rz[i] - rz[ref]));
      }
    }

    // Phases.
    int? bStart, cStart, dEnd;
    double? spread, holdGyro;
    if (release != null) {
      int idxAt(double time) {
        final i = t.indexWhere((v) => v >= time);
        return i < 0 ? n - 1 : i;
      }

      final tr = t[release];
      cStart = idxAt(max(0, tr - nominalPhaseS));
      bStart = idxAt(max(0, tr - 2 * nominalPhaseS));
      final dt = n > 1 ? (t.last - t.first) / (n - 1) : 0.02;
      final w = max(1, (0.1 / dt).round());
      dEnd = n - 1;
      for (var i = idxAt(tr + 0.3); i < n - w; i++) {
        var s = 0.0;
        for (var j = i; j < i + w; j++) {
          s += gNorm[j];
        }
        if (s / w < 0.35) {
          dEnd = i;
          break;
        }
      }
      if (ref > cStart) {
        var mh = 0.0, mv = 0.0, mg = 0.0;
        final cnt = ref - cStart + 1;
        for (var i = cStart; i <= ref; i++) {
          mh += aimH[i];
          mv += aimV[i];
          mg += gYZ[i];
        }
        mh /= cnt;
        mv /= cnt;
        var ss = 0.0;
        for (var i = cStart; i <= ref; i++) {
          ss += pow(aimH[i] - mh, 2) + pow(aimV[i] - mv, 2);
        }
        spread = sqrt(ss / cnt);
        holdGyro = mg / cnt * 180 / pi;
      }
    }

    List<double> deg(List<double> r) => [for (final v in r) v * 180 / pi];

    return ShotAnalysis._(
      t: t,
      gx: gx,
      gy: gy,
      gz: gz,
      ax: ax,
      ay: ay,
      az: az,
      dynAcc: dyn,
      angX: deg(rx),
      angY: deg(ry),
      angZ: deg(rz),
      aimH: aimH,
      aimV: aimV,
      cant: cant,
      releaseIdx: release,
      refIdx: ref,
      bStart: bStart,
      cStart: cStart,
      dEnd: dEnd,
      accExtremes: [ext(ax), ext(ay), ext(az)],
      dynMax: dynMax,
      tDynMax: n == 0 ? 0 : t[iDyn],
      holdSpreadCm: spread,
      holdGyroDegS: holdGyro,
    );
  }
}
