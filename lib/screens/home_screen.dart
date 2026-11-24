import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../services/storage.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sensor_test_screen.dart';
import 'settings_screen.dart';
import 'training_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Training>? _trainings;

  @override
  void initState() {
    super.initState();
    _load(checkOld: true);
  }

  Future<void> _load({bool checkOld = false}) async {
    final list = await TrainingStore.instance.loadAll();
    if (!mounted) return;
    setState(() => _trainings = list);
    if (checkOld) await _checkOld(list);
  }

  /// À l'ouverture : données de plus de 2 semaines -> l'Excel a-t-il été
  /// envoyé ? Si oui, on supprime.
  Future<void> _checkOld(List<Training> list) async {
    final limit =
        DateTime.now().subtract(const Duration(days: TrainingStore.maxAgeDays));
    final old = list.where((t) => t.startedAt.isBefore(limit)).toList();
    if (old.isEmpty || !mounted) return;
    final notSent = old.where((t) => t.sentAt == null).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Données de plus de 2 semaines'),
        content: Text(
          '${old.length} entraînement(s) datent de plus de '
          '${TrainingStore.maxAgeDays} jours'
          '${notSent > 0 ? ', dont $notSent jamais envoyé(s) par email' : ''}.\n\n'
          'Avez-vous bien envoyé le fichier Excel ? '
          'Si oui, ils vont être supprimés du téléphone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Pas encore')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    for (final t in old) {
      await TrainingStore.instance.delete(t);
    }
    await _load();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _delete(Training t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet entraînement ?'),
        content: Text('${fmtDate(t.startedAt)} ${fmtTime(t.startedAt)} – '
            '${t.arrowCount} flèche(s). Suppression définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await TrainingStore.instance.delete(t);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final list = _trainings;
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                settings: app.settings,
                onSensors: () => _open(const SensorTestScreen()),
                onSettings: () => _open(const SettingsScreen()),
                onNew: () => _open(TrainingScreen(training: Training.start(app.settings))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (app.demo) const DemoBanner(),
                  SectionTitle(
                    'Entraînements',
                    trailing: list == null || list.isEmpty
                        ? null
                        : Text('${list.length}',
                            style: tt.labelLarge
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                  if (list == null)
                    const Center(
                        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  else if (list.isEmpty)
                    const _EmptyState()
                  else
                    for (final t in list)
                      _TrainingCard(
                        training: t,
                        onTap: () => _open(TrainingScreen(training: t)),
                        onLongPress: () => _delete(t),
                      ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.settings,
    required this.onSensors,
    required this.onSettings,
    required this.onNew,
  });

  final AppSettings settings;
  final VoidCallback onSensors, onSettings, onNew;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 12, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.navy2],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.track_changes, color: AppTheme.sky),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('archymouv',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
              Text('Analyse du mouvement de l\'arc',
                  style: TextStyle(color: Color(0xFFB4C6EE), fontSize: 13)),
            ]),
          ),
          IconButton(
            tooltip: 'Test des capteurs',
            color: Colors.white,
            icon: const Icon(Icons.sensors),
            onPressed: onSensors,
          ),
          IconButton(
            tooltip: 'Paramètres',
            color: Colors.white,
            icon: const Icon(Icons.tune),
            onPressed: onSettings,
          ),
        ]),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ConditionsSummary(settings, onDark: true, onTap: onSettings),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navy,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('Nouvel entraînement', style: TextStyle(fontSize: 17)),
              onPressed: onNew,
            ),
          ),
        ),
      ]),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.training, required this.onTap, required this.onLongPress});
  final Training training;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = training;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sent = t.sentAt != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            DateBadge(t.startedAt),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${fmtTime(t.startedAt)} · ${fmtNum(t.settings.distanceM, 0)} m',
                    style: tt.titleMedium),
                const SizedBox(height: 2),
                Text('${t.volees.length} volée(s) · ${t.arrowCount} flèche(s)',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sent ? AppTheme.success.withValues(alpha: 0.12) : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(sent ? Icons.check_circle : Icons.outbox_outlined,
                    size: 14, color: sent ? AppTheme.success : cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(sent ? 'Envoyé' : 'À envoyer',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sent ? AppTheme.success : cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(Icons.adjust, size: 36, color: cs.primary),
        ),
        const SizedBox(height: 12),
        Text('Aucun entraînement pour l\'instant',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Fixez le téléphone sur l\'arc puis lancez un entraînement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
