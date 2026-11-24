import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'sensor_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get app => AppState.instance;
  AppSettings get s => app.settings;

  void _set(void Function(AppSettings s) change) {
    app.update(change);
    setState(() {});
  }

  Widget _num(String label, num value, String suffix, void Function(double v) onChanged,
      {bool decimal = false, String? helper}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: decimal ? value.toString() : value.round().toString(),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper),
        onChanged: (txt) {
          final v = double.tryParse(txt.replaceAll(',', '.'));
          if (v != null && v >= 0) _set((_) => onChanged(v));
        },
      ),
    );
  }

  Widget _switch(String title, String? subtitle, bool value, ValueChanged<bool>? onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionTitle('Conditions de tir'),
          SectionCard(children: [
            Row(children: [
              Expanded(
                child: _num('Distance', s.distanceM, 'm', (v) => s.distanceM = v, decimal: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<int>(
                    initialValue: blasonSizes.contains(s.blasonCm) ? s.blasonCm : null,
                    decoration: const InputDecoration(labelText: 'Blason'),
                    items: [
                      for (final b in blasonSizes) DropdownMenuItem(value: b, child: Text('$b cm')),
                    ],
                    onChanged: (v) => _set((s) => s.blasonCm = v ?? s.blasonCm),
                  ),
                ),
              ),
            ]),
          ]),

          const SectionTitle('Arc'),
          SectionCard(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: bowTypes.contains(s.bowType) ? s.bowType : bowTypes.first,
                decoration: const InputDecoration(labelText: 'Type d\'arc'),
                items: [
                  for (final b in bowTypes)
                    DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => _set((s) => s.bowType = v ?? s.bowType),
              ),
            ),
            _num('Puissance', s.drawWeightLbs, 'livres', (v) => s.drawWeightLbs = v, decimal: true),
            const SizedBox(height: 8),
            SegmentedButton<Handedness>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Handedness.droitier, label: Text('Droitier')),
                ButtonSegment(value: Handedness.gaucher, label: Text('Gaucher')),
              ],
              selected: {s.handedness},
              onSelectionChanged: (v) => _set((s) => s.handedness = v.first),
            ),
            const SizedBox(height: 4),
          ]),

          const SectionTitle('Acquisition'),
          SectionCard(children: [
            Row(children: [
              Expanded(
                child: _num('Durée', s.durationS, 's', (v) => s.durationS = v.round().clamp(2, 60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _num('Période', s.periodMs, 'ms', (v) => s.periodMs = v.round().clamp(5, 200)),
              ),
            ]),
            _num('Flèches par volée (par défaut)', s.arrowsPerEnd, '',
                (v) => s.arrowsPerEnd = v.round().clamp(1, 24),
                helper: 'Période 20 ms = 50 mesures par seconde'),
            _switch(
              'Déclenchement automatique',
              'Après le toucher de l\'écran, l\'enregistrement démarre quand l\'arc '
                  'est baissé puis remonté. Sinon : départ immédiat.',
              s.autoTrigger,
              (v) => _set((s) => s.autoTrigger = v),
            ),
            if (s.autoTrigger) ...[
              _num('Départ après le point bas', s.triggerDelayMs, 'ms',
                  (v) => s.triggerDelayMs = v.round()),
              Row(children: [
                Expanded(
                  child: _num('Baisse minimale', s.triggerDropDeg, '°',
                      (v) => s.triggerDropDeg = v, decimal: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _num('Remontée', s.triggerRiseDeg, '°',
                      (v) => s.triggerRiseDeg = v.clamp(1, 45), decimal: true),
                ),
              ]),
            ],
            _switch('Graphique après chaque flèche', null, s.showResultAfterArrow,
                (v) => _set((s) => s.showResultAfterArrow = v)),
          ]),

          const SectionTitle('Position du téléphone sur l\'arc'),
          Text('Repère de l\'arc : X = axe de tir, Y = vertical, Z = latéral. '
              'Gaucher : la cible est à gauche du téléphone.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 8),
          for (final p in PhonePosition.all) _PositionTile(
            position: p,
            selected: p.id == s.phonePosition,
            onTap: () => _set((s) => s.phonePosition = p.id),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.sensors),
              label: const Text('Vérifier / détecter avec le test capteurs'),
              onPressed: () async {
                await Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const SensorTestScreen()));
                if (mounted) setState(() {});
              },
            ),
          ),

          const SectionTitle('Envoi des données'),
          SectionCard(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextFormField(
                initialValue: s.email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email destinataire',
                  helperText: 'Le fichier Excel de l\'entraînement y est envoyé',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                onChanged: (v) => _set((s) => s.email = v.trim()),
              ),
            ),
          ]),

          const SectionTitle('Divers'),
          SectionCard(children: [
            _switch(
              'Mode démo (capteurs simulés)',
              sensorsSupported
                  ? 'Pour essayer l\'appli sans arc.'
                  : 'Pas de capteurs sur cet appareil : démo obligatoire.',
              app.demo,
              sensorsSupported ? (v) => _set((s) => s.demoMode = v) : null,
            ),
          ]),
        ],
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({required this.position, required this.selected, required this.onTap});
  final PhonePosition position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final landscape = position.id.startsWith('paysage');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(landscape ? Icons.stay_current_landscape : Icons.stay_current_portrait,
                  size: 30, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(position.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(position.description,
                      style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                ]),
              ),
              if (selected) Icon(Icons.check_circle, color: cs.primary),
            ]),
          ),
        ),
      ),
    );
  }
}
