import 'dart:math';

import 'package:flutter/material.dart';

import '../core/analysis.dart';
import 'charts.dart';

enum ChartKind {
  blason('Blason (viseur)'),
  gyroPlane('Gyro z / y'),
  accel('Accélérations'),
  gyroTime('Gyroscope'),
  cant('Verticalité');

  const ChartKind(this.label);
  final String label;

  bool get isPlane => this == blason || this == gyroPlane;
}

class ShotEntry {
  const ShotEntry(this.label, this.analysis, this.color);
  final String label;
  final ShotAnalysis analysis;
  final Color color;
}

class ChartKindSelector extends StatelessWidget {
  const ChartKindSelector({super.key, required this.kind, required this.onChanged});
  final ChartKind kind;
  final ValueChanged<ChartKind> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in ChartKind.values)
            ChoiceChip(
              label: Text(k.label),
              selected: k == kind,
              onSelected: (_) => onChanged(k),
            ),
        ],
      );
}

const _rad2deg = 180 / pi;

/// Graphique d'une flèche (couleur = accélération) ou superposition de
/// plusieurs flèches (une couleur par flèche, alignées sur le lâcher).
class ShotChart extends StatefulWidget {
  const ShotChart({
    super.key,
    required this.kind,
    required this.shots,
    required this.blasonCm,
  });

  final ChartKind kind;
  final List<ShotEntry> shots;
  final int blasonCm;

  @override
  State<ShotChart> createState() => _ShotChartState();
}

class _ShotChartState extends State<ShotChart> {
  AimWindow _win = AimWindow.c;

  ChartKind get kind => widget.kind;
  List<ShotEntry> get shots => widget.shots;

  @override
  Widget build(BuildContext context) {
    if (shots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune flèche sélectionnée')),
      );
    }
    final chart = shots.length == 1 ? _single(context, shots.first) : _overlay(context);
    if (!kind.isPlane) return chart;
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<AimWindow>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final w in AimWindow.values) ButtonSegment(value: w, label: Text(w.label)),
          ],
          selected: {_win},
          onSelectionChanged: (s) => setState(() => _win = s.first),
        ),
      ),
      const SizedBox(height: 8),
      chart,
    ]);
  }

  /// Fenêtre de tracé pour les graphiques plans. Pour le gyroscope on
  /// s'arrête au lâcher (sauf « tir complet ») : la bascule de l'arc
  /// écraserait l'échelle.
  (int, int) _range(ShotAnalysis a) {
    final (w0, w1) = a.windowFor(_win);
    if (kind == ChartKind.gyroPlane && _win != AimWindow.all) {
      return (w0, max(w0, min(a.refIdx, w1)));
    }
    return (w0, w1);
  }

  Offset _point(ShotAnalysis a, int i) => kind == ChartKind.blason
      ? Offset(a.aimH[i], a.aimV[i])
      : Offset(a.gz[i] * _rad2deg, a.gy[i] * _rad2deg);

  Widget _plane(List<PlaneSeries> series) => PlaneChart(
        series: series,
        blasonCm: kind == ChartKind.blason ? widget.blasonCm.toDouble() : null,
        fit: _win == AimWindow.all,
        xLabel: kind == ChartKind.blason ? 'Latéral Z' : 'ω Z',
        yLabel: kind == ChartKind.blason ? 'Vertical Y' : 'ω Y',
        unit: kind == ChartKind.blason ? 'cm' : '°/s',
      );

  String get _windowNote => switch (_win) {
        AimWindow.c => 'Phase C (3 s avant le lâcher) + 0,1 s après.',
        AimWindow.bc => 'Phases B + C (6 s avant le lâcher) + 0,1 s après.',
        AimWindow.all => 'Tout l\'enregistrement.',
      };

  // ---------------- une flèche ----------------

  Widget _single(BuildContext context, ShotEntry e) {
    final a = e.analysis;
    final phases = a.releaseIdx == null
        ? null
        : PhaseMarks(
            b: a.t[a.bStart!],
            c: a.t[a.cStart!],
            d: a.t[a.releaseIdx!],
            end: a.t[a.dEnd!],
          );

    if (kind.isPlane) {
      final (w0, w1) = _range(a);
      // échelle de couleur calculée jusqu'au lâcher (le choc écraserait tout)
      final cEnd = max(w0, min(a.refIdx, w1));
      var lo = double.infinity, hi = -double.infinity;
      for (var i = w0; i <= cEnd; i++) {
        lo = min(lo, a.dynAcc[i]);
        hi = max(hi, a.dynAcc[i]);
      }
      if (!lo.isFinite) {
        lo = 0;
        hi = 1;
      }
      final span = max(hi - lo, 1e-6);
      return Column(children: [
        _plane([
          PlaneSeries(
            points: [for (var i = w0; i <= w1; i++) _point(a, i)],
            colors: [for (var i = w0; i <= w1; i++) accColor((a.dynAcc[i] - lo) / span)],
          ),
        ]),
        const SizedBox(height: 6),
        AccelScaleBar(min: lo, max: hi),
        _note(context, '▲ début   ★ fin.  $_windowNote'),
        if (kind == ChartKind.blason)
          _note(context, 'Origine = fin de la phase C (lâcher), supposée au centre du jaune.'),
      ]);
    }

    switch (kind) {
      case ChartKind.accel:
        return Column(children: [
          TimeChart(
            series: [
              TimeSeries('X tir', const Color(0xFFE53935), a.t, a.ax),
              TimeSeries('Y vertical', const Color(0xFF43A047), a.t, a.ay),
              TimeSeries('Z latéral', const Color(0xFF1E88E5), a.t, a.az),
              TimeSeries('| |a| − g |', Colors.grey, a.t, a.dynAcc, width: 1),
            ],
            phases: phases,
            yLabel: 'Accélération (m/s²)',
          ),
          const SizedBox(height: 6),
          const ChartLegend([
            ('X tir', Color(0xFFE53935)),
            ('Y vertical', Color(0xFF43A047)),
            ('Z latéral', Color(0xFF1E88E5)),
            ('| |a| − g |', Colors.grey),
          ]),
        ]);
      case ChartKind.gyroTime:
        List<double> deg(List<double> v) => [for (final x in v) x * _rad2deg];
        return Column(children: [
          TimeChart(
            series: [
              TimeSeries('X', const Color(0xFFE53935), a.t, deg(a.gx)),
              TimeSeries('Y', const Color(0xFF43A047), a.t, deg(a.gy)),
              TimeSeries('Z', const Color(0xFF1E88E5), a.t, deg(a.gz)),
            ],
            phases: phases,
            yLabel: 'Rotation (°/s)',
          ),
          const SizedBox(height: 6),
          const ChartLegend([
            ('ω X : bascule (verticalité)', Color(0xFFE53935)),
            ('ω Y : visée gauche/droite', Color(0xFF43A047)),
            ('ω Z : visée haut/bas', Color(0xFF1E88E5)),
          ]),
        ]);
      default:
        final ref = a.angX[a.refIdx];
        final cantRef = a.cant[a.refIdx];
        return Column(children: [
          TimeChart(
            series: [
              TimeSeries('Inclinaison (gravité)', const Color(0xFF8E24AA), a.t, a.cant),
              TimeSeries('Rotation X intégrée', const Color(0xFF00ACC1), a.t,
                  [for (final v in a.angX) v - ref + cantRef]),
            ],
            phases: phases,
            yLabel: 'Inclinaison (°)',
          ),
          const SizedBox(height: 6),
          const ChartLegend([
            ('Inclinaison mesurée par la gravité', Color(0xFF8E24AA)),
            ('Rotation X intégrée (gyro)', Color(0xFF00ACC1)),
          ]),
          _note(context, '+ = haut de l\'arc penché vers la droite (face à la cible).'),
        ]);
    }
  }

  // ---------------- plusieurs flèches ----------------

  Widget _overlay(BuildContext context) {
    final legend = ChartLegend([for (final s in shots) (s.label, s.color)]);
    if (kind.isPlane) {
      final series = <PlaneSeries>[];
      for (final s in shots) {
        final a = s.analysis;
        final (w0, w1) = _range(a);
        series.add(PlaneSeries(
          color: s.color,
          width: 1.6,
          points: [for (var i = w0; i <= w1; i++) _point(a, i)],
        ));
      }
      return Column(children: [
        _plane(series),
        const SizedBox(height: 6),
        legend,
        _note(context, '▲ début, ★ fin. Chaque flèche est recentrée sur son lâcher. $_windowNote'),
      ]);
    }

    final series = <TimeSeries>[];
    for (final s in shots) {
      final a = s.analysis;
      final t0 = a.releaseT ?? a.t.last;
      final t = [for (final v in a.t) v - t0];
      final List<double> v = switch (kind) {
        ChartKind.accel => a.dynAcc,
        ChartKind.gyroTime => [
            for (var i = 0; i < a.n; i++)
              sqrt(a.gy[i] * a.gy[i] + a.gz[i] * a.gz[i]) * _rad2deg
          ],
        _ => a.cant,
      };
      series.add(TimeSeries(s.label, s.color, t, v));
    }
    final label = switch (kind) {
      ChartKind.accel => '| |a| − g | (m/s²)',
      ChartKind.gyroTime => 'Rotation Y+Z (°/s)',
      _ => 'Inclinaison (°)',
    };
    return Column(children: [
      TimeChart(
        series: series,
        xMin: -6.5,
        xMax: 2,
        markerX: 0,
        yLabel: label,
        xLabel: 't − t lâcher (s)',
      ),
      const SizedBox(height: 6),
      legend,
    ]);
  }

  Widget _note(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(s, style: Theme.of(context).textTheme.bodySmall),
      );
}
