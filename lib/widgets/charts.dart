import 'dart:math';

import 'package:flutter/material.dart';

/// Vert (accélération faible) -> jaune -> rouge (accélération forte).
Color accColor(double f) =>
    HSVColor.fromAHSV(1, 120 * (1 - f.clamp(0.0, 1.0)), 0.9, 0.85).toColor();

const overlayPalette = <Color>[
  Color(0xFF1E88E5), Color(0xFFD81B60), Color(0xFF43A047), Color(0xFFFB8C00),
  Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFF6D4C41), Color(0xFF3949AB),
  Color(0xFFC0CA33), Color(0xFF546E7A), Color(0xFFF4511E), Color(0xFF00897B),
];

double niceStep(double v) {
  if (v <= 0 || v.isNaN || v.isInfinite) return 1;
  final e = pow(10, (log(v) / ln10).floor()).toDouble();
  final f = v / e;
  final n = f <= 1 ? 1.0 : f <= 2 ? 2.0 : f <= 2.5 ? 2.5 : f <= 5 ? 5.0 : 10.0;
  return n * e;
}

String _tick(double v) {
  final a = v.abs();
  final s = a >= 10 || a == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(a >= 1 ? 1 : 2);
  return s.replaceAll('.', ',');
}

void _text(Canvas c, String s, Offset at, Color color,
    {double ax = 0.5, double ay = 0, double size = 10, bool vertical = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
  )..layout();
  if (vertical) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-pi / 2);
    tp.paint(c, Offset(-tp.width * ax, -tp.height * ay));
    c.restore();
  } else {
    tp.paint(c, Offset(at.dx - tp.width * ax, at.dy - tp.height * ay));
  }
}

// ---------------------------------------------------------------------------
// Graphique plan (blason ou nuage x/y)
// ---------------------------------------------------------------------------

class PlaneSeries {
  const PlaneSeries({
    required this.points,
    this.colors,
    this.color = Colors.blue,
    this.markers = true,
    this.width = 2,
  });

  final List<Offset> points;

  /// Couleur de chaque point (sinon [color]).
  final List<Color>? colors;
  final Color color;

  /// ▲ au premier point, ★ au dernier.
  final bool markers;
  final double width;
}

class PlaneChart extends StatelessWidget {
  const PlaneChart({
    super.key,
    required this.series,
    this.blasonCm,
    required this.xLabel,
    required this.yLabel,
    this.unit = '',
    this.fit = false,
  });

  final List<PlaneSeries> series;

  /// Si renseigné, dessine un blason de cette taille (cm) en fond.
  final double? blasonCm;
  final String xLabel, yLabel, unit;

  /// Avec un blason : élargit l'échelle pour montrer tous les points.
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _PlanePainter(
          series: series,
          blasonCm: blasonCm,
          xLabel: xLabel,
          yLabel: yLabel,
          unit: unit,
          fit: fit,
          fg: cs.onSurface,
          grid: cs.outlineVariant,
          bg: cs.surfaceContainerLowest,
        ),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  _PlanePainter({
    required this.series,
    required this.blasonCm,
    required this.xLabel,
    required this.yLabel,
    required this.unit,
    required this.fit,
    required this.fg,
    required this.grid,
    required this.bg,
  });

  final List<PlaneSeries> series;
  final double? blasonCm;
  final String xLabel, yLabel, unit;
  final bool fit;
  final Color fg, grid, bg;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, bottom = 34.0, top = 6.0, right = 8.0;
    final avail = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final side = min(avail.width, avail.height);
    final sq = Rect.fromLTWH(avail.left + (avail.width - side) / 2,
        avail.top + (avail.height - side) / 2, side, side);

    final b = blasonCm;
    var m = 0.0;
    for (final s in series) {
      for (final p in s.points) {
        m = max(m, max(p.dx.abs(), p.dy.abs()));
      }
    }
    final auto = niceStep(m == 0 ? 1 : m * 1.1);
    final double range;
    if (b == null) {
      range = auto;
    } else {
      range = fit ? max(b / 2 * 1.05, auto) : b / 2 * 1.05;
    }
    final scale = side / 2 / range;
    final c0 = sq.center;
    Offset px(Offset p) => Offset(c0.dx + p.dx * scale, c0.dy - p.dy * scale);

    canvas.drawRect(sq, Paint()..color = bg);
    canvas.save();
    canvas.clipRect(sq);
    if (b != null) _target(canvas, c0, scale, b);

    final step = niceStep(range / 2.5);
    final k = (range / step).floor();
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: b != null ? 0.35 : 0.8)
      ..strokeWidth = 0.5;
    for (var i = -k; i <= k; i++) {
      if (i == 0) continue;
      final x = c0.dx + i * step * scale, y = c0.dy - i * step * scale;
      canvas.drawLine(Offset(x, sq.top), Offset(x, sq.bottom), gridPaint);
      canvas.drawLine(Offset(sq.left, y), Offset(sq.right, y), gridPaint);
    }
    final axis = Paint()
      ..color = fg.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c0.dx, sq.top), Offset(c0.dx, sq.bottom), axis);
    canvas.drawLine(Offset(sq.left, c0.dy), Offset(sq.right, c0.dy), axis);

    for (final s in series) {
      _series(canvas, s, px);
    }
    canvas.restore();
    canvas.drawRect(sq, Paint()..style = PaintingStyle.stroke..color = grid);

    final label = fg.withValues(alpha: 0.75);
    for (var i = -k; i <= k; i++) {
      final v = i * step;
      _text(canvas, _tick(v), Offset(c0.dx + v * scale, sq.bottom + 3), label);
      _text(canvas, _tick(v), Offset(sq.left - 4, c0.dy - v * scale), label,
          ax: 1, ay: 0.5);
    }
    final u = unit.isEmpty ? '' : ' ($unit)';
    _text(canvas, '$xLabel$u', Offset(c0.dx, size.height - 1), fg, ay: 1, size: 11);
    _text(canvas, '$yLabel$u', Offset(1, c0.dy), fg, ay: 0, size: 11, vertical: true);
  }

  void _target(Canvas c, Offset center, double scale, double blason) {
    final w = blason / 20;
    const fills = [
      Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFF222222), Color(0xFF222222),
      Color(0xFF29B6F6), Color(0xFF29B6F6), Color(0xFFE53935), Color(0xFFE53935),
      Color(0xFFFDD835), Color(0xFFFDD835),
    ];
    for (var k = 0; k < 10; k++) {
      final r = (10 - k) * w * scale;
      c.drawCircle(center, r, Paint()..color = fills[k].withValues(alpha: 0.5));
      c.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = (k == 2 || k == 3) ? Colors.white54 : Colors.black38);
    }
    c.drawCircle(
        center,
        w / 2 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.black45);
  }

  void _series(Canvas c, PlaneSeries s, Offset Function(Offset) px) {
    if (s.points.isEmpty) return;
    final pts = [for (final p in s.points) px(p)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width + 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: 0.3));
    final colors = s.colors;
    if (colors == null) {
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = s.color);
    } else {
      final p = Paint()
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < pts.length; i++) {
        p.color = colors[i];
        c.drawLine(pts[i - 1], pts[i], p);
      }
    }
    if (s.markers) {
      _triangle(c, pts.first, colors?.first ?? s.color);
      _star(c, pts.last, colors?.last ?? s.color);
    }
  }

  void _triangle(Canvas c, Offset p, Color color) {
    const r = 7.0;
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..lineTo(p.dx + r * 0.87, p.dy + r * 0.5)
      ..lineTo(p.dx - r * 0.87, p.dy + r * 0.5)
      ..close();
    c.drawPath(path, Paint()..color = color);
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..color = Colors.black87);
  }

  void _star(Canvas c, Offset p, Color color) {
    const ro = 8.5, ri = 3.6;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? ro : ri;
      final a = -pi / 2 + i * pi / 5;
      final q = Offset(p.dx + r * cos(a), p.dy + r * sin(a));
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _PlanePainter old) => true;
}

// ---------------------------------------------------------------------------
// Graphique temporel
// ---------------------------------------------------------------------------

class TimeSeries {
  const TimeSeries(this.label, this.color, this.t, this.v, {this.width = 1.4});
  final String label;
  final Color color;
  final List<double> t;
  final List<double> v;
  final double width;
}

/// Bornes des phases (secondes). d = lâcher.
class PhaseMarks {
  const PhaseMarks({required this.b, required this.c, required this.d, required this.end});
  final double b, c, d, end;
}

class TimeChart extends StatelessWidget {
  const TimeChart({
    super.key,
    required this.series,
    this.phases,
    this.yLabel = '',
    this.xLabel = 't (s)',
    this.xMin,
    this.xMax,
    this.markerX,
  });

  final List<TimeSeries> series;
  final PhaseMarks? phases;
  final String yLabel, xLabel;
  final double? xMin, xMax;

  /// Ligne verticale (ex. lâcher à 0 quand les flèches sont alignées).
  final double? markerX;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.45,
      child: CustomPaint(
        painter: _TimePainter(
          series: series,
          phases: phases,
          yLabel: yLabel,
          xLabel: xLabel,
          xMin: xMin,
          xMax: xMax,
          markerX: markerX,
          fg: cs.onSurface,
          grid: cs.outlineVariant,
          bg: cs.surfaceContainerLowest,
        ),
      ),
    );
  }
}

class _TimePainter extends CustomPainter {
  _TimePainter({
    required this.series,
    required this.phases,
    required this.yLabel,
    required this.xLabel,
    required this.xMin,
    required this.xMax,
    required this.markerX,
    required this.fg,
    required this.grid,
    required this.bg,
  });

  final List<TimeSeries> series;
  final PhaseMarks? phases;
  final String yLabel, xLabel;
  final double? xMin, xMax, markerX;
  final Color fg, grid, bg;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 46.0, bottom = 30.0, top = 16.0, right = 8.0;
    final r = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

    var x0 = xMin ?? double.infinity, x1 = xMax ?? -double.infinity;
    if (xMin == null || xMax == null) {
      for (final s in series) {
        if (s.t.isEmpty) continue;
        if (xMin == null) x0 = min(x0, s.t.first);
        if (xMax == null) x1 = max(x1, s.t.last);
      }
    }
    if (!x0.isFinite || !x1.isFinite || x1 <= x0) {
      x0 = 0;
      x1 = 1;
    }
    var y0 = double.infinity, y1 = -double.infinity;
    for (final s in series) {
      for (var i = 0; i < s.t.length; i++) {
        if (s.t[i] < x0 || s.t[i] > x1) continue;
        y0 = min(y0, s.v[i]);
        y1 = max(y1, s.v[i]);
      }
    }
    if (!y0.isFinite) {
      y0 = -1;
      y1 = 1;
    }
    if (y1 - y0 < 1e-6) {
      y0 -= 1;
      y1 += 1;
    }
    final ys = niceStep((y1 - y0) / 4);
    y0 = (y0 / ys).floor() * ys;
    y1 = (y1 / ys).ceil() * ys;

    double px(double x) => r.left + (x - x0) / (x1 - x0) * r.width;
    double py(double y) => r.bottom - (y - y0) / (y1 - y0) * r.height;

    canvas.drawRect(r, Paint()..color = bg);
    canvas.save();
    canvas.clipRect(r);

    final ph = phases;
    if (ph != null) {
      final bands = [
        ('A', x0, ph.b, const Color(0xFF9E9E9E)),
        ('B', ph.b, ph.c, const Color(0xFF1E88E5)),
        ('C', ph.c, ph.d, const Color(0xFF43A047)),
        ('D', ph.d, ph.end, const Color(0xFFFB8C00)),
      ];
      for (final (name, a, b, col) in bands) {
        if (b <= a) continue;
        final rect = Rect.fromLTRB(px(a), r.top, px(b), r.bottom);
        canvas.drawRect(rect, Paint()..color = col.withValues(alpha: 0.10));
        if (rect.width > 14) {
          _text(canvas, name, Offset(rect.center.dx, r.top + 2), col, size: 11);
        }
      }
    }

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = 0.5;
    for (var y = y0; y <= y1 + ys / 2; y += ys) {
      canvas.drawLine(Offset(r.left, py(y)), Offset(r.right, py(y)), gridPaint);
    }
    if (y0 < 0 && y1 > 0) {
      canvas.drawLine(Offset(r.left, py(0)), Offset(r.right, py(0)),
          Paint()..color = fg.withValues(alpha: 0.4));
    }
    final mx = markerX ?? ph?.d;
    if (mx != null && mx >= x0 && mx <= x1) {
      canvas.drawLine(Offset(px(mx), r.top), Offset(px(mx), r.bottom),
          Paint()
            ..color = const Color(0xFFFB8C00)
            ..strokeWidth = 1.2);
    }

    for (final s in series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < s.t.length; i++) {
        if (s.t[i] < x0 || s.t[i] > x1) continue;
        final p = Offset(px(s.t[i]), py(s.v[i]));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width
            ..strokeJoin = StrokeJoin.round
            ..color = s.color);
    }
    canvas.restore();
    canvas.drawRect(r, Paint()..style = PaintingStyle.stroke..color = grid);

    final label = fg.withValues(alpha: 0.75);
    for (var y = y0; y <= y1 + ys / 2; y += ys) {
      _text(canvas, _tick(y), Offset(r.left - 4, py(y)), label, ax: 1, ay: 0.5);
    }
    final xs = niceStep((x1 - x0) / 6);
    for (var x = (x0 / xs).ceil() * xs; x <= x1 + 1e-9; x += xs) {
      _text(canvas, _tick(x), Offset(px(x), r.bottom + 3), label);
    }
    _text(canvas, xLabel, Offset(r.center.dx, size.height - 1), fg, ay: 1, size: 11);
    _text(canvas, yLabel, Offset(1, r.center.dy), fg, size: 11, vertical: true);
  }

  @override
  bool shouldRepaint(covariant _TimePainter old) => true;
}

// ---------------------------------------------------------------------------
// Légendes
// ---------------------------------------------------------------------------

class ChartLegend extends StatelessWidget {
  const ChartLegend(this.items, {super.key});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          ]),
      ],
    );
  }
}

class AccelScaleBar extends StatelessWidget {
  const AccelScaleBar({super.key, required this.min, required this.max});
  final double min, max;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(children: [
      Text('Accél. ${min.toStringAsFixed(2).replaceAll('.', ',')}', style: style),
      const SizedBox(width: 6),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [accColor(0), accColor(0.5), accColor(1)]),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('${max.toStringAsFixed(2).replaceAll('.', ',')} m/s²', style: style),
    ]);
  }
}
