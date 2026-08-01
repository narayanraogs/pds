import 'dart:math' as math;
import 'package:flutter/material.dart';

class CriticalChartPainter extends CustomPainter {
  final List<double> tm1History;
  final List<double> tm2History;
  final double lowerLimit;
  final double upperLimit;
  final bool isDark;
  final bool isViolated1;
  final bool isViolated2;

  CriticalChartPainter({
    required this.tm1History,
    required this.tm2History,
    required this.lowerLimit,
    required this.upperLimit,
    required this.isDark,
    required this.isViolated1,
    required this.isViolated2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double padding = 24.0;
    final double chartWidth = size.width - (padding * 2);
    final double chartHeight = size.height - (padding * 2);

    // Compute Y range (ensure limits and both TM histories fit)
    double minY = lowerLimit;
    double maxY = upperLimit;

    if (tm1History.isNotEmpty) {
      for (final v in tm1History) {
        minY = math.min(minY, v);
        maxY = math.max(maxY, v);
      }
    }

    if (tm2History.isNotEmpty) {
      for (final v in tm2History) {
        minY = math.min(minY, v);
        maxY = math.max(maxY, v);
      }
    }

    // Add 15% margin so limits aren't stuck right to edges
    double range = maxY - minY;
    if (range == 0) range = 1.0;
    minY -= range * 0.15;
    maxY += range * 0.15;
    range = maxY - minY;

    double getY(double val) {
      final normalized = (val - minY) / range;
      return padding + chartHeight * (1.0 - normalized.clamp(0.0, 1.0));
    }

    // 1. Draw Background Grid Lines
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight * i / 4);
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // 2. Draw Upper Limit Line (Dashed Red Line)
    final upperY = getY(upperLimit);
    _drawDashedLine(
      canvas,
      Offset(padding, upperY),
      Offset(size.width - padding, upperY),
      const Color(0xFFEF4444),
      2.0,
    );

    _drawLabel(
      canvas,
      'UPPER: ${upperLimit.toStringAsFixed(2)}',
      Offset(padding + 4, upperY - 14),
      const Color(0xFFEF4444),
    );

    // 3. Draw Lower Limit Line (Dashed Red Line)
    final lowerY = getY(lowerLimit);
    _drawDashedLine(
      canvas,
      Offset(padding, lowerY),
      Offset(size.width - padding, lowerY),
      const Color(0xFFEF4444),
      2.0,
    );

    _drawLabel(
      canvas,
      'LOWER: ${lowerLimit.toStringAsFixed(2)}',
      Offset(padding + 4, lowerY + 3),
      const Color(0xFFEF4444),
    );

    // 4. Draw TM2 History Curve (Cyan/Blue)
    final tm2Color = isViolated2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    _drawSeriesCurve(canvas, tm2History, tm2Color, getY, padding, chartWidth, chartHeight, isViolated2, 0.15);

    // 5. Draw TM1 History Curve (Green)
    final tm1Color = isViolated1 ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    _drawSeriesCurve(canvas, tm1History, tm1Color, getY, padding, chartWidth, chartHeight, isViolated1, 0.20);
  }

  void _drawSeriesCurve(
    Canvas canvas,
    List<double> history,
    Color color,
    double Function(double) getY,
    double padding,
    double chartWidth,
    double chartHeight,
    bool isViolated,
    double fillAlpha,
  ) {
    if (history.length < 2) return;

    final path = Path();
    final double stepX = chartWidth / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final x = padding + (i * stepX);
      final y = getY(history[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Fill Area under curve
    final fillPath = Path.from(path)
      ..lineTo(padding + chartWidth, padding + chartHeight)
      ..lineTo(padding, padding + chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isViolated ? 0.35 : fillAlpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(padding, padding, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Latest Data Point Indicator Dot
    final lastX = padding + ((history.length - 1) * stepX);
    final lastY = getY(history.last);
    final dotOffset = Offset(lastX, lastY);

    final dotGlow = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(dotOffset, 5.5, dotGlow);
    canvas.drawCircle(dotOffset, 3.0, Paint()..color = color);
    canvas.drawCircle(dotOffset, 1.2, Paint()..color = Colors.white);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5;
    const double dashSpace = 4;
    double startX = p1.dx;

    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(math.min(startX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CriticalChartPainter oldDelegate) {
    return oldDelegate.tm1History != tm1History ||
        oldDelegate.tm2History != tm2History ||
        oldDelegate.lowerLimit != lowerLimit ||
        oldDelegate.upperLimit != upperLimit ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isViolated1 != isViolated1 ||
        oldDelegate.isViolated2 != isViolated2;
  }
}
