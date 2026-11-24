import 'package:archymouv/app_state.dart';
import 'package:archymouv/core/analysis.dart';
import 'package:archymouv/core/models.dart';
import 'package:archymouv/screens/arrow_result_screen.dart';
import 'package:archymouv/screens/sensor_test_screen.dart';
import 'package:archymouv/screens/settings_screen.dart';
import 'package:archymouv/screens/training_analysis_screen.dart';
import 'package:archymouv/screens/training_screen.dart';
import 'package:archymouv/widgets/shot_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Écran de téléphone 360 × 780 dp.
Future<void> pumpPhone(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pump();
}

/// Remonte en haut de la liste principale, la fait défiler jusqu'au texte
/// puis le touche.
Future<void> tapText(WidgetTester tester, String text) async {
  final list = find.byType(Scrollable).first;
  await tester.drag(list, const Offset(0, 5000));
  await tester.pump();
  for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -200));
    await tester.pump();
  }
  await tester.ensureVisible(find.text(text).first);
  await tester.pump();
  await tester.tap(find.text(text).first);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance = AppState(AppSettings()..demoMode = true);
  });

  testWidgets('résultat d\'une flèche : tous les graphiques et fenêtres', (tester) async {
    final t = sampleTraining(volees: 1, arrows: 1);
    await pumpPhone(
      tester,
      ArrowResultScreen(
        training: t,
        volee: t.volees.first,
        arrow: t.volees.first.arrows.first,
        nextLabel: 'Flèche suivante (2)',
      ),
    );
    expect(find.text('Flèche suivante (2)'), findsOneWidget);
    // lâcher détecté (tuile sous le graphique)
    await tester.scrollUntilVisible(find.text('INCLINAISON AU LÂCHER'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('t = 7,'), findsWidgets);
    for (final k in ChartKind.values) {
      await tapText(tester, k.label);
      if (k.isPlane) {
        for (final w in AimWindow.values) {
          await tapText(tester, w.label);
        }
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('analyse de l\'entraînement : superposition volée / tout', (tester) async {
    final t = sampleTraining(volees: 2, arrows: 3);
    await pumpPhone(tester, TrainingAnalysisScreen(training: t, initialVolee: 1));
    await tester.scrollUntilVisible(find.text('Moyenne'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Moyenne'), findsOneWidget);
    for (final k in ChartKind.values) {
      await tapText(tester, k.label);
    }
    await tapText(tester, 'Tout');
    expect(find.text('V2·3'), findsWidgets);
    await tapText(tester, ChartKind.blason.label);
    await tapText(tester, AimWindow.all.label);
    // masquer une flèche
    await tapText(tester, 'V1·1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('écran entraînement', (tester) async {
    final t = sampleTraining(volees: 2, arrows: 3);
    await pumpPhone(tester, TrainingScreen(training: t));
    expect(find.text('Volée 1'), findsOneWidget);
    expect(find.text('Volée 2'), findsOneWidget);
    expect(find.text('Mesure de départ · volée 3'), findsOneWidget);
    await tester.tap(find.text('Mesure de départ · volée 3'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre de flèches'), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('6')),
        findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('paramètres : modification et sauvegarde', (tester) async {
    await pumpPhone(tester, const SettingsScreen());
    await tapText(tester, 'Gaucher');
    expect(AppState.instance.settings.handedness, Handedness.gaucher);
    await tapText(tester, 'Horizontal, haut vers la cible');
    expect(AppState.instance.settings.phonePosition, 'paysage_cible');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('archymouv.settings'), contains('paysage_cible'));
    await tester.scrollUntilVisible(find.text('Mode démo (capteurs simulés)'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Mode démo (capteurs simulés)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test des capteurs (simulés)', (tester) async {
    await pumpPhone(tester, const SensorTestScreen());
    expect(find.text('Unités (paquet sensors_plus)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
