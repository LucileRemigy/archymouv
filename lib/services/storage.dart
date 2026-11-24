import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';

/// Vrais capteurs disponibles (Android / iOS) ?
bool get sensorsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class SettingsStore {
  static const _key = 'archymouv.settings';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppSettings()..demoMode = !sensorsSupported;
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings()..demoMode = !sensorsSupported;
    }
  }

  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }
}

/// Un fichier JSON par entraînement dans le dossier de l'appli.
/// (Sur le web — démo — les données restent en mémoire.)
class TrainingStore {
  TrainingStore._();
  static final instance = TrainingStore._();

  static const maxAgeDays = 14;

  final Map<String, Training> _memory = {};

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/archymouv');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<Training>> loadAll() async {
    final list = <Training>[];
    if (kIsWeb) {
      list.addAll(_memory.values);
    } else {
      final d = await _dir();
      await for (final f in d.list()) {
        if (f is File && f.path.endsWith('.json')) {
          try {
            final j = jsonDecode(await f.readAsString());
            list.add(Training.fromJson(j as Map<String, dynamic>));
          } catch (e) {
            debugPrint('Fichier illisible ${f.path} : $e');
          }
        }
      }
    }
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  Future<void> save(Training t) async {
    if (kIsWeb) {
      _memory[t.id] = t;
      return;
    }
    final d = await _dir();
    final f = File('${d.path}/${t.id}.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(t.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> delete(Training t) async {
    if (kIsWeb) {
      _memory.remove(t.id);
      return;
    }
    final d = await _dir();
    final f = File('${d.path}/${t.id}.json');
    if (await f.exists()) await f.delete();
  }
}
