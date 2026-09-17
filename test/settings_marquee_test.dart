import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:muezzin_libya_app/remote_messaging_service.dart';

/// النص المتحرك في هيدر شاشة الإعدادات (أسماء الله الحسنى) — يُتحكَّم فيه كاملاً
/// من لوحة التحكم: النص + اللون + نوع الخط + حجم الخط.
///
/// هذه الاختبارات تحرس:
///   1. الافتراضيات: أبيض · أميري · حجم 12 (الخط أميري لا كايرو كما في
///      الشاشة الرئيسية).
///   2. الحفظ المحلي بالمفاتيح `remote_marquee_*` (فيعمل بلا إنترنت).
///   3. تطبيق أعمدة `marquee_*` الواردة من app_config، وتقييد القيم الشاذة.
///   4. أن صفاً قديماً فيه `marquee_text` وحده لا يمسّ اللون ولا الخط ولا
///      الحجم (بقاء الافتراضيات بلا كسر).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('الافتراضيات', () {
    test('أبيض · أميري · 12 والنص فارغ (أسماء الله الحسنى)', () {
      const SettingsMarqueeSettings s = SettingsMarqueeSettings();

      expect(s.color, 0xFFFFFFFF, reason: 'الافتراضي أبيض فوق الهيدر الداكن');
      expect(s.color, SettingsMarqueeSettings.defaultColor);
      expect(s.fontFamily, 'Amiri', reason: 'الخط الافتراضي أميري');
      expect(s.fontSize, 12);
      expect(s.text, isEmpty, reason: 'فارغ = أسماء الله الحسنى المضمّنة');
    });

    test('لا شيء محفوظ بعد → القيم الافتراضية نفسها', () async {
      final SettingsMarqueeSettings s = SettingsMarqueeSettings.fromPrefs(
        await prefs(),
      );

      expect(s.color, SettingsMarqueeSettings.defaultColor);
      expect(s.fontFamily, 'Amiri');
      expect(s.fontSize, 12);
      expect(s.text, isEmpty);
    });

    test('الخط الافتراضي هنا أميري (بخلاف نص الشاشة الرئيسية كايرو)', () {
      expect(SettingsMarqueeSettings.defaultFontFamily, 'Amiri');
      expect(HomeMarqueeSettings.defaultFontFamily, 'Cairo');
      expect(
        SettingsMarqueeSettings.normalizeFont('Comic Sans'),
        'Amiri',
        reason: 'أي اسم مجهول يعود إلى الأميري هنا',
      );
    });
  });

  group('أسماء الخطوط وأحجامها', () {
    test('اسم معروف يُقبل بلا حساسية لحالة الأحرف أو المسافات', () {
      expect(SettingsMarqueeSettings.normalizeFont('Amiri'), 'Amiri');
      expect(SettingsMarqueeSettings.normalizeFont('amiri'), 'Amiri');
      expect(SettingsMarqueeSettings.normalizeFont('  Cairo  '), 'Cairo');
      expect(
        SettingsMarqueeSettings.normalizeFont('Noto Kufi Arabic'),
        'Noto Kufi Arabic',
      );
      expect(SettingsMarqueeSettings.normalizeFont('Amiri Quran'), 'Amiri Quran');
    });

    test('فارغ أو null يعود إلى أميري', () {
      expect(SettingsMarqueeSettings.normalizeFont(''), 'Amiri');
      expect(SettingsMarqueeSettings.normalizeFont(null), 'Amiri');
      expect(SettingsMarqueeSettings.normalizeFont('   '), 'Amiri');
    });

    test('الحجم مقيَّد بين 9 و24 والافتراضي 12', () {
      expect(SettingsMarqueeSettings.clampFontSize(null), 12);
      expect(SettingsMarqueeSettings.clampFontSize(2), 9);
      expect(SettingsMarqueeSettings.clampFontSize(99), 24);
      expect(SettingsMarqueeSettings.clampFontSize(14), 14);
      expect(SettingsMarqueeSettings.minFontSize, 9);
      expect(SettingsMarqueeSettings.maxFontSize, 24);
    });

    test('كل خط في قائمة اللوحة له نمط فعلي بالعائلة الصحيحة', () {
      for (final String f in RemoteMessagingService.homeDuaFonts) {
        final TextStyle style = SettingsMarqueeSettings(fontFamily: f)
            .textStyle();
        final String expected = f.toLowerCase().replaceAll(' ', '');
        expect(
          (style.fontFamily ?? '').toLowerCase().startsWith(expected),
          isTrue,
          reason: 'الخط «$f» يجب أن يُحلّ إلى عائلته',
        );
      }
    });
  });

  group('نمط العرض (اللون + الخط + الحجم)', () {
    test('اللون والحجم والوزن تُطبَّق فعلاً على النمط', () {
      const SettingsMarqueeSettings s = SettingsMarqueeSettings(
        color: 0xFF00E676,
        fontFamily: 'Almarai',
        fontSize: 18,
      );

      final TextStyle style = s.textStyle();
      expect(style.color, const Color(0xFF00E676));
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontFamily?.toLowerCase(), startsWith('almarai'));
    });

    test('هالة خفيفة تُضاف ليُقرأ النص على أي خلفية', () {
      final TextStyle style = const SettingsMarqueeSettings().textStyle();
      expect(style.shadows, isNotEmpty);
    });
  });

  group('الحفظ المحلي', () {
    test('المفاتيح الأربعة تُكتب بالاسم المتوقّع', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        text: 'سبحان الله',
        color: 0xFFDFBA6B,
        fontFamily: 'Tajawal',
        fontSize: 16,
      ).saveLocally(p);

      expect(p.getString(RemoteMessagingService.settingsMarqueeTextKey),
          'سبحان الله');
      expect(p.getInt(RemoteMessagingService.settingsMarqueeColorKey),
          0xFFDFBA6B);
      expect(
          p.getString(RemoteMessagingService.settingsMarqueeFontKey), 'Tajawal');
      expect(p.getInt(RemoteMessagingService.settingsMarqueeFontSizeKey), 16);
      // نفس المفتاح القديم للنص (حتى لا تفقد النسخ المثبَّتة نصّها)
      expect(RemoteMessagingService.settingsMarqueeTextKey, 'remote_marquee_text');
    });

    test('نص فارغ يمسح المفتاح فتعود أسماء الله الحسنى', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(text: 'نص قديم').saveLocally(p);
      expect(p.getString(RemoteMessagingService.settingsMarqueeTextKey),
          'نص قديم');

      await const SettingsMarqueeSettings().saveLocally(p);
      expect(p.getString(RemoteMessagingService.settingsMarqueeTextKey), isNull);
      expect(SettingsMarqueeSettings.fromPrefs(p).text, isEmpty);
    });

    test('القيم الشاذة تُقيَّد عند الحفظ أيضاً', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        fontFamily: 'خط لا وجود له',
        fontSize: 400,
      ).saveLocally(p);

      final SettingsMarqueeSettings saved = SettingsMarqueeSettings.fromPrefs(p);
      expect(saved.fontFamily, 'Amiri');
      expect(saved.fontSize, SettingsMarqueeSettings.maxFontSize);
    });

    test('قراءة ما حُفظ على الجهاز تُعيده كما هو', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        text: 'لا إله إلا الله',
        color: 0xFF7FD4FF,
        fontFamily: 'Amiri Quran',
        fontSize: 20,
      ).saveLocally(p);

      final SettingsMarqueeSettings read =
          await RemoteMessagingService.readSettingsMarqueeSettings();
      expect(read.text, 'لا إله إلا الله');
      expect(read.color, 0xFF7FD4FF);
      expect(read.fontFamily, 'Amiri Quran');
      expect(read.fontSize, 20);
    });
  });

  group('النشر إلى app_config', () {
    test('الحمولة تحمل الأعمدة الأربعة بأسمائها الصحيحة', () {
      final Map<String, dynamic> payload = const SettingsMarqueeSettings(
        text: '  أسماء الله الحسنى  ',
        color: 0xFFDFBA6B,
        fontFamily: 'amiri',
        fontSize: 14,
      ).toRemotePayload();

      expect(payload['marquee_text'], 'أسماء الله الحسنى', reason: 'بلا فراغات');
      expect(payload['marquee_color'], 0xFFDFBA6B);
      expect(payload['marquee_font'], 'Amiri', reason: 'اسم الخط مُطبَّع');
      expect(payload['marquee_font_size'], 14);
    });
  });

  group('تطبيق ما يصل من السيرفر', () {
    test('النص واللون والخط والحجم كلها تُطبَّق محلياً', () async {
      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{
          'marquee_text': 'الله أكبر',
          'marquee_color': 0xFF9FE870,
          'marquee_font': 'Cairo',
          'marquee_font_size': 16,
        },
      );

      expect(applied.text, 'الله أكبر');
      expect(applied.color, 0xFF9FE870);
      expect(applied.fontFamily, 'Cairo');
      expect(applied.fontSize, 16);

      // ومحفوظة فعلاً — لا في الذاكرة وحدها
      final SharedPreferences p = await prefs();
      expect(p.getString(RemoteMessagingService.settingsMarqueeTextKey),
          'الله أكبر');
      expect(p.getInt(RemoteMessagingService.settingsMarqueeColorKey),
          0xFF9FE870);
    });

    test('نص فارغ من السيرفر يمحو المخصص ويعود للافتراضي', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(text: 'نص قديم').saveLocally(p);

      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{'marquee_text': '   '},
      );

      expect(applied.text, isEmpty);
      expect(p.getString(RemoteMessagingService.settingsMarqueeTextKey), isNull);
    });

    test('قيم شاذة من السيرفر تُقيَّد لا تُكسر', () async {
      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{
          'marquee_text': 'اختبار',
          'marquee_color': '4278190335', // نص لا رقم (يصل هكذا أحياناً)
          'marquee_font': 'خط مجهول',
          'marquee_font_size': '1',
        },
      );

      expect(applied.color, 4278190335);
      expect(applied.fontFamily, 'Amiri');
      expect(applied.fontSize, SettingsMarqueeSettings.minFontSize);
    });

    test('صف قديم فيه marquee_text وحده لا يمسّ اللون ولا الخط ولا الحجم',
        () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        color: 0xFFDFBA6B,
        fontFamily: 'Almarai',
        fontSize: 20,
      ).saveLocally(p);

      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{'marquee_text': 'نص جديد'},
      );

      expect(applied.text, 'نص جديد');
      expect(applied.color, 0xFFDFBA6B, reason: 'التنسيق المحفوظ يبقى كما هو');
      expect(applied.fontFamily, 'Almarai');
      expect(applied.fontSize, 20);
    });

    test('خريطة فارغة/null لا تُغيّر شيئاً', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        text: 'ثابت',
        color: 0xFFDFBA6B,
        fontFamily: 'Cairo',
        fontSize: 15,
      ).saveLocally(p);

      final SettingsMarqueeSettings fromNull =
          await RemoteMessagingService.applySettingsMarqueeConfig(null);
      final SettingsMarqueeSettings fromEmpty =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{},
      );

      for (final SettingsMarqueeSettings s in <SettingsMarqueeSettings>[
        fromNull,
        fromEmpty,
      ]) {
        expect(s.text, 'ثابت');
        expect(s.color, 0xFFDFBA6B);
        expect(s.fontFamily, 'Cairo');
        expect(s.fontSize, 15);
      }
    });
  });

  group('copyWith', () {
    test('يغيّر المطلوب ويُبقي الباقي', () {
      const SettingsMarqueeSettings base = SettingsMarqueeSettings(
        text: 'الأصل',
        color: 0xFFDFBA6B,
        fontFamily: 'Cairo',
        fontSize: 14,
      );

      final SettingsMarqueeSettings changed = base.copyWith(
        fontSize: 20,
        color: 0xFFFFFFFF,
      );

      expect(changed.text, 'الأصل');
      expect(changed.fontFamily, 'Cairo');
      expect(changed.fontSize, 20);
      expect(changed.color, 0xFFFFFFFF);
    });

    test('ينقل الأحاديث ووقت الظهور أيضاً', () {
      const SettingsMarqueeSettings base = SettingsMarqueeSettings(
        messages: <String>['أ'],
        intervalMs: 2000,
      );

      final SettingsMarqueeSettings changed = base.copyWith(
        messages: <String>['أ', 'ب'],
        intervalMs: 8000,
      );

      expect(changed.messages, <String>['أ', 'ب']);
      expect(changed.intervalMs, 8000);
      expect(base.messages, <String>['أ'], reason: 'الأصل لا يتغيّر');
      expect(base.intervalMs, 2000);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  //  أحاديث الشريط العلوي + وقت الظهور — ما أُضيف من لوحة التحكم (1918)
  // ──────────────────────────────────────────────────────────────────────────
  group('أحاديث الشريط ووقت الظهور', () {
    test('الافتراضيات: بلا أحاديث و6 ثوانٍ وقت ظهور', () {
      const SettingsMarqueeSettings s = SettingsMarqueeSettings();

      expect(s.messages, isEmpty);
      expect(s.intervalMs, 6000);
      expect(SettingsMarqueeSettings.defaultIntervalMs, 6000);
      expect(s.intervalLabel, '6.0 ثانية');
      expect(s.interval, const Duration(seconds: 6));
      expect(s.messagesCount, 0);
      expect(
        s.effectiveMessages,
        isEmpty,
        reason: 'بلا مخصص = أسماء الله الحسنى في الشاشة',
      );
    });

    test('الأولوية: الأحاديث ثم النص الواحد ثم لا شيء', () {
      expect(
        const SettingsMarqueeSettings(text: 'نص').effectiveMessages,
        <String>['نص'],
      );
      expect(
        const SettingsMarqueeSettings(
          text: 'نص',
          messages: <String>['أ', 'ب'],
        ).effectiveMessages,
        <String>['أ', 'ب'],
        reason: 'الأحاديث تتقدّم على النص الواحد',
      );
      expect(const SettingsMarqueeSettings().effectiveMessages, isEmpty);
    });

    test('التنظيف: بلا فراغات ولا تكرار وبسقف العدد والطول', () {
      expect(
        SettingsMarqueeSettings.normalizeMessages(<String>[
          '  حديث  ',
          '',
          '   ',
          'حديث',
          'ثانٍ',
        ]),
        <String>['حديث', 'ثانٍ'],
      );
      expect(
        SettingsMarqueeSettings.normalizeMessages(
          List<String>.generate(80, (int i) => 'حديث $i'),
        ).length,
        SettingsMarqueeSettings.maxMessages,
        reason: 'سقف العدد يمنع صفاً ضخماً في app_config',
      );
      expect(
        SettingsMarqueeSettings.normalizeMessages(<String>['ا' * 900]).first.length,
        SettingsMarqueeSettings.maxMessageLength,
      );
    });

    test('حديث بأسطر متعددة يُطوى إلى حديث واحد (لا يصير ثلاثة)', () {
      // السطر الجديد هو الفاصل في marquee_messages: بلا الطيّ كان حديث
      // من سطرين يُخزَّن كحديثين لكل منهما وقت ظهور مستقل.
      final List<String> cleaned = SettingsMarqueeSettings.normalizeMessages(
        <String>['حديث أول\nسطر ثانٍ', 'حديث ثانٍ'],
      );
      expect(cleaned.length, 2, reason: 'حديثان لا ثلاثة');
      expect(cleaned.first, 'حديث أول سطر ثانٍ');

      final Map<String, dynamic> payload = SettingsMarqueeSettings(
        messages: <String>['حديث\nبسطرين'],
      ).toRemotePayload();
      expect(payload['marquee_messages'], 'حديث بسطرين');
      expect(
        SettingsMarqueeSettings.parseMessages(
          payload['marquee_messages'] as String,
        ),
        <String>['حديث بسطرين'],
        reason: 'الدورة كاملة: تخزين ثم فكّ بلا انقسام زائد',
      );
    });

    test('يُفكّ من السيرفر: سطر لكل حديث أو مصفوفة JSON', () {
      expect(
        SettingsMarqueeSettings.parseMessages('أ\nب'),
        <String>['أ', 'ب'],
      );
      expect(
        SettingsMarqueeSettings.parseMessages('["أ","ب"]'),
        <String>['أ', 'ب'],
      );
      expect(SettingsMarqueeSettings.parseMessages('   '), isEmpty);
      expect(SettingsMarqueeSettings.parseMessages(null), isEmpty);
    });

    test('وقت الظهور مقيَّد بين 1.5 و60 ثانية', () {
      expect(SettingsMarqueeSettings.clampInterval(null), 6000);
      expect(
        SettingsMarqueeSettings.clampInterval(10),
        SettingsMarqueeSettings.minIntervalMs,
      );
      expect(
        SettingsMarqueeSettings.clampInterval(999999),
        SettingsMarqueeSettings.maxIntervalMs,
      );
      expect(SettingsMarqueeSettings.clampInterval(4500), 4500);
    });

    test('messageAt يدور على القائمة ولا يخرج عن الحدود', () {
      const SettingsMarqueeSettings s = SettingsMarqueeSettings(
        messages: <String>['أ', 'ب', 'ج'],
      );

      expect(s.messageAt(0), 'أ');
      expect(s.messageAt(2), 'ج');
      expect(s.messageAt(3), 'أ');
      expect(s.messagesCount, 3);
      expect(const SettingsMarqueeSettings().messageAt(5), '');
    });

    test('الحفظ المحلي: حديث لكل سطر + وقت الظهور', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        text: 'أ',
        messages: <String>['أ', 'ب', 'ج'],
        intervalMs: 4500,
      ).saveLocally(p);

      expect(
        p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        'أ\nب\nج',
      );
      expect(
        p.getInt(RemoteMessagingService.settingsMarqueeIntervalKey),
        4500,
      );

      final SettingsMarqueeSettings read = SettingsMarqueeSettings.fromPrefs(p);
      expect(read.messages, <String>['أ', 'ب', 'ج']);
      expect(read.intervalMs, 4500);
    });

    test('بلا أحاديث يُمسح المفتاح فتعود الأسماء المضمّنة', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(messages: <String>['أ']).saveLocally(p);
      expect(
        p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        'أ',
      );

      await const SettingsMarqueeSettings().saveLocally(p);
      expect(
        p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        isNull,
      );
    });

    test('الحمولة تحمل العمودين الجديدين، وmarquee_text = أول حديث', () {
      final Map<String, dynamic> payload = const SettingsMarqueeSettings(
        messages: <String>['حديث أول', 'حديث ثانٍ'],
        intervalMs: 3000,
        fontSize: 400, // شاذ → يُقيَّد
      ).toRemotePayload();

      expect(payload['marquee_messages'], 'حديث أول\nحديث ثانٍ');
      expect(payload['marquee_interval_ms'], 3000);
      expect(
        payload['marquee_text'],
        'حديث أول',
        reason: 'النسخ المثبَّتة القديمة تقرأ النص الواحد',
      );
      expect(payload['marquee_font_size'], SettingsMarqueeSettings.maxFontSize);
    });

    test('بلا أحاديث: الحمولة تمسح العمود وتحفظ النص الواحد', () {
      final Map<String, dynamic> payload =
          const SettingsMarqueeSettings(text: 'نص').toRemotePayload();

      expect(payload['marquee_messages'], '');
      expect(payload['marquee_text'], 'نص');
      expect(
        payload['marquee_interval_ms'],
        SettingsMarqueeSettings.defaultIntervalMs,
      );
    });

    test('من السيرفر: الأحاديث ووقت الظهور يُطبَّقان محلياً', () async {
      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{
          'marquee_messages': 'حديث أول\nحديث ثانٍ',
          'marquee_interval_ms': 2500,
        },
      );

      expect(applied.messages, <String>['حديث أول', 'حديث ثانٍ']);
      expect(applied.intervalMs, 2500);
      expect(applied.effectiveMessages.length, 2);

      final SharedPreferences p = await prefs();
      expect(
        p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        'حديث أول\nحديث ثانٍ',
      );
      expect(p.getInt(RemoteMessagingService.settingsMarqueeIntervalKey), 2500);
    });

    test('عمود فارغ من السيرفر يمحو المخصص ويعود للنص الواحد', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        text: 'نص',
        messages: <String>['أ'],
      ).saveLocally(p);

      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{'marquee_messages': ''},
      );

      expect(applied.messages, isEmpty);
      expect(applied.effectiveMessages, <String>['نص']);
      expect(
        p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        isNull,
      );
    });

    test('وقت ظهور شاذ من السيرفر يُقيَّد لا يُكسر', () async {
      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{'marquee_interval_ms': '50'},
      );

      expect(applied.intervalMs, SettingsMarqueeSettings.minIntervalMs);
    });

    test('صف قديم بلا الأعمدة الجديدة لا يمسّ الأحاديث المحفوظة', () async {
      final SharedPreferences p = await prefs();
      await const SettingsMarqueeSettings(
        messages: <String>['محفوظ'],
        intervalMs: 9000,
      ).saveLocally(p);

      final SettingsMarqueeSettings applied =
          await RemoteMessagingService.applySettingsMarqueeConfig(
        <String, dynamic>{'marquee_text': 'نص جديد'},
      );

      expect(applied.messages, <String>['محفوظ']);
      expect(applied.intervalMs, 9000);
      expect(applied.effectiveMessages, <String>['محفوظ']);
    });
  });
}
