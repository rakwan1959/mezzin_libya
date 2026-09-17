import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/quran_bloc.dart';
import '../bloc/quran_event.dart';
import '../bloc/quran_state.dart';
import 'quran_view_page.dart';
import 'bookmarks_page.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../data/datasources/quran_local_data_source.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/quran_settings_data_source.dart';
import '../../../voice/voice_assistant_sheet.dart';
import '../../../voice/voice_service.dart';
import '../widgets/islamic_surah_name.dart';
import '../../domain/entities/surah.dart';
import '../../data/constants/quran_divisions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/config/header_font_prefs.dart';
import '../../../../core/config/quran_dark_prefs.dart';
import 'quran_offline_manager_screen.dart';

const Color _appGold = Colors.white;
// لمسة ذهبية خفيفة لفواصل الوضع الليلي
const Color _lightGold = Color(0xFFDFBA6B);

class SurahListPage extends StatefulWidget {
  const SurahListPage({super.key});

  @override
  State<SurahListPage> createState() => _SurahListPageState();
}

class _SurahListPageState extends State<SurahListPage> {
  bool _isSearching = false;
  // false = قائمة السور، true = قائمة أجزاء القرآن الكريم
  bool _showJuzView = false;
  final TextEditingController _searchController = TextEditingController();
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    // الافتراضي عند أول تثبيت: الوضع الليلي (أسود) كما في
    // [QuranSettingsDataSource.getReadingMode]. وإن اختار المستخدم الوضع
    // النهاري سابقاً يُحترم اختياره فيفتح على ما اختاره — إلا إن كان خيار
    // «القرآن: الوضع الليلي دائماً» مفعّلاً من الإعدادات، فالشاشة ليليّة في كل
    // تشغيل (انظر [QuranDarkPrefs]).
    _isDarkMode = sl<QuranSettingsDataSource>().getReadingMode() != "white";
    // إن فُعّل الخيار من الإعدادات والشاشة مفتوحة، تتحوّل إلى الليلي في الحال.
    QuranDarkPrefs.alwaysDark.addListener(_onAlwaysDarkChanged);
    _refreshSurahs();
  }

  /// يتبع تغيير خيار «الوضع الليلي دائماً» أثناء عمل الشاشة.
  void _onAlwaysDarkChanged() {
    if (!mounted || !QuranDarkPrefs.enabled || _isDarkMode) return;
    setState(() => _isDarkMode = true);
  }

  @override
  void dispose() {
    QuranDarkPrefs.alwaysDark.removeListener(_onAlwaysDarkChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSurahs() {
    context.read<QuranBloc>().add(LoadSurahsEvent());
  }

  Future<void> _navigateToSurah(dynamic surah, {int? ayahNumber}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuranViewPage(surah: surah, initialAyah: ayahNumber)),
    );
    if (mounted) {
      setState(() {});
      _refreshSurahs();
    }
  }

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

  /// نافذة **خطوط القرآن الكريم** بنمط «معاينة قبل التطبيق» نفسه: اختيار خط
  /// يصير «مسودة» تظهر في المعاينة (الخط وحجم القراءة المحفوظ)، ولا يُحفظ إلا
  /// بالضغط على «تطبيق». و«إلغاء» يُتلف المسودة.
  void _showFontSelectorSheet(BuildContext context) {
    final settings = sl<QuranSettingsDataSource>();
    // التقاط الـmessenger قبل النافذة ليُستعمل بعد إغلاقها بأمان.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // حجم القراءة المحفوظ — تُعرض به المعاينة كي يرى المستخدم الخط وحجمه.
    final double readingSize = settings.getFontSize();
    // مسودة خارج الـbuilder حتى تبقى بين إعادات البناء.
    String draftFont = settings.getFontFamily();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        // قائمة خطوط القرآن الكريم: خلفية داكنة ثابتة وكل الخطوط باللون الأبيض دائماً
        final Color sheetBg = const Color(0xFF0B0B0F);
        final Color textColor = Colors.white;
        final Color goldColor = Colors.white;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
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
                        Expanded(
                          child: Row(
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
                                  color: goldColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  "خطوط القرآن الكريم",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.amiri(
                                    fontSize: HeaderFontPrefs.sized(18.0),
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                  // ── معاينة قبل التطبيق: الخط المسودّة بحجم القراءة ──
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
                              'حجم القراءة ${readingSize.toInt()}',
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
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            'وَلَقَدْ يَسَّرْنَا ٱلْقُرْءَانَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: draftFont,
                              fontSize: readingSize,
                              color: textColor,
                              height: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'الخط: ${_quranFonts[draftFont] ?? ''} — لا يُطبَّق شيء قبل «تطبيق»',
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
                        final String name = _quranFonts[key]!;
                        // «مختار» هنا = المسودة، لا المحفوظ: لا يُطبَّق إلا بـ«تطبيق»
                        final bool isSelected = draftFont == key;

                        return GestureDetector(
                          // الاختيار يصير «مسودة» تظهر في المعاينة — بلا حفظ
                          onTap: () => setSheetState(() => draftFont = key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? goldColor.withOpacity(0.20)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? goldColor : Colors.white.withOpacity(0.12),
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
                                          color: isSelected ? goldColor : textColor,
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B0B0F),
                      border: Border(top: BorderSide(color: Colors.white24, width: 1.0)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white10,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.amiri(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                final String applied = draftFont;
                                final String appliedName =
                                    _quranFonts[applied] ?? '';
                                settings.setFontFamily(applied);
                                Navigator.pop(ctx);
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم تطبيق خط: $appliedName على كافة سور القرآن',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color titleColor = _isDarkMode ? Colors.white : Colors.black;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // الوضع الليلي أسود فعلاً (لا كحلي): مطابقةً لخلفية التطبيق
                // السوداء في الوضع الليلي.
                colors: _isDarkMode
                    ? const [Color(0xFF000000), Color(0xFF050507)]
                    : const [Color(0xFFF8FAFC), Color(0xFFE9EEF4)],
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _isDarkMode ? const Color(0xFF000000) : Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF000000) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.14),
                  width: 1.0,
                ),
              ),
            ),
          ),
          leading: _appBarIcon(
            Icons.arrow_back_ios_new_rounded,
            tooltip: 'رجوع',
            onPressed: () => Navigator.pop(context),
          ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: titleColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "ابحث عن سورة أو آية...",
                    hintStyle: TextStyle(
                      color: _isDarkMode ? Colors.white60 : Colors.black54,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (query) {
                    context.read<QuranBloc>().add(SearchQuranEvent(query));
                  },
                )
              // عنوان الشاشة: «سور القرآن الكريم» في قائمة السور، و«أجزاء
              // القرآن الكريم» عند عرض الأجزاء — فلم تبقَ بطاقة التبديل
              // المقسمة أعلى القائمة.
              : Text(
                  _showJuzView ? 'أجزاء القرآن الكريم' : 'سور القرآن الكريم',
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
          centerTitle: true,
          actions: _isSearching
              ? [
                  _appBarIcon(
                    Icons.close_rounded,
                    tooltip: "إلغاء البحث",
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                        _refreshSurahs();
                      });
                    },
                  ),
                ]
              : [
                  _appBarIcon(
                    _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    tooltip: _isDarkMode ? "الوضع النهاري" : "الوضع الليلي",
                    onPressed: () {
                      setState(() {
                        _isDarkMode = !_isDarkMode;
                        sl<QuranSettingsDataSource>().setReadingMode(
                          _isDarkMode ? "black" : "white",
                        );
                      });
                    },
                  ),
                  _appBarIcon(
                    Icons.bookmark_rounded,
                    tooltip: "العلامات المرجعية المحفوظة",
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookmarksPage()),
                      );
                      if (mounted) {
                        setState(() {});
                        _refreshSurahs();
                      }
                    },
                  ),
                  _appBarIcon(
                    Icons.cloud_download_rounded,
                    tooltip: "تحميل القرآن والتلاوات بدون إنترنت",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuranOfflineManagerScreen(),
                        ),
                      );
                    },
                  ),
                  _appBarIcon(
                    Icons.font_download_rounded,
                    tooltip: "خطوط القرآن الكريم",
                    onPressed: () => _showFontSelectorSheet(context),
                  ),
                  _appBarIcon(
                    Icons.search_rounded,
                    tooltip: "بحث",
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                  // زر واحد للتبديل بين السور والأجزاء — بدل البطاقة المقسمة
                  // «سور القرآن الكريم | أجزاء القرآن الكريم» التي كانت أعلى
                  // القائمة، فتبقى الشاشة **قائمة سور فقط** (كل سورة على حدة)
                  // ويبقى الوصول إلى الأجزاء متاحاً بضغطة واحدة.
                  _appBarIcon(
                    _showJuzView
                        ? Icons.menu_book_rounded
                        : Icons.auto_stories_rounded,
                    tooltip: _showJuzView
                        ? "العودة إلى قائمة السور"
                        : "أجزاء القرآن الكريم",
                    onPressed: () =>
                        setState(() => _showJuzView = !_showJuzView),
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        floatingActionButton: _isSearching ? null : Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openVoiceAssistant(context),
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: BlocBuilder<QuranBloc, QuranState>(
          builder: (context, state) {
            if (state is SurahsLoaded) {
              return Column(
                children: [
                  _buildSyncStatus(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      child: _showJuzView
                          ? _buildJuzList(state.surahs)
                          : _buildSurahList(state.surahs),
                    ),
                  ),
                ],
              );
            } else if (state is SearchResultsLoaded) {
              return Column(
                children: [
                  if (state.filteredSurahs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text("السور المطابقة", 
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, 
                          color: _isDarkMode ? _appGold : Colors.black, fontSize: HeaderFontPrefs.sized(16.0))),
                    ),
                    SizedBox(
                      height: 120, 
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildSurahList(state.filteredSurahs),
                      ),
                    ),
                    Divider(color: _isDarkMode ? _appGold.withOpacity(0.2) : Colors.black.withValues(alpha: 0.15)),
                  ],
                  Expanded(child: _buildSearchResults(state.results, state.filteredSurahs)),
                ],
              );
            } else if (state is QuranError) {
              return _buildErrorState(state.message);
            }
            return Center(child: CircularProgressIndicator(color: _isDarkMode ? _appGold : Colors.black));
          },
        ),
      ),
    ],
  );
}

  /// زر شريط علوي: يحافظ على الوضع الليلي كما هو، ويعطي الوضع النهاري لمسة حديثة
  /// (زر زجاجي أبيض بإطار ذهبي وظل ناعم)
  Widget _appBarIcon(
    IconData icon, {
    required String tooltip,
    required VoidCallback onPressed,
    double size = 20,
  }) {
    if (_isDarkMode) {
      return IconButton(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(icon, color: Colors.white, size: size),
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.black, size: size),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return ValueListenableBuilder<String>(
      valueListenable: QuranLocalDataSourceImpl.syncStatus,
      builder: (context, status, child) {
        if (status.isEmpty || status.contains("جاهز")) return const SizedBox();
        final Color accent = _isDarkMode ? _appGold : Colors.black;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            border: Border(bottom: BorderSide(color: accent.withOpacity(0.2))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                height: 14, width: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: GoogleFonts.tajawal(
                    fontSize: 11, color: accent, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildSurahList(surahs) {
    final Color textColor =
        _isDarkMode ? Colors.white : Colors.black;
    final Color surahNumberBg = _isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.05);
    final Color surahNumberBorder = _isDarkMode
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.black;
    final Color surahNumberText =
        _isDarkMode ? Colors.white : Colors.black;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 100),
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        // قائمة السور وحدها: لا بطاقة تبديل أعلى القائمة — سورة الفاتحة أولاً
        final surah = surahs[index];
        final String revelationText = surah.revelationType == 'مكية' ||
                surah.revelationType == 'Meccan'
            ? 'سورة مكية'
            : 'سورة مدنية';

        final Color dividerColor = _isDarkMode
            ? _lightGold.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.20);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: AuroraGlassCard(
                borderRadius: BorderRadius.circular(14),
                blur: 16,
                gradientColors: _isDarkMode
                    ? null
                    : [
                        Colors.white.withValues(alpha: 0.90),
                        Colors.white.withValues(alpha: 0.74),
                      ],
                border: _isDarkMode
                    ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.0)
                    : Border.all(color: Colors.black, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                onTap: () => _navigateToSurah(surah),
                child: Row(
                  children: [
                    // دائرة رقم السورة بتصميم زجاجي وإطار محدد
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: surahNumberBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: surahNumberBorder, width: _isDarkMode ? 1.25 : 1.4),
                        boxShadow: _isDarkMode
                            ? [
                                BoxShadow(
                                  color: _appGold.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          surah.id.toString(),
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: surahNumberText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // اسم السورة وتفاصيلها
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IslamicSurahName(
                            surahName: surah.name,
                            style: GoogleFonts.amiri(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            ornamentColor: _isDarkMode
                                ? const Color(0xFFEDEDED).withValues(alpha: 0.85)
                                : Colors.black.withValues(alpha: 0.80),
                            ornamentWidth: 18,
                            ornamentHeight: 10,
                            mainAxisAlignment: MainAxisAlignment.start,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(5),
                                  border: !_isDarkMode
                                      ? Border.all(color: Colors.black.withValues(alpha: 0.30), width: 1.0)
                                      : null,
                                ),
                                child: Text(
                                  revelationText,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
            // عدد الآيات
                              Text(
                                "${surah.ayahsCount} آية",
                                style: GoogleFonts.tajawal(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white70 : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // سهم الانتقال الزجاجي
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: !_isDarkMode
                            ? Border.all(color: Colors.black.withValues(alpha: 0.16), width: 0.8)
                            : null,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: _isDarkMode ? Colors.white70 : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // خط فاصل ذهبي بين السور
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      dividerColor,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// قائمة أجزاء القرآن الكريم الثلاثين
  Widget _buildJuzList(List surahs) {
    final juzList = QuranDivisions.juzList;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 100),
      itemCount: juzList.length,
      itemBuilder: (context, index) {
        final juzIndex = index;
        final juz = juzList[juzIndex];
        // الجزء التالي لتحديد نهاية الجزء الحالي (الآية التي قبله)
        final nextJuz = juzIndex < juzList.length - 1 ? juzList[juzIndex + 1] : null;
        return _buildJuzItem(juz, nextJuz, surahs);
      },
    );
  }

  /// اسم السورة من القائمة المحمّلة (مع إضافة كلمة «سورة»)
  String _surahNameById(List surahs, int surahId) {
    try {
      final matched = surahs.firstWhere((s) => s.id == surahId);
      final String name = (matched as Surah).nameArabic;
      if (name.isNotEmpty) return "سورة $name";
    } catch (_) {}
    return "سورة $surahId";
  }

  /// عدد آيات السورة من القائمة المحمّلة
  int _surahAyahCount(List surahs, int surahId) {
    try {
      final matched = surahs.firstWhere((s) => s.id == surahId);
      final int count = (matched as Surah).ayahsCount;
      return count > 0 ? count : 1;
    } catch (_) {
      return 1;
    }
  }

  Widget _buildJuzItem(Map<String, dynamic> juz, Map<String, dynamic>? nextJuz, List surahs) {
    final int juzId = juz['id'] as int;
    final int startSurahId = juz['start_surah'] as int;
    final int startAyah = juz['start_ayah'] as int;

    // نهاية الجزء = الآية الأخيرة التي تسبق بداية الجزء التالي
    final int endSurahId;
    final int endAyah;
    if (nextJuz == null) {
      // الجزء الثلاثون ينتهي بنهاية المصحف: سورة الناس آية 6
      endSurahId = 114;
      endAyah = 6;
    } else {
      final int nextStartSurah = nextJuz['start_surah'] as int;
      final int nextStartAyah = nextJuz['start_ayah'] as int;
      if (nextStartAyah > 1) {
        endSurahId = nextStartSurah;
        endAyah = nextStartAyah - 1;
      } else {
        // الجزء التالي يبدأ من سورة جديدة: نهاية الجزء = آخر آية في السورة السابقة
        endSurahId = nextStartSurah - 1;
        endAyah = _surahAyahCount(surahs, endSurahId);
      }
    }

    final String startSurahName = _surahNameById(surahs, startSurahId);
    final String endSurahName = _surahNameById(surahs, endSurahId);

    // كل نصوص الجزء بيضاء (بدون اللون الأصفر)
    final Color juzTextColor = _isDarkMode ? Colors.white : Colors.black;
    final Color numberBg = _isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.05);
    final Color numberBorder = _isDarkMode
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuranViewPage(
                  juzNumber: juzId,
                  initialSurahId: startSurahId,
                  initialAyah: startAyah,
                ),
              ),
            );
          },
          child: AuroraGlassCard(
            borderRadius: BorderRadius.circular(14),
            blur: 16,
            gradientColors: _isDarkMode
                ? null
                : [
                    Colors.white.withValues(alpha: 0.90),
                    Colors.white.withValues(alpha: 0.74),
                  ],
            border: _isDarkMode
                ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.0)
                : Border.all(color: Colors.black, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                // دائرة رقم الجزء بأرقام إفرنجية
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: numberBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: numberBorder,
                      width: _isDarkMode ? 1.25 : 1.4,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$juzId',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: juzTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // عنوان الجزء ونطاقه الكامل باللون الأبيض
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الجزء $juzId',
                        style: GoogleFonts.amiri(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: juzTextColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'من آية $startAyah $startSurahName إلى آية $endAyah $endSurahName',
                        style: GoogleFonts.tajawal(
                          fontSize: 10.5,
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(results, surahs) {
    if (results.isEmpty && (surahs == null || surahs.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: _isDarkMode ? _appGold.withOpacity(0.4) : Colors.black.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text("لا توجد نتائج", style: GoogleFonts.tajawal(color: _isDarkMode ? Colors.white38 : Colors.black54, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: results.length,
      separatorBuilder: (context, index) => Divider(color: _appGold.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final ayah = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode ? _appGold.withOpacity(0.08) : Colors.black.withValues(alpha: 0.15),
            ),
          ),
          child: ListTile(
            title: Text(
              ayah.textUthmani,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: 18,
                height: 1.8,
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              "سورة ${ayah.surahId} - آية ${ayah.ayahNumber}",
              style: GoogleFonts.tajawal(
                fontSize: 11,
                color: _isDarkMode ? _appGold.withOpacity(0.5) : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            onTap: () {
               final qState = context.read<QuranBloc>().state;
               if (qState is SurahsLoaded) {
                  final s = qState.surahs.firstWhere((s) => s.id == ayah.surahId, orElse: () => qState.surahs.first);
                  _navigateToSurah(s);
               }
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: _appGold.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.tajawal(color: Colors.white60)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _appGold.withOpacity(0.15),
              foregroundColor: _appGold,
              side: BorderSide(color: _appGold.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _refreshSurahs(),
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  void _openVoiceAssistant(BuildContext context) async {
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
      if (result.type == VoiceCommandType.playSurah || result.type == VoiceCommandType.playAyah) {
          final qState = context.read<QuranBloc>().state;
          if (qState is SurahsLoaded) {
            dynamic matched;
            
            if (result.surahId != null) {
               try {
                 matched = qState.surahs.firstWhere((s) => s.id == result.surahId);
               } catch (_) {
                 matched = null;
               }
            }

            if (matched != null) {
              _navigateToSurah(matched, ayahNumber: result.ayahNumber);
            }
          }
      } else if (result.type == VoiceCommandType.webSearch) {
          final url = Uri.parse("https://www.google.com/search?q=${Uri.encodeComponent(result.payload ?? '')}");
          launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (result.type == VoiceCommandType.chatGpt) {
          final url = Uri.parse("https://chatgpt.com/?q=${Uri.encodeComponent(result.payload ?? '')}");
          launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }
}
