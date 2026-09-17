import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/audio_player_service.dart';

void main() {
  group('روابط صوت القراء', () {
    test('قارئ آيات (ar.*) له مصدر أساسي ومصدر بديل موثوق', () {
      final urls = AudioPlayerService.getAudioUrls('ar.alafasy', 256, 2, 1);
      expect(urls.length, greaterThanOrEqualTo(2));
      expect(urls.first, startsWith('https://everyayah.com/data/Alafasy'));
      expect(urls[1], startsWith('https://cdn.islamic.network/quran/audio'));
    });

    test('قارئ عبدالباسط له بديل عبر cdn.islamic.network بجودة 64', () {
      final urls = AudioPlayerService.getAudioUrls('ar.abdulsamad', 256, 2, 1);
      expect(urls.length, greaterThanOrEqualTo(2));
      expect(urls.first, contains('Abdul_Basit_Murattal_64kbps'));
      expect(urls[1], contains('/quran/audio/64/ar.abdulsamad/256.mp3'));
    });

    test('القارئ الليبي يستخدم HTTPS كمصدر أساسي', () {
      final urls = AudioPlayerService.getAudioUrls('ly.daoub', 0, 2, 1);
      expect(urls.first, startsWith('https://server10.mp3quran.net/tareq/002.mp3'));
      expect(urls[1], startsWith('http://server10.mp3quran.net/tareq/002.mp3'));
    });

    test('رابط السورة الكاملة لا يحتوي على رقم آية', () {
      final urls = AudioPlayerService.getAudioUrls('ly.dokali', 0, 2, 1);
      expect(urls.first, 'https://server7.mp3quran.net/dokali/002.mp3');
    });
  });

  group('التحقق من ملفات MP3 المحلية', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mp3_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Future<File> writeFile(String name, List<int> bytes) async {
      final f = File('${tempDir.path}${Platform.pathSeparator}$name');
      await f.writeAsBytes(bytes);
      return f;
    }

    test('ملف يبدأ بوسم ID3 يُعتبر MP3 صالحاً', () async {
      final f = await writeFile(
        'a.mp3',
        [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
      );
      expect(AudioPlayerService.isValidMp3File(f), isTrue);
    });

    test('ملف يبدأ بإطار MPEG الصوتي يُعتبر MP3 صالحاً', () async {
      final f = await writeFile(
        'b.mp3',
        [0xFF, 0xFB, 0x90, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
      );
      expect(AudioPlayerService.isValidMp3File(f), isTrue);
    });

    test('صفحة HTML لا تُعتبر MP3 صالحاً', () async {
      final f = await writeFile(
        'c.mp3',
        List<int>.generate(6000, (i) => '<html>error page</html>'.codeUnitAt(i % 22)),
      );
      expect(AudioPlayerService.isValidMp3File(f), isFalse);
    });

    test('ملف فارغ أو صغير لا يُعتبر MP3 صالحاً', () async {
      final f = await writeFile('d.mp3', [0x01]);
      expect(AudioPlayerService.isValidMp3File(f), isFalse);
    });
  });
}