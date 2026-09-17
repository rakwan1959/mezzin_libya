import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:muezzin_libya_app/remote_messaging_service.dart';

/// النص المتحرك في الشاشة الرئيسية — إعداداته كلها من لوحة التحكم (1918).
///
/// هذه الاختبارات تحرس أربعة أشياء كانت موضع الخلل:
///   1. الحفظ المحلي يعمل حتى لو تعذّر النشر على السيرفر (فتظهر النتيجة
///      على الجهاز فوراً ولا يعود الزر بلا أثر).
///   2. الخط الافتراضي **كايرو عادي (غير غليظ)**، والحجم والسرعة واللون
///      قابلة للتحكم.
///   3. القيم الشاذة الواردة من السيرفر تُقيَّد داخل الحدود المعقولة.
///   4. التفعيل ووقت الظهور بعد الأذان يعملان كما هما مضبوطان من اللوحة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('الإعدادات الافتراضية للنص المتحرك', () {
    test('الخط كايرو عادي والحجم 10 والسرعة 2.8 ثانية والتشغيل مُفعَّل', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings();

      expect(s.enabled, isTrue, reason: 'النص المتحرك مُفعَّل افتراضياً');
      expect(s.fontFamily, 'Cairo', reason: 'الخط الافتراضي كايرو');
      expect(s.bold, isFalse, reason: 'غير غليظ — كايرو عادي');
      expect(s.fontSize, 10);
      expect(s.intervalMs, 2800);
      expect(s.intervalSeconds, closeTo(2.8, 0.001));
      expect(s.afterMinutes, 15);
      // الافتراضي: يتبع ألوان أوقات الصلاة (لا لون ثابت)
      expect(s.followsPrayerColors, isTrue);
      expect(s.color, HomeMarqueeSettings.followPrayerColorsValue);
      expect(s.text, isEmpty);
    });

    test('لا شيء محفوظ بعد → القيم الافتراضية نفسها', () async {
      final HomeMarqueeSettings s = HomeMarqueeSettings.fromPrefs(
        await prefs(),
      );
      expect(s.fontFamily, 'Cairo');
      expect(s.bold, isFalse);
      expect(s.fontSize, 10);
      expect(s.intervalMs, 2800);
      expect(s.enabled, isTrue);
    });

    test('قائمة الخطوط في اللوحة تبدأ بكايرو (الافتراضي)', () {
      expect(RemoteMessagingService.homeDuaFonts.first, 'Cairo');
      expect(RemoteMessagingService.homeDuaFonts, contains('Amiri'));
      expect(RemoteMessagingService.homeDuaFonts, contains('Cairo'));
      expect(RemoteMessagingService.homeDuaFonts, contains('Almarai'));
    });
  });

  group('أسماء الخطوط', () {
    test('اسم معروف يُقبل كما هو (بلا حساسية لحالة الأحرف)', () {
      expect(HomeMarqueeSettings.normalizeFont('Amiri'), 'Amiri');
      expect(HomeMarqueeSettings.normalizeFont('amiri'), 'Amiri');
      expect(HomeMarqueeSettings.normalizeFont('  Cairo  '), 'Cairo');
      expect(
        HomeMarqueeSettings.normalizeFont('Noto Kufi Arabic'),
        'Noto Kufi Arabic',
      );
    });

    test('اسم مجهول أو فارغ يعود إلى كايرو (الافتراضي)', () {
      expect(HomeMarqueeSettings.normalizeFont(''), 'Cairo');
      expect(HomeMarqueeSettings.normalizeFont(null), 'Cairo');
      expect(HomeMarqueeSettings.normalizeFont('Comic Sans'), 'Cairo');
    });

    test('كل خط في القائمة له نمط فعلي بالعائلة الصحيحة', () {
      for (final String f in RemoteMessagingService.homeDuaFonts) {
        final TextStyle style = HomeMarqueeSettings.googleFontStyle(f);
        // google_fonts يسمّي العائلة باسم الخط + لاحقة المتغير (مثل
        // Amiri_regular)، فيكفي التحقق من بادئة الاسم بلا مسافات.
        final String expected = f.toLowerCase().replaceAll(' ', '');
        final String actual = (style.fontFamily ?? '').toLowerCase();
        expect(
          actual.startsWith(expected),
          isTrue,
          reason: 'الخط «$f» يجب أن يُحلّ إلى عائلته (وُجد: ${style.fontFamily})',
        );
      }
    });

    test('الافتراضي كايرو عادي (w400) وليس غليظاً', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(color: 0xFF00E676);

      final TextStyle style = s.textStyle();
      expect(style.fontFamily?.toLowerCase(), startsWith('cairo'));
      expect(style.fontWeight, FontWeight.w400,
          reason: 'المطلوب كايرو عادي — لا غليظ');
    });

    test('نمط النص يحمل الحجم والوزن واللون المضبوطين', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        fontFamily: 'Amiri',
        fontSize: 18,
        bold: true,
        color: 0xFF00E676,
      );
      final TextStyle style = s.textStyle();

      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, const Color(0xFF00E676));
      expect(style.fontFamily!.toLowerCase(), startsWith('amiri'));

      final TextStyle light = s.copyWith(bold: false).textStyle();
      expect(light.fontWeight, FontWeight.w400);
    });
  });

  group('حدود القيم (حماية من قيم السيرفر الشاذة)', () {
    test('حجم الخط بين 8 و30', () {
      expect(HomeMarqueeSettings.clampFontSize(null), 10);
      expect(HomeMarqueeSettings.clampFontSize(2), 8);
      expect(HomeMarqueeSettings.clampFontSize(99), 30);
      expect(HomeMarqueeSettings.clampFontSize(14), 14);
    });

    test('سرعة التقليب بين 0.6 و20 ثانية', () {
      expect(HomeMarqueeSettings.clampInterval(null), 2800);
      expect(HomeMarqueeSettings.clampInterval(50), 600);
      expect(HomeMarqueeSettings.clampInterval(999999), 20000);
      expect(HomeMarqueeSettings.clampInterval(4000), 4000);
    });

    test('وقت الظهور بين 0 و240 دقيقة', () {
      expect(HomeMarqueeSettings.clampAfterMinutes(null), 15);
      expect(HomeMarqueeSettings.clampAfterMinutes(-5), 0);
      expect(HomeMarqueeSettings.clampAfterMinutes(999), 240);
    });

    test('القيم المحفوظة الشاذة تُقيَّد عند القراءة', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        RemoteMessagingService.homeDuaFontKey: 'خط غريب',
        RemoteMessagingService.homeDuaFontSizeKey: 500,
        RemoteMessagingService.homeDuaIntervalKey: 1,
        RemoteMessagingService.homeDuaAfterMinutesKey: -20,
      });

      final HomeMarqueeSettings s = HomeMarqueeSettings.fromPrefs(
        await prefs(),
      );
      expect(s.fontFamily, 'Cairo');
      expect(s.fontSize, 30);
      expect(s.intervalMs, 600);
      expect(s.afterMinutes, 0);
    });
  });

  group('تقسيم النص إلى عبارات', () {
    test('نص فارغ = لا عبارات (فتُعرض الأدعية الافتراضية)', () {
      expect(const HomeMarqueeSettings().phrases, isEmpty);
      expect(const HomeMarqueeSettings(text: '   ').phrases, isEmpty);
    });

    test('سطر واحد = عبارة واحدة', () {
      expect(const HomeMarqueeSettings(text: 'سبحان الله').phrases, <String>[
        'سبحان الله',
      ]);
    });

    test('عدة أسطر = عدة عبارات بلا أسطر فارغة', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        text: 'سبحان الله\n\nالحمد لله\n  الله أكبر  ',
      );
      expect(s.phrases, <String>['سبحان الله', 'الحمد لله', 'الله أكبر']);
    });

    test('الفصل بنقطة فاصلة • يعمل أيضاً', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        text: 'اللهم • ارزقنا •  •  العافية',
      );
      expect(s.phrases, <String>['اللهم', 'ارزقنا', 'العافية']);
    });
  });

  group('الظهور بعد الأذان', () {
    test('مُعطَّل → لا يظهر أبداً', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        enabled: false,
        afterMinutes: 0,
      );
      expect(s.shouldShow(minutesSincePrevPrayer: 999), isFalse);
    });

    test('0 دقيقة = يظهر دائماً بلا انتظار', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(afterMinutes: 0);
      expect(s.shouldShow(minutesSincePrevPrayer: 0), isTrue);
    });

    test('15 دقيقة (الافتراضي): لا يظهر قبلها ويظهر عندها', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings();
      expect(s.shouldShow(minutesSincePrevPrayer: 14), isFalse);
      expect(s.shouldShow(minutesSincePrevPrayer: 15), isTrue);
      expect(s.shouldShow(minutesSincePrevPrayer: 60), isTrue);
    });

    test('تسمية وقت الظهور كما تُعرض في اللوحة', () {
      expect(const HomeMarqueeSettings(afterMinutes: 0).afterLabel, 'يظهر دائماً');
      expect(
        const HomeMarqueeSettings(afterMinutes: 20).afterLabel,
        'بعد 20 دقيقة من الأذان',
      );
    });
  });

  group('الحفظ والنشر', () {
    test('الحفظ المحلي يُطبَّق فوراً على كل الإعدادات', () async {
      final SharedPreferences p = await prefs();
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        enabled: true,
        text: 'اللهم ارزقنا\nوأكرمنا',
        color: 0xFF00E5FF,
        fontFamily: 'Tajawal',
        fontSize: 22,
        intervalMs: 4500,
        bold: false,
        afterMinutes: 0,
      );

      await s.saveLocally(p);
      final HomeMarqueeSettings saved = HomeMarqueeSettings.fromPrefs(p);

      expect(saved.enabled, isTrue);
      expect(saved.text, 'اللهم ارزقنا\nوأكرمنا');
      expect(saved.phrases, <String>['اللهم ارزقنا', 'وأكرمنا']);
      expect(saved.color, 0xFF00E5FF);
      expect(saved.fontFamily, 'Tajawal');
      expect(saved.fontSize, 22);
      expect(saved.intervalMs, 4500);
      expect(saved.bold, isFalse);
      expect(saved.afterMinutes, 0);
    });

    test('نص فارغ يمسح النص المخصص ويُعيد الأدعية الافتراضية', () async {
      final SharedPreferences p = await prefs();
      await const HomeMarqueeSettings(text: 'نص قديم').saveLocally(p);
      expect(p.getString(RemoteMessagingService.homeDuaTextKey), 'نص قديم');

      await const HomeMarqueeSettings().saveLocally(p);
      expect(p.containsKey(RemoteMessagingService.homeDuaTextKey), isFalse);
      expect(
        HomeMarqueeSettings.fromPrefs(p).phrases,
        isEmpty,
        reason: 'فارغ = الأدعية الافتراضية تُعرض من التطبيق',
      );
    });

    test('الحمولة المُرسلة للسيرفر تحمل كل الإعدادات بلا نقص', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings(
        text: 'نص',
        fontFamily: 'Almarai',
        fontSize: 16,
        intervalMs: 3200,
        bold: true,
        afterMinutes: 30,
        color: 0xFFE040FB,
      );
      final Map<String, dynamic> payload = s.toRemotePayload();

      expect(payload['home_dua_enabled'], isTrue);
      expect(payload['home_dua_text'], 'نص');
      expect(payload['home_dua_color'], 0xFFE040FB);
      expect(payload['home_dua_font'], 'Almarai');
      expect(payload['home_dua_font_size'], 16);
      expect(payload['home_dua_interval_ms'], 3200);
      expect(payload['home_dua_bold'], isTrue);
      expect(payload['home_dua_after_minutes'], 30);
    });

    test(
      'النشر يحفظ على الجهاز حتى لو تعذّر الوصول للسيرفر (الخلل الأصلي)',
      () async {
        const HomeMarqueeSettings s = HomeMarqueeSettings(
          text: 'اللهم تقبّل',
          fontFamily: 'Cairo',
          fontSize: 20,
          intervalMs: 4000,
          afterMinutes: 0,
        );

        // لا يوجد اتصال بـ Supabase في الاختبار → النشر يفشل
        final bool ok = await RemoteMessagingService.publishHomeMarquee(s);

        expect(ok, isFalse, reason: 'السيرفر غير متاح في الاختبار');

        final HomeMarqueeSettings saved =
            await RemoteMessagingService.readHomeMarqueeSettings();
        expect(
          saved.text,
          'اللهم تقبّل',
          reason: 'كان الزر يفشل بلا أثر محلي — الآن الحفظ المحلي يسبق النشر',
        );
        expect(saved.fontFamily, 'Cairo');
        expect(saved.fontSize, 20);
        expect(saved.intervalMs, 4000);
        expect(saved.afterMinutes, 0);
      },
    );

    test('إعادة الضبط تُعيد الافتراضيات محلياً', () async {
      final SharedPreferences p = await prefs();
      await const HomeMarqueeSettings(
        enabled: false,
        text: 'نص',
        fontFamily: 'Cairo',
        fontSize: 28,
        intervalMs: 9000,
        bold: false,
        afterMinutes: 60,
      ).saveLocally(p);

      final bool ok = await RemoteMessagingService.resetHomeMarquee();
      expect(ok, isFalse, reason: 'السيرفر غير متاح في الاختبار');

      final HomeMarqueeSettings saved = HomeMarqueeSettings.fromPrefs(p);
      expect(saved.enabled, isTrue);
      expect(saved.text, isEmpty);
      expect(saved.fontFamily, 'Cairo');
      expect(saved.fontSize, 10);
      expect(saved.intervalMs, 2800);
      expect(saved.bold, isFalse);
      expect(saved.afterMinutes, 15);
      // إعادة الضبط تعيد «يتبع ألوان أوقات الصلاة»
      expect(saved.followsPrayerColors, isTrue);
    });
  });

  group('copyWith', () {
    test('يغيّر الحقل المطلوب ويُبقي البقية', () {
      const HomeMarqueeSettings s = HomeMarqueeSettings();
      final HomeMarqueeSettings changed = s.copyWith(
        fontFamily: 'Almarai',
        fontSize: 24,
        afterMinutes: 0,
      );

      expect(changed.fontFamily, 'Almarai');
      expect(changed.fontSize, 24);
      expect(changed.afterMinutes, 0);
      expect(changed.intervalMs, s.intervalMs);
      expect(changed.bold, s.bold);
      expect(changed.color, s.color);
    });
  });
}
