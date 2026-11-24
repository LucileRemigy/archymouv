String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String fmtTime(DateTime d, {bool seconds = false}) =>
    '${two(d.hour)}h${two(d.minute)}${seconds ? ':${two(d.second)}' : ''}';

/// Nombre à la française (virgule décimale).
String fmtNum(num v, [int digits = 1]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

String fmtSigned(num v, [int digits = 1]) =>
    '${v >= 0 ? '+' : ''}${fmtNum(v, digits)}';
