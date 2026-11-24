import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String monthShort(DateTime d) => _months[d.month - 1];

/// Petite pastille icône + texte.
class InfoPill extends StatelessWidget {
  const InfoPill(this.icon, this.text, {super.key, this.onDark = false});
  final IconData icon;
  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = onDark ? Colors.white : cs.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.12) : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: onDark ? Border.all(color: Colors.white.withValues(alpha: 0.18)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: fg.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

/// Résumé des conditions de tir et du réglage d'acquisition.
class ConditionsSummary extends StatelessWidget {
  const ConditionsSummary(this.s, {super.key, this.onTap, this.onDark = false});
  final AppSettings s;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.straighten, '${fmtNum(s.distanceM, 0)} m'),
      (Icons.track_changes, 'Blason ${s.blasonCm} cm'),
      (Icons.sports, '${s.bowType.split(' (').first} · ${fmtNum(s.drawWeightLbs, 0)} lbs'),
      (Icons.back_hand_outlined, s.handedness.label),
      (Icons.smartphone, PhonePosition.byId(s.phonePosition).label.replaceAll(' – défaut', '')),
      (Icons.timer_outlined, '${s.durationS} s · ${s.periodMs} ms'),
    ];
    final wrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final (icon, text) in items) InfoPill(icon, text, onDark: onDark)],
    );
    if (onTap == null) return wrap;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: wrap);
  }
}

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.hint, this.width = 160, this.icon});
  final String label, value;
  final String? hint;
  final double width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: cs.primary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(value, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(children: [
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant, letterSpacing: 0.3, fontWeight: FontWeight.w700)),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Carte regroupant une section (paramètres, infos…).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );
}

/// Pavé date (jour + mois) pour les listes d'entraînements.
class DateBadge extends StatelessWidget {
  const DateBadge(this.date, {super.key});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${date.day}',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer, height: 1.1)),
        Text(monthShort(date),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
      ]),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.science_outlined, color: cs.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Mode démo : capteurs simulés, chaque mesure rejoue un tir type. '
            'Désactivable dans les paramètres sur un téléphone.',
            style: TextStyle(color: cs.onSecondaryContainer, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}
