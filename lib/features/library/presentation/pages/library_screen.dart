import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/islamic_data.dart';
import '../../../../main.dart'; // For pushDark, SurahListPage, etc.
import '../../../../advanced_settings_screen.dart';
import '../../../quran/presentation/pages/surah_list_page.dart';
import '../../../quran/presentation/bloc/quran_bloc.dart';
import '../../../quran/presentation/bloc/quran_state.dart';
import '../../../quran/presentation/bloc/quran_audio_bloc.dart';
import '../../../quran/presentation/pages/quran_view_page.dart';
import '../../../quran/domain/entities/surah.dart';
import '../../../quran/data/datasources/quran_settings_data_source.dart';
import '../../../quran/presentation/bloc/quran_event.dart';
import '../../../voice/voice_assistant_sheet.dart';
import '../../../voice/voice_service.dart';
import 'dart:ui' as ui;
import '../../../../injection_container.dart' as di;
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/constants/nawawi_hadith.dart';
import 'ruqyah_player_screen.dart';
import 'khatma_screen.dart';
import 'prophetic_hadith_screen.dart';
import 'sahaba_list_page.dart';
import '../../../live/presentation/pages/kaaba_live_screen.dart';

class IslamicLibraryScreen extends StatefulWidget {
  final Coordinates? coordinates;
  final List<int>? offsets;
  final VoidCallback onBack;
  const IslamicLibraryScreen({super.key, this.coordinates, this.offsets, required this.onBack});

  @override
  State<IslamicLibraryScreen> createState() => _IslamicLibraryScreenState();
}

class _IslamicLibraryScreenState extends State<IslamicLibraryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  /// يفتح مشغّل الرقية الشرعية كـ ModalBottomSheet
  void _openRuqyahPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => const RuqyahPlayerScreen(),
    );
  }

  /// يفتح خرائط جوجل مباشرة للبحث عن المساجد القريبة
  Future<void> _launchGoogleMapsForMosques() async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=mosques");
    final Uri googleMapsAppUrl = Uri.parse("geo:0,0?q=mosques");

    try {
      // نحاول فتح تطبيق الخرائط أولاً
      bool launched = await launchUrl(googleMapsAppUrl);
      if (!launched) {
        // إذا فشل، نفتح المتصفح
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // في حالة حدوث أي خطأ، نلجأ للمتصفح كخيار آمن
      try {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الخرائط')),
          );
        }
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        InkWell(
                          onTap: widget.onBack,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                child: Text(
                                  'الأذكار والمكتبة',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    shadows: const [
                                      Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                height: 4,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white54,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvancedSettingsScreen(
                            coordinates: widget.coordinates,
                            offsets: widget.offsets,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCard(context, 'القرآن الكريم', Icons.menu_book_rounded, const Color(0xFF002855), () {
                          pushDark(context, const SurahListPage());
                        }),
                        _buildCard(context, 'الأحاديث النبوية', Icons.format_quote_rounded, const Color(0xFF002855), () {
                          pushDark(context, const PropheticHadithScreen());
                        }),
                        _buildCard(context, 'حصن المسلم', Icons.security_rounded, const Color(0xFF002855), () {
                          _showHisnAlMuslim(context);
                        }),
                        _buildCard(context, 'أذكار الصباح', Icons.wb_sunny_rounded, const Color(0xFF002855), () {
                          _showLibraryContent(context, 'أذكار الصباح', IslamicData.morningAzkar);
                        }),
                        _buildCard(context, 'أذكار المساء', Icons.nightlight_round, const Color(0xFF002855), () {
                          _showLibraryContent(context, 'أذكار المساء', IslamicData.eveningAzkar);
                        }),
                        // كارد الأربعون النووية وحده يحتفظ بخطّه 14.5 — تنقيص
                        // الواحد لا يشمله (بقية الكاردات 13.5)
                        _buildCard(context, 'الأربعون النووية', Icons.auto_stories_rounded, const Color(0xFF002855), () {
                          _showNawawiHadiths(context);
                        }, fontSize: 14.5),
                        _buildCard(context, 'تسبيح', Icons.touch_app_rounded, const Color(0xFF002855), () {
                          _showTasbih(context);
                        }),
                        _buildCard(context, 'الرقية الشرعية', Icons.shield_rounded, const Color(0xFF002855), () {
                          _openRuqyahPlayer(context);
                        }),
                        _buildCard(context, 'بث مباشر الكعبة', Icons.live_tv_rounded, const Color(0xFF002855), () {
                          pushDark(context, const KaabaLiveScreen());
                        }, useAmiri: true),
                        _buildCard(context, 'خرائط قوقل', Icons.map_rounded, const Color(0xFF002855), () {
                          _launchGoogleMapsForMosques();
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// [fontSize] خطّ عنوان الكارد — 13.5 افتراضاً، ويُرفع لكارد واحد بعينه
  /// (الأربعون النووية) فلا يشملها أي تنقيص عام على كاردات الشاشة.
  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap, {bool useAmiri = false, double fontSize = 13.5}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AuroraGlassCard(
        borderRadius: BorderRadius.circular(24),
        blur: 16,
        isActive: true,
        glowColor: color.withOpacity(0.4),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.amiri(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLibraryContent(BuildContext context, String title, List<String> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0C192E).withValues(alpha: 0.88),
                    const Color(0xFF040A14).withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFDFBA6B).withValues(alpha: 0.40),
                  width: 1.2,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 25,
                    spreadRadius: 4,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  _buildSheetHeader(context, title),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: const Color(0xFFDFBA6B).withValues(alpha: 0.25), height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.auto_awesome, color: const Color(0xFFDFBA6B).withValues(alpha: 0.6), size: 14),
                            ),
                            Expanded(child: Divider(color: const Color(0xFFDFBA6B).withValues(alpha: 0.25), height: 1)),
                          ],
                        ),
                      ),
                      itemBuilder: (c, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Text(
                          items[i],
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            color: const Color(0xFFFAF7F2),
                            fontSize: 20,
                            height: 2.1,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// فاصل إسلامي زخرفي وناعم بين الأذكار
  Widget _buildDhikrSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.0),
                    Colors.amber.withOpacity(0.35),
                    Colors.amber.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "✦",
              style: TextStyle(
                color: Colors.amber.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.7),
                    Colors.amber.withOpacity(0.35),
                    Colors.amber.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, String title) {
    IconData headerIcon;
    Color iconColor;
    Color glowColor;

    if (title.contains('الصباح')) {
      headerIcon = Icons.wb_sunny_rounded;
      iconColor = const Color(0xFFFFD54F);
      glowColor = const Color(0xFFFFB300);
    } else if (title.contains('المساء')) {
      headerIcon = Icons.nightlight_round;
      iconColor = const Color(0xFF90CAF9);
      glowColor = const Color(0xFF42A5F5);
    } else if (title.contains('النوم')) {
      headerIcon = Icons.bedtime_rounded;
      iconColor = const Color(0xFFCE93D8);
      glowColor = const Color(0xFFAB47BC);
    } else if (title.contains('الاستيقاظ')) {
      headerIcon = Icons.wb_twilight_rounded;
      iconColor = const Color(0xFFFFB74D);
      glowColor = const Color(0xFFFF9800);
    } else if (title.contains('النووية') || title.contains('الأربعون')) {
      headerIcon = Icons.auto_stories_rounded;
      iconColor = const Color(0xFF81C784);
      glowColor = const Color(0xFF4CAF50);
    } else if (title.contains('حصن')) {
      headerIcon = Icons.shield_rounded;
      iconColor = const Color(0xFFFFD54F);
      glowColor = const Color(0xFFFFB300);
    } else {
      headerIcon = Icons.auto_awesome_rounded;
      iconColor = Colors.amber;
      glowColor = Colors.amberAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
        ),
      ),
      child: Row(
        children: [
          // زر الرجوع
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          // العنوان والأيقونة في المنتصف
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.35), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(headerIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  void _showNawawiHadiths(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF071A10).withValues(alpha: 0.92),
                    const Color(0xFF040A08).withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 25,
                    spreadRadius: 4,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  _buildSheetHeader(context, 'الأربعون النووية'),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                      itemCount: NawawiHadithData.hadiths.length,
                      separatorBuilder: (context, index) => _buildDhikrSeparator(),
                      itemBuilder: (context, index) {
                        final hadith = NawawiHadithData.hadiths[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                hadith['title']!,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.tajawal(
                                  color: const Color(0xFF81C784),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hadith['text']!,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.amiri(
                                  color: const Color(0xFFFAF7F2),
                                  fontSize: 18,
                                  height: 2.0,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHisnAlMuslim(BuildContext context) {
    final categories = [
      {'title': 'أذكار النوم', 'items': IslamicData.sleepAzkar, 'icon': Icons.bedtime_rounded, 'subtitle': 'أدعية وآيات النوم المشروعة', 'color': const Color(0xFFCE93D8)},
      {'title': 'أذكار الاستيقاظ', 'items': IslamicData.wakeUpAzkar, 'icon': Icons.wb_twilight_rounded, 'subtitle': 'أذكار وثناء عند الاستيقاظ', 'color': const Color(0xFFFFB74D)},
      {'title': 'أذكار بعد الصلاة', 'items': IslamicData.afterPrayerAzkar, 'icon': Icons.mosque_rounded, 'subtitle': 'الاستغفار والتسبيح دبر الصلوات', 'color': const Color(0xFF81D4FA)},
      {'title': 'أدعية نبوية', 'items': IslamicData.propheticDuas, 'icon': Icons.auto_awesome_rounded, 'subtitle': 'جوامع دعاء النبي ﷺ', 'color': const Color(0xFFFFD54F)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF07111E), Color(0xFF0A1828), Color(0xFF040A12)],
            ),
            border: Border.all(color: Colors.amber.withOpacity(0.35), width: 1.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 25,
                spreadRadius: 4,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              _buildSheetHeader(context, 'حصن المسلم'),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => _buildDhikrSeparator(),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final Color catColor = cat['color'] as Color;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: catColor.withOpacity(0.35), width: 1.1),
                        ),
                        child: Icon(cat['icon'] as IconData, color: catColor, size: 22),
                      ),
                      title: Text(
                        cat['title'] as String,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: Text(
                        cat['subtitle'] as String,
                        style: GoogleFonts.tajawal(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.amber.withOpacity(0.5),
                        size: 15,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showLibraryContent(context, cat['title'] as String, cat['items'] as List<String>);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTasbih(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int count = prefs.getInt('tasbeeh_count') ?? 0;
    int target = prefs.getInt('tasbeeh_target') ?? 33;
    int selectedDhikr = prefs.getInt('tasbeeh_dhikr_index') ?? 0;
    bool vibrateEnabled = prefs.getBool('tasbeeh_vibrate') ?? true;

    final List<Map<String, String>> adhkar = [
      {'text': 'سُبْحَانَ اللّٰه', 'short': 'سبحان الله'},
      {'text': 'اَلْحَمْدُ لِلّٰه', 'short': 'الحمد لله'},
      {'text': 'اللّٰهُ أَكْبَر', 'short': 'الله أكبر'},
      {'text': 'لَا إِلٰهَ إِلَّا اللّٰه', 'short': 'لا إله إلا الله'},
      {'text': 'اَسْتَغْفِرُ اللّٰه', 'short': 'أستغفر الله'},
      {'text': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللّٰه', 'short': 'لا حول ولا قوة إلا بالله'},
    ];
    final List<int> targets = [33, 34, 99, 100, 1000];

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setST) {
          final double progress = target > 0 ? (count % target) / target : 0;
          final int rounds = target > 0 ? count ~/ target : 0;
          final bool justCompleted = target > 0 && count > 0 && count % target == 0;

          // ── ألوان هادئة ومريحة متناسقة مع التطبيق ──
          const Color cardBg       = Color(0xFF112238);
          const Color accentColor  = Color(0xFF7986CB);

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0C192E).withValues(alpha: 0.88),
                      const Color(0xFF040A14).withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: const Color(0xFF4DB6AC).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 2,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Handle bar
                      const SizedBox(height: 8),
                      Container(
                        width: 40, height: 3,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(height: 6),

                      // ── Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // زر الرجوع
                            InkWell(
                              onTap: () => Navigator.pop(ctx),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            Text(
                              'المسبحة الإلكترونية',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // زر إعادة العد
                            InkWell(
                              onTap: () async {
                                HapticFeedback.mediumImpact();
                                setST(() => count = 0);
                                await prefs.setInt('tasbeeh_count', 0);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(color: Colors.white.withOpacity(0.10), height: 1, indent: 16, endIndent: 16),
                      const SizedBox(height: 10),

                      // ── كاردات الأذكار الصغيرة ظاهرة بالكامل للمستخدم (3 في كل سطر)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                for (int i = 0; i < 3; i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildDhikrSmallCard(
                                      title: adhkar[i]['short']!,
                                      isSelected: selectedDhikr == i,
                                      cardBg: cardBg,
                                      onTap: () async {
                                        HapticFeedback.selectionClick();
                                        setST(() { selectedDhikr = i; count = 0; });
                                        await prefs.setInt('tasbeeh_dhikr_index', i);
                                        await prefs.setInt('tasbeeh_count', 0);
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                for (int i = 3; i < 6; i++) ...[
                                  if (i > 3) const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildDhikrSmallCard(
                                      title: adhkar[i]['short']!,
                                      isSelected: selectedDhikr == i,
                                      cardBg: cardBg,
                                      onTap: () async {
                                        HapticFeedback.selectionClick();
                                        setST(() { selectedDhikr = i; count = 0; });
                                        await prefs.setInt('tasbeeh_dhikr_index', i);
                                        await prefs.setInt('tasbeeh_count', 0);
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Main Dhikr Text فوق الدائرة (حجم 13 ونوع الخط تجوال)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          adhkar[selectedDhikr]['text']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Progress Arc + Counter (حجم متناسق واهتزاز مفعّل)
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // حلقة التقدم
                            SizedBox(
                              width: 110, height: 110,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 6.5,
                                backgroundColor: Colors.white.withOpacity(0.10),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  justCompleted ? const Color(0xFF81C784) : accentColor,
                                ),
                              ),
                            ),
                            // الزر الرئيسي
                            GestureDetector(
                              onTap: () async {
                                if (vibrateEnabled) {
                                  HapticFeedback.vibrate();
                                }
                                setST(() => count++);
                                await prefs.setInt('tasbeeh_count', count);
                                if (vibrateEnabled && count % target == 0 && count > 0) {
                                  HapticFeedback.heavyImpact();
                                  Future.delayed(const Duration(milliseconds: 120), () {
                                    HapticFeedback.vibrate();
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                width: 88, height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF1E3553), Color(0xFF102035)],
                                  ),
                                  border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.25),
                                      blurRadius: 18, spreadRadius: 1,
                                    ),
                                    const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${count % (target > 0 ? target : 1)}',
                                      style: TextStyle(
                                        fontFamily: 'Amiri',
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'من $target',
                                      style: TextStyle(
                                        fontFamily: 'Amiri',
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 13,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Rounds + Total (حجم 13 ونوع الخط تجوال)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _tasbihStat('الجولات', '$rounds', Icons.repeat_rounded),
                            _tasbihStat('الإجمالي', '$count', Icons.calculate_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Settings Row (الهدف واهتزاز: حجم 13 ونوع الخط تجوال)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text('الهدف:', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  DropdownButton<int>(
                                    value: target,
                                    dropdownColor: const Color(0xFF0D2137),
                                    iconEnabledColor: Colors.white,
                                    underline: const SizedBox(),
                                    style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    items: targets.map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text('$t', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13)),
                                    )).toList(),
                                    onChanged: (v) async {
                                      if (v == null) return;
                                      setST(() { target = v; count = 0; });
                                      await prefs.setInt('tasbeeh_target', v);
                                      await prefs.setInt('tasbeeh_count', 0);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.vibration_rounded, color: vibrateEnabled ? Colors.white : Colors.white54, size: 16),
                                const SizedBox(width: 4),
                                Text('اهتزاز', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13)),
                                const SizedBox(width: 2),
                                Transform.scale(
                                  scale: 0.70,
                                  child: Switch(
                                    value: vibrateEnabled,
                                    onChanged: (v) async {
                                      if (v) HapticFeedback.vibrate();
                                      setST(() => vibrateEnabled = v);
                                      await prefs.setBool('tasbeeh_vibrate', v);
                                    },
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: accentColor,
                                    inactiveThumbColor: Colors.white54,
                                    inactiveTrackColor: Colors.white24,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildDhikrSmallCard({
    required String title,
    required bool isSelected,
    required Color cardBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? cardBg : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.70) : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.2 : 0.7,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7986CB).withOpacity(0.35),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  )
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Amiri',
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tasbihStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF112238).withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  void _showNawawiHadith(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0C192E).withValues(alpha: 0.88),
                    const Color(0xFF040A14).withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF81C784).withValues(alpha: 0.40),
                  width: 1.2,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 25,
                    spreadRadius: 4,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  _buildSheetHeader(context, 'الأربعون النووية'),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                      itemCount: NawawiHadithData.hadiths.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final hadith = NawawiHadithData.hadiths[index];
                        return AuroraGlassCard(
                          borderRadius: BorderRadius.circular(20),
                          blur: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── عنوان الحديث الإسلامي المنسق ──
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF81C784).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF81C784).withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.menu_book_rounded,
                                      color: Color(0xFF81C784),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        hadith['title']!,
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: GoogleFonts.tajawal(
                                          color: const Color(0xFFFFD54F),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ── نص الحديث النبوي الشريف ──
                              Text(
                                hadith['text']!,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.amiri(
                                  color: const Color(0xFFFAF7F2),
                                  fontSize: 19,
                                  height: 2.1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

