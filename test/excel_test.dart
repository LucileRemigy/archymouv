import 'package:archymouv/core/models.dart';
import 'package:archymouv/services/excel_export.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('Excel : une feuille par volée, flèches séparées par xxx, JSON aller-retour', () {
    final t = sampleTraining(settings: AppSettings()..handedness = Handedness.gaucher);

    // aller-retour JSON (stockage)
    final back = Training.fromJson(t.toJson());
    expect(back.arrowCount, 6);
    expect(back.settings.handedness, Handedness.gaucher);

    final bytes = buildTrainingExcelFromJson(t.toJson());
    expect(bytes.length, greaterThan(10000));
    final x = Excel.decodeBytes(bytes);
    expect(x.tables.keys, containsAll(['Entraînement', 'Volée 1', 'Volée 2']));
    final v1 = x.tables['Volée 1']!;
    // titre + en-têtes + 3 × 751 mesures + 2 séparateurs
    expect(v1.maxRows, 2 + 3 * 751 + 2);
    final sep = v1.rows[2 + 751];
    expect(sep.every((c) => c?.value.toString() == 'xxx'), isTrue);
    expect(emailSubject(t), 'archymouv entraînement du 24/11/2026 14h30');
  });
}
