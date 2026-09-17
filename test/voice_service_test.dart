import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/voice/voice_service.dart';

void main() {
  final VoiceService service = VoiceService();

  Future<int?> surahOf(String phrase) async {
    final result = await service.processCommand(phrase);
    return result.surahId;
  }

  group('التعرف الصوتي على أسماء السور', () {
    test('يتعرف على جميع السور التي تبدأ بحرف القاف بدقة', () async {
      expect(await surahOf('سورة القصص'), 28);
      expect(await surahOf('سورة القمر'), 54);
      expect(await surahOf('سورة القلم'), 68);
      expect(await surahOf('سورة القيامة'), 75);
      expect(await surahOf('سورة القدر'), 97);
      expect(await surahOf('سورة القارعة'), 101);
      expect(await surahOf('سورة قريش'), 106);
      expect(await surahOf('سورة الفرقان'), 25);
      expect(await surahOf('سورة الفلق'), 113);
    });

    test('سورتا ق وص لا تخطفان أسماء السور الأخرى', () async {
      expect(await surahOf('سورة ق'), 50);
      expect(await surahOf('سورة ص'), 38);
      expect(await surahOf('سورة الصافات'), 37);
      expect(await surahOf('سورة الصف'), 61);
      expect(await surahOf('سورة العصر'), 103);
      expect(await surahOf('سورة النصر'), 110);
      expect(await surahOf('سورة الإخلاص'), 112);
      expect(await surahOf('سورة فصلت'), 41);
    });

    test('يميز بين الأسماء المتشابهة في الحروف', () async {
      expect(await surahOf('سورة الحجر'), 15);
      expect(await surahOf('سورة الحجرات'), 49);
      expect(await surahOf('سورة الحج'), 22);
      expect(await surahOf('سورة الفاتحة'), 1);
      expect(await surahOf('سورة الناس'), 114);
      expect(await surahOf('سورة الإنسان'), 76);
      expect(await surahOf('سورة يس'), 36);
    });

    test('يتعرف على الأسماء البديلة وصيغ النطق المختلفة', () async {
      expect(await surahOf('سورة قاف'), 50);
      expect(await surahOf('سورة صاد'), 38);
      expect(await surahOf('سورة ياسين'), 36);
      expect(await surahOf('سورة طاها'), 20);
      expect(await surahOf('سورة تبارك'), 67);
      expect(await surahOf('سورة الحمد'), 1);
      expect(await surahOf('سورة تبت'), 111);
    });

    test('يتعرف على أسماء بقية السور', () async {
      expect(await surahOf('سورة البقرة'), 2);
      expect(await surahOf('سورة آل عمران'), 3);
      expect(await surahOf('سورة الكهف'), 18);
      expect(await surahOf('سورة مريم'), 19);
      expect(await surahOf('سورة الرحمن'), 55);
      expect(await surahOf('سورة الملك'), 67);
      expect(await surahOf('سورة الكوثر'), 108);
      expect(await surahOf('سورة الفيل'), 105);
    });
  });
}