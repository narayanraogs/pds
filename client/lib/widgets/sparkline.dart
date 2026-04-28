import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double? min;
  final double? max;

  const Sparkline({
    super.key,
    required this.data,
    required this.color,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();

    return CustomPainterWidget(
      data: data,
      color: color,
      min: min,
      max: max,
    );
  }
}

class CustomPainterWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double? min;
  final double? max;

  const CustomPainterWidget({
    super.key,
    required this.data,
    required this.color,
    this.min,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(data, color, min, max),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double? fixedMin;
  final double? fixedMax;

  _SparklinePainter(this.data, this.color, this.fixedMin, this.fixedMax);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2 || size.width <= 0 || size.height <= 0) return;

    final validData = data.where((v) => v.isFinite).toList();
    if (validData.length < 2) return;

    // AUTO-SCALE LOGIC
    double dataMin = validData[0];
    double dataMax = validData[0];
    for (var val in validData) {
      if (val < dataMin) dataMin = val;
      if (val > dataMax) dataMax = val;
    }

    // Apply 5% padding to the range
    double padding = (dataMax - dataMin).abs() * 0.05;
    if (padding < 0.0001) padding = 1.0; // Avoid flat lines taking 0 height

    double minVal = fixedMin ?? (dataMin - padding);
    double maxVal = fixedMax ?? (dataMax + padding);

    double range = maxVal - minVal;
    if (range.abs() < 0.000001 || !range.isFinite) range = 1.0;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (validData.length - 1);

    Offset lastPoint = Offset.zero;
    bool started = false;
    for (int i = 0; i < validData.length; i++) {
      final val = validData[i];
      final x = i * stepX;
      final normalized = (val - minVal) / range;
      final y = size.height - (normalized.clamp(0.0, 1.0) * size.height);
      
      final currentPoint = Offset(x, y);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
      lastPoint = currentPoint;
    }

    if (started) {
      // Draw Area Fill
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, paint);

      // Draw Highlight Dot
      final dotPaint = Paint()..color = color;
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      canvas.drawCircle(lastPoint, 4.5, glowPaint);
      canvas.drawCircle(lastPoint, 2.5, dotPaint);
      canvas.drawCircle(lastPoint, 1.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
