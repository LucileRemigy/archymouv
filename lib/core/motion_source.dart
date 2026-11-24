import 'package:sensors_plus/sensors_plus.dart';

/// Une mesure brute d'un capteur, repère téléphone.
/// tUs = horodatage capteur en microsecondes.
class RawEvent {
  const RawEvent(this.tUs, this.x, this.y, this.z);
  final int tUs;
  final double x, y, z;
}

/// Source des mesures de mouvement : vrais capteurs ou simulation.
abstract class MotionSource {
  /// Gyroscope en rad/s (unité fournie par sensors_plus).
  Stream<RawEvent> gyro(Duration period);

  /// Accéléromètre en m/s², gravité incluse.
  Stream<RawEvent> accel(Duration period);

  /// Appelé quand l'archer touche l'écran pour lancer une mesure.
  void onArmed() {}

  void dispose() {}
}

/// Capteurs réels du téléphone via sensors_plus.
///
/// Sur Android l'horodatage vient de l'événement capteur matériel
/// (SensorEvent.timestamp) : il est précis même si Flutter reçoit
/// les événements par paquets.
class DeviceMotionSource extends MotionSource {
  @override
  Stream<RawEvent> gyro(Duration period) =>
      gyroscopeEventStream(samplingPeriod: period).map(
          (e) => RawEvent(e.timestamp.microsecondsSinceEpoch, e.x, e.y, e.z));

  @override
  Stream<RawEvent> accel(Duration period) =>
      accelerometerEventStream(samplingPeriod: period).map(
          (e) => RawEvent(e.timestamp.microsecondsSinceEpoch, e.x, e.y, e.z));
}
