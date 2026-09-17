import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../../../core/config/home_date_font_prefs.dart';
import '../../../../core/config/prayer_card_font_prefs.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../remote_messaging_service.dart';
import '../pages/home_page.dart';

String _toWestern(String s) => s
  .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
  .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
  .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8')
  .replaceAll('٩', '9');

// لون أيقونة كل صلاة — يُستخدم للأيقونة واسم الصلاة ووقتها والعداد التنازلي.
//
// القيم نفسها في [GlassPalette.prayerTimesColor] — مصدر الحقيقة الواحد: شاشة
// المواقيت والنص المتحرك وشاشة «عن التطبيق» كلها تقرأ من هناك، فلا يختلف
// لون الصلاة من شاشة لأخرى.
Color prayerIconColor(String name) => GlassPalette.prayerTimesColor(name);

/// أدنى ارتفاع لكارد الصلاة حتى يظهر محتواه كاملاً (أيقونة + اسم + وقت/فترة)
/// بلا تلاصق ولا قصّ. إن لم تكفِ المساحة المتاحة لهذا الحد تتحوّل قائمة
/// الصلوات من توزيع ثابت إلى قائمة قابلة للسكرول.
///
/// محتوى الكارد (بلا حشو رأسي: الصف وحده) ≈ 22 بكسل بعد زيادة الـ1.5، فـ40
/// تعني مساحة تنفّس مريحة وليست حدّاً حرجاً — ولهذا لا يتغيّر التصميم الثابت
/// على مقاسات الهواتف المعتادة، ولا يظهر السكرول إلا عندما يضيق حقّاً.
///
/// رقم صريح مقصود: هو المرجع الذي تُقاس عليه المساحة في [LayoutBuilder]،
/// وتؤكّده اختبارات `test/main_screen_text_boost_test.dart` على مقاسات مختلفة.
const double kMinPrayerTileHeight = 40;

/// الفواصل بين كاردات الصلوات (بين كاردين 3، وبعد الأخير 2 كما كان التصميم).
const double _kTileGap = 3;
const double _kTailGap = 2;

/// أقل ارتفاع يكفيه شريط الكاردات كاملاً بلا سكرول داخلي.
const double _kTilesMinHeight =
    kMinPrayerTileHeight * 6 + _kTileGap * 5 + _kTailGap;

/// أقل ارتفاع تكفيه الترويسة + كارد العدّاد + شريط الدعاء معاً. تحته تكون
/// الترويسة وحدها أطول من الشاشة، فلا بد من سحب الشاشة كلها (حالة لا تحدث
/// على شاشة هاتف، لكنها تضمن عدم الأوفرفلو في أي نافذة).
const double _kMinChromeHeight = 260;

/// صفّ في قائمة الصلوات: اسم الصلاة وحرف الفترة (ص/م).
class _PrayerSlot {
  const _PrayerSlot(this.name, this.period);
  final String name;
  final String period;
}

/// ترتيب الصلوات المعروض في الشاشة الرئيسية — مصدر واحد للنسختين
/// (التوزيع الثابت والقائمة القابلة للسكرول).
const List<_PrayerSlot> _kPrayerSlots = <_PrayerSlot>[
  _PrayerSlot('الفجر', 'ص'),
  _PrayerSlot('الشروق', 'ص'),
  _PrayerSlot('الظهر', 'م'),
  _PrayerSlot('العصر', 'م'),
  _PrayerSlot('المغرب', 'م'),
  _PrayerSlot('العشاء', 'م'),
];

class PrayerTimesScreen extends StatefulWidget {
  final bool is24H;
  final PrayerTimes? pt;
  final Map<String, DateTime>? dailyPrayerTimes;
  final Map<String, DateTime>? apiPrayerTimes;
  final List<int> offsets;
  final String city;
  final int hijriOffset;
  final Coordinates coordinates;
  final String method;
  final String madhab;
  final VoidCallback onAutoDetect;

  const PrayerTimesScreen({
    super.key,
    required this.is24H,
    required this.pt,
    this.dailyPrayerTimes,
    this.apiPrayerTimes,
    required this.offsets,
    required this.city,
    required this.hijriOffset,
    required this.coordinates,
    required this.method,
    required this.madhab,
    required this.onAutoDetect,
  });

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with TickerProviderStateMixin {
  Timer? _clockTimer;
  late DateTime _now;
  String? _lastDuaPlayedKey;

  /// إعدادات النص المتحرك (الخط والحجم والسرعة والتفعيل) — تُقرأ من
  /// لوحة التحكم 1918 ← تبويب «الرسائل»، وتُحدَّث دورياً بلا إعادة تشغيل.
  HomeMarqueeSettings _marquee = const HomeMarqueeSettings();
  int _marqueeTick = 0;
  final AudioPlayer _notifyPlayer = AudioPlayer();
  
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _loadMarqueeSettings();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
        _checkAndPlayDuaSound();
        // كل 5 ثوانٍ: التحقق من تغيير إعدادات النص المتحرك من لوحة التحكم
        _marqueeTick++;
        if (_marqueeTick % 5 == 0) _loadMarqueeSettings();
      }
    });

    _entranceController.forward();
  }

  /// قراءة إعدادات النص المتحرك من التخزين المحلي (يكتبها لوحة التحكم فوراً).
  Future<void> _loadMarqueeSettings() async {
    final HomeMarqueeSettings next =
        await RemoteMessagingService.readHomeMarqueeSettings();
    if (!mounted) return;
    if (!_sameMarquee(next)) setState(() => _marquee = next);
  }

  /// مقارنة سريعة تمنع إعادة الرسم بلا تغيير فعلي.
  bool _sameMarquee(HomeMarqueeSettings other) {
    return _marquee.enabled == other.enabled &&
        _marquee.text == other.text &&
        _marquee.color == other.color &&
        _marquee.fontFamily == other.fontFamily &&
        _marquee.fontSize == other.fontSize &&
        _marquee.intervalMs == other.intervalMs &&
        _marquee.bold == other.bold &&
        _marquee.afterMinutes == other.afterMinutes;
  }

  Map<String, DateTime> _resolveActivePrayers() {
    final activePrayers = <String, DateTime>{};
    if (widget.apiPrayerTimes != null && widget.apiPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(widget.apiPrayerTimes!);
    } else if (widget.dailyPrayerTimes != null && widget.dailyPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(widget.dailyPrayerTimes!);
    } else if (widget.pt != null) {
      activePrayers['الفجر'] = widget.pt!.fajr.add(Duration(minutes: widget.offsets[0]));
      activePrayers['الشروق'] = widget.pt!.sunrise.add(Duration(minutes: widget.offsets.length > 5 ? widget.offsets[5] : 0));
      activePrayers['الظهر'] = widget.pt!.dhuhr.add(Duration(minutes: widget.offsets[1]));
      activePrayers['العصر'] = widget.pt!.asr.add(Duration(minutes: widget.offsets[2]));
      activePrayers['المغرب'] = widget.pt!.maghrib.add(Duration(minutes: widget.offsets[3]));
      activePrayers['العشاء'] = widget.pt!.isha.add(Duration(minutes: widget.offsets[4]));
    }
    return activePrayers;
  }

  void _checkAndPlayDuaSound() async {
    final activePrayers = _resolveActivePrayers();
    if (activePrayers.isEmpty) return;

    final prayers = [
      {'name': 'الفجر', 'time': activePrayers['الفجر']!},
      {'name': 'الظهر', 'time': activePrayers['الظهر']!},
      {'name': 'العصر', 'time': activePrayers['العصر']!},
      {'name': 'المغرب', 'time': activePrayers['المغرب']!},
      {'name': 'العشاء', 'time': activePrayers['العشاء']!},
    ];

    Map<String, dynamic>? prevPrayer;
    for (var i = prayers.length - 1; i >= 0; i--) {
      if ((prayers[i]['time'] as DateTime).isBefore(_now)) {
        prevPrayer = prayers[i];
        break;
      }
    }
    if (prevPrayer == null) return;

    if (prevPrayer['name'] != 'الفجر' && prevPrayer['name'] != 'الشروق') {
      final diff = _now.difference(prevPrayer['time'] as DateTime).inMinutes;
      if (diff >= 15 && diff <= 45) {
        final key = '${prevPrayer['name']}_${prevPrayer['time'].day}';
        if (_lastDuaPlayedKey != key) {
          _lastDuaPlayedKey = key;
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  // تحديد اسم الصلاة النشطة (آخر صلاة مضى وقتها) — لتلوين اسم ووقت الصلاة النشطة فقط
  String _getCurrentPrayerName() {
    final activePrayers = _resolveActivePrayers();
    if (activePrayers.isEmpty) return 'العشاء';

    final sortedPrayers = [
      {'name': 'الفجر', 'time': activePrayers['الفجر']!},
      {'name': 'الظهر', 'time': activePrayers['الظهر']!},
      {'name': 'العصر', 'time': activePrayers['العصر']!},
      {'name': 'المغرب', 'time': activePrayers['المغرب']!},
      {'name': 'العشاء', 'time': activePrayers['العشاء']!},
    ];

    for (int i = sortedPrayers.length - 1; i >= 0; i--) {
      if (_now.isAfter(sortedPrayers[i]['time'] as DateTime)) {
        return sortedPrayers[i]['name'] as String;
      }
    }
    return 'العشاء'; // إذا كان قبل الفجر
  }



  @override
  void dispose() {
    _clockTimer?.cancel();
    _notifyPlayer.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pt == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFDFBA6B)));
    
    final h = HijriCalendar.fromDate(_now.add(Duration(days: widget.hijriOffset)));
    final months = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // العدّاد التنازلي يبقى باللون الافتراضي، أما اسم المدينة (بنغازي) فقد
    // صار يتبع ألوان أوقات الصلاة (انظر [_buildHeader]).

    // ملاحظة: زيادة الخط 1.5 بكسل تُطبّق من **جذر الشاشة الرئيسية** في
    // home_page.dart عبر [TextScaleBoost] — لا من هنا — فلا يُكرّر التغليف.
    //
    // ── الأوفرفلو: تخطيط متكيّف بدل التخطيط الثابت ──────────────────────────
    //   • المساحة كافية (المعتاد على الهواتف) → نفس التصميم الثابت كما هو.
    //   • المساحة ضيقة (شاشة قصيرة، أو خط نظام كبير مع زيادة الـ1.5، أو
    //     أسماء مدن/تواريخ أطول) → قائمة الكاردات تصير قابلة للسكرول بارتفاع
    //     أدنى ثابت لكل كارد، فلا يتلاصق المحتوى ولا يُقصّ ولا يخرج عن الشاشة.
    //     والترويسة والعدّاد يبقيان مثبّتين أعلى الشاشة.
    //   • نافذة أقصر من أن تحمل الترويسة والعدّاد معاً (لا تحدث على هاتف) →
    //     الشاشة كلها تُسحب.
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent, // نعتمد على تدرج الخلفية في HomePage
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget header = _buildHeader(h, months);
          final Widget countdown = CountdownWidget(
            pt: widget.pt,
            dailyPrayerTimes: widget.dailyPrayerTimes,
            apiPrayerTimes: widget.apiPrayerTimes,
            offsets: widget.offsets,
            coordinates: widget.coordinates,
            method: widget.method,
            madhab: widget.madhab,
            now: _now,
            is24H: widget.is24H,
            marquee: _marquee,
          );
          final Widget tiles = _buildTilesArea(isDark);

          // حالة نادرة جداً: لا تكفي الشاشة للترويسة والعدّاد — كلها تُسحب،
          // والكاردات بارتفاع ثابت داخل نفس المساحة الأدنى
          if (constraints.maxHeight < _kMinChromeHeight) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  header,
                  countdown,
                  SizedBox(height: _kTilesMinHeight, child: tiles),
                ],
              ),
            );
          }

          return Column(
            children: [
              header,
              countdown,
              // جسم الصفحة: يأخذ ما تبقّى من المساحة ويتكيّف داخلياً
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                      child: tiles,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ترويسة الشاشة الرئيسية: التاريخ الهجري، ثم الميلادي، ثم اسم المدينة
  /// في سطر مستقل تحتهما — والخطوط الثلاثة في منتصف عرض الشاشة.
  ///
  /// مفصلة عن بناء الشاشة لأن الشاشة قد تبنيها داخل سكرول كامل في الحالة
  /// النادرة القصيرة ([_kMinChromeHeight])، فلا يُكرَّر الكود.
  Widget _buildHeader(HijriCalendar h, List<String> months) {
    // اسم المدينة (بنغازي) وشعار الموقع يتبعان **لون الصلاة النشطة** كما في
    // كاردات الصلوات تماماً — فيتنفّس اسم المدينة بلون الوقت نفسه.
    final Color cityColor =
        GlassPalette.prayerTimesColor(_getCurrentPrayerName());
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0D1B3E).withOpacity(0.55),
                const Color(0xFF0A0F2C).withOpacity(0.45),
                const Color(0xFF1A0A2E).withOpacity(0.35),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFDFBA6B).withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
          child: Align(
            // الترويسة كلها في المنتصف: عمود يأخذ كامل العرض ويوسّط
            // سطوره الثلاثة
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // التاريخ الهجري: [HomeDateFontPrefs.hijriFontSize] = الأساس
                // 15 + تعديل المستخدم من الإعدادات، وفوقهما 1.5 من تكبير
                // الشاشة الرئيسية. وFittedBox(scaleDown) هو الضمان: لو ضاق
                // العرض على شاشة صغيرة ينزل الحجم قدر الحاجة بدل الأوفرفلو
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    '${h.hDay} ${months[h.hMonth - 1]} ${h.hYear} هـ',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: HomeDateFontPrefs.hijriFontSize,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // التاريخ الميلادي وحده في سطر — بلا اسم مدينة بجانبه
                Text(
                  _toWestern(DateFormat('dd', 'ar').format(_now)) +
                      ' ' +
                      DateFormat('MMMM', 'ar').format(_now) +
                      ' ' +
                      _toWestern(DateFormat('yyyy', 'ar').format(_now)) +
                      ' | ' +
                      DateFormat('EEEE', 'ar').format(_now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.85),
                    // الأساس 10 + تعديل المستخدم (نفس إعداد التاريخ الهجري)
                    fontSize: HomeDateFontPrefs.gregorianFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                // اسم المدينة (بنغازي) في سطر مستقل تحت التاريخ الميلادي
                // وفي منتصف العرض تماماً — واللمس عليه يعيد تحديد الموقع
                Center(
                  child: GestureDetector(
                    onTap: widget.onAutoDetect,
                    child: ConstrainedBox(
                      // مهيأ بمساحة كافية لأسماء من 8 أحرف أو أكثر (مثل «حقل البوري»)
                      constraints: const BoxConstraints(
                        minWidth: 50,
                        maxWidth: 160,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          widget.city,
                          maxLines: 1,
                          style: GoogleFonts.cairo(
                            color: cityColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  /// كاردات الصلوات الست — مصدر واحد للأسماء والأوقات، بتخطيط متكيّف.
  ///
  /// يُقاس الارتفاع المتاح في [LayoutBuilder]: فإن كفى الحد الأدنى لكل كارد
  /// ([kMinPrayerTileHeight]) توزّعت الكاردات كما في التصميم الثابت، وإلا
  /// تحوّلت إلى قائمة قابلة للسكرول بنفس الارتفاع الأدنى.
  Widget _buildTilesArea(bool isDark) {
    // درجة «تكبير خط كاردات أوقات الصلاة» من الإعدادات (+2 / 0 / −2): البناء
    // يعاد فوراً عند تغييرها (بلا إعادة تشغيل وبلا انتظار rebuild من الأم).
    return ValueListenableBuilder<int>(
      valueListenable: PrayerCardFontPrefs.adjustment,
      builder: (_, _, _) => _buildTilesLayout(isDark),
    );
  }

  Widget _buildTilesLayout(bool isDark) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Map<String, DateTime> activePrayers = _resolveActivePrayers();
        final String currentPrayerName = _getCurrentPrayerName();

        Widget tile(_PrayerSlot slot) => _buildPrayerTile(
          slot.name,
          activePrayers[slot.name]!,
          slot.period,
          // «الشروق» ليس صلاة لها أذان — لا يتلوّن كالصلاة النشطة
          slot.name != 'الشروق' && currentPrayerName == slot.name,
          isDark,
        );

        // حصة الكارد الواحد من المساحة بعد الفواصل
        final double perTile =
            (constraints.maxHeight -
                    _kTileGap * (_kPrayerSlots.length - 1) -
                    _kTailGap) /
                _kPrayerSlots.length;

        // ── المساحة كافية: نفس التصميم الثابت (بلا سكرول) ──
        if (perTile >= kMinPrayerTileHeight) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < _kPrayerSlots.length; i++) ...[
                if (i > 0) const SizedBox(height: _kTileGap),
                Expanded(child: tile(_kPrayerSlots[i])),
              ],
              const SizedBox(height: _kTailGap),
            ],
          );
        }

        // ── المساحة ضيقة: سكرول داخل مساحة الكاردات فقط ──
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              for (int i = 0; i < _kPrayerSlots.length; i++) ...[
                if (i > 0) const SizedBox(height: _kTileGap),
                SizedBox(
                  height: kMinPrayerTileHeight,
                  child: tile(_kPrayerSlots[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrayerTile(String nameAr, DateTime time, String period, bool isActive, bool isDark) {
    final timeFormatted = _toWestern(DateFormat(widget.is24H ? 'HH:mm' : 'hh:mm').format(time));
    final isAM = time.hour < 12;
    final periodAr = isAM ? 'ص' : 'م';

    IconData getIcon(String name) {
      switch (name) {
        case 'الفجر':
          return Icons.nights_stay_rounded;
        case 'الشروق':
          return Icons.wb_twilight_rounded;
        case 'الظهر':
          return Icons.wb_sunny_rounded;
        case 'العصر':
          return Icons.wb_cloudy_rounded;
        case 'المغرب':
          return Icons.brightness_medium_rounded;
        case 'العشاء':
          return Icons.dark_mode_rounded;
        default:
          return Icons.access_time_rounded;
      }
    }

    return AuroraGlassCard(
      isActive: false,
      glowColor: null,
      borderRadius: BorderRadius.circular(16),
      blur: 22,
      // زجاجية شفافة افتراضية بلون الخلفية لا تتبع ألوان أوقات الصلاة
      gradientColors: [
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.04),
        Colors.white.withValues(alpha: 0.015),
      ],
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.15),
        width: 0.9,
      ),
      child: SizedBox(
        height: double.infinity,
        child: Stack(
            fit: StackFit.expand,
            children: [
            // محتوى الكارت
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // اسم الصلاة والأيقونة المميزة مع تصغير الخط (-2)
                  // Flexible(loose) + MainAxisSize.min: يمنح كل شقّ عرضاً محدوداً
                  // فيعمل القص بالثلاث نقاط داخل Text بدل تجاوز حدود الكارد بعد
                  // تكبير الخط 1.5 بكسل، ويبقى التوزيع spaceBetween كما هو.
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getIcon(nameAr),
                            color: prayerIconColor(nameAr),
                            // 13 عادةً و15 بالتکبير (+2)
                            size: PrayerCardFontPrefs.iconSize,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: isActive ? prayerIconColor(nameAr) : Colors.white,
                              // 11 بدل 12 (تُضاف عليها 1.5 من تكبير الشاشة
                              // الرئيسية، فيصير المقاس الفعلي 12.5) — و13 مع
                              // درجة التكبير (+2) داخل الكاردات
                              fontSize: PrayerCardFontPrefs.nameFontSize,
                              fontWeight: FontWeight.w800,
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: prayerIconColor(nameAr).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 6,
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // وقت الصلاة والفترة الزمنية مع تصغير الخط (-2)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            timeFormatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: isActive ? prayerIconColor(nameAr) : Colors.white,
                              // 13 − 0.5 = 12.5 (تُضاف عليها 1.5 من تكبير الشاشة
                              // الرئيسية، فيصير المقاس الفعلي 14) — و14.5 مع
                              // درجة التكبير (+2) داخل الكاردات
                              fontSize: PrayerCardFontPrefs.timeFontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color: prayerIconColor(nameAr).withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      )
                                    ]
                                  : [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 6,
                                      ),
                                    ],
                            ),
                          ),
                        ),
                        if (!widget.is24H) ...[
                          const SizedBox(width: 5),
                          Text(
                            periodAr,
                            maxLines: 1,
                            style: GoogleFonts.cairo(
                              color: isActive ? prayerIconColor(nameAr).withValues(alpha: 0.8) : Colors.white54,
                              // 10 عادةً و12 مع درجة التكبير (+2)
                              fontSize: PrayerCardFontPrefs.periodFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ووترمارك القوس الإسلامي في الكارت النشط بلون أبيض هادئ
            if (isActive)
              Positioned(
                right: 15,
                top: 0,
                bottom: 0,
                width: 35,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.08,
                    child: CustomPaint(
                      painter: IslamicArchPainter(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CountdownWidget extends StatefulWidget {
  final PrayerTimes? pt;
  final Map<String, DateTime>? dailyPrayerTimes;
  final Map<String, DateTime>? apiPrayerTimes;
  final List<int> offsets;
  final Coordinates coordinates;
  final String method;
  final String madhab;
  final DateTime now;
  final bool is24H;

  /// إعدادات النص المتحرك (من لوحة التحكم 1918 ← تبويب الرسائل)
  final HomeMarqueeSettings marquee;

  const CountdownWidget({
    super.key,
    this.pt,
    this.dailyPrayerTimes,
    this.apiPrayerTimes,
    required this.offsets,
    required this.coordinates,
    required this.method,
    required this.madhab,
    required this.now,
    this.is24H = false,
    this.marquee = const HomeMarqueeSettings(),
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  Timer? _timer;
  bool _showElapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  CalculationParameters _getParams() {
    return MainNavigationScreen.getCalculationParameters(widget.method, widget.madhab);
  }

  IconData _getPrayerIcon(String name) {
    switch (name) {
      case 'الفجر':
        return Icons.nights_stay_rounded;
      case 'الظهر':
        return Icons.wb_sunny_rounded;
      case 'العصر':
        return Icons.wb_cloudy_rounded;
      case 'المغرب':
        return Icons.brightness_medium_rounded;
      case 'العشاء':
        return Icons.dark_mode_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activePrayers = <String, DateTime>{};
    if (widget.apiPrayerTimes != null && widget.apiPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(widget.apiPrayerTimes!);
    } else if (widget.dailyPrayerTimes != null && widget.dailyPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(widget.dailyPrayerTimes!);
    } else if (widget.pt != null) {
      activePrayers['الفجر'] = widget.pt!.fajr.add(Duration(minutes: widget.offsets[0]));
      activePrayers['الظهر'] = widget.pt!.dhuhr.add(Duration(minutes: widget.offsets[1]));
      activePrayers['العصر'] = widget.pt!.asr.add(Duration(minutes: widget.offsets[2]));
      activePrayers['المغرب'] = widget.pt!.maghrib.add(Duration(minutes: widget.offsets[3]));
      activePrayers['العشاء'] = widget.pt!.isha.add(Duration(minutes: widget.offsets[4]));
    }

    if (activePrayers.isEmpty) return const SizedBox.shrink();

    final prayers = [
      {'name': 'الفجر', 'time': activePrayers['الفجر']!},
      {'name': 'الظهر', 'time': activePrayers['الظهر']!},
      {'name': 'العصر', 'time': activePrayers['العصر']!},
      {'name': 'المغرب', 'time': activePrayers['المغرب']!},
      {'name': 'العشاء', 'time': activePrayers['العشاء']!},
    ];

    // 1. الصلاة القادمة
    Map<String, dynamic>? nextPrayer;
    for (var p in prayers) {
      if ((p['time'] as DateTime).isAfter(now)) {
        nextPrayer = p;
        break;
      }
    }
    if (nextPrayer == null) {
      final params = _getParams();
      final tomorrowPt = PrayerTimes(widget.coordinates, DateComponents.from(now.add(const Duration(days: 1))), params);
      nextPrayer = {'name': 'الفجر', 'time': tomorrowPt.fajr.add(Duration(minutes: widget.offsets[0]))};
    }

    // 2. الصلاة السابقة (الحالية التي مضى وقتها)
    Map<String, dynamic>? prevPrayer;
    for (var i = prayers.length - 1; i >= 0; i--) {
      if ((prayers[i]['time'] as DateTime).isBefore(now)) {
        prevPrayer = prayers[i];
        break;
      }
    }
    if (prevPrayer == null) {
      final params = _getParams();
      final yesterdayPt = PrayerTimes(widget.coordinates, DateComponents.from(now.subtract(const Duration(days: 1))), params);
      prevPrayer = {'name': 'العشاء', 'time': yesterdayPt.isha.add(Duration(minutes: widget.offsets[4]))};
    }

    final nextPrayerTime = nextPrayer['time'] as DateTime;
    final nextPrayerName = nextPrayer['name'] as String;

    final prevPrayerTime = prevPrayer['time'] as DateTime;
    final prevPrayerName = prevPrayer['name'] as String;

    // عداد الوقت المتبقي
    final diffRem = nextPrayerTime.difference(now);
    final totalSecsRem = diffRem.inSeconds.abs();
    final hRem = (totalSecsRem ~/ 3600).toString().padLeft(2, '0');
    final mRem = ((totalSecsRem % 3600) ~/ 60).toString().padLeft(2, '0');
    final sRem = (totalSecsRem % 60).toString().padLeft(2, '0');

    // عداد الوقت المنقضي
    final diffElap = now.difference(prevPrayerTime);
    final totalSecsElap = diffElap.inSeconds.abs();
    final hElap = (totalSecsElap ~/ 3600).toString().padLeft(2, '0');
    final mElap = ((totalSecsElap % 3600) ~/ 60).toString().padLeft(2, '0');
    final sElap = (totalSecsElap % 60).toString().padLeft(2, '0');

    final activeIcon = _getPrayerIcon(_showElapsed ? prevPrayerName : nextPrayerName);


    return GestureDetector(
      onTap: () => setState(() => _showElapsed = !_showElapsed),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── كارد يضم العنوان + العداد التنازلي ──
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // العنوان: أيقونة ملونة + نص أبيض دائماً بخط -4 (14 بدل 18)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            activeIcon,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _showElapsed
                                  ? 'مضى على أذان $prevPrayerName'
                                  : 'بقي على أذان $nextPrayerName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 13, // تصغير -4 من 18
                                fontWeight: FontWeight.w700,
                                color: Colors.white, // أبيض دائماً بغض النظر عن الصلاة
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // الأرقام الكبيرة للعداد التنازلي
                      Directionality(
                        textDirection: ui.TextDirection.ltr,
                        child: Text(
                          _showElapsed
                              ? '$hElap : $mElap : $sElap'
                              : '$hRem : $mRem : $sRem',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white, // اللون الافتراضي أبيض لا يتبع ألوان أوقات الصلاة
                            letterSpacing: 1.6,
                            fontFeatures: const [ui.FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسام القوس الإسلامي المنسق
class IslamicArchPainter extends CustomPainter {
  final Color color;
  IslamicArchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.45);
    
    // رسم القوس الإسلامي المدبب (المحراب)
    path.cubicTo(
      0, size.height * 0.2,
      size.width * 0.2, 0,
      size.width * 0.5, 0,
    );
    path.cubicTo(
      size.width * 0.8, 0,
      size.width, size.height * 0.2,
      size.width, size.height * 0.45,
    );
    path.lineTo(size.width, size.height);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedDuaText extends StatefulWidget {
  /// إعدادات النص المتحرك من لوحة التحكم (1918 ← تبويب الرسائل):
  /// الخط (أميري وغيره) + الحجم + السرعة + اللون + التفعيل + وقت البداية.
  final HomeMarqueeSettings settings;

  /// لون الصلاة الحالية — يُستعمل عندما يكون الوضع «يتبع ألوان أوقات الصلاة».
  /// يأتي من [GlassPalette.prayerTextColor] (نفس لون الصلاة لكن مقروء).
  final Color? prayerColor;

  const AnimatedDuaText({
    super.key,
    this.settings = const HomeMarqueeSettings(),
    this.prayerColor,
  });

  @override
  State<AnimatedDuaText> createState() => _AnimatedDuaTextState();
}

class _AnimatedDuaTextState extends State<AnimatedDuaText> {
  static const List<String> _defaultPhrases = [
    '- اللهم إنا :',
    '• نسألك إيماناً دائماً',
    '• ونسألك قلباً خاشعاً',
    '• ونسالك علما نافعاً',
    '• ونسألك صبرًا جميلاً',
    '• ونسألك فرجاً قريباً',
    '• ونسألك أجراً عظيماً',
    '• ونسألك يقينا صاداقاً',
    '• ونسألك دينا قيماً',
    '• ونسألك العافية مـטּ ڪل بَلِيَّة',
    '• ونسألك الغنى عــטּ الناس',
    '• ونسألك تمام العافية',
    '• ونسألك الشڪر على العافية',
    '- اللهُم :',
    '• جنبنا أذى الدنيا',
    '• وحيرة النفس',
    '• وموت الضمير',
    '• وسوء الخاتمة',
    '• بفضلك ورحمتك',
    'يـــــارب العالمــــــيـטּ.',
    'أوقات الصلاة',
    'تصميم و برمجه',
    'رزق الله العريبي',
  ];

  int _currentIndex = 0;
  Timer? _timer;

  /// العبارات المعروضة: نص لوحة التحكم إن وُجد، وإلا الأدعية المضمّنة الأصلية.
  List<String> get _phrases {
    final List<String> custom = widget.settings.phrases;
    if (custom.isNotEmpty) return custom;
    return _defaultPhrases;
  }

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedDuaText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final HomeMarqueeSettings old = oldWidget.settings;
    final HomeMarqueeSettings now = widget.settings;
    // تغيير السرعة أو النص أو التفعيل = إعادة المؤقت من أول عبارة فوراً
    if (old.intervalMs != now.intervalMs ||
        old.text != now.text ||
        old.enabled != now.enabled) {
      _currentIndex = 0;
      _startAnimation();
    } else if (_currentIndex >= _phrases.length) {
      _currentIndex = 0;
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.settings.interval, (_) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _phrases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.enabled) return const SizedBox.shrink();
    final List<String> phrases = _phrases;
    if (phrases.isEmpty) return const SizedBox.shrink();

    final displayText = phrases[_currentIndex % phrases.length];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        displayText,
        key: ValueKey<String>('${_currentIndex}_$displayText'),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.settings.textStyle(prayerColor: widget.prayerColor),
      ),
    );
  }
}
