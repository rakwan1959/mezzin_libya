import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/ayah.dart';
import 'islamic_surah_name.dart';

class FatihaQalunView extends StatelessWidget {
  final List<Ayah> ayahs;
  final Function(Ayah) onAyahTap;

  const FatihaQalunView({
    super.key,
    required this.ayahs,
    required this.onAyahTap,
  });

  static const Color cyanColor = Color(0xFF50C8EF);
  static const Color whiteColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactHeader(),
          const SizedBox(height: 20),
          _buildBismillah(),
          const SizedBox(height: 20),
          _buildAyahsContent(context),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2347).withOpacity(0.35),
        border: Border.all(color: const Color(0xFFDFBA6B).withOpacity(0.6), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDFBA6B).withOpacity(0.25), width: 0.8),
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFDFBA6B), size: 18),
              Icon(Icons.star_rounded, color: Color(0xFFDFBA6B), size: 18),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IslamicSurahName(
                surahName: 'الفَاتِحَة',
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDFBA6B),
                ),
                ornamentColor: const Color(0xFFEDEDED).withOpacity(0.88),
                ornamentWidth: 26,
                ornamentHeight: 13,
                spacing: 8,
              ),
              const SizedBox(height: 2),
              Text(
                'مكية   عدد آياتها ٧',
                style: GoogleFonts.amiri(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDFBA6B).withOpacity(0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBismillah() {
    return Text(
      'بِسْمِ اِ۬للَّهِ اِ۬لرَّحْمَٰنِ اِ۬لرَّحِيمِ',
      textAlign: TextAlign.center,
      style: GoogleFonts.amiri(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: whiteColor,
      ),
    );
  }

  Widget _buildAyahsContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: RichText(
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: GoogleFonts.amiri(
            fontSize: 22,
            height: 2.0,
            color: whiteColor,
          ),
          children: [
            _ayahSpan('اِ۬لْحَمْدُ لِلهِ رَبِّ اِ۬لْعَٰلَمِينَ', 1),
            const TextSpan(text: ' '),
            _ayahSpan('اَ۬لرَّحْمَٰنِ اِ۬لرَّحِيمِ', 2),
            const TextSpan(text: ' '),
            _ayahSpan('مَلِكِ يَوْمِ اِ۬لدِّينِۖ', 3),
            const TextSpan(text: ' '),
            _ayahSpan('إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُۖ', 4),
            const TextSpan(text: ' '),
            const TextSpan(text: 'اُ۪هْدِنَا '),
            _ayahSpan('اَ۬لصِّرَٰطَ اَ۬لْمُسْتَقِيمَ', 5),
            const TextSpan(text: ' '),
            const TextSpan(text: 'صِرَٰطَ اَ۬لذِينَ أَنْعَمْتَ '),
            _ayahSpan('عَلَيْهِمْ', 6),
            const TextSpan(text: ' '),
            const TextSpan(text: 'غَيْرِ اِ۬لْمَغْضُوبِ عَلَيْهِمْ '),
            _ayahSpan('اَ۬لضَّآلِّينَۖ', 7),
          ],
        ),
      ),
    );
  }

  TextSpan _ayahSpan(String text, int number) {
    final Ayah? ayah = ayahs.length >= number ? ayahs[number - 1] : null;
    return TextSpan(
      children: [
        TextSpan(
          text: text,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (ayah != null) onAyahTap(ayah);
            },
        ),
        const WidgetSpan(child: SizedBox(width: 5)),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ayahMarker(number),
        ),
      ],
    );
  }

  Widget _ayahMarker(int number) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cyanColor.withOpacity(0.7), width: 1.5),
      ),
      child: Center(
        child: Text(
          _toArabicNumbers(number.toString()),
          style: GoogleFonts.tajawal(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cyanColor,
          ),
        ),
      ),
    );
  }

  String _toArabicNumbers(String n) {
    return n
        .replaceAll('0', '٠')
        .replaceAll('1', '١')
        .replaceAll('2', '٢')
        .replaceAll('3', '٣')
        .replaceAll('4', '٤')
        .replaceAll('5', '٥')
        .replaceAll('6', '٦')
        .replaceAll('7', '٧')
        .replaceAll('8', '٨')
        .replaceAll('9', '٩');
  }
}

