# دليل بناء تطبيق iOS (مؤذن ليبيا)

> **قاعدة ذهبية:** بناء iOS يتطلب **macOS + Xcode**. أدوات Apple
> (`xcodebuild`، و`pod install` لأهداف iOS) لا تعمل على Windows.
> هذه الصفحة تشرح الطرق الثلاث المتاحة.

---

## 0. جاهزية المشروع (منجزة في هذا المستودع)

| البند | الحالة |
|---|---|
| مجلد `ios/` كامل (مشروع Xcode، storyboards، أيقونات كل المقاسات) | ✅ |
| `Info.plist` بالأذونات العربية (موقع، ميكروفون، تعرّف على الكلام) | ✅ |
| أصوات الأذان بصيغة `.caf` (8 أصوات) في `ios/Runner/sounds/` ومسجّلة في المشروع | ✅ |
| Podfile مضبوط على iOS 14 مع الإضافات كلها | ✅ |
| كود Dart يتعامل مع iOS بأمان (كل قنوات الأندرويد محمية بـ `Platform.isAndroid`) | ✅ |
| إشعارات iOS عبر `DarwinNotificationDetails` (حرِج + صوت مخصص) | ✅ |
| سير عمل GitHub Actions جاهز: `.github/workflows/build_ios.yml` | ✅ |

---

## 1. الطريقة الأسهل: البناء السحابي عبر GitHub Actions (بدون Mac)

1. ارفع المشروع إلى مستودع GitHub (عام — الـ runners المجانية macOS).
2. من تبويب **Actions** اختر **Build iOS** ثم **Run workflow**.
3. بعد انتهاء البناء (~15–25 دقيقة) نزّل الأرتيفاكت
   `muezzin-ios-ipa-<رقم البناء>` — ستجد بداخله:
   `muezzin_libya_app_v<رقم>.ipa`

الـ IPA الناتج **غير موقّع** ويصلح لـ:
- **AltStore / SideStore** (تثبيت مجاني بحساب Apple عادي — 7 أيام ثم إعادة تثبيت)
- **Sideloadly** على Windows/Mac
- **TrollStore** (للإصدارات المدعومة فقط)

### التوقيع الكامل (App Store / TestFlight) — اختياري

أضف في **Settings → Secrets and variables → Actions**:

| السر | القيمة |
|---|---|
| `APPLE_CERTIFICATE_P12` | شهادة Apple Distribution (base64) |
| `APPLE_CERTIFICATE_PASSWORD` | كلمة سر الـ P12 |
| `APPLE_TEAM_ID` | معرّف فريق المطور |
| `KEYCHAIN_PASSWORD` | أي كلمة سر قوية للـ keychain المؤقت |
| `APP_STORE_CONNECT_ISSUER_ID` | لـ TestFlight (اختياري) |
| `APP_STORE_CONNECT_KEY_ID` | لـ TestFlight (اختياري) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | محتوى مفتاح `.p8` (اختياري) |

ثم راجع قسم التوقيع في `build_ios.yml` (الخطوات معطّلة بتعليق
`if: false` — فعّلها بعد إضافة الأسرار).

---

## 2. البناء محلياً على Mac

```bash
# المتطلبات: Xcode 15+ مع Command Line Tools، CocoaPods، Flutter 3.41+
flutter pub get
cd ios && pod install && cd ..

# للتجربة على محاكي أو جهاز موصول:
flutter run -d <device-id>

# لإنتاج IPA:
flutter build ipa --release           # يتطلب توقيعاً صحيحاً في Xcode
flutter build ipa --no-codesign       # IPA غير موقّع (للـ sideload)
# المخرج: build/ios/ipa/*.ipa
```

افتح `ios/Runner.xcworkspace` (وليس `.xcodeproj`) في Xcode لضبط:
- **Signing & Capabilities**: Team + Bundle ID خاص بك
- غيّر `PRODUCT_BUNDLE_IDENTIFIER` من `com.example.muezzinLibyaApp`
  إلى معرّف حقيقي (مثل `ly.muezzin.app`) في **Debug/Release/Profile**

---

## 3. خدمة سحابية مدفوعة (بدون Mac ولا GitHub)

- **Codemagic** (من Flutter — الأنسب لهذا المشروع): 500 دقيقة/شهر مجاناً
- **FlutterFlow / AppCircle / Bitrise**: بدائل تجارية

في Codemagic: اربط المستودع، اختر Workflow **Flutter App**،
iOS → `Release`، وسيبني وينتج IPA (مع توقيع إن أضفت شهاداتك).

---

## ملاحظات وظيفية على iOS

- **الأذان في الخلفية:** يعتمد iOS على إشعارات مجدولة (`UNUserNotificationCenter`)
  بصوت مخصص `.caf` — كود Dart يمرر `$soundName.caf` وهذه الملفات أُضيفت الآن
  إلى `ios/Runner/sounds/` وحزمة المشروع. الصوت الحرج
  (`InterruptionLevel.critical`) يحتاج موافقة Apple على صلاحية
  **Critical Alerts** إن أردت سماعه على الوضع الصامت.
- **الأذان المتصل (Foreground Service):** خاصية أندرويد فقط؛ على iOS
  يعمل التطبيق بالتنبيهات المجدولة، والصوت داخل التطبيق عبر `just_audio`.
- **القبلة:** البوصلة عبر `flutter_compass` تعمل على iPhone (له مغناطيس).
- **شاشة الأقفال:** الإشعارات الحرِجة تظهر فوق شاشة القفل تلقائياً.

## استكشاف الأخطاء

| المشكلة | الحل |
|---|---|
| `pod install` يفشل على الوسائط | `pod repo update` ثم أعد المحاولة |
| خطأ توقيع `No profiles` | اختر Team في Xcode وأعد `flutter build ipa` |
| لا صوت أذان على iOS | تأكد من وجود `.caf` في الحزمة: `ls build/ios/iphoneos/Runner.app/*.caf` |
| إشعارات لا تظهر | اسمح بالإشعارات من الإعدادات عند أول تشغيل |
