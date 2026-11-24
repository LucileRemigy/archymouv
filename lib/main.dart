import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'services/storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Le téléphone est fixé sur l'arc : on bloque l'interface en portrait
  // (les capteurs, eux, ne dépendent pas de l'orientation de l'écran).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  AppState.instance = AppState(await SettingsStore.load());
  runApp(const ArchymouvApp());
}

class ArchymouvApp extends StatelessWidget {
  const ArchymouvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'archymouv',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Android 15+ affiche l'appli « bord à bord » : sans cette marge, le bas
      // des pages passe sous la barre de navigation (boutons Samsung).
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(top: false, child: child ?? const SizedBox.shrink()),
      ),
      home: const HomeScreen(),
    );
  }
}
