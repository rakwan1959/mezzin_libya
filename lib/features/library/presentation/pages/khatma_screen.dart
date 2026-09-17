import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../quran/presentation/bloc/quran_bloc.dart';
import '../../../quran/presentation/bloc/quran_state.dart';
import '../../../quran/presentation/pages/quran_view_page.dart';
import '../../../../main.dart';
import '../../../../core/widgets/glass_scaffold.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/glass_widgets.dart';

const Color _appGold = Color(0xFFDFBA6B);

/// يُستخدم كنص/أيقونة فوق الخلفيات الذهبية فقط.
const Color _navyDark = Color(0xFF020814);

/// طبقة زجاجية شفافة (بدل الكحلي الصلب) — تُظهر تدرّج الأورورا من خلفها.
const Color _navyLight = Color(0x2EFFFFFF);

class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});
  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  int _currentJuz = 1;
  String _lastSurahName = "الفاتحة";
  int _lastSurahId = 1;
  int _lastAyah = 1;
  int _streak = 0;
  int _pagesRead = 0;
  int _totalKhatmas = 0;
  int _dailyGoalPages = 5;
  int _todayPages = 0;
  double _progress = 0.0;
  List<bool> _completedJuzaa = List.filled(30, false);

  static const _quotes = [
    'خيركم من تعلّم القرآن وعلّمه',
    'اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعاً لأصحابه',
    'الماهر بالقرآن مع السفرة الكرام البررة',
    'من قرأ حرفاً من كتاب الله فله حسنة والحسنة بعشر أمثالها',
  ];
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadKhatmaData();
    _startQuoteRotation();
  }

  void _startQuoteRotation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
        _startQuoteRotation();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadKhatmaData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = 'khatma_today_${DateTime.now().toIso8601String().substring(0, 10)}';
    setState(() {
      _currentJuz = prefs.getInt('khatma_juz') ?? 1;
      _lastSurahName = prefs.getString('khatma_surah_name') ?? "الفاتحة";
      _lastSurahId = prefs.getInt('khatma_surah_id') ?? 1;
      _lastAyah = prefs.getInt('khatma_ayah') ?? 1;
      _streak = prefs.getInt('khatma_streak') ?? 0;
      _pagesRead = prefs.getInt('khatma_pages') ?? 0;
      _totalKhatmas = prefs.getInt('khatma_total_completed') ?? 0;
      _dailyGoalPages = prefs.getInt('khatma_daily_goal') ?? 5;
      _todayPages = prefs.getInt(todayKey) ?? 0;
      _progress = (_currentJuz - 1) / 30;
      for (int i = 0; i < 30; i++) {
        _completedJuzaa[i] = prefs.getBool('khatma_juz_done_$i') ?? (i < _currentJuz - 1);
      }
    });
  }

  void _continueReading() {
    pushDark(context, QuranViewPage(
      juzNumber: _currentJuz,
      initialAyah: _lastAyah,
      initialSurahId: _lastSurahId,
    )).then((_) => _loadKhatmaData());
  }

  Future<void> _markJuzDone(int juzIndex) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final newVal = !_completedJuzaa[juzIndex];
    await prefs.setBool('khatma_juz_done_$juzIndex', newVal);
    int nextJuz = _currentJuz;
    if (newVal && juzIndex + 1 >= _currentJuz - 1) {
      nextJuz = juzIndex + 2;
      if (nextJuz > 30) {
        await prefs.setInt('khatma_total_completed', _totalKhatmas + 1);
        _showKhatmaCompletedDialog();
        nextJuz = 1;
        for (int i = 0; i < 30; i++) await prefs.setBool('khatma_juz_done_$i', false);
      }
      await prefs.setInt('khatma_juz', nextJuz);
    }
    await _loadKhatmaData();
  }

  void _showKhatmaCompletedDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white, width: 1.0),
      ),
      title: Text('🎉 تهانينا! أتممت الختمة', textAlign: TextAlign.center,
        style: GoogleFonts.amiri(color: _appGold, fontSize: 20, fontWeight: FontWeight.bold)),
      content: Text('بارك الله فيك، لقد أتممت ختمة القرآن الكريم كاملة.\nهذه هي ختمتك رقم ${_totalKhatmas + 1} 🌟',
        textAlign: TextAlign.center, style: GoogleFonts.amiri(color: Colors.white70, fontSize: 15, height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
        child: Text('جزاك الله خيراً', style: GoogleFonts.amiri(color: _appGold, fontWeight: FontWeight.bold)))],
    ));
  }

  void _showResetDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white, width: 1.0),
      ),
      title: Text('بدء ختمة جديدة', style: GoogleFonts.amiri(color: _appGold)),
      content: Text('هل تريد البدء من جديد؟ سيتم حفظ سجل ختماتك السابقة.',
        style: GoogleFonts.amiri(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('إلغاء', style: GoogleFonts.amiri(color: Colors.white38))),
        TextButton(onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('khatma_total_completed', _totalKhatmas + 1);
          await prefs.remove('khatma_juz'); await prefs.remove('khatma_surah_id');
          await prefs.remove('khatma_surah_name'); await prefs.remove('khatma_ayah');
          await prefs.remove('khatma_pages'); await prefs.remove('khatma_last_page_num');
          for (int i = 0; i < 30; i++) await prefs.remove('khatma_juz_done_$i');
          Navigator.pop(context); _loadKhatmaData();
        }, child: Text('بدء جديد', style: GoogleFonts.amiri(color: _appGold))),
      ],
    ));
  }

  void _showGoalDialog() async {
    int tempGoal = _dailyGoalPages;
    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setST) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text('الهدف اليومي 🎯', textAlign: TextAlign.center,
          style: GoogleFonts.amiri(color: _appGold, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$tempGoal صفحة / يوم', style: GoogleFonts.amiri(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Slider(
            value: tempGoal.toDouble(), min: 1, max: 60, divisions: 59,
            activeColor: _appGold, inactiveColor: Colors.white12,
            onChanged: (v) => setST(() => tempGoal = v.toInt()),
          ),
          Text('ستنتهي الختمة خلال ~${(604 / (tempGoal > 0 ? tempGoal : 1)).ceil()} يوم',
            style: GoogleFonts.amiri(color: Colors.white54, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.amiri(color: Colors.white38))),
          TextButton(onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('khatma_daily_goal', tempGoal);
            Navigator.pop(ctx); _loadKhatmaData();
          }, child: Text('حفظ', style: GoogleFonts.amiri(color: _appGold))),
        ],
      ),
    ));
  }

  String _estimatedCompletion() {
    final remainPages = (30 - _currentJuz + 1) * 20;
    final perDay = _dailyGoalPages > 0 ? _dailyGoalPages : 1;
    final days = (remainPages / perDay).ceil();
    if (days <= 0) return 'قريباً 🎉';
    if (days <= 7) return 'خلال $days أيام';
    if (days <= 30) return 'خلال ${(days / 7).ceil()} أسابيع';
    return 'خلال ${(days / 30).ceil()} أشهر';
  }

  @override
  Widget build(BuildContext context) {
    final dailyProgress = (_todayPages / (_dailyGoalPages > 0 ? _dailyGoalPages : 1)).clamp(0.0, 1.0);

    return GlassScaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar
          SliverAppBar(
            expandedHeight: 130,
            floating: false, pinned: true,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: _navyLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _appGold.withOpacity(0.15)),
                ),
                child: IconButton(
                  icon: Icon(Icons.flag_rounded, color: _appGold, size: 20),
                  onPressed: _showGoalDialog, tooltip: 'الهدف اليومي',
                ),
              ),
              const SizedBox(width: 4),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: _navyLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _appGold.withOpacity(0.15)),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: _appGold, size: 20),
                  onPressed: _showResetDialog, tooltip: 'ختمة جديدة',
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'ختمة القرآن',
                style: GoogleFonts.amiri(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      _appGold.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Opacity(opacity: 0.05,
                    child: Icon(Icons.menu_book_rounded, size: 100, color: _appGold)),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              child: Column(children: [

                // ── أدعية / Motivational Quote
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: GlassPanel(
                    key: ValueKey(_quoteIndex),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    borderRadius: BorderRadius.circular(18),
                    accent: _appGold,
                    child: Row(children: [
                      Icon(Icons.format_quote_rounded, color: _appGold.withOpacity(0.6), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_quotes[_quoteIndex],
                          textAlign: TextAlign.right,
                          style: GoogleFonts.amiri(color: Colors.white, fontSize: 15, height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Main Progress Card (بدون pulse animation)
                GlassPanel(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  borderRadius: BorderRadius.circular(28),
                  accent: _appGold,
                  child: Row(children: [
                    // Circular progress (بدون نبض)
                    SizedBox(width: 90, height: 90,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                          value: _progress, strokeWidth: 7,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(_appGold),
                        ),
                        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${(_progress * 100).toInt()}%',
                            style: GoogleFonts.amiri(color: _appGold, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('مكتمل', style: GoogleFonts.amiri(color: Colors.white38, fontSize: 9)),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الجزء الحالي', style: GoogleFonts.amiri(color: Colors.white38, fontSize: 12)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text('$_currentJuz من 30', style: GoogleFonts.amiri(
                          color: _appGold, fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text('سورة $_lastSurahName · آية $_lastAyah',
                          style: GoogleFonts.amiri(color: Colors.white60, fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.schedule_rounded, color: _appGold.withOpacity(0.7), size: 14),
                        const SizedBox(width: 4),
                        Text(_estimatedCompletion(),
                          style: GoogleFonts.amiri(color: _appGold.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ])),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Daily Goal Card (تم تغيير لونه إلى كحلي+ذهبي)
                GestureDetector(
                  onTap: _showGoalDialog,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(20),
                    accent: _appGold,
                    child: Row(children: [
                      Icon(Icons.flag_rounded, color: _appGold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('الهدف اليومي: $_dailyGoalPages صفحة',
                          style: GoogleFonts.amiri(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: dailyProgress, minHeight: 7,
                            backgroundColor: Colors.white.withOpacity(0.07),
                            valueColor: const AlwaysStoppedAnimation<Color>(_appGold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$_todayPages / $_dailyGoalPages صفحة اليوم',
                          style: GoogleFonts.amiri(color: _appGold.withOpacity(0.7), fontSize: 11)),
                      ])),
                      Icon(Icons.edit_rounded, color: _appGold.withOpacity(0.4), size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Continue Button
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); _continueReading(); },
                  child: GlassPanel(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    borderRadius: BorderRadius.circular(20),
                    accent: _appGold,
                    active: true,
                    vibrancy: 1.15,
                    gradientColors: [
                      _appGold.withValues(alpha: 0.94),
                      _appGold.withValues(alpha: 0.74),
                    ],
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.menu_book_rounded, color: _navyDark, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('متابعة القراءة من الجزء $_currentJuz',
                            style: GoogleFonts.amiri(color: _navyDark, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // ── 30-Juz Map
                Row(
                  children: [
                    Expanded(
                      child: Text('خريطة الأجزاء الثلاثين',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(color: _appGold, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Row(children: [
                      _legendDot(_appGold, 'مكتمل'),
                      const SizedBox(width: 8),
                      _legendDot(const Color(0xFF26A69A), 'الحالي'),
                      const SizedBox(width: 8),
                      _legendDot(Colors.white12, 'متبقي'),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1),
                  itemCount: 30,
                  itemBuilder: (_, i) {
                    final juzNum = i + 1;
                    final isDone = _completedJuzaa[i];
                    final isCurrent = juzNum == _currentJuz;
                    return GestureDetector(
                      onTap: () => _markJuzDone(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: isDone
                            ? LinearGradient(colors: [_appGold, _appGold.withOpacity(0.7)])
                            : isCurrent
                              ? const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF00796B)])
                              : null,
                          color: (!isDone && !isCurrent) ? Colors.white.withOpacity(0.05) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF26A69A) : isDone ? _appGold : Colors.white10,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            if (isDone)
                              const Icon(Icons.check_rounded, color: Color(0xFF020814), size: 16)
                            else
                              Text('$juzNum', style: GoogleFonts.amiri(
                                color: isCurrent ? Colors.white : Colors.white54,
                                fontSize: 14, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                            if (isCurrent)
                              Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 9),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text('اضغط على الجزء لتحديده كمكتمل',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(color: Colors.white24, fontSize: 11)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.amiri(color: Colors.white38, fontSize: 10)),
    ]);
  }
}
