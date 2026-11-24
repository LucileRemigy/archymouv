import 'package:flutter/foundation.dart';

import 'core/axis_mapping.dart';
import 'core/models.dart';
import 'core/motion_source.dart';
import 'core/simulation.dart';
import 'services/storage.dart';

/// État global minimal : les paramètres.
class AppState extends ChangeNotifier {
  AppState(this.settings);

  static late AppState instance;

  AppSettings settings;

  bool get demo => settings.demoMode || !sensorsSupported;

  Future<void> update(void Function(AppSettings s) change) async {
    change(settings);
    notifyListeners();
    await SettingsStore.save(settings);
  }

  MotionSource createSource([AppSettings? s]) {
    final st = s ?? settings;
    if (!demo) return DeviceMotionSource();
    return SimulatedMotionSource(
      AxisMapper(st.phonePosition, st.handedness),
      cycleS: st.durationS + 4.0,
    );
  }
}
