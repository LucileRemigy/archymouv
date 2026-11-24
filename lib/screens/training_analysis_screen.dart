import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/analysis.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../services/share_service.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/shot_chart.dart';

/// Analyse d'un entraînement : superposition des flèches d'une volée ou
/// de tout l'entraînement, choix du graphique, tableau récapitulatif.
class TrainingAnalysisScreen extends StatefulWidget {
  const TrainingAnalysisScreen({super.key, required this.training, this.initialVolee});
  final Training training;
  final int? initialVolee;

  @override
  State<TrainingAnalysisScreen> createState() => _TrainingAnalysisScreenState();
}

class _Item {
  _Item(this.volee, this.arrow, this.analysis);
  final Volee volee;
  final Arrow arrow;
  final ShotAnalysis analysis;
  String get key => '${volee.number}-${arrow.number}';
}

class _TrainingAnalysisScreenState extends State<TrainingAnalysisScreen> {
  late int? _volee = widget.initialVolee;
  ChartKind _kind = ChartKind.blason;
  final Set<String> _hidden = {};
  late final List<_Item> _all = [
    for (final v in widget.training.volees)
      for (final a in v.arrows) _Item(v, a, ShotAnalysis.forArrow(a, widget.training.settings)),
  ];

  List<_Item> get _items =>
      _volee == null ? _all : _all.where((i) => i.volee.number == _volee).toList();

  String _label(_Item i) => _volee == null ? 'V${i.volee.number}·${i.arrow.number}' : '${i.arrow.number}';

  @override
  Widget build(BuildContext context) {
    final t = widget.training;
    final items = _items;
    final colored = [
      for (var k = 0; k < items.length; k++) (items[k], overlayPalette[k % overlayPalette.length])
    ];
    final visible = colored.where((c) => !_hidden.contains(c.$1.key)).toList();
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse'),
        actions: [
          IconButton(
            tooltip: 'Envoyer l\'Excel par email',
            icon: const Icon(Icons.send),
            onPressed: () async {
              final msg = await sendTrainingByEmail(t, AppState.instance.settings.email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text('Volée', style: tt.labelLarge),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: const Text('Tout'),
              selected: _volee == null,
              onSelected: (_) => setState(() => _volee = null),
            ),
            for (final v in t.volees)
              if (v.arrows.isNotEmpty)
                ChoiceChip(
                  label: Text('${v.number}'),
                  selected: _volee == v.number,
                  onSelected: (_) => setState(() => _volee = v.number),
                ),
          ]),
          const SizedBox(height: 10),
          Text('Flèches affichées', style: tt.labelLarge),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (item, color) in colored)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: color, radius: 6),
                label: Text(_label(item)),
                selected: !_hidden.contains(item.key),
                showCheckmark: false,
                onSelected: (sel) => setState(
                    () => sel ? _hidden.remove(item.key) : _hidden.add(item.key)),
              ),
          ]),
          const SizedBox(height: 12),
          ChartKindSelector(kind: _kind, onChanged: (k) => setState(() => _kind = k)),
          const SizedBox(height: 10),
          ShotChart(
            kind: _kind,
            shots: [for (final (i, c) in visible) ShotEntry(_label(i), i.analysis, c)],
            blasonCm: t.settings.blasonCm,
          ),
          const SectionTitle('Récapitulatif'),
          _table(visible),
        ],
      ),
    );
  }

  Widget _table(List<(_Item, Color)> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    double? avg(double? Function(ShotAnalysis a) f) {
      final v = [for (final (i, _) in rows) f(i.analysis)].whereType<double>().toList();
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    String n(double? v, [int d = 1]) => v == null ? '–' : fmtNum(v, d);
    DataRow row(String label, Color? color, ShotAnalysis? a, {bool bold = false}) {
      final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
      double? cant(ShotAnalysis x) => x.cant[x.refIdx];
      return DataRow(cells: [
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          if (color != null) ...[CircleAvatar(backgroundColor: color, radius: 5), const SizedBox(width: 6)],
          Text(label, style: style),
        ])),
        DataCell(Text(n(a == null ? avg((x) => x.releaseT) : a.releaseT, 2), style: style)),
        DataCell(Text(n(a == null ? avg((x) => x.holdSpreadCm) : a.holdSpreadCm), style: style)),
        DataCell(Text(n(a == null ? avg((x) => x.holdGyroDegS) : a.holdGyroDegS), style: style)),
        DataCell(Text(n(a == null ? avg(cant) : cant(a)), style: style)),
        DataCell(Text(n(a == null ? avg((x) => x.dynMax) : a.dynMax), style: style)),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 44,
        columns: const [
          DataColumn(label: Text('Flèche')),
          DataColumn(label: Text('Lâcher\n(s)'), numeric: true),
          DataColumn(label: Text('Visée C\n± cm'), numeric: true),
          DataColumn(label: Text('Rotation C\n°/s'), numeric: true),
          DataColumn(label: Text('Inclin.\n°'), numeric: true),
          DataColumn(label: Text('Accél. max\nm/s²'), numeric: true),
        ],
        rows: [
          for (final (i, c) in rows) row(_label(i), c, i.analysis),
          if (rows.length > 1) row('Moyenne', null, null, bold: true),
        ],
      ),
    );
  }
}
