import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:ui';

class RuqyahPlayerScreen extends StatefulWidget {
  const RuqyahPlayerScreen({super.key});

  @override
  State<RuqyahPlayerScreen> createState() => _RuqyahPlayerScreenState();
}

class _RuqyahPlayerScreenState extends State<RuqyahPlayerScreen> with TickerProviderStateMixin {
  late AudioPlayer _player;
  bool _isLoading = true;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setAudioSource(
        AudioSource.asset(
          'assets/audio/ruqya_mo3aykaly.mp3',
          tag: MediaItem(
            id: 'ruqya_maher',
            album: "المكتبة الإسلامية",
            title: "الرقية الشرعية",
            artist: "الشيخ ماهر المعيقلي",
            artUri: Uri.parse("https://i.ibb.co/vY8p0fM/ruqya-icon.png"),
          ),
        ),
      );
      
      _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });
      _player.durationStream.listen((dur) {
        if (mounted) setState(() => _duration = dur ?? Duration.zero);
      });
      _player.playerStateStream.listen((state) {
        if (mounted) setState(() {});
      });
      _player.volumeStream.listen((v) {
        if (mounted) setState(() => _volume = v);
      });

      if (mounted) setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    HapticFeedback.mediumImpact();
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _stop() {
    HapticFeedback.heavyImpact();
    _player.stop();
    _player.seek(Duration.zero);
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    if (_volume > 0) {
      _player.setVolume(0);
    } else {
      _player.setVolume(1.0);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.playing;
    final isMuted = _volume == 0;
    final progress = _duration.inSeconds > 0
        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      // سطح زجاجي شفاف بدل التدرّج المعتم
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 15),
          
          // Header Row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 30),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'الرقية الشرعية',
                      style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                    Text(
                      'الشيخ ماهر المعيقلي',
                      style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: isMuted ? Colors.redAccent : Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_hasError)
            Text('خطأ في تحميل الملف', style: GoogleFonts.tajawal(color: Colors.redAccent))
          else ...[
            // Progress Bar
            Row(
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: Colors.amberAccent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (val) {
                        _player.seek(Duration(seconds: (val * _duration.inSeconds).toInt()));
                      },
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),

            // Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stop Button
                IconButton(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded, color: Colors.white70, size: 28),
                ),
                
                // Seek Back 10s
                IconButton(
                  onPressed: () => _player.seek(_player.position - const Duration(seconds: 10)),
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 28),
                ),

                // Play/Pause
                GestureDetector(
                  onTap: _isLoading ? null : _togglePlayPause,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent]),
                      boxShadow: [BoxShadow(color: Colors.orangeAccent.withOpacity(0.2), blurRadius: 10)],
                    ),
                    child: _isLoading
                        ? const Center(child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2)))
                        : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 35, color: Colors.black87),
                  ),
                ),

                // Seek Forward 10s
                IconButton(
                  onPressed: () => _player.seek(_player.position + const Duration(seconds: 10)),
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 28),
                ),

                // Replay/Loop (Simple Toggle)
                IconButton(
                  onPressed: () {
                    final isLoop = _player.loopMode == LoopMode.one;
                    _player.setLoopMode(isLoop ? LoopMode.off : LoopMode.one);
                    HapticFeedback.selectionClick();
                  },
                  icon: Icon(Icons.loop_rounded, 
                    color: _player.loopMode == LoopMode.one ? Colors.amberAccent : Colors.white70, 
                    size: 24),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
