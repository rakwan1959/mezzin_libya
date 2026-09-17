import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:muezzin_libya_app/user_messaging_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// المراسلة بين المستخدمين بمعرّف الجهاز فقط:
///   1. معرّف الجهاز بصيغة USR-XXXXXX ويُنشأ مرة واحدة.
///   2. معرّف رسالة المستخدم يبدأ بـ dm_ ويحمل المُرسِل ولا يتكرر.
///   3. اسم المُرسِل يُستخرج من عنوان الرسالة ليظهر للمستلم.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('معرّف الجهاز', () {
    test('يُنظَّف من المسافات ويُحوَّل إلى حروف كبيرة', () {
      expect(
        RemoteMessagingService.normalizeDeviceId(' usr-r7umaw '),
        'USR-R7UMAW',
      );
      expect(
        RemoteMessagingService.normalizeDeviceId('usr r7u maw'),
        'USRR7UMAW',
      );
    });

    test('رمز الجهاز بلا شرطة', () {
      expect(RemoteMessagingService.deviceTag('usr-r7umaw'), 'USRR7UMAW');
    });

    test('يُنشأ مرة واحدة بالصيغة USR-XXXXXX ويُحفظ', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final String first = await RemoteMessagingService.getOrCreateUserId();
      final String again = await RemoteMessagingService.myDeviceId();

      expect(first, again);
      expect(RegExp(r'^USR-[A-Z0-9]{6}$').hasMatch(first), isTrue);
    });
  });

  group('معرّفات رسائل المستخدمين', () {
    test('تبدأ بـ dm_ وتُختم برمز المُرسِل ولا تتكرر', () {
      final String id1 = RemoteMessagingService.buildUserMessageId('USR-R7UMAW');
      final String id2 = RemoteMessagingService.buildUserMessageId('USR-R7UMAW');

      expect(id1.startsWith('dm_'), isTrue);
      expect(id1.endsWith('USRR7UMAW'), isTrue);
      expect(id1, isNot(id2), reason: 'معرّفان في نفس اللحظة يجب ألا يتطابقا');
    });

    test('تُميَّز عن رسائل الإدارة', () {
      expect(RemoteMessagingService.isUserMessageId('dm_12_USRABC'), isTrue);
      expect(
        RemoteMessagingService.isUserMessageId('hidden_update_12'),
        isFalse,
      );
    });

    test('اسم المُرسِل يُستخرج من عنوان الرسالة', () {
      expect(
        RemoteMessagingService.senderFromTitle('رسالة من USR-R7UMAW'),
        'USR-R7UMAW',
      );
      expect(
        RemoteMessagingService.senderFromTitle('تحديث جديد متوفر'),
        'تحديث جديد متوفر',
      );
      expect(RemoteMessagingService.senderFromTitle(''), '');
    });
  });

  group('الرقم السري الذي يفتح الغرفة', () {
    test('يقبل الرقم الصحيح بمسافات أو بأرقام عربية/هندية', () {
      expect(UserMessagingScreen.isRoomPasscodeCorrect('1959'), isTrue);
      expect(UserMessagingScreen.isRoomPasscodeCorrect(' 1959 '), isTrue);
      expect(UserMessagingScreen.isRoomPasscodeCorrect('١٩٥٩'), isTrue);
      expect(UserMessagingScreen.isRoomPasscodeCorrect('۱۹۵۹'), isTrue);
    });

    test('يرفض أي رقم آخر', () {
      expect(UserMessagingScreen.isRoomPasscodeCorrect(''), isFalse);
      expect(UserMessagingScreen.isRoomPasscodeCorrect('1918'), isFalse);
      expect(UserMessagingScreen.isRoomPasscodeCorrect('19590'), isFalse);
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('1916'),
        isFalse,
        reason: 'أرقام اللوحات الأخرى لا تفتح الغرفة',
      );
      expect(UserMessagingScreen.isRoomPasscodeCorrect('abc'), isFalse);
    });

    test('يقبل الرقم القادم من اللوحة بأرقام عربية/هندية', () {
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('2026', expected: '٢٠٢٦'),
        isTrue,
      );
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('٢٠٢٦', expected: '2026'),
        isTrue,
      );
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('2027', expected: '2026'),
        isFalse,
      );
    });

    test('الرقم السري مضبوط وغير فارغ', () {
      expect(UserMessagingScreen.roomPasscode.trim(), isNotEmpty);
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect(
          UserMessagingScreen.roomPasscode,
        ),
        isTrue,
      );
    });
  });

  group('الرقم السري من إعدادات السيرفر (app_config)', () {
    test('رقم اللوحة يُحفظ محلياً ويسبق الرقم المضمَّن', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'room_passcode_remote': '2026',
      });

      expect(await RemoteMessagingService.getRemoteRoomPasscode(), '2026');
      expect(await UserMessagingScreen.resolveRoomPasscode(), '2026');

      final String expected = await UserMessagingScreen.resolveRoomPasscode();
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('2026', expected: expected),
        isTrue,
      );
      expect(
        UserMessagingScreen.isRoomPasscodeCorrect('1959', expected: expected),
        isFalse,
        reason: 'رقم اللوحة يلغي الرقم المضمَّن',
      );
    });

    test('بلا رقم على السيرفر → يبقى الرقم المضمَّن احتياطاً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      expect(await RemoteMessagingService.getRemoteRoomPasscode(), isNull);
      expect(
        await UserMessagingScreen.resolveRoomPasscode(),
        UserMessagingScreen.roomPasscode,
      );
    });
  });

  group('عرض الرسالة', () {
    test('الوقت يُعرض بصيغة مختصرة بالتوقيت المحلي', () {
      final UserMessage m = UserMessage(
        id: 'dm_1_USRX',
        body: 'السلام عليكم',
        otherDeviceId: 'USR-R7UMAW',
        outgoing: false,
        createdAt: '2026-09-14T11:37:05.000+00:00',
      );

      expect(m.time, isNotNull);
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2}  \d{2}:\d{2}$').hasMatch(m.displayTime),
        isTrue,
        reason: 'صيغة العرض: 2026-09-14  13:37',
      );
      expect(m.otherLabel, 'USR-R7UMAW');
    });

    test('الرسالة العامة تُعرض باسم «الجميع»', () {
      const UserMessage m = UserMessage(
        id: 'dm_2_USRX',
        body: 'تعميم',
        otherDeviceId: '',
        outgoing: true,
        createdAt: '',
      );

      expect(m.otherLabel, 'الجميع');
      expect(m.displayTime, '');
    });

    test('عنوان الرسالة معرّف الجهاز وحده بلا «رسالة من»', () {
      expect(RemoteMessagingService.senderFromTitle('USR-R7UMAW'), 'USR-R7UMAW');
      expect(
        RemoteMessagingService.senderFromTitle('USR-ABC123'),
        'USR-ABC123',
        reason: 'يظهر معرّف الجهاز فقط في أعلى الرسالة',
      );
    });
  });

  group('صلاحية الإرسال لجميع المستخدمين (المدير)', () {
    test('الرقم السري 1508 يفتح الصلاحية بمسافات أو أرقام عربية/هندية', () {
      expect(UserMessagingScreen.adminBroadcastPasscode, '1508');
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('1508'),
        isTrue,
      );
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect(' ١٥٠٨ '),
        isTrue,
      );
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('۱۵۰۸'),
        isTrue,
      );
    });

    test('أي رقم آخر لا يفتح الصلاحية', () {
      expect(UserMessagingScreen.isAdminBroadcastPasscodeCorrect(''), isFalse);
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('1509'),
        isFalse,
      );
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('1959'),
        isFalse,
      );
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('1918'),
        isFalse,
      );
    });

    test('رقم الغرفة ورقم الصلاحية لا يتبادلان العمل', () {
      expect(UserMessagingScreen.isRoomPasscodeCorrect('1508'), isFalse);
      expect(
        UserMessagingScreen.isAdminBroadcastPasscodeCorrect('1959'),
        isFalse,
      );
    });
  });

  group('حذف الرسائل المستلمة', () {
    test('الرسالة المحذوفة تُخفى على الجهاز ولا تعود إليه', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await RemoteMessagingService.hiddenUserMessageIds(), isEmpty);

      await RemoteMessagingService.hideUserMessagesLocally(<String>[
        'dm_1_USRX',
      ]);
      await RemoteMessagingService.hideUserMessagesLocally(<String>[
        ' dm_1_USRX ',
        'dm_2_USRY',
      ]);

      final Set<String> hidden =
          await RemoteMessagingService.hiddenUserMessageIds();
      expect(hidden, <String>{'dm_1_USRX', 'dm_2_USRY'});
    });

    test('قائمة فارغة لا تُخفي شيئاً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await RemoteMessagingService.hideUserMessagesLocally(<String>['  ', '']);
      expect(await RemoteMessagingService.hiddenUserMessageIds(), isEmpty);
    });
  });

  // ── حذف جميع الرسائل (التطبيق + قاعدة البيانات) ─────────────────────
  group('حذف جميع الرسائل', () {
    test('يُخفي كل شيء محلياً ويُرجع false إن تعذّر الوصول للسحابة', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // بلا Supabase مُهيّأ: قراءة قائمة السحابة تفشل، فلا يجوز أن يُقال
      // «تم الحذف» — الإخفاء المحلي يحدث، والنتيجة تُبلّغ بالفشل بصدق.
      final bool ok = await RemoteMessagingService.deleteAllUserMessages();

      expect(
        ok,
        isFalse,
        reason: 'لا يُبلَّغ بالنجاح بينما الرسائل ما زالت على السحابة',
      );
    });

    test('قائمة معرّفات السحابة فارغة بلا اتصال (لا انهيار)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      expect(await RemoteMessagingService.allUserMessageIds(), isEmpty);
    });

    test('الفشل لا يُخفي رسائل لم تُطلب (لا ضرر جانبي)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await RemoteMessagingService.deleteAllUserMessages();

      expect(
        await RemoteMessagingService.hiddenUserMessageIds(),
        isEmpty,
        reason: 'لم تُقرأ أي معرّفات فلا يُخفي شيء',
      );
    });
  });
}
