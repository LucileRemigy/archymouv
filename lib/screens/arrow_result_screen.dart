import 'package:flutter/material.dart';

import '../core/analysis.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import '../widgets/shot_chart.dart';

/// Affichage après chaque flèche (ou depuis l'historique).
/// Si [nextLabel] est fourni, l'écran fait partie de la séquence
/// d'acquisition et renvoie 'next' ou 'stop'.
class ArrowResultScreen extends StatefulWidget {
  const ArrowResultScreen({
    super.key,
    required this.training,
    required this.volee,
    required this.arrow,
    this.nextLabel,
  });

  final Training training;
  final Volee volee;
  final Arrow arrow;
  final String? nextLabel;

  @override
  State<ArrowResultScreen> createState() => _ArrowResultScreenState();
}

class _ArrowResultScreenState extends State<ArrowResultScreen> {
  ChartKind _kind = ChartKind.blason;
  late final ShotAnalysis _an =
      ShotAnalysis.forArrow(widget.arrow, widget.training.settings);

  @override
  Widget build(BuildContext context) {
    final a = widget.arrow;
    final next = widget.nextLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text('Volée ${widget.volee.number} · flèche ${a.number}'),
        leading: next == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Arrêter la volée',
                onPressed: () => Navigator.pop(context, 'stop'),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          ChartKindSelector(kind: _kind, onChanged: (k) => setState(() => _kind = k)),
          const SizedBox(height: 10),
          ShotChart(
            kind: _kind,
            shots: [ShotEntry('Flèche ${a.number}', _an, Colors.blue)],
            blasonCm: widget.training.settings.blasonCm,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stats((c.maxWidth - 8) / 2),
            ),
          ),
        ],
      ),
      bottomNavigationBar: next == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 28),
                    label: Text(next, style: const TextStyle(fontSize: 18)),
                    onPressed: () => Navigator.pop(context, 'next'),
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _stats(double w) {
    final an = _an;
    final a = widget.arrow;
    final e = an.accExtremes;
    String ext(AxisExtremes x) => '${fmtSigned(x.max)} / ${fmtSigned(x.min)}';
    return [
      StatTile(
        'Lâcher',
        an.releaseT == null ? 'non détecté' : 't = ${fmtNum(an.releaseT!, 2)} s',
        hint: 'fin de phase C = origine du blason',
        icon: Icons.flash_on,
        width: w,
      ),
      StatTile(
        'Visée (phase C)',
        an.holdSpreadCm == null ? '–' : '± ${fmtNum(an.holdSpreadCm!)} cm',
        hint: an.holdGyroDegS == null
            ? 'dispersion RMS'
            : 'rotation moy. ${fmtNum(an.holdGyroDegS!)} °/s',
        icon: Icons.center_focus_strong,
        width: w,
      ),
      StatTile(
        'Inclinaison au lâcher',
        '${fmtSigned(an.cant[an.refIdx])}°',
        hint: '+ = haut de l\'arc vers la droite',
        icon: Icons.rotate_right,
        width: w,
      ),
      StatTile(
        'Accél. max',
        '${fmtNum(an.dynMax)} m/s²',
        hint: '| |a| − g | à t = ${fmtNum(an.tDynMax, 2)} s',
        icon: Icons.speed,
        width: w,
      ),
      StatTile('Accél. X (max / min)', ext(e[0]), hint: 'axe de tir, m/s²', icon: Icons.east, width: w),
      StatTile('Accél. Y (max / min)', ext(e[1]), hint: 'vertical, m/s²', icon: Icons.north, width: w),
      StatTile('Accél. Z (max / min)', ext(e[2]), hint: 'latéral, m/s²', icon: Icons.swap_horiz, width: w),
      StatTile(
        'Acquisition',
        '${an.n} mesures / ${a.periodMs} ms',
        hint: 'capteurs : gyro ${fmtNum(a.gyroHz, 0)} Hz, accél. ${fmtNum(a.accHz, 0)} Hz',
        icon: Icons.sensors,
        width: w,
      ),
      StatTile(
        'Départ ${a.triggerMode}',
        fmtTime(a.triggeredAt, seconds: true),
        hint: 'écran touché à ${fmtTime(a.armedAt, seconds: true)}',
        icon: Icons.play_circle_outline,
        width: w,
      ),
    ];
  }
}
