import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../../core/theme/glass_theme.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/bookmark.dart';
import '../bloc/quran_bloc.dart';
import '../bloc/quran_event.dart';
import '../bloc/quran_state.dart';
import '../bloc/quran_audio_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../core/config/header_font_prefs.dart';
import '../../data/datasources/quran_settings_data_source.dart';
import '../../data/datasources/quran_local_data_source.dart';
import '../widgets/islamic_surah_name.dart';
import '../../../voice/voice_assistant_sheet.dart';
import '../../../voice/voice_service.dart';
import '../../../ai/ai_tafsir_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'quran_offline_manager_screen.dart';
import '../../data/constants/quran_divisions.dart';

List<Ayah> sortAyahsBySurahNumber(List<Ayah> ayahs) {
  final sorted = List<Ayah>.from(ayahs);
  sorted.sort((a, b) {
    final aNum = a.ayahNumber > 0 ? a.ayahNumber : 1;
    final bNum = b.ayahNumber > 0 ? b.ayahNumber : 1;
    return aNum.compareTo(bNum);
  });
  return sorted;
}

int resolveAyahNumberInSurah(int fallbackIndex, Ayah ayah) {
  final int candidate = ayah.ayahNumber;
  if (candidate > 0) {
    return candidate;
  }
  return fallbackIndex > 0 ? fallbackIndex : 1;
}

class QuranViewPage extends StatefulWidget {
  final Surah? surah;
  final int? juzNumber;
  final int? initialAyah;
  final int? initialSurahId;
  const QuranViewPage({super.key, this.surah, this.juzNumber, this.initialAyah, this.initialSurahId});

  @override
  State<QuranViewPage> createState() => _QuranViewPageState();
}

class _QuranViewPageState extends State<QuranViewPage> {
  static const Map<String, String> _reciters = {
    "ar.buajan": "عبدالله البعيجان",
    "ly.dokali": "الدوكالي العالم",
    "ly.daoub": "طارق دعوب",
    "ar.alafasy": "مشاري العفاسي",
    "ar.abdulsamad": "عبدالباسط عبدالصمد",
    "ar.minshawi": "محمد المنشاوي",
    "ar.mahermuaiqly": "ماهر المعيقلي",
    "ar.sudais": "السديس",
  };

  static const Map<String, String> _quranFonts = {
    "QuranUthmanicHafs": "مصحف المدينة (الرسم العثماني لحفص)",
    "QuranMe": "مصحف المدينة المنورة",
    "QuranAlQalam": "خط القلم القرآني المجيد",
    "QuranAlQalam2": "خط القلم القرآني 2",
    "QuranAlmushaf1": "خط المصحف الشريف",
    "QuranAlKareem": "خط القرآن الكريم",
    "QuranAmiri": "خط القرآن الأميري",
    "QuranAmiriRegular": "خط أميري قياسي",
    "QuranAmiriBold": "خط أميري عريض",
    "QuranAmiriSlanted": "خط أميري مائل",
    "QuranTaha": "خط طه القرآني",
    "QuranNoon": "خط نون الإسلامي",
  };

  late ScrollController _scrollController;
  double _fontSize = 22.0;
  String _selectedReciter = "ar.sudais";
  String _readingMode = "black"; // الافتراضي عند التثبيت الأول: الوضع الليلي
  String _fontWeightMode = "semi_bold"; // "normal", "semi_bold", "bold"
  String _fontFamily = "QuranAmiriRegular"; // الافتراضي: خط أميري قياسي
  double _brightness = 1.0;
  final String _selectedTafsir = "ar.jalalayn";

  bool _isAutoScrolling = false;
  double _scrollSpeed = 0.5;
  Timer? _scrollTimer;

  // ── السورة الحالية والآيات الخاصة بها (سورة مستقلة تماماً) ─────────
  late int _currentSurahId;
  List<Ayah> _ayahs = [];
  // عناصر العرض: أرقام فهارس الآيات داخل _ayahs، وفواصل الأجزاء عند تغيّر رقم الجزء
  List<Object> _displayItems = [];
  bool _isLoading = true;
  String _currentSurahTitle = "";

  // ── تتبع الآية الأولى المرئية فعلاً على الشاشة ──
  final Map<int, GlobalKey> _ayahKeys = {};
  int _currentVisibleAyahIndex = 0;

  final GlobalKey _scrollViewKey = GlobalKey();
  int? _highlightedAyahNumber;

  // ── حالة العلامة المرجعية للآية الحالية (أيقونة التبديل) ──
  bool _isCurrentAyahBookmarked = false;
  int _lastBookmarkCheckedAyah = -1;
  Timer? _bookmarkRefreshTimer;

  /// مؤقّت إزالة تظليل الآية التي فُتحت عليها الشاشة.
  Timer? _highlightTimer;

  TextStyle _getQuranTextStyle({
    required Color color,
    required double fontSize,
    FontWeight? fontWeight,
    double height = 2.0,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight ?? _currentFontWeight,
      height: height,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChanged);
    final settings = sl<QuranSettingsDataSource>();
    _fontSize = settings.getFontSize();
    _selectedReciter = settings.getReciter();
    _readingMode = settings.getReadingMode();
    _fontWeightMode = settings.getFontWeight();
    _fontFamily = settings.getFontFamily();
    _brightness = settings.getBrightness();

    // تحديد السورة والآية الافتراضية عند الفتح
    int targetSurahId = widget.surah?.id ?? (widget.initialSurahId ?? 1);
    int? targetAyah = widget.initialAyah;

    if (widget.juzNumber != null && widget.surah == null && widget.initialSurahId == null) {
      try {
        final juzInfo = QuranDivisions.juzList.firstWhere(
          (j) => j['id'] == widget.juzNumber,
        );
        targetSurahId = juzInfo['start_surah'] as int;
        targetAyah = juzInfo['start_ayah'] as int;
      } catch (_) {}
    }

    _currentSurahId = targetSurahId;
    _currentSurahTitle = widget.surah?.nameArabic ??
        (_surahMetadata[_currentSurahId]?['name'] as String? ?? "القرآن الكريم");

    // تحميل السورة المحددة ككائن مستقل
    _loadSurah(_currentSurahId, initialAyah: targetAyah);
  }

  /// سماكة أي نمط خط — تخدم الشاشة **ومعاينة نافذة الإعدادات** معاً، حتى
  /// تكون المعاينة مطابقة لما سيُطبَّق تماماً.
  static FontWeight _weightOf(String mode) {
    switch (mode) {
      case "normal":
        return FontWeight.w400;
      case "bold":
        return FontWeight.bold;
      case "semi_bold":
      default:
        return FontWeight.w600;
    }
  }

  /// خلفية أي نمط قراءة — للشاشة وللمعاينة قبل التطبيق.
  static Color _bgColorOf(String mode) {
    switch (mode) {
      case "black":
        return const Color(0xFF0C1017);
      case "sepia":
        return const Color(0xFFF7F1E3);
      case "contrast":
        return const Color(0xFF030D1A);
      case "white":
      default:
        return Colors.white; // أبيض ناصع
    }
  }

  /// لون نص أي نمط قراءة — للشاشة وللمعاينة قبل التطبيق.
  static Color _textColorOf(String mode) {
    switch (mode) {
      case "black":
        return const Color(0xFFFDF7E7);
      case "sepia":
        return const Color(0xFF2C1D11);
      case "contrast":
        return const Color(0xFFFFFAED);
      case "white":
      default:
        return Colors.black; // أسود داكن
    }
  }

  FontWeight get _currentFontWeight => _weightOf(_fontWeightMode);

  Color get _resolvedBgColor => _bgColorOf(_readingMode);

  Color get _resolvedTextColor => _textColorOf(_readingMode);

  Color get _resolvedGoldColor {
    switch (_readingMode) {
      case "black":
        return const Color(0xFFDFBA6B);
      case "sepia":
        return const Color(0xFF9E6B20);
      case "contrast":
        return const Color(0xFFFFD700);
      case "white":
      default:
        return Colors.black; // أسود داكن في الوضع النهاري
    }
  }

  // ملاحظة: أُزيلت هنا دالة "تقدير" إزاحة الآية (_calculateEstimatedOffset)
  // لأنها كانت تُنتج موضعاً خاطئاً في السور الطوال والأجزاء المتأخرة، وصار
  // التوجيه يعتمد على قياس مواضع الآيات المرسومة فعلاً (انظر _scrollToInitialAyah).

  Future<void> _scrollToInitialAyah(int? initialAyah) async {
    if (initialAyah == null || initialAyah < 1) return;

    int targetIndex = _ayahs.indexWhere((a) => a.ayahNumber == initialAyah);
    if (targetIndex < 0) {
      targetIndex = (initialAyah - 1).clamp(0, _ayahs.length - 1);
    }
    _currentVisibleAyahIndex = targetIndex;

    if (mounted) {
      setState(() => _highlightedAyahNumber = initialAyah);
    }
    // مؤقّت معروف ومُلغى عند الخروج من الشاشة (لا مؤقّت معلّق)
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _highlightedAyahNumber = null);
    });

    if (targetIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      });
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _ayahs.isEmpty) return;

    // ── التوجيه الدقيق إلى أي آية في أي سورة ─────────────────────────────
    // السورة تُعرض في قائمة بطيئة البناء (SliverList) وحسبتها الإجمالية
    // **تقديرية** قبل أن يُبنى محتواها، وأي قفزة كبيرة تُقيَّد بهذا التقدير
    // فتضعك في موضع اعتباطي (كانت العلامة المرجعية في آخر السور الطوال
    // تُفتح قرب الآية ١٠٠ أو في غير موضعها).
    //
    // لذلك نتقدّم هنا بخطوات **محسوبة من مفاتيح مبنية فعلاً** (المصدر الوحيد
    // الموثوق)، حتى تُبنى آية الهدف، ثم ضبط دقيق يضعها في أعلى منطقة
    // القراءة. لا رقم سحري ولا اعتماد على تقدير ارتفاع.
    const int maxSteps = 60;
    int stalled = 0;
    int lastStepEdge = -2;

    for (int step = 0; step < maxSteps && mounted; step++) {
      if (!_scrollController.hasClients) return;

      final ({int first, int last})? range = _builtKeyRange();

      // لا شيء مبني بعد (نادر): ننزلق شاشة واحدة ثم نعيد القياس
      if (range == null) {
        final double max = _scrollController.position.maxScrollExtent;
        final double next =
            math.min(_scrollController.offset + _viewportHeight * 0.9, max);
        if (next <= _scrollController.offset + 1) return;
        _scrollController.jumpTo(next);
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }

      // الهدف أسفل ما هو مبني → ننزل إلى حدّ البناء الأسفل
      // الهدف أعلى ما هو مبني (عند إعادة فتح سورة مقروءة) → نصعد إلى حدّه الأعلى
      final int edge = range.last < targetIndex ? range.last :
          (range.first > targetIndex ? range.first : -1);

      if (edge >= 0) {
        if (edge == lastStepEdge) {
          if (++stalled > 2) return; // توقّف البناء وحدّه — لا تُطارد بلا نهاية
        } else {
          stalled = 0;
          lastStepEdge = edge;
        }
        _revealKey(edge);
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }

      // الهدف صار مبنيّاً → ضبط دقيق: نهاية الآية السابقة عند أعلى القراءة،
      // فيبدأ نصّ آية الهدف من أول الصفحة تماماً (وإن لم تُبنَ السابقة نضع
      // مفتاح الآية نفسها عند الحدّ).
      if (targetIndex > 0 && _ayahKeys[targetIndex - 1]?.currentContext != null) {
        final ro = _ayahKeys[targetIndex - 1]!
            .currentContext!
            .findRenderObject();
        if (ro is RenderBox && ro.attached) {
          final double bottom =
              ro.localToGlobal(Offset(0, ro.size.height)).dy;
          final double max = _scrollController.position.maxScrollExtent;
          final double delta = bottom - _readingTopY + 4.0;
          if (delta.abs() > 0.5) {
            _scrollController
                .jumpTo((_scrollController.offset + delta).clamp(0.0, max));
          }
          return;
        }
      }
      _revealKey(targetIndex);
      return;
    }
  }

  /// ارتفاع منطقة القراءة الفعلي (لا ارتفاع النافذة) — يُقاس من نفس العرض.
  double get _viewportHeight {
    final ctx = _scrollViewKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.size.height > 50) {
      return ro.size.height;
    }
    return MediaQuery.of(context).size.height * 0.6;
  }

  /// نطاق مفاتيح الآيات المبنية (مرسومة) الآن: أصغر وأكبر فهرس لهما سياق.
  ///
  /// كل مفتاح موضوع على **نهاية** نصّ الآية، فموضع المفتاح قياس هندسي حقيقي
  /// لا تقدير — وهو ما يعتمد عليه التوجيه إلى آية في آخر السورة.
  ({int first, int last})? _builtKeyRange() {
    int first = -1;
    int last = -1;
    for (int i = 0; i < _ayahs.length; i++) {
      final ctx = _ayahKeys[i]?.currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      if (first < 0) first = i;
      last = i;
    }
    return first < 0 ? null : (first: first, last: last);
  }

  /// تمرير فوري يُحسب من هندسة المفتاح نفسه (لا تقدير)، فيصبح أعلى منطقة
  /// القراءة. تُستدعى فقط على مفتاح مبنيّ فعلاً.
  void _revealKey(int index) {
    final ctx = _ayahKeys[index]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: Duration.zero,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _bookmarkRefreshTimer?.cancel();
    _highlightTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// تحميل سورة مستقلة من قاعدة البيانات المحلية
  Future<void> _loadSurah(int surahId, {int? initialAyah}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentSurahId = surahId;
      _currentSurahTitle = _surahMetadata[surahId]?['name'] as String? ?? "سورة $surahId";
    });

    try {
      final localDs = sl<QuranLocalDataSource>();
      final loadedAyahs = await localDs.getAyahsBySurah(surahId);

      if (!mounted) return;
      final sortedAyahs = sortAyahsBySurahNumber(loadedAyahs);
      _ayahKeys.clear();
      _currentVisibleAyahIndex = 0;
      _lastBookmarkCheckedAyah = -1;
      setState(() {
        _ayahs = sortedAyahs;
        _displayItems = _buildDisplayItems(sortedAyahs);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (surahId == 1) {
        final fallbackFatiha = [
          const Ayah(id: 1, surahId: 1, ayahNumber: 1, text: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ", textUthmani: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ", page: 1, juz: 1),
          const Ayah(id: 2, surahId: 1, ayahNumber: 2, text: "الرَّحْمَٰنِ الرَّحِيمِ", textUthmani: "الرَّحْمَٰنِ الرَّحِيمِ", page: 1, juz: 1),
          const Ayah(id: 3, surahId: 1, ayahNumber: 3, text: "مَلِكِ يَوْمِ الدِّينِ", textUthmani: "مَلِكِ يَوْمِ الدِّينِ", page: 1, juz: 1),
          const Ayah(id: 4, surahId: 1, ayahNumber: 4, text: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ", textUthmani: "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ", page: 1, juz: 1),
          const Ayah(id: 5, surahId: 1, ayahNumber: 5, text: "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ", textUthmani: "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ", page: 1, juz: 1),
          const Ayah(id: 6, surahId: 1, ayahNumber: 6, text: "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ", textUthmani: "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ", page: 1, juz: 1),
          const Ayah(id: 7, surahId: 1, ayahNumber: 7, text: "غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ", textUthmani: "غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ", page: 1, juz: 1),
        ];
        _ayahKeys.clear();
        _lastBookmarkCheckedAyah = -1;
        final fallbackSorted = sortAyahsBySurahNumber(fallbackFatiha);
        setState(() {
          _ayahs = fallbackSorted;
          _displayItems = _buildDisplayItems(fallbackSorted);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }

    if (initialAyah != null && initialAyah >= 1) {
      _scrollToInitialAyah(initialAyah);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      });
    }

    // تحديث حالة أيقونة العلامة المرجعية بعد اكتمال البناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCurrentBookmarkState();
    });
  }

  /// عند التمرير: تحديث حالة أيقونة العلامة المرجعية للآية المرئية حالياً
  void _onScrollChanged() {
    _bookmarkRefreshTimer?.cancel();
    _bookmarkRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final int idx = _getFirstVisibleAyahIndex();
      if (idx >= 0 && idx < _ayahs.length) {
        _currentVisibleAyahIndex = idx;
      }
      _refreshCurrentBookmarkState();
    });
  }

  /// فحص حالة العلامة المرجعية للآية المرئية حالياً وتحديث الأيقونة
  Future<void> _refreshCurrentBookmarkState() async {
    if (!mounted || _ayahs.isEmpty) return;
    // استخدام الفهرس المُتتبع إن لم ينجح الكشف الهندسي
    final int idx = _getFirstVisibleAyahIndex();
    final int visibleIdx = (idx >= 0 && idx < _ayahs.length) ? idx : _currentVisibleAyahIndex;
    if (visibleIdx < 0 || visibleIdx >= _ayahs.length) return;
    final ayah = _ayahs[visibleIdx];
    final int number = resolveAyahNumberInSurah(visibleIdx + 1, ayah);
    if (number == _lastBookmarkCheckedAyah) return;

    bool bookmarked = false;
    try {
      final localDs = sl<QuranLocalDataSource>();
      final bookmarks = await localDs.getBookmarks();
      bookmarked = bookmarks.any(
        (b) => b.surahId == _currentSurahId && b.ayahNumber == number,
      );
    } catch (_) {}

    if (!mounted) return;
    _currentVisibleAyahIndex = visibleIdx;
    _lastBookmarkCheckedAyah = number;
    if (_isCurrentAyahBookmarked != bookmarked) {
      setState(() => _isCurrentAyahBookmarked = bookmarked);
    }
  }


  void _startAutoScroll() {
    _isAutoScrolling = true;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(Duration(milliseconds: (60 / _scrollSpeed).round()), (timer) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.offset + 1);
      }
    });
  }

  String get _scrollSpeedLabel {
    if (_scrollSpeed == 0.5) return "0.5x";
    if (_scrollSpeed == 0.75) return "0.75x";
    if (_scrollSpeed == 1.0) return "1x";
    if (_scrollSpeed == 1.5) return "1.5x";
    if (_scrollSpeed == 2.0) return "2x";
    if (_scrollSpeed == 3.0) return "3x";
    return "${_scrollSpeed}x";
  }

  void _cycleSpeed() {
    setState(() {
      if (_scrollSpeed == 0.5) {
        _scrollSpeed = 0.75;
      } else if (_scrollSpeed == 0.75) {
        _scrollSpeed = 1.0;
      } else if (_scrollSpeed == 1.0) {
        _scrollSpeed = 1.5;
      } else if (_scrollSpeed == 1.5) {
        _scrollSpeed = 2.0;
      } else if (_scrollSpeed == 2.0) {
        _scrollSpeed = 3.0;
      } else {
        _scrollSpeed = 0.5;
      }
      if (_isAutoScrolling) {
        _startAutoScroll();
      }
    });
  }

  void _stopAutoScroll() {
    _isAutoScrolling = false;
    _scrollTimer?.cancel();
  }

  /// فتح نافذة المساعد الصوتي (الذكاء الاصطناعي) من شاشة القراءة
  Future<void> _openVoiceAssistant(BuildContext context) async {
    final result = await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "VoiceAssistant",
      pageBuilder: (context, anim1, anim2) => const VoiceAssistantSheet(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1,
            child: child,
          ),
        );
      },
    );

    if (result != null && result is VoiceCommandResult && mounted) {
      if (result.type == VoiceCommandType.playSurah ||
          result.type == VoiceCommandType.playAyah) {
        final int targetSurahId = result.surahId ?? _currentSurahId;
        if (targetSurahId >= 1 && targetSurahId <= 114) {
          _loadSurah(targetSurahId, initialAyah: result.ayahNumber);
        }
      } else if (result.type == VoiceCommandType.webSearch) {
        final url = Uri.parse(
          "https://www.google.com/search?q=${Uri.encodeComponent(result.payload ?? '')}",
        );
        launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (result.type == VoiceCommandType.chatGpt) {
        final url = Uri.parse(
          "https://chatgpt.com/?q=${Uri.encodeComponent(result.payload ?? '')}",
        );
        launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _resolvedBgColor;
    final Color textColor = _resolvedTextColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: _buildSingleSurahBody(bgColor, textColor),
      bottomNavigationBar: _buildBottomActionMenu(bgColor),
    );
  }

  Widget _buildSingleSurahBody(Color bgColor, Color textColor) {
    final info = _surahMetadata[_currentSurahId];

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // ── شريط العنوان العلوي ────────────────────────────────
              _buildHeader(textColor),



              // ── محتوى السورة المستقلة فقط ──────
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _resolvedGoldColor))
                    : CustomScrollView(
                        key: _scrollViewKey,
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        cacheExtent: 2500.0,
                        slivers: [
                          // ── اسم السورة يتحرك مع الآيات ──
                          if (info != null)
                            SliverToBoxAdapter(
                              child: _buildScrollableSurahHeader(
                                info: info!,
                                isDark: _readingMode == "black" || _readingMode == "contrast",
                                // عدد الآيات الفعلي المُحمَّل (وليس العدد الثابت القديم)
                                // حتى يطابق رقم آخر آية معروضة دائماً.
                                ayahsCount: _ayahs.isNotEmpty ? _ayahs.length : (info?['count'] as int? ?? 0),
                              ),
                            ),
                          if (_currentSurahId != 9)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                                child: _buildBismillah(textColor),
                              ),
                            ),

                          if (_ayahs.isEmpty && _currentSurahId != 1)
                            SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(
                                    color: _resolvedGoldColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else
                            // ── عرض الآيات متجاورة كما في المصحف الشريف ──
                            // نُقسّم _displayItems إلى مجموعات بين فواصل الأجزاء،
                            // ثم نعرض كل مجموعة في RichText واحد متدفق.
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final Object item = _displayItems[index];

                                  // فاصل الجزء: يُعرض مستقلاً كعنصر كامل
                                  if (item is _JuzMarkerItem) {
                                    return _buildJuzMarker(item.juzNumber);
                                  }

                                  // نتحقق: هل هذا العنصر هو بداية مجموعة آيات؟
                                  // (أي أنه إما العنصر الأول أو يأتي بعد _JuzMarkerItem)
                                  final bool isPrevJuzMarker = index == 0 || _displayItems[index - 1] is _JuzMarkerItem;
                                  if (!isPrevJuzMarker) {
                                    // هذه الآية مدمجة داخل مجموعة سابقة → نتجاهلها هنا
                                    return const SizedBox.shrink();
                                  }

                                  // ════════════════════════════════════════════════
                                  // ★ معالجة خاصة: سورة الفاتحة ★
                                  // نتجاهل تقسيم قاعدة البيانات ونستخدم النصوص
                                  // الصحيحة الثابتة (7 آيات تبدأ بالحمد لله)
                                  // ════════════════════════════════════════════════
                                  if (_currentSurahId == 1) {
                                    // نُرجع كتلة الفاتحة عند أول عنصر فقط
                                    if (index != 0) return const SizedBox.shrink();

                                    const List<Map<String, dynamic>> fatihaVerses = [
                                      {"num": 1, "text": "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ"},
                                      {"num": 2, "text": "ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"},
                                      {"num": 3, "text": "مَـٰلِكِ يَوْمِ ٱلدِّينِ"},
                                      {"num": 4, "text": "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ"},
                                      {"num": 5, "text": "ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ"},
                                      {"num": 6, "text": "صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ"},
                                      {"num": 7, "text": "غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ"},
                                    ];

                                    final List<InlineSpan> fatihaSpans = [];
                                    for (final v in fatihaVerses) {
                                      final int fNum = v["num"] as int;
                                      final String fText = v["text"] as String;

                                      // نحاول إيجاد الآية المقابلة في الـ DB للتفسير
                                      Ayah? dbAyah;
                                      for (int di = 0; di < _ayahs.length; di++) {
                                        final int n = resolveAyahNumberInSurah(di + 1, _ayahs[di]);
                                        if (n == fNum) { dbAyah = _ayahs[di]; break; }
                                      }
                                      final Ayah tafsirAyah = dbAyah != null
                                          ? Ayah(
                                              id: dbAyah.id, surahId: 1, ayahNumber: fNum,
                                              text: dbAyah.text, textUthmani: dbAyah.textUthmani,
                                              translation: dbAyah.translation,
                                              tafsir: dbAyah.tafsir,
                                              tafsirIbnKathir: dbAyah.tafsirIbnKathir,
                                              tafsirJalalayn: dbAyah.tafsirJalalayn,
                                              page: dbAyah.page, juz: dbAyah.juz,
                                            )
                                          : Ayah(
                                              id: fNum, surahId: 1, ayahNumber: fNum,
                                              text: fText, textUthmani: fText,
                                              page: 1, juz: 1,
                                            );

                                      fatihaSpans.add(TextSpan(
                                        text: '$fText ',
                                        style: _getQuranTextStyle(
                                          color: _highlightedAyahNumber == fNum
                                              ? const Color(0xFFDFBA6B) : textColor,
                                          fontSize: _fontSize,
                                          fontWeight: _currentFontWeight,
                                          height: 2.0,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showTafsirDialog(tafsirAyah),
                                      ));
                                      fatihaSpans.add(WidgetSpan(
                                         alignment: PlaceholderAlignment.middle,
                                         child: KeyedSubtree(
                                           key: _ayahKeys.putIfAbsent(fNum - 1, () => GlobalKey()),
                                           child: GestureDetector(
                                             onTap: () => _showTafsirDialog(tafsirAyah),
                                             onLongPress: () => _toggleCurrentBookmark(specificAyah: tafsirAyah),
                                             child: _buildAyahNumber(fNum, textColor),
                                           ),
                                         ),
                                       ));
                                    }

                                    return KeyedSubtree(
                                      key: const ValueKey('fatiha_block'),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                        child: RichText(
                                          textAlign: TextAlign.justify,
                                          textDirection: TextDirection.rtl,
                                          text: TextSpan(children: fatihaSpans),
                                        ),
                                      ),
                                    );
                                  }
                                  // ════════════════════════════════════════════════

                                  // جمع كل الآيات المتتالية حتى الفاصل التالي أو نهاية القائمة
                                  final List<InlineSpan> groupSpans = [];

                                  for (int j = index; j < _displayItems.length; j++) {
                                    final Object jItem = _displayItems[j];
                                    if (jItem is _JuzMarkerItem) break; // وصلنا لفاصل → نتوقف

                                    final int ayahIndex = jItem as int;
                                    final ayah = _ayahs[ayahIndex];
                                    final int explicitNumber = resolveAyahNumberInSurah(ayahIndex + 1, ayah);
                                    final String rawText = ayah.textUthmani.isNotEmpty ? ayah.textUthmani : ayah.text;
                                    final String cleanText = explicitNumber == 1
                                        ? _cleanFirstAyahText(rawText, _currentSurahId)
                                        : rawText;

                                    final Ayah normalizedAyah = Ayah(
                                      id: ayah.id,
                                      surahId: _currentSurahId,
                                      ayahNumber: explicitNumber,
                                      text: ayah.text,
                                      textUthmani: ayah.textUthmani,
                                      translation: ayah.translation,
                                      tafsir: ayah.tafsir,
                                      tafsirIbnKathir: ayah.tafsirIbnKathir,
                                      tafsirJalalayn: ayah.tafsirJalalayn,
                                      page: ayah.page,
                                      juz: ayah.juz,
                                    );

                                    // نسجّل مفتاح كل آية بشكل مستقل لتتبع موضعها بدقة متناهية
                                    final ayahKey = _ayahKeys.putIfAbsent(ayahIndex, () => GlobalKey());

                                    // نص الآية
                                    groupSpans.add(
                                      TextSpan(
                                        text: '$cleanText ',
                                        style: _getQuranTextStyle(
                                          color: _highlightedAyahNumber != null && explicitNumber == _highlightedAyahNumber
                                              ? const Color(0xFFDFBA6B)
                                              : textColor,
                                          fontSize: _fontSize,
                                          fontWeight: _currentFontWeight,
                                          height: 2.0,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showTafsirDialog(normalizedAyah),
                                      ),
                                    );

                                    // رقم الآية
                                    groupSpans.add(
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: KeyedSubtree(
                                          key: ayahKey,
                                          child: GestureDetector(
                                            onTap: () => _showTafsirDialog(normalizedAyah),
                                            onLongPress: () => _toggleCurrentBookmark(specificAyah: normalizedAyah),
                                            child: _buildAyahNumber(explicitNumber, textColor),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (groupSpans.isEmpty) return const SizedBox.shrink();

                                  return KeyedSubtree(
                                    key: ValueKey('group_${_currentSurahId}_${index}'),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                      child: RichText(
                                        textAlign: TextAlign.justify,
                                        textDirection: TextDirection.rtl,
                                        text: TextSpan(children: groupSpans),
                                      ),
                                    ),
                                  );
                                },
                                childCount: _displayItems.length,
                              ),
                            ),

                        ],
                      ),
              ),
            ],
          ),
        ),

        // ── طبقة تخفيف السطوع ──────────────────────────────────────
        if (_brightness < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity((1.0 - _brightness) * 0.75),
              ),
            ),
          ),
      ],
    );
  }



  String _cleanFirstAyahText(String text, int surahId) {
    if (surahId == 9) return text;

    String cleaned = text.trim();
    final bismillahPatterns = [
      "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ",
      "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
      "بِسْمِ اِ۬للَّهِ اِ۬لرَّحْمَٰنِ اِ۬لرَّحِيمِ",
      "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
      "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ",
      "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
      "بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ",
    ];

    for (final pattern in bismillahPatterns) {
      if (cleaned.startsWith(pattern)) {
        cleaned = cleaned.substring(pattern.length).trim();
        break;
      }
    }

    if (cleaned.startsWith("بِسْمِ") || cleaned.startsWith("بِسۡمِ") || cleaned.startsWith("بسم")) {
      final words = cleaned.split(RegExp(r'\s+'));
      if (words.length > 4) {
        cleaned = words.sublist(4).join(' ').trim();
      }
    }

    // حماية قاطعة لفواتح السور والحروف المقطعة لعدم حذفها أبداً
    if (cleaned.isEmpty) {
      const Map<int, String> fawatih = {
        2: "الم",
        3: "الم",
        7: "المص",
        10: "الر",
        11: "الر",
        12: "الر",
        13: "المر",
        14: "الر",
        15: "الر",
        19: "كهيعص",
        20: "طه",
        26: "طسم",
        28: "طسم",
        29: "الم",
        30: "الم",
        31: "الم",
        32: "الم",
        36: "يسٓ",
        38: "صٓ",
        40: "حمٓ",
        41: "حمٓ",
        42: "حمٓ",
        43: "حمٓ",
        44: "حمٓ",
        45: "حمٓ",
        46: "حمٓ",
        50: "قٓ",
        68: "نٓ",
      };
      if (fawatih.containsKey(surahId)) {
        cleaned = fawatih[surahId]!;
      }
    }

    return cleaned.isNotEmpty ? cleaned : text;
  }

  List<InlineSpan> _buildAyahSpans(List<Ayah> ayahs, Color textColor, int surahId) {
    if (surahId == 1) {
      return _buildFatihaSpans(ayahs, textColor);
    }

    List<InlineSpan> spans = [];

    for (int i = 0; i < ayahs.length; i++) {
      final ayah = ayahs[i];
      String displayByText = ayah.textUthmani.isNotEmpty ? ayah.textUthmani : ayah.text;

      final int inSurahNumber = resolveAyahNumberInSurah(i + 1, ayah);

      // إزالة البسملة من مطلع الآية الأولى فقط لأنها معروضة بالترويسة بالأعلى
      if (inSurahNumber == 1) {
        displayByText = _cleanFirstAyahText(displayByText, surahId);
      }

      if (displayByText.isEmpty) {
        displayByText = ayah.text.isNotEmpty ? ayah.text : " ";
      }

      final normalizedAyah = Ayah(
        id: ayah.id,
        surahId: surahId,
        ayahNumber: inSurahNumber,
        text: ayah.text,
        textUthmani: ayah.textUthmani,
        translation: ayah.translation,
        tafsir: ayah.tafsir,
        tafsirIbnKathir: ayah.tafsirIbnKathir,
        tafsirJalalayn: ayah.tafsirJalalayn,
        page: ayah.page,
        juz: ayah.juz,
      );

      spans.add(
        TextSpan(
          text: "$displayByText ",
          style: _getQuranTextStyle(
            color: textColor,
            fontSize: _fontSize,
            fontWeight: _currentFontWeight,
            height: 2.0,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(normalizedAyah),
        ),
      );

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => _showTafsirDialog(normalizedAyah),
            child: _buildAyahNumber(inSurahNumber, textColor),
          ),
        ),
      );
    }

    return spans;
  }

  List<InlineSpan> _buildFatihaSpans(List<Ayah> ayahs, Color textColor) {
    final List<Map<String, dynamic>> defaultFatiha = [
      {"num": 1, "text": "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ"},
      {"num": 2, "text": "الرَّحْمَٰنِ الرَّحِيمِ"},
      {"num": 3, "text": "مَلِكِ يَوْمِ الدِّينِ"},
      {"num": 4, "text": "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ"},
      {"num": 5, "text": "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ"},
      {"num": 6, "text": "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ"},
      {"num": 7, "text": "غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ"},
    ];

    List<InlineSpan> spans = [];
    final List<Ayah> listToRender = ayahs.isNotEmpty ? ayahs : [];

    if (listToRender.isNotEmpty) {
      for (int i = 0; i < listToRender.length; i++) {
        final ayah = listToRender[i];
        String txt = ayah.textUthmani.isNotEmpty ? ayah.textUthmani : ayah.text;
        
        // إزالة البسملة المزدوجة إن وجدت في أول آية لأنها معروضة بالترويسة بالأعلى
        if (i == 0 || ayah.ayahNumber == 1) {
          const String officialBismillah = "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ";
          const String officialBismillahUthmani = "بِسْمِ اِ۬للَّهِ اِ۬لرَّحْمَٰنِ اِ۬لرَّحِيمِ";
          if (txt.startsWith(officialBismillah)) {
            txt = txt.substring(officialBismillah.length).trim();
          } else if (txt.startsWith(officialBismillahUthmani)) {
            txt = txt.substring(officialBismillahUthmani.length).trim();
          } else if (txt.startsWith("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")) {
            txt = txt.substring("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ".length).trim();
          }
        }

        if (txt.isEmpty) continue;
        final int num = resolveAyahNumberInSurah(i + 1, ayah);

        spans.add(
          TextSpan(
            text: "$txt ",
            style: _getQuranTextStyle(
              color: textColor,
              fontSize: _fontSize,
              fontWeight: _currentFontWeight,
              height: 2.0,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(ayah),
          ),
        );

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _showTafsirDialog(ayah),
              child: _buildAyahNumber(num, textColor),
            ),
          ),
        );
      }
    } else {
      for (int i = 0; i < defaultFatiha.length; i++) {
        final item = defaultFatiha[i];
        final int num = item["num"] as int;
        final String txt = item["text"] as String;
        final Ayah correspondingAyah = Ayah(
          id: num,
          surahId: 1,
          ayahNumber: num,
          text: txt,
          textUthmani: txt,
          page: 1,
          juz: 1,
        );

        spans.add(
          TextSpan(
            text: "$txt ",
            style: _getQuranTextStyle(
              color: textColor,
              fontSize: _fontSize,
              fontWeight: _currentFontWeight,
              height: 2.0,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(correspondingAyah),
          ),
        );

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _showTafsirDialog(correspondingAyah),
              child: _buildAyahNumber(num, textColor),
            ),
          ),
        );
      }
    }

    return spans;
  }

  static const Map<int, Map<String, dynamic>> _surahMetadata = {
    1: {"name": "الفاتحة", "type": "مكية", "count": 7},
    2: {"name": "البقرة", "type": "مدنية", "count": 286},
    3: {"name": "آل عمران", "type": "مدنية", "count": 200},
    4: {"name": "النساء", "type": "مدنية", "count": 176},
    5: {"name": "المائدة", "type": "مدنية", "count": 120},
    6: {"name": "الأنعام", "type": "مكية", "count": 165},
    7: {"name": "الأعراف", "type": "مكية", "count": 206},
    8: {"name": "الأنفال", "type": "مدنية", "count": 75},
    9: {"name": "التوبة", "type": "مدنية", "count": 129},
    10: {"name": "يونس", "type": "مكية", "count": 109},
    11: {"name": "هود", "type": "مكية", "count": 123},
    12: {"name": "يوسف", "type": "مكية", "count": 111},
    13: {"name": "الرعد", "type": "مدنية", "count": 43},
    14: {"name": "إبراهيم", "type": "مكية", "count": 52},
    15: {"name": "الحجر", "type": "مكية", "count": 99},
    16: {"name": "النحل", "type": "مكية", "count": 128},
    17: {"name": "الإسراء", "type": "مكية", "count": 111},
    18: {"name": "الكهف", "type": "مكية", "count": 110},
    19: {"name": "مريم", "type": "مكية", "count": 98},
    20: {"name": "طه", "type": "مكية", "count": 135},
    21: {"name": "الأنبياء", "type": "مكية", "count": 112},
    22: {"name": "الحج", "type": "مدنية", "count": 78},
    23: {"name": "المؤمنون", "type": "مكية", "count": 118},
    24: {"name": "النور", "type": "مدنية", "count": 64},
    25: {"name": "الفرقان", "type": "مكية", "count": 77},
    26: {"name": "الشعراء", "type": "مكية", "count": 227},
    27: {"name": "النمل", "type": "مكية", "count": 93},
    28: {"name": "القصص", "type": "مكية", "count": 88},
    29: {"name": "العنكبوت", "type": "مكية", "count": 69},
    30: {"name": "الروم", "type": "مكية", "count": 60},
    31: {"name": "لقمان", "type": "مكية", "count": 34},
    32: {"name": "السجدة", "type": "مكية", "count": 30},
    33: {"name": "الأحزاب", "type": "مدنية", "count": 73},
    34: {"name": "سبأ", "type": "مكية", "count": 54},
    35: {"name": "فاطر", "type": "مكية", "count": 45},
    36: {"name": "يس", "type": "مكية", "count": 83},
    37: {"name": "الصافات", "type": "مكية", "count": 182},
    38: {"name": "ص", "type": "مكية", "count": 88},
    39: {"name": "الزمر", "type": "مكية", "count": 75},
    40: {"name": "غافر", "type": "مكية", "count": 85},
    41: {"name": "فصلت", "type": "مكية", "count": 54},
    42: {"name": "الشورى", "type": "مكية", "count": 53},
    43: {"name": "الزخرف", "type": "مكية", "count": 89},
    44: {"name": "الدخان", "type": "مكية", "count": 59},
    45: {"name": "الجاثية", "type": "مكية", "count": 37},
    46: {"name": "الأحقاف", "type": "مكية", "count": 35},
    47: {"name": "محمد", "type": "مدنية", "count": 38},
    48: {"name": "الفتح", "type": "مدنية", "count": 29},
    49: {"name": "الحجرات", "type": "مدنية", "count": 18},
    50: {"name": "ق", "type": "مكية", "count": 45},
    51: {"name": "الذاريات", "type": "مكية", "count": 60},
    52: {"name": "الطور", "type": "مكية", "count": 49},
    53: {"name": "النجم", "type": "مكية", "count": 62},
    54: {"name": "القمر", "type": "مكية", "count": 55},
    55: {"name": "الرحمن", "type": "مدنية", "count": 78},
    56: {"name": "الواقعة", "type": "مكية", "count": 96},
    57: {"name": "الحديد", "type": "مدنية", "count": 29},
    58: {"name": "المجادلة", "type": "مدنية", "count": 22},
    59: {"name": "الحشر", "type": "مدنية", "count": 24},
    60: {"name": "الممتحنة", "type": "مدنية", "count": 13},
    61: {"name": "الصف", "type": "مدنية", "count": 14},
    62: {"name": "الجمعة", "type": "مدنية", "count": 11},
    63: {"name": "المنافقون", "type": "مدنية", "count": 11},
    64: {"name": "التغابن", "type": "مدنية", "count": 18},
    65: {"name": "الطلاق", "type": "مدنية", "count": 12},
    66: {"name": "التحريم", "type": "مدنية", "count": 12},
    67: {"name": "الملك", "type": "مكية", "count": 30},
    68: {"name": "القلم", "type": "مكية", "count": 52},
    69: {"name": "الحاقة", "type": "مكية", "count": 52},
    70: {"name": "المعارج", "type": "مكية", "count": 44},
    71: {"name": "نوح", "type": "مكية", "count": 28},
    72: {"name": "الجن", "type": "مكية", "count": 28},
    73: {"name": "المزمل", "type": "مكية", "count": 20},
    74: {"name": "المدثر", "type": "مكية", "count": 56},
    75: {"name": "القيامة", "type": "مكية", "count": 40},
    76: {"name": "الإنسان", "type": "مدنية", "count": 31},
    77: {"name": "المرسلات", "type": "مكية", "count": 50},
    78: {"name": "النبأ", "type": "مكية", "count": 40},
    79: {"name": "النازعات", "type": "مكية", "count": 40},
    80: {"name": "عبس", "type": "مكية", "count": 42},
    81: {"name": "التكوير", "type": "مكية", "count": 29},
    82: {"name": "الانفطار", "type": "مكية", "count": 19},
    83: {"name": "المطففين", "type": "مكية", "count": 36},
    84: {"name": "الانشقاق", "type": "مكية", "count": 25},
    85: {"name": "البروج", "type": "مكية", "count": 22},
    86: {"name": "الطارق", "type": "مكية", "count": 17},
    87: {"name": "الأعلى", "type": "مكية", "count": 19},
    88: {"name": "الغاشية", "type": "مكية", "count": 26},
    89: {"name": "الفجر", "type": "مكية", "count": 30},
    90: {"name": "البلد", "type": "مكية", "count": 20},
    91: {"name": "الشمس", "type": "مكية", "count": 15},
    92: {"name": "الليل", "type": "مكية", "count": 21},
    93: {"name": "الضحى", "type": "مكية", "count": 11},
    94: {"name": "الشرح", "type": "مكية", "count": 8},
    95: {"name": "التين", "type": "مكية", "count": 8},
    96: {"name": "العلق", "type": "مكية", "count": 19},
    97: {"name": "القدر", "type": "مكية", "count": 5},
    98: {"name": "البينة", "type": "مدنية", "count": 8},
    99: {"name": "الزلزلة", "type": "مدنية", "count": 8},
    100: {"name": "العاديات", "type": "مكية", "count": 11},
    101: {"name": "القارعة", "type": "مكية", "count": 11},
    102: {"name": "التكاثر", "type": "مكية", "count": 8},
    103: {"name": "العصر", "type": "مكية", "count": 3},
    104: {"name": "الهمزة", "type": "مكية", "count": 9},
    105: {"name": "الفيل", "type": "مكية", "count": 5},
    106: {"name": "قريش", "type": "مكية", "count": 4},
    107: {"name": "الماعون", "type": "مكية", "count": 7},
    108: {"name": "الكوثر", "type": "مكية", "count": 3},
    109: {"name": "الكافرون", "type": "مكية", "count": 6},
    110: {"name": "النصر", "type": "مدنية", "count": 3},
    111: {"name": "المسد", "type": "مكية", "count": 5},
    112: {"name": "الإخلاص", "type": "مكية", "count": 4},
    113: {"name": "الفلق", "type": "مكية", "count": 5},
    114: {"name": "الناس", "type": "مكية", "count": 6},
  };

  Widget _buildIslamicSurahHeader({
    required String surahName,
    required String revelationType,
    required int ayahsCount,
    required bool isDark,
  }) {
    final Color goldColor = isDark ? const Color(0xFFDFBA6B) : const Color(0xFF8B6B23);
    final Color frameBg = isDark ? const Color(0xFF0F2347).withOpacity(0.35) : const Color(0xFFFFFDF5);
    final Color innerBorderColor = isDark ? const Color(0xFFDFBA6B).withOpacity(0.3) : const Color(0xFFDFBA6B).withOpacity(0.85);
    final Color subTextColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: frameBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldColor.withOpacity(isDark ? 0.55 : 0.95), width: isDark ? 1.2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: goldColor.withOpacity(isDark ? 0.06 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner Frame Border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: innerBorderColor, width: isDark ? 0.7 : 1.1),
              ),
            ),
          ),
          // Content: Name + (مكية / مدنية) + عدد آياتها
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IslamicSurahName(
                  surahName: surahName,
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: goldColor,
                    height: 1.2,
                  ),
                  ornamentColor: isDark
                      ? const Color(0xFFEDEDED).withOpacity(0.88)
                      : const Color(0xFF8C9BAE),
                  ornamentWidth: 26,
                  ornamentHeight: 13,
                  spacing: 8,
                ),
                const SizedBox(height: 2),
                Text(
                  '($revelationType - عدد آياتها $ayahsCount)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// اسم السورة المتحرك مع الآيات - يُعرض ضمن CustomScrollView
  Widget _buildScrollableSurahHeader({
    required Map<String, dynamic> info,
    required bool isDark,
    int? ayahsCount,
  }) {
    final Color goldColor = isDark ? const Color(0xFFDFBA6B) : const Color(0xFF8B6B23);
    final Color frameBg = isDark
        ? const Color(0xFF0F2347).withValues(alpha: 0.35)
        : const Color(0xFFFFFDF5);
    final Color innerBorderColor = isDark
        ? const Color(0xFFDFBA6B).withValues(alpha: 0.30)
        : const Color(0xFFDFBA6B).withValues(alpha: 0.85);
    final Color subTextColor = isDark ? Colors.white : Colors.black;
    final Color titleColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: frameBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: goldColor.withValues(alpha: isDark ? 0.55 : 0.95),
            width: isDark ? 1.2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: isDark ? 0.07 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: innerBorderColor, width: isDark ? 0.7 : 1.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IslamicSurahName(
                    surahName: info['name'] ?? '',
                    style: GoogleFonts.amiri(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      height: 1.4,
                    ),
                    ornamentColor: isDark
                        ? const Color(0xFFEDEDED).withValues(alpha: 0.88)
                        : const Color(0xFF8C9BAE),
                    ornamentWidth: 30,
                    ornamentHeight: 14,
                    spacing: 10,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${info['type'] ?? ''} - عدد آياتها ${ayahsCount ?? info['count'] ?? 0})',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: subTextColor,
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

  /// نافذة اختيار القارئ الزجاجية السريعة
  void _showReciterSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        const Color sheetBg = Color(0xFF0C192E);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.50),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFBA6B).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDFBA6B).withOpacity(0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.record_voice_over_rounded,
                            color: Color(0xFFDFBA6B),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "اختر القارئ للترتيل",
                          style: GoogleFonts.amiri(
                            fontSize: HeaderFontPrefs.sized(17.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranOfflineManagerScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFDFBA6B).withOpacity(0.20),
                            const Color(0xFF1E3A8A).withOpacity(0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDFBA6B).withOpacity(0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFBA6B).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download_for_offline_rounded,
                              color: Color(0xFFDFBA6B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "تحميل القرآن كاملاً (بدون إنترنت)",
                                  style: GoogleFonts.tajawal(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "تحميل المصحف لجميع القراء أو لقارئ محدد أوفلاين",
                                  style: GoogleFonts.tajawal(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFDFBA6B),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _reciters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final key = _reciters.keys.elementAt(index);
                    final name = _reciters[key]!;
                    final bool isSelected = _selectedReciter == key;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedReciter = key);
                        sl<QuranSettingsDataSource>().setReciter(key);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم اختيار القارئ: $name',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFDFBA6B).withOpacity(0.20)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFDFBA6B)
                                : Colors.white.withOpacity(0.12),
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected
                                  ? const Color(0xFFDFBA6B)
                                  : Colors.white38,
                              size: 19,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.amiri(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// نافذة **خطوط القرآن الكريم** بنمط «معاينة قبل التطبيق»: اختيار خط لا
  /// يُطبَّق فوراً بل يصير «مسودة» تظهر في المعاينة (الخط وحجم القراءة الحالي)،
  /// ولا يُحفظ إلا بالضغط على «تطبيق». و«إلغاء» يُتلف المسودة.
  void _showFontSelectorSheet() {
    // التقاط الـmessenger قبل النافذة ليُستعمل بعد إغلاقها بأمان.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // مسودة خارج الـbuilder حتى تبقى بين إعادات البناء.
    String draftFont = _fontFamily;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        // قائمة خطوط القرآن الكريم: خلفية داكنة ثابتة وكل الخطوط باللون الأبيض دائماً
        final Color sheetBg = const Color(0xFF0C192E);
        final Color textColor = Colors.white;
        final Color goldColor = const Color(0xFFDFBA6B);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final String draftName = _quranFonts[draftFont] ?? '';
            return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.40),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: goldColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: goldColor.withOpacity(0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.font_download_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "خطوط القرآن الكريم",
                          style: GoogleFonts.amiri(
                            fontSize: HeaderFontPrefs.sized(18.0),
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white12,
                height: 1,
              ),
              // ── معاينة قبل التطبيق: الخط المسودّة بحجم القراءة الحالي ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_rounded,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'معاينة قبل التطبيق',
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'حجم القراءة ${_fontSize.toInt()}',
                          style: GoogleFonts.amiri(
                            fontSize: 11.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _resolvedBgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _resolvedTextColor.withOpacity(0.25),
                          width: 1.0,
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'وَلَقَدْ يَسَّرْنَا ٱلْقُرْءَانَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: draftFont,
                            fontSize: _fontSize,
                            fontWeight: _currentFontWeight,
                            color: _resolvedTextColor,
                            height: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الخط: $draftName — لا يُطبَّق شيء قبل «تطبيق»',
                      style: GoogleFonts.amiri(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _quranFonts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final key = _quranFonts.keys.elementAt(index);
                    final name = _quranFonts[key]!;
                    // «مختار» هنا = المسودة، لا المحفوظ: لا يُطبَّق إلا بـ«تطبيق»
                    final bool isSelected = draftFont == key;

                    return GestureDetector(
                      onTap: () => setSheetState(() => draftFont = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? goldColor.withOpacity(0.20)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                            width: isSelected ? 1.5 : 0.9,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? goldColor : Colors.white38,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    // عنوان الخط بالخط الأميري — وبحجم أصغر بمقدار واحد
                                    style: GoogleFonts.amiri(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: textColor, // كل الخطوط باللون الأبيض دائماً
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white10,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: key,
                                  fontSize: 18,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ── شريط التطبيق: لا يُحفظ الخط إلا بالضغط على «تطبيق» ──
              _buildSheetActionsBar(
                background: sheetBg,
                onCancel: () => Navigator.pop(ctx),
                onApply: () {
                  setState(() => _fontFamily = draftFont);
                  sl<QuranSettingsDataSource>().setFontFamily(draftFont);
                  Navigator.pop(ctx);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تطبيق خط: $draftName على كافة السور',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(Color textColor) {
    final bool isDarkMode = _readingMode == "black" || _readingMode == "contrast";
    final Color topGlassBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.78);
    final Color topGlassBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.30);
    final Color iconColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final Color goldColor = isDarkMode ? const Color(0xFFDFBA6B) : const Color(0xFF8B6810);
    final String currentReciterName = _reciters[_selectedReciter] ?? "اختر القارئ";

    const Color activeDarkBlueBg = Color(0xFF0F2347);
    const Color activeWhiteText = Colors.white;
    const Color activeWhiteBorder = Colors.white;

    final Color autoReadingTextColor = _isAutoScrolling ? activeWhiteText : iconColor;
    final Color autoReadingIconColor = _isAutoScrolling ? activeWhiteText : iconColor;

    final bool isSpeedActive = _scrollSpeed != 0.5;
    final Color speedTextColor = isSpeedActive ? activeWhiteText : iconColor;
    final Color speedIconColor = isSpeedActive ? activeWhiteText : iconColor;

    final Color hintColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF666666);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── السطر الأول: زر الرجوع + اسم القارئ الزجاجي + زر الحفظ ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // زر الرجوع
              Container(
                decoration: BoxDecoration(
                  color: topGlassBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: topGlassBorder, width: 0.9),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 16),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
              const SizedBox(width: 8),

              // ── شارة اسم القارئ الزجاجية التفاعلية ──
              Expanded(
                child: GestureDetector(
                  onTap: _showReciterSelectorSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: topGlassBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !isDarkMode ? Colors.black : topGlassBorder,
                        width: !isDarkMode ? 1.2 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            currentReciterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.tajawal(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF0F172A),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── أيقونة العلامة المرجعية (تبديل حفظ/إزالة الآية الحالية + ضغطة مطولة لاختيار آية) ──
              Tooltip(
                message: _isCurrentAyahBookmarked
                    ? 'إزالة العلامة المرجعية من هذه الآية (اضغط مطولاً لاختيار آية)'
                    : 'حفظ العلامة المرجعية للآية الحالية (اضغط مطولاً لاختيار آية)',
                child: GestureDetector(
                  onLongPress: _showAyahBookmarkPicker,
                  child: IconButton(
                    icon: Icon(
                      _isCurrentAyahBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_rounded,
                      size: 22,
                    ),
                    color: _isCurrentAyahBookmarked
                        ? goldColor
                        : (isDarkMode ? Colors.white : Colors.black),
                    onPressed: () => _toggleCurrentBookmark(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── السطر الثاني: أزرار القراءة الآلية + السرعة بتنسيق زجاجي منسق ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر القراءة الآلية
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_isAutoScrolling) {
                      _stopAutoScroll();
                    } else {
                      _startAutoScroll();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isAutoScrolling
                        ? activeDarkBlueBg
                        : topGlassBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !isDarkMode
                          ? Colors.black
                          : (_isAutoScrolling ? activeWhiteBorder : topGlassBorder),
                      width: !isDarkMode ? 1.2 : (_isAutoScrolling ? 1.2 : 0.9),
                    ),
                    boxShadow: _isAutoScrolling
                        ? [
                            BoxShadow(
                              color: const Color(0xFFDFBA6B).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAutoScrolling
                            ? Icons.pause_circle_filled_rounded
                            : Icons.auto_stories_rounded,
                        size: 15,
                        color: autoReadingIconColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isAutoScrolling ? "إيقاف القراءة" : "قراءة آلية",
                        style: GoogleFonts.tajawal(
                          fontSize: 10.5,
                          fontWeight: _isAutoScrolling ? FontWeight.bold : FontWeight.w600,
                          color: autoReadingTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // زر السرعة
              GestureDetector(
                onTap: _cycleSpeed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSpeedActive
                        ? activeDarkBlueBg
                        : topGlassBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !isDarkMode
                          ? Colors.black
                          : (isSpeedActive ? activeWhiteBorder : topGlassBorder),
                      width: !isDarkMode ? 1.2 : (isSpeedActive ? 1.2 : 0.9),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed_rounded, size: 15, color: speedIconColor),
                      const SizedBox(width: 5),
                      Text(
                        "السرعة $_scrollSpeedLabel",
                        style: GoogleFonts.tajawal(
                          fontSize: 10.5,
                          fontWeight: isSpeedActive ? FontWeight.bold : FontWeight.w600,
                          color: speedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── تلميح التفسير ──
        Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 5),
          child: Text(
            'للتفسير انقر على الآية',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : const Color(0xFF2D3748),
            ),
          ),
        ),
      ],
    );
  }


  /// الحد العلوي لمنطقة القراءة (أسفل الهيدر وشريط الحالة) بإحداثيات الشاشة.
  ///
  /// مصدر واحد يُستخدمه كل من اكتشاف الآية المرئية وتصحيح موضع التمرير،
  /// فلا يختلف القياس بينهما.
  double get _readingTopY {
    final scrollCtx = _scrollViewKey.currentContext;
    if (scrollCtx != null) {
      final ro = scrollCtx.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        final double top = ro.localToGlobal(Offset.zero).dy;
        if (top > 0) return top;
      }
    }
    return MediaQuery.of(context).padding.top + 65.0;
  }

  /// قياس **هندسي بحت**: فهرس أعلى آية نصّها يلامس حدّ القراءة العلوي الآن.
  ///
  /// يعتمد على مفاتيح الآيات المبنية فعلاً ونهاياتها المحسوبة فعلياً، فلا
  /// تقدير ولا افتراض في ارتفاع أي آية. يُرجع `null` إذا لم تكن هناك أي آية
  /// مبنية (حالة نادرة جداً) — عندها فقط يُلجأ إلى التقدير.
  int? _measureTopVisibleIndex() {
    if (_ayahs.isEmpty) return null;
    final double viewportTop = _readingTopY;
    for (int i = 0; i < _ayahs.length; i++) {
      final ctx = _ayahKeys[i]?.currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro == null || !ro.attached || ro is! RenderBox) continue;
      if (ro.localToGlobal(Offset.zero).dy >= viewportTop - 15.0) return i;
    }
    return null;
  }

  /// اكتشاف أول آية مرئية فعلاً على الشاشة أسفل الهيدر
  int _getFirstVisibleAyahIndex() {
    if (_ayahs.isEmpty) return 0;
    final double viewportTop = _readingTopY;

    // الفحص الهندسي الدقيق للمفاتيح المبنية فعلاً:
    // بما أن رقم كل آية مرتبط بمفتاح GlobalKey في نهاية نص الآية،
    // فإن أول آية يكون رقمها عند أو أسفل حد القراءة العلوي هي الآية الجاري قراءتها الآن.
    final int? measured = _measureTopVisibleIndex();
    if (measured != null) return measured;

    // 2. خوارزمية احتياطية تعتمد على إزاحة التمرير (Fallback via scroll offset)
    if (_scrollController.hasClients && _scrollController.offset > 10.0) {
      final double offset = _scrollController.offset;
      final double screenWidth = MediaQuery.of(context).size.width;
      final double contentWidth = math.max(280.0, screenWidth - 40.0);

      double accumulated = _currentSurahId == 9 ? 60.0 : 120.0;
      for (int i = 0; i < _ayahs.length; i++) {
        final text = _ayahs[i].textUthmani.isNotEmpty ? _ayahs[i].textUthmani : _ayahs[i].text;
        final charsPerLine = math.max(15, (contentWidth / (_fontSize * 0.58)).floor());
        final int lines = math.max(1, (text.length / charsPerLine).ceil());
        final double height = (lines * _fontSize * 1.8) + 12.0;
        accumulated += height;
        if (accumulated >= offset) {
          return i;
        }
      }
      return _ayahs.length - 1;
    }

    return 0;
  }

  /// تحديد الآية المستهدفة بدقة (المرئية حالياً على الشاشة أو المحددة صراحةً)
  /// وتُرجع الآية مع رقمها الصحيح داخل السورة.
  ({Ayah ayah, int number}) _resolveTargetAyah({Ayah? specificAyah}) {
    if (specificAyah != null) {
      return (
        ayah: specificAyah,
        number: specificAyah.ayahNumber > 0 ? specificAyah.ayahNumber : 1,
      );
    }
    if (_ayahs.isEmpty) {
      // لا يُستدعى مع سورة فارغة (كل المتصلين يفحصون ذلك أولاً)
      return (
        ayah: const Ayah(
          id: 0,
          surahId: 0,
          ayahNumber: 1,
          text: '',
          textUthmani: '',
          page: 0,
          juz: 0,
        ),
        number: 1,
      );
    }

    // الاكتشاف الدقيق للآية المرئية باستخدام GlobalKey ثم خوارزمية الإزاحة
    final visibleIndex = _getFirstVisibleAyahIndex();
    // استخدام الفهرس المُتتبع كخيار احتياطي إذا فشل الكشف الهندسي
    final int effectiveIndex = (visibleIndex >= 0 && visibleIndex < _ayahs.length)
        ? visibleIndex
        : _currentVisibleAyahIndex.clamp(0, _ayahs.length - 1);
    final ayah = _ayahs[effectiveIndex];
    return (
      ayah: ayah,
      number: resolveAyahNumberInSurah(effectiveIndex + 1, ayah),
    );
  }

  /// عرض إشعار SnackBar موحد لحالات العلامة المرجعية
  void _showBookmarkSnackBar({required String message}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// حفظ العلامة المرجعية للآية مع موضع التوقف وتحديث الختمة
  ///
  /// كل خطوة محصّنة وحدها: فشل حفظ "آخر قراءة" أو تحديث الختمة لم يكن
  /// ليُسقط العلامة المرجعية نفسها (كان ذلك يجعل الزر يبدو بلا أثر أحياناً).
  Future<void> _performBookmarkAdd(Ayah targetAyah, int targetAyahNumber) async {
    // 1. حفظ في إعدادات آخر قراءة (Last Read)
    try {
      final settings = sl<QuranSettingsDataSource>();
      await settings.saveLastRead(_currentSurahId, targetAyahNumber);
    } catch (_) {}

    // 2. تحديث الختمة
    try {
      await _updateKhatma(targetAyah);
    } catch (_) {}

    // 3. حفظ كعلامة مرجعية رسمية (Bookmark)
    bool saved = false;
    try {
      final localDs = sl<QuranLocalDataSource>();
      await localDs.addBookmark(Bookmark(
        surahId: _currentSurahId,
        ayahNumber: targetAyahNumber,
        surahName: _currentSurahTitle,
        createdAt: DateTime.now(),
      ));
      saved = true;
    } catch (_) {}

    HapticFeedback.mediumImpact();

    // تحديث حالة الأيقونة للآية المرئية فعلاً (قد تختلف عن آية التفسير)
    _lastBookmarkCheckedAyah = -1;
    await _refreshCurrentBookmarkState();

    _showBookmarkSnackBar(
      message: saved
          ? 'تم حفظ العلامة المرجعية: سورة $_currentSurahTitle - الآية $targetAyahNumber'
          : 'تعذّر حفظ العلامة المرجعية (سورة $_currentSurahTitle - الآية $targetAyahNumber)',
    );
  }

  /// نافذة اختيار آية لحفظ علامتها المرجعية أو الانتقال إليها مباشرة
  void _showAyahBookmarkPicker() async {
    if (_ayahs.isEmpty) return;
    final bool isDark = _readingMode == "black" || _readingMode == "contrast";
    final Color bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFFAF7F0);
    final Color cardBg = isDark ? const Color(0xFF142236) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color goldColor = _resolvedGoldColor;

    List<int> bookmarkedAyahs = [];
    try {
      final localDs = sl<QuranLocalDataSource>();
      final bms = await localDs.getBookmarks();
      bookmarkedAyahs = bms
          .where((b) => b.surahId == _currentSurahId)
          .map((b) => b.ayahNumber)
          .toList();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollCtrl) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'العلامات المرجعية - سورة $_currentSurahTitle',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      Text(
                        '(${_ayahs.length} آية)',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _ayahs.length,
                    itemBuilder: (context, i) {
                      final ayah = _ayahs[i];
                      final int num = resolveAyahNumberInSurah(i + 1, ayah);
                      final bool isBookmarked = bookmarkedAyahs.contains(num);
                      final String text = ayah.textUthmani.isNotEmpty ? ayah.textUthmani : ayah.text;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isBookmarked ? goldColor : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: _buildAyahNumber(num, isBookmarked ? goldColor : textColor),
                          title: Text(
                            text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiri(
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                              color: isBookmarked ? goldColor : Colors.grey,
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _toggleCurrentBookmark(specificAyah: ayah);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _scrollToInitialAyah(num);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// حفظ موضع التوقف والعلامة المرجعية (يُستدعى من نافذة التفسير)
  Future<void> _saveCurrentProgress({Ayah? specificAyah}) async {
    if (_ayahs.isEmpty) return;
    final target = _resolveTargetAyah(specificAyah: specificAyah);
    await _performBookmarkAdd(target.ayah, target.number);
  }

  /// تبديل العلامة المرجعية للآية الحالية: إضافة إن لم تكن موجودة، وإزالة إن كانت موجودة
  Future<void> _toggleCurrentBookmark({Ayah? specificAyah}) async {
    if (_ayahs.isEmpty) return;

    final target = _resolveTargetAyah(specificAyah: specificAyah);
    final Ayah targetAyah = target.ayah;
    final int targetAyahNumber = target.number;

    try {
      final localDs = sl<QuranLocalDataSource>();
      final bookmarks = await localDs.getBookmarks();
      final bool isBookmarked = bookmarks.any(
        (b) => b.surahId == _currentSurahId && b.ayahNumber == targetAyahNumber,
      );

      if (isBookmarked) {
        await localDs.removeBookmark(_currentSurahId, targetAyahNumber);
        HapticFeedback.mediumImpact();

        _lastBookmarkCheckedAyah = -1;
        await _refreshCurrentBookmarkState();

        _showBookmarkSnackBar(
          message: 'تمت إزالة العلامة المرجعية: سورة $_currentSurahTitle - الآية $targetAyahNumber',
        );
        return;
      }
    } catch (_) {
      // في حال فشل القراءة نتابع عملية الحفظ فقط
    }

    await _performBookmarkAdd(targetAyah, targetAyahNumber);
  }

  /// مسح العلامة المرجعية للآية الحالية وموضع التوقف
  Future<void> _clearCurrentBookmark() async {
    if (_ayahs.isEmpty) return;

    final target = _resolveTargetAyah();
    final int targetAyahNumber = target.number;

    // حذف العلامة المرجعية لهذه الآية فقط (وليس كل العلامات)
    try {
      final localDs = sl<QuranLocalDataSource>();
      await localDs.removeBookmark(_currentSurahId, targetAyahNumber);
    } catch (_) {}

    // مسح بيانات آخر قراءة من SharedPreferences أيضاً
    try {
      final settings = sl<QuranSettingsDataSource>();
      await settings.clearLastRead();
    } catch (_) {}

    HapticFeedback.mediumImpact();

    _lastBookmarkCheckedAyah = -1;
    await _refreshCurrentBookmarkState();

    _showBookmarkSnackBar(
      message: 'سورة $_currentSurahTitle - الآية $targetAyahNumber',
    );
  }


  /// بناء عناصر العرض: فهارس الآيات + فاصل «بداية الجزء الجديد» عند تغيّر رقم الجزء
  List<Object> _buildDisplayItems(List<Ayah> ayahs) {
    final items = <Object>[];
    for (int i = 0; i < ayahs.length; i++) {
      if (i > 0) {
        final prevJuz = ayahs[i - 1].juz;
        final currJuz = ayahs[i].juz;
        if (prevJuz > 0 && currJuz > 0 && prevJuz != currJuz) {
          items.add(_JuzMarkerItem(currJuz));
        }
      }
      items.add(i);
    }
    return items;
  }

  /// فاصل الجزء: «جزء (الرقم)» بخط ذهبي مع نجمة بجواره
  Widget _buildJuzMarker(int juzNumber) {
    final bool isDark = _readingMode == "black" || _readingMode == "contrast";
    final Color goldColor = isDark ? const Color(0xFFDFBA6B) : const Color(0xFF8B6B23);
    final Color lineColor = goldColor.withValues(alpha: isDark ? 0.45 : 0.60);
    final double starSize = math.max(14.0, _fontSize * 0.6);
    final double textSize = math.max(16.0, _fontSize * 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 42, height: 1.2, color: lineColor),
          const SizedBox(width: 10),
          Icon(Icons.star_rounded, color: goldColor, size: starSize),
          const SizedBox(width: 8),
          Text(
            'جزء ${_toArabicNumbers(juzNumber.toString())}',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: textSize,
              fontWeight: FontWeight.bold,
              color: goldColor,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, color: goldColor, size: starSize),
          const SizedBox(width: 10),
          Container(width: 42, height: 1.2, color: lineColor),
        ],
      ),
    );
  }

  Widget _buildBismillah(Color textColor) {
    final bool isDarkMode = _readingMode == "black" || _readingMode == "contrast";
    final double bismillahFontSize = isDarkMode ? _fontSize - 3 : _fontSize;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Center(
        child: Text(
          "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ",
          textAlign: TextAlign.center,
          style: _getQuranTextStyle(
            fontSize: bismillahFontSize,
            fontWeight: _currentFontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAyahNumber(int number, Color textColor) {
    final bool isDark = _readingMode == "black" || _readingMode == "contrast";
    final int digitCount = number.toString().length;
    final double baseSize = math.max(27.0, _fontSize * 1.15);
    // 3-digit numbers need more width; keep height capped
    final double markerWidth = digitCount >= 3 ? baseSize * 1.35 : baseSize;
    final double markerHeight = baseSize;
    final double numberFontSize = digitCount >= 3
        ? math.max(9.5, _fontSize * 0.38)
        : math.max(10.5, _fontSize * 0.45);

    // في الوضع الليلي: أبيض، في الوضع النهاري: أسود داكن
    final Color ornamentColor = isDark ? Colors.white : Colors.black;
    final Color numberColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      width: markerWidth,
      height: markerHeight,
      child: CustomPaint(
        size: Size(markerWidth, markerHeight),
        painter: _IslamicAyahOrnamentPainter(
          goldColor: ornamentColor,
          innerBg: _resolvedBgColor,
          isDark: isDark,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Text(
              _toArabicNumbers(number.toString()),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: GoogleFonts.amiri(
                fontSize: numberFontSize,
                fontWeight: FontWeight.bold,
                color: numberColor,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionMenu(Color bgColor) {
    final bool isDark = _readingMode == "black" || _readingMode == "contrast";

    final Color sideBtnBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);
    final Color sideIconColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      // الوضع الليلي: تاسك بار أسود صافٍ
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.98),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.97),
                      Colors.white.withValues(alpha: 0.93),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.20),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. زر التشغيل / الإيقاف الصوتي
                BlocListener<QuranAudioBloc, QuranAudioState>(
                  listenWhen: (previous, current) =>
                      current.errorMessage != null &&
                      previous.errorMessage != current.errorMessage,
                  listener: (context, audioState) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFFF6B6B), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                audioState.errorMessage ??
                                    'فشل في تحميل الصوت. تأكد من اتصالك بالإنترنت.',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: GlassNoticeSpec.surface,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                  child: BlocBuilder<QuranAudioBloc, QuranAudioState>(
                  builder: (context, audioState) {
                    final bool isPlaying =
                        audioState.playerState?.playing ?? false;
                    return _modernTaskbarButton(
                      icon: isPlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      // الوضع الليلي: زر التشغيل أبيض والأيقونة في وسطه سوداء
                      iconColor: isDark ? Colors.black : Colors.white,
                      bgColor: isDark ? Colors.white : const Color(0xFF0F2347),
                      tooltip: isPlaying ? 'إيقاف التلاوة' : 'تشغيل التلاوة',
                      onTap: () {
                        if (isPlaying) {
                          context
                              .read<QuranAudioBloc>()
                              .add(StopAudioEvent());
                        } else {
                          final currentSurahId = _currentSurahId;
                          final sName =
                              _surahMetadata[currentSurahId]?['name'] as String? ??
                                  _currentSurahTitle;
                          final target = _resolveTargetAyah();
                          final startAyah = target.number;
                          context.read<QuranAudioBloc>().add(PlayAyahAudioEvent(
                                surahId: currentSurahId,
                                ayahNumber: startAyah,
                                reciterIdentifier: _selectedReciter,
                                surahName: sName,
                              ));
                        }
                      },
                    );
                  },
                  ),
                ),

                // زر مايك الذكاء الاصطناعي: دائرة سوداء + مايك أبيض
                Tooltip(
                  message: 'مساعد الذكاء الاصطناعي الصوتي',
                  child: GestureDetector(
                    onTap: () => _openVoiceAssistant(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. زر تغيير نوع خط القرآن الكريم
                _modernTaskbarButton(
                  icon: Icons.font_download_rounded,
                  iconColor: sideIconColor,
                  bgColor: sideBtnBg,
                  border: !isDark ? Border.all(color: Colors.black, width: 1.2) : null,
                  tooltip: 'تغيير نوع خط القرآن',
                  onTap: _showFontSelectorSheet,
                ),

                // 3. زر المظهر (ليلي / نهاري)
                _modernTaskbarButton(
                  icon: _readingMode == "white"
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  iconColor: sideIconColor,
                  bgColor: sideBtnBg,
                  border: !isDark ? Border.all(color: Colors.black, width: 1.2) : null,
                  tooltip:
                      _readingMode == "white" ? 'الوضع الليلي' : 'الوضع النهاري',
                  onTap: () {
                    setState(() {
                      _readingMode =
                          _readingMode == "white" ? "black" : "white";
                      sl<QuranSettingsDataSource>().setReadingMode(_readingMode);
                    });
                  },
                ),

                // 4. زر الإعدادات
                _modernTaskbarButton(
                  icon: Icons.settings_rounded,
                  iconColor: sideIconColor,
                  bgColor: sideBtnBg,
                  border: !isDark ? Border.all(color: Colors.black, width: 1.2) : null,
                  tooltip: 'إعدادات القراءة',
                  onTap: _showSettingsSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernTaskbarButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
    BoxBorder? border,
  }) {
    const double buttonSize = 42.0;
    const double iconSize = 22.0;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateKhatma(Ayah ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('khatma_juz', ayah.juz);
    await prefs.setInt('khatma_surah_id', ayah.surahId);

    const Map<int, String> surahNames = {
      1: "الفاتحة", 2: "البقرة", 3: "آل عمران", 4: "النساء", 5: "المائدة",
      6: "الأنعام", 7: "الأعراف", 8: "الأنفال", 9: "التوبة", 10: "يونس",
      11: "هود", 12: "يوسف", 13: "الرعد", 14: "إبراهيم", 15: "الحجر",
      16: "النحل", 17: "الإسراء", 18: "الكهف", 19: "مريم", 20: "طه",
      21: "الأنبياء", 22: "الحج", 23: "المؤمنون", 24: "النور", 25: "الفرقان",
      26: "الشعراء", 27: "النمل", 28: "القصص", 29: "العنكبوت", 30: "الروم",
      31: "لقمان", 32: "السجدة", 33: "الأحزاب", 34: "سبأ", 35: "فاطر",
      36: "يس", 37: "الصافات", 38: "ص", 39: "الزمر", 40: "غافر",
      41: "فصلت", 42: "الشورى", 43: "الزخرف", 44: "الدخان", 45: "الجاثية",
      46: "الأحقاف", 47: "محمد", 48: "الفتح", 49: "الحجرات", 50: "ق",
      51: "الذاريات", 52: "الطور", 53: "النجم", 54: "القمر", 55: "الرحمن",
      56: "الواقعة", 57: "الحديد", 58: "المجادلة", 59: "الحشر", 60: "الممتحنة",
      61: "الصف", 62: "الجمعة", 63: "المنافقون", 64: "التغابن", 65: "الطلاق",
      66: "التحريم", 67: "الملك", 68: "القلم", 69: "الحاقة", 70: "المعارج",
      71: "نوح", 72: "الجن", 73: "المزمل", 74: "المدثر", 75: "القيامة",
      76: "الإنسان", 77: "المرسلات", 78: "النبأ", 79: "النازعات", 80: "عبس",
      81: "التكوير", 82: "الانفطار", 83: "المطففين", 84: "الانشقاق", 85: "البروج",
      86: "الطارق", 87: "الأعلى", 88: "الغاشية", 89: "الفجر", 90: "البلد",
      91: "الشمس", 92: "الليل", 93: "الضحى", 94: "الشرح", 95: "التين",
      96: "العلق", 97: "القدر", 98: "البينة", 99: "الزلزلة", 100: "العاديات",
      101: "القارعة", 102: "التكاثر", 103: "العصر", 104: "الهمزة", 105: "الفيل",
      106: "قريش", 107: "الماعون", 108: "الكوثر", 109: "الكافرون", 110: "النصر",
      111: "المسد", 112: "الإخلاص", 113: "الفلق", 114: "الناس"
    };

    String surahName = widget.surah?.nameArabic ?? surahNames[ayah.surahId] ?? "سورة";
    await prefs.setString('khatma_surah_name', surahName);
    await prefs.setInt('khatma_ayah', ayah.ayahNumber);
    
    final lastDate = prefs.getString('khatma_last_date') ?? "";
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    if (lastDate != today) {
      int streak = prefs.getInt('khatma_streak') ?? 0;
      await prefs.setInt('khatma_streak', streak + 1);
      await prefs.setString('khatma_last_date', today);
    }
    
    int lastPage = prefs.getInt('khatma_last_page_num') ?? 0;
    if (ayah.page != lastPage) {
      int totalPages = prefs.getInt('khatma_pages') ?? 0;
      await prefs.setInt('khatma_pages', totalPages + 1);
      await prefs.setInt('khatma_last_page_num', ayah.page);
    }
  }

  void _showTafsirDialog(Ayah ayah) {
    _updateKhatma(ayah);
    final bool isDark = _readingMode == "black" || _readingMode == "contrast";
    final Color bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFFAF7F0);
    final Color cardBg = isDark ? const Color(0xFF142236) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE8E0D0) : const Color(0xFF2C2013);
    final Color goldColor = _resolvedGoldColor;

    showDialog(
      context: context,
      builder: (context) => _TafsirDialogWidget(
        ayah: ayah,
        bgColor: bgColor,
        cardBg: cardBg,
        textColor: textColor,
        goldColor: goldColor,
        onSaveBookmark: () => _saveCurrentProgress(specificAyah: ayah),
        onPlayAudio: () {
          final sName =
              _surahMetadata[ayah.surahId]?['name'] as String? ??
                  _currentSurahTitle;
          context.read<QuranAudioBloc>().add(PlayAyahAudioEvent(
                surahId: ayah.surahId,
                ayahNumber: ayah.ayahNumber,
                reciterIdentifier: _selectedReciter,
                surahName: sName,
              ));
        },
      ),
    );
  }



  /// نافذة **إعدادات القراءة** بنمط «معاينة قبل التطبيق»: كل ما يُمسك في
  /// النافذة (الحجم، السماكة، النمط، الإضاءة، القارئ) يبقى **مسودة** تظهر في
  /// المعاينة المباشرة، ولا يُحفظ ولا يغيّر شاشة القراءة إلا بالضغط على
  /// «تطبيق». و«إلغاء» يُتلف المسودة.
  void _showSettingsSheet() {
    // ── توحيد إعدادات القراءة: استخدام تصميم الوضع الليلي الداكن والفاخر لكلا الوضعين النهاري والليلي ──
    const Color sheetBg = Color(0xFF09101D);
    const Color primaryColor = Colors.white;
    const Color textColor = Colors.white;
    final Color subTextColor = Colors.white.withOpacity(0.85);

    // حدود الكاردات الإسلامية الاحترافية الواضحة:
    final Color cardBorderColor = Colors.white.withOpacity(0.35);
    const Color cardBg = Color(0xFF131D2E);
    const Color headerBg = Color(0xFF0F172A);

    // ── أحجام الخطوط ونوع الخط المطلوب ──
    // عنوان إعدادات القراءة ورؤوس الأقسام: 14 | باقي النصوص والخيارات: 13 | نوع الخط: خط القرآن أميري (Amiri)
    const double sTitle = 14.0;
    const double sSection = 14.0;
    const double sSmall = 13.0;

    // ── المسودات: خارج الـbuilder حتى تبقى بين إعادات البناء، ولا شيء منها
    //    يُحفظ في التفضيلات قبل «تطبيق». ──
    double draftSize = _fontSize;
    String draftWeight = _fontWeightMode;
    String draftMode = _readingMode;
    double draftBrightness = _brightness;
    String draftReciter = _selectedReciter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.50),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.35),
                width: 1.2,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: 0,
            right: 0,
            top: 0,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Stack(
            children: [
              // المحتوى قابل للتمرير، وشريط «إلغاء/تطبيق» ثابت أسفله فلا
              // يحتاج المستخدم للتمرير للوصول إليه.
              SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 84),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle Bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                // ── Header مزخرف بإطار إسلامي أنيق ─────────────────────────────
                Container(
                  margin: const EdgeInsets.only(top: 10, left: 0, right: 0, bottom: 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.20),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.30),
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(Icons.tune_rounded, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "إعدادات القراءة",
                            style: GoogleFonts.amiri(
                              fontSize: sTitle,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),

                // ─── محتوى الإعدادات ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),

                      // ── 0. معاينة قبل التطبيق ────────────────────────────────
                      // الحجم والسماكة والنمط والإضاءة كما ستُطبَّق فعلاً — والخط
                      // نفسه المستخدم في الشاشة، فلا يُحفظ شيء قبل «تطبيق».
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "معاينة قبل التطبيق",
                            style: GoogleFonts.amiri(
                              fontSize: sSection,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_quranFonts[_fontFamily] ?? ''} • حجم ${draftSize.toInt()} • لا يُحفظ شيء قبل «تطبيق»',
                        style: GoogleFonts.amiri(
                          fontSize: 11.5,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReadingPreview(
                        fontSize: draftSize,
                        fontWeightMode: draftWeight,
                        readingMode: draftMode,
                        brightness: draftBrightness,
                      ),

                      const SizedBox(height: 18),

                      // ── 1. Font Size Section (حجم الخط) ─────────────────────
                      Row(
                        children: [
                          const Icon(Icons.format_size_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "حجم الخط",
                            style: GoogleFonts.amiri(
                              fontSize: sSection,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.40),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              "${draftSize.toInt()}",
                              style: GoogleFonts.amiri(
                                fontSize: sSmall,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // زر التصغير
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (draftSize > 16) {
                                    setST(() => draftSize = draftSize - 2);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.remove_rounded, color: primaryColor, size: 22),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: primaryColor,
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: primaryColor,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  overlayColor: primaryColor.withOpacity(0.15),
                                  trackHeight: 4.0,
                                ),
                                child: Slider(
                                  value: draftSize,
                                  min: 16,
                                  max: 42,
                                  divisions: 13,
                                  // المسودة فقط: شاشة القراءة تُحدَّث عند «تطبيق»
                                  onChanged: (v) => setST(() => draftSize = v),
                                ),
                              ),
                            ),
                            // زر التكبير
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (draftSize < 42) {
                                    setST(() => draftSize = draftSize + 2);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.add_rounded, color: primaryColor, size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── 2. Font Weight Section (سمك الخط) ─────────────────────
                      Row(
                        children: [
                          const Icon(Icons.text_fields_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "سمك الخط",
                            style: GoogleFonts.amiri(
                              fontSize: sSection,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildWeightOption(
                            label: "عادي",
                            value: "normal",
                            selected: draftWeight,
                            onSelect: (v) => setST(() => draftWeight = v),
                          ),
                          const SizedBox(width: 8),
                          _buildWeightOption(
                            label: "غامق",
                            value: "semi_bold",
                            selected: draftWeight,
                            onSelect: (v) => setST(() => draftWeight = v),
                          ),
                          const SizedBox(width: 8),
                          _buildWeightOption(
                            label: "عريض",
                            value: "bold",
                            selected: draftWeight,
                            onSelect: (v) => setST(() => draftWeight = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 3. Contrast & Theme Section (نمط القراءة) ─────────────
                      Row(
                        children: [
                          const Icon(Icons.contrast_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "نمط القراءة",
                            style: GoogleFonts.amiri(
                              fontSize: sSection,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildThemeOption(
                            label: "ليلي",
                            mode: "black",
                            icon: Icons.dark_mode_rounded,
                            selected: draftMode,
                            onSelect: (v) => setST(() => draftMode = v),
                          ),
                          const SizedBox(width: 6),
                          _buildThemeOption(
                            label: "نهاري",
                            mode: "white",
                            icon: Icons.light_mode_rounded,
                            selected: draftMode,
                            onSelect: (v) => setST(() => draftMode = v),
                          ),
                          const SizedBox(width: 6),
                          _buildThemeOption(
                            label: "دافئ",
                            mode: "sepia",
                            icon: Icons.menu_book_rounded,
                            selected: draftMode,
                            onSelect: (v) => setST(() => draftMode = v),
                          ),
                          const SizedBox(width: 6),
                          _buildThemeOption(
                            label: "عالي التباين",
                            mode: "contrast",
                            icon: Icons.flash_on_rounded,
                            selected: draftMode,
                            onSelect: (v) => setST(() => draftMode = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ── 4. Brightness Section (الإضاءة) ─────────────────────────
                      Row(
                        children: [
                          const Icon(Icons.brightness_medium_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "إضاءة الشاشة",
                            style: GoogleFonts.amiri(
                              fontSize: sSection,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.40),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              "${(draftBrightness * 100).toInt()}%",
                              style: GoogleFonts.amiri(
                                fontSize: sSmall,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.brightness_low_rounded, color: Colors.white70, size: 20),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: primaryColor,
                                  inactiveTrackColor: Colors.white30,
                                  thumbColor: primaryColor,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  trackHeight: 4.0,
                                ),
                                child: Slider(
                                  value: draftBrightness,
                                  min: 0.25,
                                  max: 1.0,
                                  // المسودة فقط: الإضاءة تُطبَّق عند «تطبيق»
                                  onChanged: (v) =>
                                      setST(() => draftBrightness = v),
                                ),
                              ),
                            ),
                            const Icon(Icons.brightness_high_rounded, color: primaryColor, size: 20),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── 5. Reciter Section (اختر القارئ) ──────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mic_external_on_rounded, color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "اختر القارئ",
                                style: GoogleFonts.amiri(
                                  fontSize: sSection,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QuranOfflineManagerScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: primaryColor.withOpacity(0.12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cloud_download_rounded, size: 16, color: primaryColor),
                            label: Text(
                              "إدارة التنزيلات",
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 170,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _reciters.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final key = _reciters.keys.elementAt(index);
                            final name = _reciters[key]!;
                            // «مختار» هنا = المسودة: القارئ يُطبَّق عند «تطبيق»
                            final bool isSelected = draftReciter == key;

                            return GestureDetector(
                              onTap: () =>
                                  setST(() => draftReciter = key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.18)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? primaryColor : cardBorderColor,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: isSelected ? primaryColor : Colors.white70,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.amiri(
                                          fontSize: sSmall,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? primaryColor : textColor,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
              // ── شريط «إلغاء/تطبيق» ثابت أسفل النافذة ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSheetActionsBar(
                  onCancel: () => Navigator.pop(context),
                  onApply: () {
                    _applyReadingSettings(
                      fontSize: draftSize,
                      fontWeight: draftWeight,
                      readingMode: draftMode,
                      brightness: draftBrightness,
                      reciter: draftReciter,
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// شريط «إلغاء / تطبيق» المشترك بين نوافذ القرآن — لا يُحفظ شيء قبل «تطبيق».
  Widget _buildSheetActionsBar({
    required VoidCallback onCancel,
    required VoidCallback onApply,
    Color background = const Color(0xFF0F172A),
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.20), width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.10),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withOpacity(0.30)),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton(
                onPressed: onApply,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'تطبيق',
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// معاينة قراءة قبل التطبيق: نفس الخلفية واللون والخط والحجم والسماكة
  /// والإضاءة التي سيصبح عليها النص — بلا أي حفظ.
  Widget _buildReadingPreview({
    required double fontSize,
    required String fontWeightMode,
    required String readingMode,
    required double brightness,
  }) {
    final Color bg = _bgColorOf(readingMode);
    final Color fg = _textColorOf(readingMode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.25), width: 1.2),
      ),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              'وَلَقَدْ يَسَّرْنَا ٱلْقُرْءَانَ لِلذِّكْرِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: fontSize,
                fontWeight: _weightOf(fontWeightMode),
                color: fg,
                height: 2.0,
              ),
            ),
          ),
          // خفوت الإضاءة كما في شاشة القراءة (بلا اعتراض للمس)
          if (brightness < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity((1.0 - brightness) * 0.75),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// يحفظ إعدادات القراءة الممسوكة في نافذة الإعدادات — يُستدعى عند «تطبيق» فقط.
  void _applyReadingSettings({
    required double fontSize,
    required String fontWeight,
    required String readingMode,
    required double brightness,
    required String reciter,
  }) {
    final double size = fontSize.clamp(16.0, 42.0);
    final double dim = brightness.clamp(0.25, 1.0);
    final settings = sl<QuranSettingsDataSource>();
    setState(() {
      _fontSize = size;
      _fontWeightMode = fontWeight;
      _readingMode = readingMode;
      _brightness = dim;
      _selectedReciter = reciter;
    });
    settings.setFontSize(size);
    settings.setFontWeight(fontWeight);
    settings.setReadingMode(readingMode);
    settings.setBrightness(dim);
    settings.setReciter(reciter);
  }

  Widget _buildWeightOption({
    required String label,
    required String value,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final bool isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.20)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white30,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.amiri(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String label,
    required String mode,
    required IconData icon,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final bool isSelected = selected == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.20)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white30,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Icon(icon, size: 22, color: isSelected ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  String _toArabicNumbers(String n) {
    return n.replaceAll('0', '٠').replaceAll('1', '١').replaceAll('2', '٢').replaceAll('3', '٣').replaceAll('4', '٤').replaceAll('5', '٥').replaceAll('6', '٦').replaceAll('7', '٧').replaceAll('8', '٨').replaceAll('9', '٩');
  }
}

/// عنصر فاصل يُعرض في نهاية الجزء (عند تغيّر رقم الجزء بين آيتين متتاليتين)
class _JuzMarkerItem {
  final int juzNumber;
  const _JuzMarkerItem(this.juzNumber);
}

// ── زخرفة نجمة إسلامية صغيرة على جانبين اسم السورة ──
class _IslamicOrnamentDotPainter extends CustomPainter {
  final Color color;
  _IslamicOrnamentDotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2 - 1;

    final Paint fill = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final Paint innerStroke = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final Paint dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // نجمة ثمانية صغيرة
    final Path star = Path();
    const int pts = 8;
    final double iR = r * 0.55;
    for (int i = 0; i < pts * 2; i++) {
      final double rad = (i % 2 == 0) ? r : iR;
      final double angle = (i * math.pi / pts) - (math.pi / 2);
      final double x = cx + rad * math.cos(angle);
      final double y = cy + rad * math.sin(angle);
      if (i == 0) star.moveTo(x, y); else star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, fill);
    canvas.drawPath(star, stroke);

    // دائرة داخلية
    canvas.drawCircle(Offset(cx, cy), r * 0.38, innerStroke);

    // نقطة مركزية
    canvas.drawCircle(Offset(cx, cy), 2.0, dot);
  }

  @override
  bool shouldRepaint(covariant _IslamicOrnamentDotPainter old) => old.color != color;
}

// ── خط زخرفي أفقي بين الاسم والتفاصيل ──
class _IslamicLinePainter extends CustomPainter {
  final Color color;
  _IslamicLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double w = size.width;

    final Paint linePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // الخط الأفقي
    canvas.drawLine(Offset(0, cy), Offset(w, cy), linePaint);

    // نقطة في كل طرف
    canvas.drawCircle(Offset(4, cy), 1.8, dotPaint);
    canvas.drawCircle(Offset(w - 4, cy), 1.8, dotPaint);

    // نجمة صغيرة في الوسط
    final double cx2 = w / 2;
    final double mr = 3.5;
    final double miR = 2.0;
    final Path miniStar = Path();
    for (int i = 0; i < 16; i++) {
      final double rad = (i % 2 == 0) ? mr : miR;
      final double angle = (i * math.pi / 8) - (math.pi / 2);
      final double x = cx2 + rad * math.cos(angle);
      final double y = cy + rad * math.sin(angle);
      if (i == 0) miniStar.moveTo(x, y); else miniStar.lineTo(x, y);
    }
    miniStar.close();
    canvas.drawPath(miniStar, Paint()..color = color.withOpacity(0.5));
    canvas.drawPath(miniStar, Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(covariant _IslamicLinePainter old) => old.color != color;
}

class _IslamicAyahOrnamentPainter extends CustomPainter {
  final Color goldColor;
  final Color innerBg;
  final bool isDark;

  _IslamicAyahOrnamentPainter({
    required this.goldColor,
    required this.innerBg,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(size.width, size.height) / 2;

    final Paint bgPaint = Paint()
      ..color = innerBg
      ..style = PaintingStyle.fill;

    final Paint goldFill = Paint()
      ..color = goldColor.withOpacity(isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.fill;

    final Paint outerStroke = Paint()
      ..color = goldColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final Paint innerStroke = Paint()
      ..color = goldColor.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // رسم النجمة الثمانية الإسلامية (Islamic 8-pointed star / Rosette)
    final Path starPath = Path();
    const int points = 8;
    final double outerR = radius - 0.8;
    final double innerR = radius * 0.76;

    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? outerR : innerR;
      final double angle = (i * math.pi / points) - (math.pi / 2);
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    canvas.drawPath(starPath, bgPaint);
    canvas.drawPath(starPath, goldFill);
    canvas.drawPath(starPath, outerStroke);

    // دائرة داخلية ناعمة تحيط برقم الآية
    final double innerCircleR = radius * 0.62;
    canvas.drawCircle(Offset(cx, cy), innerCircleR, innerStroke);

    // نقاط زخرفية في أركان النجمة
    final Paint dotPaint = Paint()
      ..color = goldColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = (i * math.pi / 2) + (math.pi / 4);
      final double dotX = cx + (radius * 0.86) * math.cos(angle);
      final double dotY = cy + (radius * 0.86) * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 0.9, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicAyahOrnamentPainter oldDelegate) {
    return oldDelegate.goldColor != goldColor ||
        oldDelegate.innerBg != innerBg ||
        oldDelegate.isDark != isDark;
  }
}

// ── زخرفة الفاصل بين السور ── Islamic Surah Separator Ornament ─────────────
class _IslamicSeparatorOrnamentPainter extends CustomPainter {
  final Color goldColor;
  final bool isDark;

  _IslamicSeparatorOrnamentPainter({required this.goldColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2 - 1;

    final Paint outerStroke = Paint()
      ..color = goldColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Paint innerStroke = Paint()
      ..color = goldColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final Paint fillPaint = Paint()
      ..color = goldColor.withOpacity(isDark ? 0.22 : 0.12)
      ..style = PaintingStyle.fill;

    final Paint dotPaint = Paint()
      ..color = goldColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // 1. نجمة ثمانية الأوجه متناسقة (Islamic 8-pointed star)
    final Path starPath = Path();
    const int points = 8;
    final double innerR = r * 0.58;
    for (int i = 0; i < points * 2; i++) {
      final double rad = (i % 2 == 0) ? r : innerR;
      final double angle = (i * math.pi / points) - (math.pi / 2);
      final double x = cx + rad * math.cos(angle);
      final double y = cy + rad * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    canvas.drawPath(starPath, fillPaint);
    canvas.drawPath(starPath, outerStroke);

    // 2. دائرة زخرفية وسطية ناعمة
    final double circleR = r * 0.45;
    canvas.drawCircle(Offset(cx, cy), circleR, innerStroke);

    // 3. جوهرة مركزية (Central Gold Jewel Dot)
    canvas.drawCircle(Offset(cx, cy), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _IslamicSeparatorOrnamentPainter oldDelegate) {
    return oldDelegate.goldColor != goldColor || oldDelegate.isDark != isDark;
  }
}

// ── Tafsir Dialog Widget ──────────────────────────────────────

class _TafsirDialogWidget extends StatefulWidget {
  final Ayah ayah;
  final Color bgColor, cardBg, textColor, goldColor;
  final VoidCallback? onSaveBookmark;
  final VoidCallback? onPlayAudio;

  const _TafsirDialogWidget({
    required this.ayah,
    required this.bgColor,
    required this.cardBg,
    required this.textColor,
    required this.goldColor,
    this.onSaveBookmark,
    this.onPlayAudio,
  });

  @override
  State<_TafsirDialogWidget> createState() => _TafsirDialogWidgetState();
}

class _TafsirDialogWidgetState extends State<_TafsirDialogWidget> {
  String tafsirText = "";
  bool loadingTafsir = true;

  @override
  void initState() {
    super.initState();
    sl<QuranLocalDataSource>()
        .fetchTafsir(widget.ayah.surahId, widget.ayah.ayahNumber, "ar.muyassar")
        .then((text) {
      if (mounted) {
        setState(() {
          tafsirText = text;
          loadingTafsir = false;
        });
      }
    });
  }

  void _copyAyahAndTafsir() {
    final ayahText = widget.ayah.textUthmani.isNotEmpty ? widget.ayah.textUthmani : widget.ayah.text;
    final fullText = "﴿ $ayahText ﴾ [الآية ${widget.ayah.ayahNumber}]\n\nالتفسير الميسر:\n$tafsirText";
    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "تم نسخ الآية وتفسيرها بنجاح",
          textAlign: TextAlign.center,
          style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: GlassNoticeSpec.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ayah = widget.ayah;
    final cardBg = widget.cardBg;
    final textColor = widget.textColor;
    final goldColor = widget.goldColor;
    final bgColor = widget.bgColor;
    final ayahText = ayah.textUthmani.isNotEmpty ? ayah.textUthmani : ayah.text;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: goldColor.withValues(alpha: 0.20), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(color: goldColor.withValues(alpha: 0.20), width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: goldColor.withValues(alpha: 0.75), size: 20),
                    tooltip: "إغلاق",
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "تفسير الآية",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: goldColor.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "الآية  ${ayah.ayahNumber}  •  سورة ${ayah.surahId}",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "نسخ الآية والتفسير",
                        onPressed: _copyAyahAndTafsir,
                        icon: Icon(Icons.copy_rounded, color: goldColor.withValues(alpha: 0.75), size: 19),
                      ),
                      if (widget.onPlayAudio != null)
                        IconButton(
                          tooltip: "استماع للآية",
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onPlayAudio!();
                          },
                          icon: Icon(Icons.volume_up_rounded, color: goldColor.withValues(alpha: 0.75), size: 20),
                        ),
                      if (widget.onSaveBookmark != null)
                        IconButton(
                          tooltip: "حفظ موضع القراءة هنا",
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSaveBookmark!();
                          },
                          icon: Icon(Icons.bookmark_add_rounded, color: goldColor.withValues(alpha: 0.75), size: 20),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── نص الآية الكريمة ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: goldColor.withValues(alpha: 0.30),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_stories_rounded, size: 13, color: goldColor.withValues(alpha: 0.7)),
                              const SizedBox(width: 5),
                              Text(
                                "نص الآية الكريمة",
                                style: GoogleFonts.amiri(
                                  fontSize: 13,
                                  color: goldColor.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                            color: goldColor.withValues(alpha: 0.18),
                            thickness: 0.7,
                            height: 14,
                          ),
                          Text(
                            "﴿  $ayahText  ﴾",
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                              height: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── قسم التفسير ──
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: goldColor.withValues(alpha: 0.13),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.08),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              border: Border(
                                bottom: BorderSide(color: goldColor.withValues(alpha: 0.15), width: 0.8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book_rounded, size: 15, color: goldColor),
                                const SizedBox(width: 8),
                                Text(
                                  "التفسير الميسر",
                                  style: GoogleFonts.amiri(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: goldColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                            child: loadingTafsir
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                            color: goldColor,
                                            strokeWidth: 2.5,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "جاري تحميل التفسير...",
                                            style: GoogleFonts.amiri(
                                              fontSize: 14,
                                              color: textColor.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : tafsirText.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            children: [
                                              Icon(Icons.info_outline_rounded,
                                                  color: goldColor.withValues(alpha: 0.5), size: 32),
                                              const SizedBox(height: 8),
                                              Text(
                                                "لا يوجد تفسير متاح لهذه الآية",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.amiri(
                                                  fontSize: 15,
                                                  color: textColor.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Text(
                                        tafsirText,
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                        softWrap: true,
                                        style: GoogleFonts.amiri(
                                          fontSize: 18,
                                          height: 2.1,
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


