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
    if (data.length < 2) return;

    double minVal = fixedMin ?? data[0];
    double maxVal = fixedMax ?? data[0];

    if (fixedMin == null || fixedMax == null) {
      for (var val in data) {
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    // Add small padding to avoid touching edges
    double range = maxVal - minVal;
    if (range == 0) range = 1.0;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      // Flip Y because (0,0) is top-left
      final y = size.height - ((data[i] - minVal) / range * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // DRAW SHADOW/AREA BELOW
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(40), color.withAlpha(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
