import 'axis_mapping.dart';

export 'axis_mapping.dart' show Handedness, HandednessLabel, PhonePosition;

const bowTypes = <String>[
  'Classique (recurve)',
  'Poulies (compound)',
  'Barebow',
  'Arc droit (longbow)',
  'Arc traditionnel / chasse',
];

const blasonSizes = <int>[40, 60, 80, 122];

/// Paramètres de l'application (écran Paramètres).
class AppSettings {
  AppSettings();

  // 1. Conditions de tir
  double distanceM = 18;
  int blasonCm = 40;

  // 2. Arc
  String bowType = bowTypes.first;
  double drawWeightLbs = 30;
  Handedness handedness = Handedness.droitier;

  // 3. Acquisition
  int durationS = 15;
  int periodMs = 20;
  int arrowsPerEnd = 6;
  bool autoTrigger = true;
  int triggerDelayMs = 200;
  double triggerDropDeg = 5;
  double triggerRiseDeg = 5;
  bool showResultAfterArrow = true;

  // 4. Calibrage : position du téléphone sur l'arc
  String phonePosition = PhonePosition.defaultId;

  // 5. Envoi
  String email = '';

  // Divers
  bool demoMode = false;

  Map<String, dynamic> toJson() => {
        'distanceM': distanceM,
        'blasonCm': blasonCm,
        'bowType': bowType,
        'drawWeightLbs': drawWeightLbs,
        'handedness': handedness.name,
        'durationS': durationS,
        'periodMs': periodMs,
        'arrowsPerEnd': arrowsPerEnd,
        'autoTrigger': autoTrigger,
        'triggerDelayMs': triggerDelayMs,
        'triggerDropDeg': triggerDropDeg,
        'triggerRiseDeg': triggerRiseDeg,
        'showResultAfterArrow': showResultAfterArrow,
        'phonePosition': phonePosition,
        'email': email,
        'demoMode': demoMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    bool b(String k, bool def) => j[k] as bool? ?? def;
    s.distanceM = d('distanceM', s.distanceM);
    s.blasonCm = i('blasonCm', s.blasonCm);
    s.bowType = j['bowType'] as String? ?? s.bowType;
    s.drawWeightLbs = d('drawWeightLbs', s.drawWeightLbs);
    s.handedness =
        j['handedness'] == 'gaucher' ? Handedness.gaucher : Handedness.droitier;
    s.durationS = i('durationS', s.durationS);
    s.periodMs = i('periodMs', s.periodMs);
    s.arrowsPerEnd = i('arrowsPerEnd', s.arrowsPerEnd);
    s.autoTrigger = b('autoTrigger', s.autoTrigger);
    s.triggerDelayMs = i('triggerDelayMs', s.triggerDelayMs);
    s.triggerDropDeg = d('triggerDropDeg', s.triggerDropDeg);
    s.triggerRiseDeg = d('triggerRiseDeg', s.triggerRiseDeg);
    s.showResultAfterArrow = b('showResultAfterArrow', s.showResultAfterArrow);
    s.phonePosition = j['phonePosition'] as String? ?? s.phonePosition;
    s.email = j['email'] as String? ?? s.email;
    s.demoMode = b('demoMode', s.demoMode);
    return s;
  }

  AppSettings copy() => AppSettings.fromJson(toJson());
}

/// Une flèche = un enregistrement.
class Arrow {
  Arrow({
    required this.number,
    required this.armedAt,
    required this.triggeredAt,
    required this.triggerMode,
    required this.periodMs,
    required this.samples,
    this.gyroHz = 0,
    this.accHz = 0,
  });

  final int number;

  /// Heure où l'archer a touché l'écran.
  final DateTime armedAt;

  /// Heure du début de l'enregistrement (t = 0).
  final DateTime triggeredAt;

  /// 'auto' (arc baissé puis remonté) ou 'manuel'.
  final String triggerMode;
  final int periodMs;

  /// Fréquences réellement fournies par les capteurs.
  final double gyroHz;
  final double accHz;

  /// Une ligne par pas de temps, repère TÉLÉPHONE, valeurs brutes :
  /// [t (ms), gyro x, y, z (rad/s), accél. x, y, z (m/s²)].
  final List<List<double>> samples;

  static double _r(double v) => (v * 10000).roundToDouble() / 10000;

  Map<String, dynamic> toJson() => {
        'number': number,
        'armedAt': armedAt.toIso8601String(),
        'triggeredAt': triggeredAt.toIso8601String(),
        'triggerMode': triggerMode,
        'periodMs': periodMs,
        'gyroHz': _r(gyroHz),
        'accHz': _r(accHz),
        'samples': [
          for (final s in samples) [for (final v in s) _r(v)]
        ],
      };

  factory Arrow.fromJson(Map<String, dynamic> j) => Arrow(
        number: (j['number'] as num).toInt(),
        armedAt: DateTime.parse(j['armedAt'] as String),
        triggeredAt: DateTime.parse(j['triggeredAt'] as String),
        triggerMode: j['triggerMode'] as String? ?? 'auto',
        periodMs: (j['periodMs'] as num?)?.toInt() ?? 20,
        gyroHz: (j['gyroHz'] as num?)?.toDouble() ?? 0,
        accHz: (j['accHz'] as num?)?.toDouble() ?? 0,
        samples: [
          for (final r in j['samples'] as List)
            [for (final v in r as List) (v as num).toDouble()]
        ],
      );
}

/// Une volée = une série de flèches.
class Volee {
  Volee({
    required this.number,
    required this.startedAt,
    required this.plannedArrows,
    List<Arrow>? arrows,
  }) : arrows = arrows ?? [];

  final int number;
  final DateTime startedAt;
  final int plannedArrows;
  final List<Arrow> arrows;

  Map<String, dynamic> toJson() => {
        'number': number,
        'startedAt': startedAt.toIso8601String(),
        'plannedArrows': plannedArrows,
        'arrows': [for (final a in arrows) a.toJson()],
      };

  factory Volee.fromJson(Map<String, dynamic> j) => Volee(
        number: (j['number'] as num).toInt(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        plannedArrows: (j['plannedArrows'] as num?)?.toInt() ?? 6,
        arrows: [
          for (final a in j['arrows'] as List)
            Arrow.fromJson(a as Map<String, dynamic>)
        ],
      );
}

/// Un entraînement = un fichier (et un fichier Excel à l'export).
class Training {
  Training({
    required this.id,
    required this.startedAt,
    required this.settings,
    this.sentAt,
    List<Volee>? volees,
  }) : volees = volees ?? [];

  factory Training.start(AppSettings settings) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final id = '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return Training(id: id, startedAt: now, settings: settings.copy());
  }

  final String id;
  final DateTime startedAt;

  /// Copie des paramètres au moment de l'entraînement.
  final AppSettings settings;
  DateTime? sentAt;
  final List<Volee> volees;

  int get arrowCount => volees.fold(0, (n, v) => n + v.arrows.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
        'settings': settings.toJson(),
        'volees': [for (final v in volees) v.toJson()],
      };

  factory Training.fromJson(Map<String, dynamic> j) => Training(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        sentAt: j['sentAt'] == null ? null : DateTime.parse(j['sentAt'] as String),
        settings: AppSettings.fromJson(j['settings'] as Map<String, dynamic>),
        volees: [
          for (final v in j['volees'] as List)
            Volee.fromJson(v as Map<String, dynamic>)
        ],
      );
}
