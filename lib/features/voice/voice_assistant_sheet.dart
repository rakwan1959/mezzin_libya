import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'voice_service.dart';
import '../ai/gemini_service.dart';
import '../../voice_announcement_service.dart';

class VoiceAssistantSheet extends StatefulWidget {
  final ScrollController? scrollController;
  const VoiceAssistantSheet({super.key, this.scrollController});

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> with TickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  String _currentText = "";
  bool _processing = false;
  bool _thinking = false;
  String _aiAnswer = "";
  String? _aiError;

  Timer? _settleTimer;
  String _candidateText = "";
  bool _answered = false;

  late AnimationController _pulseController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _voiceService.isListeningNotifier.addListener(_onListeningStateChanged);
    _startVoice();
  }

  Future<void> _startVoice() async {
    _settleTimer?.cancel();
    setState(() {
      _aiAnswer = "";
      _aiError = null;
      _processing = false;
      _thinking = false;
      _candidateText = "";
      _answered = false;
    });
    bool init = await _voiceService.initialize();
    if (!mounted) return;

    if (!init) {
      setState(() => _currentText = "خطأ في الميكروفون — تحقق من الإذن");
      return;
    }

    _scaleController.forward();
    await _voiceService.listen(
      onResult: (text) {
        if (!mounted) return;
        setState(() => _currentText = text);
        _onPartialResult(text);
      },
    );
  }

  void _onPartialResult(String text) {
    if (_answered || _thinking || _processing) return;
    _settleTimer?.cancel();
    _candidateText = text.trim();
    if (_candidateText.isEmpty) return;
    // ننتظر هدوء الكلام (جزء من الثانية) ثم نعالج الجملة كاملة
    _settleTimer = Timer(const Duration(milliseconds: 900), _finalize);
  }

  void _onListeningStateChanged() {
    // توقف المايك (يدوياً أو تلقائياً) → نعالج ما قيل فوراً
    if (_voiceService.isListeningNotifier.value == false) {
      _settleTimer?.cancel();
      _finalize();
    }
  }

  Future<void> _finalize() async {
    if (!mounted || _answered || _thinking || _processing) return;
    _answered = true;
    if (_voiceService.isListening) {
      await _voiceService.stop();
    }
    if (!mounted) return;
    final text = _candidateText;
    if (text.isEmpty) return;

    final result = await _voiceService.processCommand(text);
    if (!mounted) return;
    if (result.type != VoiceCommandType.unknown) {
      _processing = true;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.pop(context, result);
      });
    } else {
      _askAi(text);
    }
  }

  Future<void> _askAi(String text) async {
    if (_thinking) return;
    setState(() {
      _thinking = true;
      _aiAnswer = "";
      _aiError = null;
    });
    try {
      final answer = await GeminiService.instance.ask(text);
      if (!mounted) return;
      setState(() {
        _thinking = false;
        if (answer == null) {
          _aiError = "لم يتم الحصول على إجابة، يرجى المحاولة مرة أخرى.";
        } else {
          _aiAnswer = answer;
        }
      });
      if (answer != null) {
        VoiceAnnouncementService().speakText(answer);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _aiError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _voiceService.isListeningNotifier.removeListener(_onListeningStateChanged);
    _voiceService.stop();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _voiceService.isListeningNotifier,
      builder: (context, listening, child) {
        if (listening) {
          if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        } else {
          if (_pulseController.isAnimating) _pulseController.stop();
        }

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF101B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // شريط علوي صغير: العنوان
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Center(
                    child: Text('مساعد اوقات الصلاه',
                        style: TextStyle(fontFamily: 'Amiri', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                // المايك
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    double pulseValue = _pulseController.value;
                    return GestureDetector(
                      onTap: () {
                        if (_voiceService.isListening) {
                          _voiceService.stop();
                        } else {
                          _startVoice();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withOpacity(listening ? (0.05 + (pulseValue * 0.1)) : 0.0),
                        ),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: listening ? Colors.amber : Colors.white.withOpacity(0.06),
                            border: Border.all(color: listening ? Colors.amber : Colors.white24, width: 1.2),
                            boxShadow: listening
                                ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]
                                : null,
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            size: 28,
                            color: listening ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  listening ? 'أستمع إليك الآن...' : 'انطق اسم السوره، قل شاتجيبيتي، قوقل',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    color: listening ? Colors.amber : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _currentText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(color: Colors.amber.withOpacity(0.7), fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_thinking) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                      const SizedBox(width: 10),
                      Text('ذكاء اوقات الصلاه يفكّر...', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
                if (_aiError != null && !_thinking) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _aiError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(fontSize: 11.5, height: 1.6, color: const Color(0xFFFFB4AB)),
                    ),
                  ),
                ],
                if (_aiAnswer.isNotEmpty && !_thinking) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _aiAnswer,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.tajawal(fontSize: 12.5, height: 1.7, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => VoiceAnnouncementService().speakText(_aiAnswer),
                        child: _miniPill(Icons.volume_up_rounded, 'إعادة القراءة'),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: _aiAnswer));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الإجابة'), duration: Duration(seconds: 1)));
                          }
                        },
                        child: _miniPill(Icons.copy_rounded, 'نسخ'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.tajawal(fontSize: 10.5, color: Colors.white70)),
        ],
      ),
    );
  }
}
