import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/libyan_prayer_database.dart';
import 'dart:math' as math;

class QiblaScreen extends StatefulWidget {
  final VoidCallback onBack;
  const QiblaScreen({super.key, required this.onBack});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with SingleTickerProviderStateMixin {
  double? _qDir, _dist, _lat, _long;
  String? _cityName;
  bool _loading = true;
  bool _isOfflineFallback = false;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // للحصول على حركة سلسة للبوصلة
  double _lastHeading = 0;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _calc();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _calc() async {
    try {
      // محاولة الحصول على الموقع الحالي (GPS)
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      
      Position? p;
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        try {
          p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {
          p = null;
        }
      }

      if (p != null) {
        // نجح GPS -> احفظ الموقع للاستخدام المستقبلي
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('last_lat', p.latitude);
        await prefs.setDouble('last_lng', p.longitude);
        _updateQibla(p.latitude, p.longitude);
      } else {
        // فشل GPS -> حاول استخدام آخر موقع معروف
        final prefs = await SharedPreferences.getInstance();
        final lastLat = prefs.getDouble('last_lat');
        final lastLng = prefs.getDouble('last_lng');
        if (lastLat != null && lastLng != null) {
          _updateQibla(lastLat, lastLng);
        } else {
          // لا يوجد موقع سابق -> استخدم المدينة المحفوظة
          await _fallbackToCity();
        }
      }
    } catch (e) {
      await _fallbackToCity();
    }
  }

  Future<void> _fallbackToCity() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString('city') ?? 'طرابلس';
    final coord = LibyanPrayerDatabase.getCityCoordinates(city);
    
    if (mounted) {
      setState(() {
        _cityName = city;
        _isOfflineFallback = true;
        _updateQibla(coord.latitude, coord.longitude);
      });
    }
  }

  void _updateQibla(double lat, double lng) {
    final q = Qibla(Coordinates(lat, lng));
    if (mounted) {
      setState(() {
        _qDir = q.direction;
        _dist = Geolocator.distanceBetween(lat, lng, 21.4225, 39.8262) / 1000;
        _lat = lat;
        _long = lng;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            const SizedBox(height: 28),
            _buildHeader(),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : StreamBuilder<CompassEvent>(
                      stream: FlutterCompass.events,
                      builder: (context, snapshot) {
                        // التعامل مع خطأ البوصلة أو عدم توفر حساس البوصلة
                        if (snapshot.hasError || !snapshot.hasData) {
                          // البوصلة غير متاحة -> اعرض اتجاه القبلة الثابت
                          if (_qDir != null) {
                            return _buildCompassContent(_qDir!, 0, null);
                          }
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.explore_off_rounded, color: Colors.amber[200], size: 48),
                                const SizedBox(height: 12),
                                Text('حساس البوصلة غير متاح',
                                  style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 6),
                                if (_qDir != null)
                                  Text('اتجاه القبلة: ${_qDir!.toStringAsFixed(1)}°',
                                    style: GoogleFonts.poppins(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }
                        double heading = snapshot.data?.heading ?? 0;
                        if ((heading - _lastHeading).abs() > 0.1) {
                          _lastHeading = heading;
                        } else {
                          heading = _lastHeading;
                        }
                        if (_qDir == null) {
                          return const Center(child: CircularProgressIndicator(color: Colors.amber));
                        }
                        double qiblaRotation = ((_qDir! - heading) * (math.pi / 180));
                        return _buildCompassContent(heading, qiblaRotation, snapshot.data);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassContent(double heading, double qiblaRotation, CompassEvent? compassData) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        if (_isOfflineFallback)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Text(
              'وضع اوفلاين: $_cityName',
              style: GoogleFonts.tajawal(fontSize: 10, color: Colors.amber[200]),
            ),
          ),
        Text(
          '${_qDir!.toStringAsFixed(1)}°',
          style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
            Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 8),
          ]),
        ),
        const SizedBox(height: 2),
        if (_dist != null)
          Text(
            '${_dist!.toStringAsFixed(0)} كم إلى الكعبة',
            style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, shadows: [
              Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 6),
            ]),
          ),
        const SizedBox(height: 12),
        _buildCompassDial(heading, qiblaRotation),
        const SizedBox(height: 12),
        if (compassData?.accuracy != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vibration_rounded, size: 12, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  'حرك الهاتف لمعايرة الحساس',
                  style: GoogleFonts.tajawal(fontSize: 9, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        if (_lat != null && _long != null)
          _buildInfoPanel(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem(Icons.explore_rounded, 'الاتجاه', '${_qDir!.toStringAsFixed(0)}°'),
          _buildInfoItem(Icons.gps_fixed_rounded, 'الموقع', '${_lat!.toStringAsFixed(2)}°, ${_long!.toStringAsFixed(2)}°'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.tajawal(fontSize: 8, color: Colors.white38)),
        Text(value, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 10),
          Text('بوصلة القبلة', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCompassDial(double heading, double qiblaRotation) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.08), blurRadius: 40, spreadRadius: 4),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. External Dial (Cardinal Directions)
          Transform.rotate(
            angle: (-heading * (math.pi / 180)),
            child: CustomPaint(
              size: const Size(190, 190),
              painter: _CompassPainter(),
            ),
          ),
          // 2. Qibla Needle
          Transform.rotate(
            angle: qiblaRotation,
            child: Column(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 28),
                Container(
                  width: 3,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
          // 3. Center Point
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw main circle
    canvas.drawCircle(center, radius, paint);

    // Draw Ticks
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * (math.pi / 180);
      final isCardinal = i % 18 == 0; // N, E, S, W
      final isSubCardinal = i % 9 == 0 && !isCardinal;
      
      final tickLength = isCardinal ? 15.0 : (isSubCardinal ? 10.0 : 5.0);
      final tickPaint = Paint()
        ..color = isCardinal ? Colors.white : (isSubCardinal ? Colors.white : Colors.white24)
        ..strokeWidth = isCardinal ? 2.5 : 1.5;

      final start = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      final __end = Offset(
        center.dx + (radius - 5 - tickLength) * math.cos(angle),
        center.dy + (radius - 5 - tickLength) * math.sin(angle),
      );
      canvas.drawLine(start, __end, tickPaint);

      // Draw Letters
      if (isCardinal) {
        final label = _getLabel(i);
        _drawText(canvas, label, center, radius - 30, angle);
      }
    }
  }

  String _getLabel(int i) {
    if (i == 0) return 'N';
    if (i == 18) return 'E';
    if (i == 36) return 'S';
    if (i == 54) return 'W';
    return '';
  }

  void _drawText(Canvas canvas, String text, Offset center, double radius, double angle) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final x = center.dx + radius * math.cos(angle) - textPainter.width / 2;
    final y = center.dy + radius * math.sin(angle) - textPainter.height / 2;
    
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
