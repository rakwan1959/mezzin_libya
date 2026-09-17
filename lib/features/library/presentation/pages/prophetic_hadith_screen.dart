import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/hadith_database_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/glass_scaffold.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  شاشة الأحاديث النبوية — لوحة **أبيض أحادي** بالكامل.
///
///  لا يوجد فيها أي لون صفراء/ذهبي ولا أي تدرّج ملوّن: كل النصوص والأيقونات
///  والحدود أبيض بدرجات شفافية فقط، والزجاج رمادي محايد (بلا كحلي ولا رمادي
///  أزرق). والشرائح (الكاردات الصغيرة) تنمو مع نصها فلا تُقتطع أبداً.
/// ════════════════════════════════════════════════════════════════════════════
class PropheticHadithScreen extends StatefulWidget {
  const PropheticHadithScreen({super.key});

  @override
  State<PropheticHadithScreen> createState() => _PropheticHadithScreenState();
}

class _PropheticHadithScreenState extends State<PropheticHadithScreen> {
  final ScrollController _scrollController = ScrollController();

  List<HadithItem> _allHadiths = [];
  List<HadithItem> _filteredHadiths = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0; // 0: الكل, 1: عامة, 2: رمضان
  double _fontSize = 18.0;
  HadithItem? _dailyHadith;

  // ── لوحة أبيض أحادي (Monochromatic White) ────────────────────────────────
  /// حبر أساسي — النص الرئيسي.
  static const Color _ink = Color(0xFFFFFFFF);

  /// حبر ثانوي — العناوين الفرعية والتفاصيل.
  static const Color _inkSoft = Color(0xD9FFFFFF); // 85%

  /// حبر خافت — الأرقام والوسوم.
  static const Color _inkMuted = Color(0x99FFFFFF); // 60%

  /// حدّ شعرة أبيض على الزجاج.
  static const Color _hairline = Color(0x40FFFFFF); // 25%

  /// سطح الكارد المميّز (رمادي محايد غامق — بلا أي مسحة لونية).
  static const Color _featuredTop = Color(0xFF1B1B1F);
  static const Color _featuredBottom = Color(0xFF0A0A0C);

  /// سطح الكارد العادي.
  static const Color _cardTop = Color(0xFF17171B);
  static const Color _cardBottom = Color(0xFF0B0B0D);

  final List<String> _categories = [
    'الكل',
    'أحاديث عامة',
    'فضائل رمضان',
  ];

  /// خط شريحة «الكل» في الترويسة: أصغر بمقدار واحد عن شرائح التصنيف (12 → 11).
  static const double _headerChipFontSize = 11;

  /// مقدار تصغير نص الحديث في الكارد الصغير عن الحجم المختار.
  static const double _smallCardQuoteDelta = 2;

  /// حدود حجم الخط المتاحة في نافذة التغيير.
  static const double _minFontSize = 14.0;
  static const double _maxFontSize = 28.0;

  /// مدة انتقال حجم الخط داخل الكاردات (وفي المعاينة) — بلا قفزة مفاجئة.
  static const Duration _quoteFontTransition = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // تحميل حجم الخط المفضل
    _fontSize = prefs.getDouble('hadith_font_size') ?? 18.0;

    // تحميل الأحاديث
    final hadiths = await HadithDatabaseService.instance.getAllHadiths();
    final daily = await HadithDatabaseService.instance.getDailyHadith();

    if (mounted) {
      setState(() {
        _allHadiths = hadiths;
        _dailyHadith = daily;
        _isLoading = false;
        _filterHadiths();
      });
    }
  }

  Future<void> _saveFontSize(double size) async {
    final double clamped = size.clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadith_font_size', clamped);
  }

  /// نسبة خط الكارد الصغير إلى الكارد الكبير — تُعرض في نافذة الحجم.
  int _smallCardPercentOf(double base) {
    if (base <= 0) return 0;
    return ((base - _smallCardQuoteDelta) / base * 100).round();
  }

  void _filterHadiths() {
    List<HadithItem> result = [];

    // تصفية حسب التبويب
    if (_selectedCategoryIndex == 0) {
      result = List.from(_allHadiths);
    } else if (_selectedCategoryIndex == 1) {
      result = _allHadiths.where((h) => h.category.contains('عامة')).toList();
    } else if (_selectedCategoryIndex == 2) {
      result = _allHadiths.where((h) => h.category.contains('رمضان')).toList();
    }

    setState(() {
      _filteredHadiths = result;
    });
  }

  void _copyHadith(HadithItem hadith) {
    HapticFeedback.mediumImpact();
    final buffer = StringBuffer();
    if (hadith.title.isNotEmpty) {
      buffer.writeln(hadith.title);
    }
    buffer.writeln('«${hadith.text}»');
    if (hadith.narrator.isNotEmpty) {
      buffer.writeln('المصدر: ${hadith.narrator}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الحديث بنجاح',
          textAlign: TextAlign.center,
          style: GoogleFonts.amiri(
            fontWeight: FontWeight.bold,
            color: _ink,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF14141A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _hairline, width: 1.0),
        ),
      ),
    );
  }

  /// حوار تغيير حجم الخط.
  ///
  /// - **مسودة محلية**: لا يُحفظ شيء في التفضيلات ولا تتغير الكاردات خلف
  ///   النافذة إلا بالضغط على «حفظ».
  /// - **معاينة مباشرة**: نص حديث بخط الكارد الكبير، وآخر بخط الكارد الصغير
  ///   (الحجم المختار ‎- [_smallCardQuoteDelta]) — قبل الحفظ.
  /// - **نسبة واضحة**: حجم نص الكارد الصغير معروض مع نسبته المئوية من الكارد
  ///   الكبير.
  void _showFontSizeDialog() {
    const String sample =
        'مَنْ عَمِلَ عَمَلًا لَيْسَ عَلَيْهِ أَمْرُنَا فَهُوَ رَدٌّ';
    // مسودة **خارج** الـbuilder حتى تبقى بين إعادات البناء.
    double draft = _fontSize;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double smallSize = draft - _smallCardQuoteDelta;
          final int smallPercent = _smallCardPercentOf(draft);
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0F).withValues(alpha: 0.97),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: const Border(
                top: BorderSide(color: _hairline, width: 1.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _inkMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'حجم خط الأحاديث',
                      style: GoogleFonts.amiri(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معاينة مباشرة — لا يُحفظ التغيير إلا بالضغط على «حفظ»',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: 11.5,
                        color: _inkMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // نسبة واضحة: حجم الكارد الصغير مقابل الكبير
                    Row(
                      children: [
                        Expanded(
                          child: _buildSizePill(
                            label: 'الكارد الكبير',
                            value: draft,
                            note: 'الحجم المختار',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSizePill(
                            label: 'الكارد الصغير',
                            value: smallSize,
                            note: '$smallPercent٪ من الكارد الكبير',
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewLabel('معاينة الكارد الكبير'),
                    const SizedBox(height: 6),
                    _buildPreviewCard(
                      sample: sample,
                      fontSize: draft,
                      big: true,
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewLabel('معاينة الكارد الصغير'),
                    const SizedBox(height: 6),
                    _buildPreviewCard(
                      sample: sample,
                      fontSize: smallSize,
                      big: false,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: _ink,
                            size: 28,
                          ),
                          onPressed: draft > _minFontSize
                              ? () {
                                  setModalState(() {
                                    draft = (draft - 1.0)
                                        .clamp(_minFontSize, _maxFontSize);
                                  });
                                }
                              : null,
                        ),
                        Expanded(
                          child: Slider(
                            value: draft,
                            min: _minFontSize,
                            max: _maxFontSize,
                            divisions: (_maxFontSize - _minFontSize).round(),
                            activeColor: _ink,
                            inactiveColor: _hairline,
                            label: '${draft.toInt()}',
                            onChanged: (val) {
                              setModalState(() {
                                draft =
                                    val.clamp(_minFontSize, _maxFontSize);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: _ink,
                            size: 28,
                          ),
                          onPressed: draft < _maxFontSize
                              ? () {
                                  setModalState(() {
                                    draft = (draft + 1.0)
                                        .clamp(_minFontSize, _maxFontSize);
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              backgroundColor: _ink.withValues(alpha: 0.06),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: _hairline),
                              ),
                            ),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.amiri(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _saveFontSize(draft);
                              Navigator.pop(ctx);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: _ink,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'حفظ',
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// بطاقة صغيرة تعرض حجمًا خطيًا ونسبته — بلا أي لون (أبيض/رمادي فقط).
  Widget _buildSizePill({
    required String label,
    required double value,
    required String note,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: highlight ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? _ink : _hairline,
          width: highlight ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.amiri(
              fontSize: 11,
              color: _inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${value.toInt()}',
                style: GoogleFonts.amiri(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  note,
                  maxLines: 2,
                  style: GoogleFonts.amiri(
                    fontSize: 10.5,
                    color: _inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewLabel(String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        style: GoogleFonts.amiri(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _inkMuted,
        ),
      ),
    );
  }

  /// معاينة حقيقية: نفس هندسة الكارد الكبير (حديث اليوم) أو الكارد الصغير —
  /// بالحجم المعروض فقط، ليرى المستخدم النتيجة قبل الحفظ.
  Widget _buildPreviewCard({
    required String sample,
    required double fontSize,
    required bool big,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(big ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: big
              ? [
                  _featuredTop.withValues(alpha: 0.62),
                  _featuredBottom.withValues(alpha: 0.90),
                ]
              : [
                  _cardTop.withValues(alpha: 0.62),
                  _cardBottom.withValues(alpha: 0.86),
                ],
        ),
        borderRadius: BorderRadius.circular(big ? 22 : 18),
        border: Border.all(
          color: _ink.withValues(alpha: big ? 0.45 : 0.25),
          width: big ? 1.2 : 1.0,
        ),
      ),
      child: big
          ? _buildQuote(sample, fontSize: fontSize)
          : Container(
              // إطار نص الحديث نفسه المستخدم في الكارد الصغير
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hairline),
              ),
              child: _buildQuote(sample, fontSize: fontSize),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildCategoryTabs(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _ink),
                      )
                    : _filteredHadiths.isEmpty
                        ? _buildEmptyState()
                        : _buildHadithList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── الترويسة ──────────────────────────────────────────────────────────────
  /// ترويسة بلا عنوان نصّي: زرّ الرجوع وزرّ حجم الخط على الطرفين، وفي
  /// **منتصفها** شريحة «الكل» (انتقلت من صف الشرائح) بحجم أصغر من شرائح التصنيف.
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          _buildRoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'رجوع',
            onTap: () => Navigator.pop(context),
          ),
          // الوسط: شريحة «الكل» — الزرّان على الطرفين بالحجم نفسه،
          // فيقع مِنتصف الشريحة في مِنتصف الترويسة تماماً.
          Expanded(
            child: Center(child: _buildCategoryChip(0, header: true)),
          ),
          _buildRoundIconButton(
            icon: Icons.format_size_rounded,
            tooltip: 'تغيير حجم الخط',
            onTap: _showFontSizeDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: _hairline),
          ),
          child: Icon(icon, color: _ink, size: 16),
        ),
      ),
    );
  }

  // ─── شرائح التصنيف (تنمو مع النص — لا اقتطاع) ─────────────────────────────
  /// صفّ الشرائح: «أحاديث عامة» و«فضائل رمضان» فقط — أما «الكل» فانتقلت
  /// إلى منتصف الترويسة ([_buildAppBar]).
  Widget _buildCategoryTabs() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int index = 1; index < _categories.length; index++) ...[
              if (index > 1) const SizedBox(width: 10),
              _buildCategoryChip(index),
            ],
          ],
        ),
      ),
    );
  }

  /// شريحة تصنيف واحدة.
  ///
  /// [header] = نسخة الترويسة («الكل»): حشو أصغر **وخط أصغر بمقدار واحد**
  /// (11 بدل 12) حتى لا تزاحم الطرفين.
  Widget _buildCategoryChip(int index, {bool header = false}) {
    final bool isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCategoryIndex = index;
          _filterHadiths();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: header
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: isSelected ? 0.20 : 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? _ink : _hairline,
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          _categories[index],
          style: GoogleFonts.amiri(
            color: _ink,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: header ? _headerChipFontSize : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHadithList() {
    final showDailyBanner = _selectedCategoryIndex == 0 && _dailyHadith != null;

    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      itemCount: _filteredHadiths.length + (showDailyBanner ? 1 : 0),
      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (showDailyBanner && index == 0) {
          return _buildDailyHadithCard(_dailyHadith!);
        }
        final hadithIndex = showDailyBanner ? index - 1 : index;
        final hadith = _filteredHadiths[hadithIndex];
        return _buildHadithCard(hadith, hadithIndex + 1);
      },
    );
  }

  // ─── الكارد الكبير: حديث اليوم ────────────────────────────────────────────
  Widget _buildDailyHadithCard(HadithItem hadith) {
    return AuroraGlassCard(
      borderRadius: BorderRadius.circular(24),
      blur: 18,
      isActive: true,
      glowColor: _ink.withValues(alpha: 0.22),
      gradientColors: [
        _featuredTop.withValues(alpha: 0.62),
        _featuredBottom.withValues(alpha: 0.90),
      ],
      border: Border.all(color: _ink.withValues(alpha: 0.45), width: 1.2),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة: نجمة + عنوان + زر النسخ
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _ink.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _hairline),
                ),
                child: const Icon(Icons.star_rounded, color: _ink, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'حديث اليوم',
                style: GoogleFonts.amiri(
                  color: _ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              const _Diamond(),
              const Spacer(),
              _buildActionIcon(
                icon: Icons.copy_rounded,
                tooltip: 'نسخ حديث اليوم',
                onTap: () => _copyHadith(hadith),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // فاصل شعري متلاشٍ الأطراف
          const _Hairline(),
          if (hadith.title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              hadith.title,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                color: _inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildQuote(hadith.text, fontSize: _fontSize),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildNarratorChip(hadith.narrator, fallback: 'حديث شريف'),
          ),
        ],
      ),
    );
  }

  // ─── الكارد الصغير: حديث عادي ─────────────────────────────────────────────
  Widget _buildHadithCard(HadithItem hadith, int displayIndex) {
    return AuroraGlassCard(
      borderRadius: BorderRadius.circular(20),
      blur: 14,
      gradientColors: [
        _cardTop.withValues(alpha: 0.62),
        _cardBottom.withValues(alpha: 0.86),
      ],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: Border.all(color: _hairline, width: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة: رقم الحديث + التصنيف + زر النسخ
          Row(
            children: [
              _buildTag('حديث $displayIndex', bold: true),
              // وسم «نبوي عام» أُزيل من الكارد الصغير: لا يظهر إلا وسم
              // «رمضانيات» للأحاديث الرمضانية.
              if (hadith.category.contains('رمضان')) ...[
                const SizedBox(width: 8),
                _buildTag('رمضانيات'),
              ],
              const Spacer(),
              _buildActionIcon(
                icon: Icons.copy_rounded,
                tooltip: 'نسخ الحديث',
                onTap: () => _copyHadith(hadith),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // عنوان/سند الحديث
          if (hadith.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                hadith.title,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiri(
                  color: _inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
          // نص الحديث في إطار شعري أبيض على سطح محايد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _hairline),
            ),
            // نص الحديث في الكارد الصغير أصغر بمقدار [_smallCardQuoteDelta]
            // عن حجم الخط المختار.
            child: _buildQuote(
              hadith.text,
              fontSize: _fontSize - _smallCardQuoteDelta,
            ),
          ),
          if (hadith.narrator.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildNarratorChip(hadith.narrator),
            ),
          ],
        ],
      ),
    );
  }

  /// نص الحديث بعلامتي تنصيص، أبيض بلا أي لون.
  ///
  /// الحجم ينتقل **بسلاسة** بدل القفزة المفاجئة: أي تغيير للحجم — من نافذة
  /// التغيير (معاينة مباشرة) أو بعد الحفظ — يجعل الخط يتحرّك تدريجياً من
  /// الحجم المعروض إلى الجديد، ويتوسّع الكارد معه في نفس الحركة.
  Widget _buildQuote(String text, {required double fontSize}) {
    return TweenAnimationBuilder<double>(
      // بلا `begin`: البناء الأول يظهر على الحجم المطلوب بلا حركة، وكل تغيير
      // لاحق لـ[end] ينطلق من الحجم المعروض حالياً نحو الجديد.
      tween: Tween<double>(end: fontSize),
      duration: _quoteFontTransition,
      curve: Curves.easeOutCubic,
      builder: (context, animatedFontSize, _) => Text(
        '«$text»',
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.amiri(
          color: _ink,
          fontSize: animatedFontSize,
          height: 2.0,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline, width: 0.8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.amiri(
          color: _ink,
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNarratorChip(String narrator, {String fallback = 'حديث شريف'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_added_rounded, color: _ink, size: 14),
          const SizedBox(width: 6),
          // يلتفّ/يُقصّ عند تكبير الخط بدل أن يفيض خارج الكارد
          Flexible(
            child: Text(
              narrator.isNotEmpty ? narrator : fallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.amiri(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hairline),
          ),
          child: Icon(icon, color: _ink, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, color: _ink, size: 56),
            const SizedBox(height: 16),
            Text(
              'لا توجد أحاديث لعرضها',
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── عناصر زخرفية أحادية اللون ───────────────────────────────────────────────

/// معيّن صغير أبيض — لمسة زخرفية بلا أي لون.
class _Diamond extends StatelessWidget {
  const _Diamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0x99FFFFFF),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// فاصل شعري أبيض متلاشٍ الأطراف.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x40FFFFFF),
            Color(0x00FFFFFF),
          ],
        ),
      ),
    );
  }
}
