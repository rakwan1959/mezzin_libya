import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'gemini_service.dart';
import '../../injection_container.dart';
import '../quran/data/datasources/quran_local_data_source.dart';
import '../../voice_announcement_service.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_scaffold.dart';

/// المفسّر الذكي: اسأل عن أي آية ويجيبك الذكاء الاصطناعي
class AiTafsirPage extends StatefulWidget {
  final int? initialSurahId;
  final int? initialAyahNumber;
  final String? initialSurahName;
  final String? initialAyahText;

  const AiTafsirPage({
    super.key,
    this.initialSurahId,
    this.initialAyahNumber,
    this.initialSurahName,
    this.initialAyahText,
  });

  @override
  State<AiTafsirPage> createState() => _AiTafsirPageState();
}

class _AiTafsirPageState extends State<AiTafsirPage> {
  final TextEditingController _surahCtrl = TextEditingController();
  final TextEditingController _ayahCtrl = TextEditingController();
  final TextEditingController _questionCtrl = TextEditingController();

  static const List<String> _quickQuestions = [
    'اشرح لي الآية ببساطة',
    'ما سبب نزول هذه الآية؟',
    'ما الدروس والعبر المستفادة؟',
    'هل لهذه الآية علاقة بأحكام الصلاة؟',
  ];

  String? _surahName;
  String? _ayahText;
  bool _loading = false;
  bool _loadingLocal = false;
  String _localTafsir = '';
  String _answer = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSurahId != null) _surahCtrl.text = '${widget.initialSurahId}';
    if (widget.initialAyahNumber != null) _ayahCtrl.text = '${widget.initialAyahNumber}';
    if (widget.initialSurahName != null) _surahName = widget.initialSurahName;
    if (widget.initialAyahText != null) _ayahText = widget.initialAyahText;
    if (widget.initialSurahId != null) _loadContextIfNeeded();
  }

  Future<void> _loadContextIfNeeded() async {
    if (_ayahText != null && _surahName != null) return;
    final surahId = int.tryParse(_surahCtrl.text.trim());
    final ayahNo = int.tryParse(_ayahCtrl.text.trim());
    if (surahId == null || ayahNo == null || !mounted) return;
    setState(() => _loadingLocal = true);
    try {
      final ds = sl<QuranLocalDataSource>();
      final ayahs = await ds.getAyahsBySurah(surahId);
      if (!mounted) return;
      for (final a in ayahs) {
        if (a.ayahNumber == ayahNo) {
          final t = a.textUthmani.isNotEmpty ? a.textUthmani : a.text;
          if (mounted) setState(() => _ayahText = t);
          break;
        }
      }
    } catch (_) {}
    if (_surahName == null) {
      _surahName = 'سورة رقم $surahId';
    }
    setState(() => _loadingLocal = false);
  }

  Future<void> _ask([String? question]) async {
    FocusScope.of(context).unfocus();
    final surahId = int.tryParse(_surahCtrl.text.trim());
    final ayahNo = int.tryParse(_ayahCtrl.text.trim());
    final q = (question ?? _questionCtrl.text).trim();

    if (surahId == null || surahId < 1 || surahId > 114) {
      _toast('أدخل رقم السورة من 1 إلى 114');
      return;
    }
    if (ayahNo == null || ayahNo < 1) {
      _toast('أدخل رقم الآية');
      return;
    }
    if (q.isEmpty) {
      _toast('اكتب سؤالك عن الآية أو اختر سؤالاً جاهزاً');
      return;
    }

    await _loadContextIfNeeded();
    if (!mounted) return;

    final hasKey = await GeminiService.instance.hasApiKey();
    if (!hasKey) {
      setState(() {
        _error = 'لم يتم تفعيل الخدمة حالياً. يرجى المحاولة لاحقاً.';
        _answer = '';
      });
      return;
    }

    final ayahRef = 'سورة $_surahName - الآية $ayahNo';
    setState(() {
      _loading = true;
      _error = null;
      _answer = '';
    });
    try {
      final ayahText = _ayahText ?? '';
      final result = await GeminiService.instance.ask(
        q,
        context: 'نص الآية ($ayahRef): $ayahText\n(إن وُجد) التفسير المحلي: $_localTafsir',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result == null) {
          _error = 'لم يتم ربط مفتاح الذكاء الاصطناعي بعد.';
        } else {
          _answer = result;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
      backgroundColor: GlassNoticeSpec.surface,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _speakAnswer(String text) async {
    await VoiceAnnouncementService().speakText(text);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _ayahCard(),
                    const SizedBox(height: 12),
                    _questionInput(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickQuestions.map((q) => _chip(q, () => _ask(q))).toList(),
                    ),
                    const SizedBox(height: 14),
                    if (_loading) ...[
                      const Center(child: CircularProgressIndicator(color: Color(0xFF8AB4FF), strokeWidth: 2.5)),
                      const SizedBox(height: 8),
                      Center(child: Text('جارٍ التفكير في إجابتك...', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white54))),
                    ],
                    if (_error != null && !_loading)
                      _resultBox(
                        color: const Color(0xFFFFB4AB),
                        child: Text(_error!, textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                            style: GoogleFonts.tajawal(fontSize: 13, height: 1.7, color: const Color(0xFF3A0D0D))),
                      ),
                    if (_answer.isNotEmpty)
                      _resultBox(
                        color: const Color(0xFFE8F0FE),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF5B7CFA), size: 16),
                                const SizedBox(width: 6),
                                Text('إجابة الذكاء الاصطناعي', style: GoogleFonts.tajawal(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1F2A44))),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF1F2A44), size: 18),
                                  onPressed: () => _speakAnswer(_answer),
                                  tooltip: 'قراءة الإجابة صوتياً',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF1F2A44), size: 16),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: _answer));
                                    _toast('تم نسخ الإجابة');
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: Colors.black12, height: 8),
                            Text(_answer, textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                                style: GoogleFonts.amiri(fontSize: 14.5, height: 1.9, color: const Color(0xFF101828))),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8AB4FF), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('المفسّر الذكي للآيات',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _ayahCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تحديد الآية', style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numberField(_surahCtrl, 'رقم السورة', 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(_ayahCtrl, 'رقم الآية', 2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_ayahText != null && _ayahText!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8AB4FF).withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_surahName != null)
                    Text(_surahName!,
                        style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF8AB4FF))),
                  const SizedBox(height: 6),
                  Text(_ayahText!,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(fontSize: 15, height: 1.9, color: Colors.white)),
                ],
              ),
            )
          else if (_loadingLocal)
            const Align(alignment: Alignment.center, child: Padding(
              padding: EdgeInsets.all(6),
              child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
            )),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label, int maxLength) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLength,
      onChanged: (_) { _surahName = null; _ayahText = null; },
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: 12.5),
        counterText: '',
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _questionInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اسأل عن هذه الآية', style: GoogleFonts.tajawal(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 10),
          TextField(
            controller: _questionCtrl,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.6),
            decoration: InputDecoration(
              hintText: 'مثال: ما معنى «اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ»؟',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(_loading ? '...' : 'اسأل الذكاء الاصطناعي',
                  style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.tajawal(fontSize: 11.5, color: Colors.white)),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  Widget _resultBox({required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}
