import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'core/database/libyan_prayer_database.dart';
import 'advanced_reminders.dart';
import 'core/widgets/glass_scaffold.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  final Coordinates? coordinates;
  final List<int>? offsets;

  const AdvancedSettingsScreen({super.key, this.coordinates, this.offsets});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  bool _remMorning = true;
  bool _remEvening = true;
  bool _remDuha = true;
  bool _remMonThu = true;
  bool _remWhiteDays = true;
  bool _remLastThird = true;
  bool _remSpecialDays = true;
  bool _remFridayPrayer = true;
  bool _remKahf = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remMorning = prefs.getBool(AdvancedReminders.keyMorningAzkar) ?? true;
      _remEvening = prefs.getBool(AdvancedReminders.keyEveningAzkar) ?? true;
      _remDuha = prefs.getBool(AdvancedReminders.keyDuha) ?? true;
      _remMonThu = prefs.getBool(AdvancedReminders.keyMonThu) ?? true;
      _remWhiteDays = prefs.getBool(AdvancedReminders.keyWhiteDays) ?? true;
      _remLastThird = prefs.getBool(AdvancedReminders.keyLastThird) ?? true;
      _remSpecialDays = prefs.getBool(AdvancedReminders.keySpecialDays) ?? true;
      _remFridayPrayer = prefs.getBool(AdvancedReminders.keyFridayPrayer) ?? true;
      _remKahf = prefs.getBool(AdvancedReminders.keyKahf) ?? true;
    });
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    
    // إعادة الجدولة فوراً بكل دقة
    try {
      final city = prefs.getString('city') ?? 'بنغازي';
      final coord = widget.coordinates ?? LibyanPrayerDatabase.getCityCoordinates(city);
      final offsets = widget.offsets ?? [
        prefs.getInt('fOff') ?? 0,
        prefs.getInt('dOff') ?? 0,
        prefs.getInt('aOff') ?? 0,
        prefs.getInt('mOff') ?? 0,
        prefs.getInt('iOff') ?? 0,
        prefs.getInt('sOff') ?? 0,
      ];
      await AdvancedReminders.scheduleAllReminders(coord, offsets, city: city);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إعدادات التنبيهات والوقت',
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSwitchTile(
            title: 'أذكار الصباح',
            subtitle: 'تنبيه ورسالة صوتية بعد شروق الشمس بـ 30 دقيقة',
            icon: Icons.light_mode_rounded,
            iconColor: const Color(0xFF4DB6AC),
            value: _remMorning,
            onChanged: (val) {
              setState(() => _remMorning = val);
              _toggleSetting(AdvancedReminders.keyMorningAzkar, val);
            },
          ),
          _buildSwitchTile(
            title: 'أذكار المساء',
            subtitle: 'تنبيه ورسالة صوتية قبل أذان المغرب بـ 30 دقيقة',
            icon: Icons.nights_stay_rounded,
            iconColor: const Color(0xFF90CAF9),
            value: _remEvening,
            onChanged: (val) {
              setState(() => _remEvening = val);
              _toggleSetting(AdvancedReminders.keyEveningAzkar, val);
            },
          ),
          _buildSwitchTile(
            title: 'صلاة الضحى',
            subtitle: 'تنبيه بعد شروق الشمس بـ 45 دقيقة',
            icon: Icons.wb_twilight_rounded,
            iconColor: const Color(0xFFFFAB91),
            value: _remDuha,
            onChanged: (val) {
              setState(() => _remDuha = val);
              _toggleSetting(AdvancedReminders.keyDuha, val);
            },
          ),
          _buildSwitchTile(
            title: 'صيام الإثنين والخميس',
            subtitle: 'تذكير في الليلة السابقة بعد العشاء',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF81C784),
            value: _remMonThu,
            onChanged: (val) {
              setState(() => _remMonThu = val);
              _toggleSetting(AdvancedReminders.keyMonThu, val);
            },
          ),
          _buildSwitchTile(
            title: 'صيام الأيام البيض',
            subtitle: 'تذكير أيام 13، 14، 15 هجري (في الليلة السابقة)',
            icon: Icons.brightness_3_rounded,
            iconColor: const Color(0xFFE0E0E0),
            value: _remWhiteDays,
            onChanged: (val) {
              setState(() => _remWhiteDays = val);
              _toggleSetting(AdvancedReminders.keyWhiteDays, val);
            },
          ),
          _buildSwitchTile(
            title: 'الثلث الأخير من الليل',
            subtitle: 'تنبيه عند بدء الثلث الأخير',
            icon: Icons.star_purple500_rounded,
            iconColor: const Color(0xFFB39DDB),
            value: _remLastThird,
            onChanged: (val) {
              setState(() => _remLastThird = val);
              _toggleSetting(AdvancedReminders.keyLastThird, val);
            },
          ),
          _buildSwitchTile(
            title: 'الأيام الفاضلة',
            subtitle: 'تذكير بصيام عاشوراء، تاسوعاء، عرفة وعشر ذي الحجة',
            icon: Icons.event_note_rounded,
            iconColor: const Color(0xFFFF8A65),
            value: _remSpecialDays,
            onChanged: (val) {
              setState(() => _remSpecialDays = val);
              _toggleSetting(AdvancedReminders.keySpecialDays, val);
            },
          ),
          _buildSwitchTile(
            title: 'صلاة الجمعة',
            subtitle: 'تنبيه: بقي على صلاة الجمعة 45 دقيقة',
            icon: Icons.mosque_rounded,
            iconColor: const Color(0xFFDFBA6B),
            value: _remFridayPrayer,
            onChanged: (val) {
              setState(() => _remFridayPrayer = val);
              _toggleSetting(AdvancedReminders.keyFridayPrayer, val);
            },
          ),
          _buildSwitchTile(
            title: 'قراءة سورة الكهف',
            subtitle: 'تذكير كل جمعة الساعة 10:00 صباحاً',
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF4DB6AC),
            value: _remKahf,
            onChanged: (val) {
              setState(() => _remKahf = val);
              _toggleSetting(AdvancedReminders.keyKahf, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconColor.withOpacity(0.15), iconColor.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withOpacity(0.1), width: 0.5),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: iconColor,
                activeTrackColor: iconColor.withOpacity(0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
