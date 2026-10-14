import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/measurement.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/format.dart';

/// Courbe d'évolution du poids, dessinée à la main (aucune dépendance).
/// [points] doit être trié par date croissante.
class WeightChart extends StatelessWidget {
  final List<Measurement> points;
  final double height;

  /// Version compacte (aperçu) : sans grille ni étiquettes de dates.
  final bool compact;

  const WeightChart({super.key, required this.points, this.height = 170, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Pas encore de mesure', style: AppText.caption)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(painter: _WeightPainter(points, compact: compact)),
        ),
        if (!compact && points.length > 1) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDate(points.first.date), style: AppText.caption.copyWith(fontSize: 10.5)),
                Text(formatDate(points.last.date), style: AppText.caption.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<Measurement> points;
  final bool compact;
  _WeightPainter(this.points, {required this.compact});

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = compact ? 6.0 : 34.0;
    const topPad = 22.0; // place pour l'étiquette du dernier point
    const bottomPad = 8.0;
    const rightPad = 10.0;
    final chart = Rect.fromLTRB(leftPad, topPad, size.width - rightPad, size.height - bottomPad);

    // Échelle verticale avec marge, au moins 2 kg d'amplitude pour éviter une courbe « hachée ».
    final weights = points.map((p) => p.weightKg.toDouble()).toList();
    var minW = weights.reduce(math.min);
    var maxW = weights.reduce(math.max);
    if (maxW - minW < 2) {
      final mid = (maxW + minW) / 2;
      minW = mid - 1;
      maxW = mid + 1;
    }
    final pad = (maxW - minW) * 0.15;
    minW -= pad;
    maxW += pad;

    // Échelle horizontale proportionnelle au temps (et non à l'index).
    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
    double x(Measurement m) => points.length == 1 || t1 == t0
        ? chart.center.dx
        : chart.left + (m.date.millisecondsSinceEpoch - t0) / (t1 - t0) * chart.width;
    double y(num w) => chart.bottom - (w - minW) / (maxW - minW) * chart.height;

    // Grille + étiquettes kg (3 lignes).
    if (!compact) {
      final gridPaint = Paint()
        ..color = AppColors.border
        ..strokeWidth = 1;
      for (var i = 0; i <= 2; i++) {
        final w = minW + (maxW - minW) * i / 2;
        final gy = y(w);
        canvas.drawLine(Offset(chart.left, gy), Offset(chart.right, gy), gridPaint);
        _text(canvas, formatKg(w), Offset(0, gy - 7), AppColors.muted, 10.5, width: leftPad - 6, alignRight: true);
      }
    }

    final offsets = [for (final p in points) Offset(x(p), y(p.weightKg))];

    if (offsets.length > 1) {
      // Courbe lissée (Catmull-Rom → Bézier).
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (var i = 0; i < offsets.length - 1; i++) {
        final p0 = i == 0 ? offsets[i] : offsets[i - 1];
        final p1 = offsets[i];
        final p2 = offsets[i + 1];
        final p3 = i + 2 < offsets.length ? offsets[i + 2] : p2;
        final c1 = p1 + (p2 - p0) / 6;
        final c2 = p2 - (p3 - p1) / 6;
        line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
      // Remplissage dégradé sous la courbe.
      final fill = Path.from(line)
        ..lineTo(offsets.last.dx, chart.bottom)
        ..lineTo(offsets.first.dx, chart.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accent.withValues(alpha: 0.35), AppColors.accent.withValues(alpha: 0)],
          ).createShader(chart),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 2 : 2.6
          ..strokeCap = StrokeCap.round
          ..shader = AppColors.progressGradient.createShader(chart),
      );
    }

    // Points (le dernier plus gros, avec sa valeur).
    if (!compact || offsets.length == 1) {
      for (final o in offsets.take(offsets.length - 1)) {
        canvas.drawCircle(o, 3, Paint()..color = AppColors.accent2);
      }
    }
    final last = offsets.last;
    canvas.drawCircle(last, 6, Paint()..color = AppColors.background);
    canvas.drawCircle(last, 4.5, Paint()..color = AppColors.accent);
    _text(canvas, '${formatKg(points.last.weightKg)} kg', last + const Offset(-60, -21), AppColors.text, 11.5,
        width: 120, center: true, bold: true);
  }

  void _text(Canvas canvas, String s, Offset at, Color color, double size,
      {double width = 60, bool alignRight = false, bool center = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: AppText.body, color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
      textAlign: center ? TextAlign.center : (alignRight ? TextAlign.right : TextAlign.left),
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_WeightPainter old) => old.points != points || old.compact != compact;
}
