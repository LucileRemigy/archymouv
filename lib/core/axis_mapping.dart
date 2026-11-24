/// Correspondance entre les axes du téléphone et les axes de l'arc.
///
/// Repère « arc » utilisé partout dans l'appli :
///   X = axe de tir (+ vers la cible)
///   Y = vertical (+ vers le haut)
///   Z = latéral (+ à droite quand on regarde la cible), Z = X ∧ Y
///
/// Repère « téléphone » (Android / sensors_plus), téléphone tenu en portrait :
///   x = vers la droite de l'écran, y = vers le haut de l'écran,
///   z = sort de l'écran (vers l'utilisateur).
library;

enum Handedness { droitier, gaucher }

extension HandednessLabel on Handedness {
  String get label => this == Handedness.droitier ? 'Droitier' : 'Gaucher';
}

class PhonePosition {
  const PhonePosition(this.id, this.label, this.description, this.rows);

  final String id;
  final String label;
  final String description;

  /// Pour un DROITIER : pour chaque axe arc (X, Y, Z), l'axe téléphone
  /// correspondant (0 = x, 1 = y, 2 = z) et son signe.
  final List<(int, double)> rows;

  static const defaultId = 'portrait';

  static const all = <PhonePosition>[
    PhonePosition(
      'portrait',
      'Vertical (portrait) – défaut',
      'Plaqué sur la poignée, haut du téléphone vers le haut. '
          'x tél. = axe de tir, y tél. = vertical, z tél. = latéral.',
      [(0, 1), (1, 1), (2, 1)],
    ),
    PhonePosition(
      'portrait_inverse',
      'Vertical inversé',
      'Plaqué sur la poignée, haut du téléphone vers le bas.',
      [(0, -1), (1, -1), (2, 1)],
    ),
    PhonePosition(
      'paysage_cible',
      'Horizontal, haut vers la cible',
      'Téléphone couché (paysage), son haut pointé vers la cible : '
          'y tél. = axe de tir, x tél. = vertical.',
      [(1, 1), (0, -1), (2, 1)],
    ),
    PhonePosition(
      'paysage_archer',
      'Horizontal, haut vers l\'archer',
      'Téléphone couché (paysage), son haut pointé vers l\'archer.',
      [(1, -1), (0, 1), (2, 1)],
    ),
  ];

  static PhonePosition byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);

  /// Devine la position à partir de la gravité mesurée (accéléromètre au
  /// repos, repère téléphone). Renvoie null si le téléphone est à plat.
  static String? detectFromGravity(double ax, double ay, double az) {
    final mx = ax.abs(), my = ay.abs(), mz = az.abs();
    if (my >= mx && my >= mz) return ay > 0 ? 'portrait' : 'portrait_inverse';
    if (mx >= mz) return ax < 0 ? 'paysage_cible' : 'paysage_archer';
    return null;
  }
}

/// Convertit les mesures du repère téléphone vers le repère arc
/// (et inversement), selon la position du téléphone et la main de l'archer.
///
/// Gaucher = même montage tourné de 180° autour de la verticale :
/// la cible est à gauche du téléphone et l'écran regarde l'autre côté,
/// donc X et Z changent de signe.
class AxisMapper {
  AxisMapper(String positionId, Handedness handedness)
      : _rows = _build(positionId, handedness);

  final List<(int, double)> _rows;

  static List<(int, double)> _build(String id, Handedness h) {
    final rows = PhonePosition.byId(id).rows.toList();
    if (h == Handedness.gaucher) {
      rows[0] = (rows[0].$1, -rows[0].$2);
      rows[2] = (rows[2].$1, -rows[2].$2);
    }
    return rows;
  }

  List<double> toBow(double x, double y, double z) {
    final d = [x, y, z];
    return [for (final (axis, sign) in _rows) d[axis] * sign];
  }

  List<double> toDevice(double bx, double by, double bz) {
    final b = [bx, by, bz];
    final d = [0.0, 0.0, 0.0];
    for (var i = 0; i < 3; i++) {
      final (axis, sign) = _rows[i];
      d[axis] = b[i] * sign;
    }
    return d;
  }
}
