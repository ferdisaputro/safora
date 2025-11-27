import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;


class FlutterMapCompass extends StatelessWidget {
  final MapController mapController;
  final Alignment alignment;
  final EdgeInsets padding;
  final double size;
  final VoidCallback? onTap;

  const FlutterMapCompass({
    super.key,
    required this.mapController,
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(12),
    this.size = 60,
    this.onTap, required BoxDecoration decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: StreamBuilder<MapEvent>(
          stream: mapController.mapEventStream, // 🔥 dengerin perubahan map
          builder: (context, snapshot) {
            final rotation = mapController.camera.rotation;

            return GestureDetector(
              onTap: onTap ?? () => mapController.rotate(0), // reset ke utara
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: rotation * (math.pi / 180), // ✅ ubah ke radian dan ikut arah mata angin
                  child: CustomPaint(
                    painter: _CompassNeedlePainter(),
                    size: Size(size, size),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}

class _CompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double needleWidth = size.width * 0.25;
    final double needleHeight = size.height * 0.45;

    final Paint redPaint = Paint()..color = Colors.red;
    final Paint greyPaint = Paint()..color = Colors.grey.shade600;

    // Segitiga atas (Utara, merah)
    final Path northTriangle = Path()
      ..moveTo(center.dx, center.dy - needleHeight)
      ..lineTo(center.dx - needleWidth / 2, center.dy)
      ..lineTo(center.dx + needleWidth / 2, center.dy)
      ..close();

    // Segitiga bawah (Selatan, abu-abu)
    final Path southTriangle = Path()
      ..moveTo(center.dx, center.dy + needleHeight)
      ..lineTo(center.dx - needleWidth / 2, center.dy)
      ..lineTo(center.dx + needleWidth / 2, center.dy)
      ..close();

    canvas.drawPath(northTriangle, redPaint);
    canvas.drawPath(southTriangle, greyPaint);

    // Titik tengah
    final Paint centerDot = Paint()..color = Colors.white;
    canvas.drawCircle(center, size.width * 0.08, centerDot);
    final Paint borderDot = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, size.width * 0.08, borderDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
