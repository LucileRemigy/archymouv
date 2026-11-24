import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/motion_source.dart';
import '../core/recorder.dart';
import '../services/beeper.dart';
import '../services/storage.dart';
import '../theme.dart';
import 'arrow_result_screen.dart';

/// Écran noir d'acquisition : une flèche après l'autre.
///  1. « Flèche k / n – touchez l'écran » ; n'importe quel toucher arme
///     la mesure (bip) ;
///  2. on attend que l'arc soit baissé puis remonté (ou un 2e toucher) ;
///  3. enregistrement pendant la durée réglée, puis bip de fin.
class AcquisitionScreen extends StatefulWidget {
  const AcquisitionScreen({super.key, required this.training, required this.volee});
  final Training training;
  final Volee volee;

  @override
  State<AcquisitionScreen> createState() => _AcquisitionScreenState();
}

class _AcquisitionScreenState extends State<AcquisitionScreen> {
  late final AppSettings s = widget.training.settings;
  late final MotionSource _src = AppState.instance.createSource(s);
  late final ArrowRecorder _rec =
      ArrowRecorder(source: _src, settings: s, onTrigger: Beeper.recording);
  Timer? _ui;
  final DateTime _openedAt = DateTime.now();

  Volee get v => widget.volee;
  int get _arrowNumber => v.arrows.length + 1;
  bool get _busy => _rec.state == RecState.armed || _rec.state == RecState.recording;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable().catchError((Object e) => debugPrint('Wakelock : $e'));
    _rec.start();
    _ui = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ui?.cancel();
    _rec.dispose();
    _src.dispose();
    WakelockPlus.disable().catchError((Object e) => debugPrint('Wakelock : $e'));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onTap() {
    switch (_rec.state) {
      case RecState.idle:
      case RecState.done:
        _arm();
      case RecState.armed:
        _rec.triggerNow();
      case RecState.recording:
        break;
    }
  }

  Future<void> _arm() async {
    Beeper.armed();
    final rec = await _rec.arm();
    if (!mounted) return;
    Beeper.done();
    final arrow = rec.toArrow(_arrowNumber, s.periodMs);
    v.arrows.add(arrow);
    await TrainingStore.instance.save(widget.training);
    if (!mounted) return;
    final last = v.arrows.length >= v.plannedArrows;
    if (s.showResultAfterArrow) {
      final r = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ArrowResultScreen(
            training: widget.training,
            volee: v,
            arrow: arrow,
            nextLabel: last ? 'Terminer la volée' : 'Flèche suivante (${arrow.number + 1})',
          ),
        ),
      );
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (last || r != 'next') {
        Navigator.pop(context);
        return;
      }
    } else if (last) {
      Navigator.pop(context);
      return;
    }
    setState(() {});
  }

  Future<void> _quit() async {
    if (!_busy) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner cette flèche ?'),
        content: const Text('La mesure en cours sera perdue. Les flèches déjà enregistrées sont conservées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abandonner')),
        ],
      ),
    );
    if (ok == true && mounted) {
      _rec.cancel();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = Colors.white.withValues(alpha: 0.55);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: SafeArea(
            child: Stack(children: [
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: Icon(Icons.close, color: dim),
                  onPressed: _quit,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Text('Volée ${v.number}', style: TextStyle(color: dim, fontSize: 16)),
              ),
              if (AppState.instance.demo)
                const Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('MODE DÉMO – capteurs simulés',
                        style: TextStyle(color: Colors.amber, fontSize: 12)),
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Flèche $_arrowNumber / ${v.plannedArrows}',
                        style: const TextStyle(
                            color: white, fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 28),
                    ..._stateWidgets(white, dim),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _stateWidgets(Color white, Color dim) {
    switch (_rec.state) {
      case RecState.idle:
      case RecState.done:
        final silent = !_rec.sensorsAlive &&
            DateTime.now().difference(_openedAt) > const Duration(seconds: 2);
        return [
          Icon(Icons.touch_app_outlined, color: dim, size: 64),
          const SizedBox(height: 12),
          Text('Touchez l\'écran pour lancer',
              textAlign: TextAlign.center, style: TextStyle(color: white, fontSize: 22)),
          if (silent)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Aucune mesure des capteurs…',
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ];
      case RecState.armed:
        final drop = _rec.dropDetected;
        Widget step(String label, bool ok) => Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ok ? AppTheme.sky : dim, size: 22),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: ok ? white : dim, fontSize: 18)),
            ]);
        return [
          Text('Baissez puis remontez l\'arc',
              textAlign: TextAlign.center, style: TextStyle(color: white, fontSize: 24)),
          const SizedBox(height: 18),
          Row(mainAxisSize: MainAxisSize.min, children: [
            step('baisse', drop),
            const SizedBox(width: 24),
            step('remontée', false),
          ]),
          const SizedBox(height: 12),
          Text('Inclinaison ${fmtSigned(_rec.pitchDeg, 0)}°',
              style: TextStyle(color: dim, fontSize: 16)),
          const SizedBox(height: 36),
          Text('Touchez à nouveau pour démarrer tout de suite',
              textAlign: TextAlign.center, style: TextStyle(color: dim, fontSize: 14)),
        ];
      case RecState.recording:
        return [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('Enregistrement', style: TextStyle(color: dim, fontSize: 18)),
          ]),
          const SizedBox(height: 8),
          Text('${_rec.remainingS.ceil()} s',
              style: TextStyle(color: white, fontSize: 72, fontWeight: FontWeight.w300)),
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: LinearProgressIndicator(
              value: _rec.progress,
              color: AppTheme.sky,
              backgroundColor: Colors.white12,
              borderRadius: BorderRadius.circular(3),
              minHeight: 6,
            ),
          ),
        ];
    }
  }
}
