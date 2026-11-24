import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../services/share_service.dart';
import '../widgets/common.dart';
import 'acquisition_screen.dart';
import 'arrow_result_screen.dart';
import 'training_analysis_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, required this.training});
  final Training training;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  Training get t => widget.training;
  bool _sending = false;

  Future<void> _newVolee() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => _ArrowCountDialog(initial: t.settings.arrowsPerEnd),
    );
    if (count == null || !mounted) return;
    final v = Volee(number: t.volees.length + 1, startedAt: DateTime.now(), plannedArrows: count);
    t.volees.add(v);
    await _acquire(v);
  }

  Future<void> _acquire(Volee v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AcquisitionScreen(training: t, volee: v)),
    );
    if (v.arrows.isEmpty) t.volees.remove(v);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    if (t.arrowCount == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aucune flèche à envoyer')));
      return;
    }
    setState(() => _sending = true);
    try {
      final msg = await sendTrainingByEmail(t, AppState.instance.settings.email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _analysis([int? volee]) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TrainingAnalysisScreen(training: t, initialVolee: volee)),
      );

  void _openArrow(Volee v, Arrow a) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArrowResultScreen(training: t, volee: v, arrow: a)),
      );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Entraînement'),
          Text('${fmtDate(t.startedAt)} · ${fmtTime(t.startedAt)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Analyse de l\'entraînement',
            icon: const Icon(Icons.insights),
            onPressed: t.arrowCount == 0 ? null : _analysis,
          ),
          IconButton(
            tooltip: 'Envoyer l\'Excel par email',
            icon: _sending
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            onPressed: _sending ? null : _send,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.adjust),
        label: Text('Mesure de départ · volée ${t.volees.length + 1}'),
        onPressed: _newVolee,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          ConditionsSummary(t.settings),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Counter('Volées', '${t.volees.length}')),
            const SizedBox(width: 8),
            Expanded(child: _Counter('Flèches', '${t.arrowCount}')),
            const SizedBox(width: 8),
            Expanded(
                child: _Counter('Envoi', t.sentAt == null ? 'à faire' : fmtDate(t.sentAt!))),
          ]),
          if (t.volees.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SectionCard(children: [
                Row(children: [
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Comment ça marche', style: tt.titleSmall),
                ]),
                const SizedBox(height: 8),
                const Text(
                  '1. Touchez « Mesure de départ » et choisissez le nombre de flèches.\n'
                  '2. Pour chaque flèche, un écran noir s\'affiche : touchez-le.\n'
                  '3. Baissez puis remontez l\'arc : l\'enregistrement démarre.',
                  style: TextStyle(height: 1.5),
                ),
              ]),
            ),
          if (t.volees.isNotEmpty) const SectionTitle('Volées'),
          for (final v in t.volees.reversed)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Volée ${v.number}', style: tt.titleMedium),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${fmtTime(v.startedAt)} · ${v.arrows.length}/${v.plannedArrows} flèches',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Superposer les flèches de la volée',
                      icon: const Icon(Icons.stacked_line_chart),
                      onPressed: v.arrows.isEmpty ? null : () => _analysis(v.number),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final a in v.arrows)
                      _ArrowDot(
                        number: a.number,
                        tooltip: 'Flèche ${a.number}',
                        onTap: () => _openArrow(v, a),
                      ),
                    for (var k = v.arrows.length + 1; k <= v.plannedArrows; k++)
                      _ArrowDot(number: k),
                  ]),
                  if (v.arrows.length < v.plannedArrows)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Continuer la volée (flèche ${v.arrows.length + 1})'),
                        onPressed: () => _acquire(v),
                      ),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Pastille numérotée d'une flèche (pleine si enregistrée, en pointillé sinon).
class _ArrowDot extends StatelessWidget {
  const _ArrowDot({required this.number, this.onTap, this.tooltip});
  final int number;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = onTap != null;
    final dot = Material(
      color: done ? cs.primary : Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: done ? cs.primary : cs.outlineVariant, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text('$number',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: done ? cs.onPrimary : cs.outline)),
          ),
        ),
      ),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}

class _ArrowCountDialog extends StatefulWidget {
  const _ArrowCountDialog({required this.initial});
  final int initial;

  @override
  State<_ArrowCountDialog> createState() => _ArrowCountDialogState();
}

class _ArrowCountDialogState extends State<_ArrowCountDialog> {
  late int n = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.adjust),
      title: const Text('Nombre de flèches'),
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(
          onPressed: n > 1 ? () => setState(() => n--) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 80,
          child: Text('$n',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton.filledTonal(
          onPressed: n < 24 ? () => setState(() => n++) : null,
          icon: const Icon(Icons.add),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, n), child: const Text('Commencer')),
      ],
    );
  }
}
