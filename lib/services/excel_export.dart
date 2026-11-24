import 'package:excel/excel.dart';

import '../core/analysis.dart';
import '../core/format.dart';
import '../core/models.dart';

String excelFileName(Training t) =>
    'archymouv_${t.startedAt.year}-${two(t.startedAt.month)}-${two(t.startedAt.day)}'
    '_${two(t.startedAt.hour)}h${two(t.startedAt.minute)}.xlsx';

String emailSubject(Training t) =>
    'archymouv entraînement du ${fmtDate(t.startedAt)} ${fmtTime(t.startedAt)}';

String emailBody(Training t) =>
    'Entraînement du ${fmtDate(t.startedAt)} à ${fmtTime(t.startedAt)}\n'
    '${t.volees.length} volée(s), ${t.arrowCount} flèche(s).\n'
    'Distance ${fmtNum(t.settings.distanceM, 0)} m, blason ${t.settings.blasonCm} cm, '
    '${t.settings.bowType} ${fmtNum(t.settings.drawWeightLbs, 0)} lbs, '
    '${t.settings.handedness.label.toLowerCase()}.\n\n'
    'Fichier Excel en pièce jointe (une feuille par volée).';

/// Point d'entrée pour compute() : JSON -> octets du fichier .xlsx.
List<int> buildTrainingExcelFromJson(Map<String, dynamic> json) =>
    buildTrainingExcel(Training.fromJson(json));

/// Construit le classeur :
///  - feuille « Entraînement » : paramètres + résumé de chaque flèche ;
///  - une feuille par volée : toutes les mesures, flèches séparées par
///    une ligne de « xxx ».
List<int> buildTrainingExcel(Training t) {
  final excel = Excel.createExcel();
  const summary = 'Entraînement';
  final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  excel.rename(defaultSheet, summary);
  final s = t.settings;
  final sum = excel[summary];

  CellValue tx(String v) => TextCellValue(v);
  CellValue db(double v, [int digits = 4]) {
    final p = digits == 4 ? 10000 : (digits == 2 ? 100 : 10);
    return DoubleCellValue((v * p).roundToDouble() / p);
  }

  CellValue it(int v) => IntCellValue(v);

  sum.appendRow([tx(emailSubject(t))]);
  sum.appendRow([]);
  final params = <List<CellValue>>[
    [tx('Date'), tx(fmtDate(t.startedAt))],
    [tx('Heure'), tx(fmtTime(t.startedAt, seconds: true))],
    [tx('Distance (m)'), db(s.distanceM, 1)],
    [tx('Blason (cm)'), it(s.blasonCm)],
    [tx('Type d\'arc'), tx(s.bowType)],
    [tx('Puissance (lbs)'), db(s.drawWeightLbs, 1)],
    [tx('Main'), tx(s.handedness.label)],
    [tx('Position du téléphone'), tx(PhonePosition.byId(s.phonePosition).label)],
    [tx('Durée d\'acquisition (s)'), it(s.durationS)],
    [tx('Période d\'acquisition (ms)'), it(s.periodMs)],
    [
      tx('Déclenchement'),
      tx(s.autoTrigger
          ? 'auto : arc baissé puis remonté, départ ${s.triggerDelayMs} ms après le point bas'
          : 'manuel (toucher de l\'écran)')
    ],
  ];
  params.forEach(sum.appendRow);
  sum.appendRow([]);
  for (final line in const [
    'Repère arc : X = axe de tir (+ vers la cible), Y = vertical (+ vers le haut), Z = latéral (+ à droite face à la cible).',
    'Gyroscope en °/s (le capteur fournit des rad/s ; 1 rad/s = 57,3 °/s). Accéléromètre en m/s², gravité incluse.',
    'Visée : position estimée du viseur sur le blason (cm). Origine = fin de la phase C (juste avant le lâcher).',
    'Phases : A préparation, B armement (3 s nominal), C visée (3 s nominal), D volée de la flèche.',
  ]) {
    sum.appendRow([tx(line)]);
  }
  sum.appendRow([]);

  final headers = [
    'Volée', 'Flèche', 'Heure toucher', 'Heure départ', 'Déclenchement',
    'Lâcher t (s)', 'Dispersion visée phase C (cm)', 'Rotation moy. phase C (°/s)',
    'Inclinaison au lâcher (°)', '| |a|-g | max (m/s²)', 't max (s)',
    'Acc X max', 'Acc X min', 'Acc Y max', 'Acc Y min', 'Acc Z max', 'Acc Z min',
    'Fréq. gyro (Hz)', 'Fréq. accél. (Hz)',
  ];
  sum.appendRow([for (final h in headers) tx(h)]);

  final analyses = <Arrow, ShotAnalysis>{};
  for (final v in t.volees) {
    for (final a in v.arrows) {
      final an = analyses[a] = ShotAnalysis.forArrow(a, s);
      final e = an.accExtremes;
      sum.appendRow([
        it(v.number),
        it(a.number),
        tx(fmtTime(a.armedAt, seconds: true)),
        tx(fmtTime(a.triggeredAt, seconds: true)),
        tx(a.triggerMode),
        an.releaseT == null ? tx('non détecté') : db(an.releaseT!, 2),
        an.holdSpreadCm == null ? tx('') : db(an.holdSpreadCm!, 2),
        an.holdGyroDegS == null ? tx('') : db(an.holdGyroDegS!, 2),
        db(an.cant[an.refIdx], 1),
        db(an.dynMax, 2),
        db(an.tDynMax, 2),
        db(e[0].max, 2), db(e[0].min, 2),
        db(e[1].max, 2), db(e[1].min, 2),
        db(e[2].max, 2), db(e[2].min, 2),
        db(a.gyroHz, 1),
        db(a.accHz, 1),
      ]);
    }
  }
  sum.setColumnWidth(0, 28);

  const cols = [
    'Flèche', 'Heure départ', 't (ms)',
    'Gyro X (°/s)', 'Gyro Y (°/s)', 'Gyro Z (°/s)',
    'Acc X (m/s²)', 'Acc Y (m/s²)', 'Acc Z (m/s²)',
    'Visée latérale (cm)', 'Visée verticale (cm)', 'Inclinaison (°)', 'Phase',
  ];
  const radToDeg = 57.29577951308232;
  for (final v in t.volees) {
    final sh = excel['Volée ${v.number}'];
    sh.appendRow([
      tx('Volée ${v.number} – début ${fmtTime(v.startedAt, seconds: true)} – '
          '${v.arrows.length} flèche(s)')
    ]);
    sh.appendRow([for (final c in cols) tx(c)]);
    for (var k = 0; k < v.arrows.length; k++) {
      final a = v.arrows[k];
      if (k > 0) sh.appendRow([for (final _ in cols) tx('xxx')]);
      final an = analyses[a]!;
      final start = fmtTime(a.triggeredAt, seconds: true);
      for (var i = 0; i < an.n; i++) {
        sh.appendRow([
          it(a.number),
          tx(start),
          it((an.t[i] * 1000).round()),
          db(an.gx[i] * radToDeg, 2),
          db(an.gy[i] * radToDeg, 2),
          db(an.gz[i] * radToDeg, 2),
          db(an.ax[i]),
          db(an.ay[i]),
          db(an.az[i]),
          db(an.aimH[i], 2),
          db(an.aimV[i], 2),
          db(an.cant[i], 2),
          tx(an.phaseAt(i)),
        ]);
      }
    }
  }
  excel.setDefaultSheet(summary);
  return excel.encode()!;
}
