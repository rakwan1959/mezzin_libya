# دليل بناء تطبيق iOS (مؤذن ليبيا)

> **قاعدة ذهبية:** بناء iOS يتطلب **macOS + Xcode**. أدوات Apple
> (`xcodebuild`، و`pod install` لأهداف iOS) لا تعمل على Windows.
> هذه الصفحة تشرح الطرق الثلاث المتاحة، ثم **التوقيع الكامل** خطوة بخطوة.

---

## 0. جاهزية المشروع (منجزة في هذا المستودع)

| البند | الحالة |
|---|---|
| مجلد `ios/` كامل (مشروع Xcode، storyboards، أيقونات كل المقاسات) | ✅ |
| `Info.plist` بالأذونات العربية (موقع، ميكروفون، تعرّف على الكلام) | ✅ |
| أصوات الأذان بصيغة `.caf` (8 أصوات) في `ios/Runner/sounds/` ومسجّلة في المشروع | ✅ |
| أيقونات معتمة بلا قناة شفافية (شرط App Store — خطأ `ITMS-90717`) | ✅ |
| Podfile مضبوط على iOS 14 مع الإضافات كلها | ✅ |
| كود Dart يتعامل مع iOS بأمان (كل قنوات الأندرويد محمية بـ `Platform.isAndroid`) | ✅ |
| إشعارات iOS عبر `DarwinNotificationDetails` (حرِج + صوت مخصص) | ✅ |
| سير عمل البناء: `.github/workflows/build_ios.yml` | ✅ |
| سير عمل لقطات الشاشة: `.github/workflows/ios_screenshots.yml` | ✅ |

---

## 1. الطريقة الأسهل: البناء السحابي عبر GitHub Actions (بدون Mac)

1. ارفع المشروع إلى مستودع GitHub (عام — الـ runners المجانية macOS).
2. من تبويب **Actions** اختر **Build iOS** ثم **Run workflow**.
3. بعد انتهاء البناء (~15–25 دقيقة) نزّل الأرتيفاكت
   `muezzin-ios-ipa-<رقم البناء>` — بداخله `muezzin_libya_app_v<رقم>.ipa`

الـ IPA الناتج **غير موقّع** ويصلح لـ:
- **AltStore / SideStore** (تثبيت مجاني بحساب Apple عادي — 7 أيام ثم إعادة تثبيت)
- **Sideloadly** على Windows/Mac → الدليل الكامل في
  [`docs/INSTALL_IPA_SIDELOADLY.md`](INSTALL_IPA_SIDELOADLY.md)
- **TrollStore** (للإصدارات المدعومة فقط)

> إن أضفت أسرار التوقيع (القسم 1.1) سيُنتج نفس التشغيل **نسخة موقّعة إضافية**
> باسم `muezzin-ios-signed-<رقم>` صالحة للنشر على App Store، بدون أي خطوة يدوية.

---

## 1.1 التوقيع الكامل (App Store / TestFlight) — خطوة بخطوة

كل ما تحتاجه مرّة واحدة: حساب **Apple Developer Program** (99$/سنة).

### الخطوة 1: Team ID

1. افتح <https://developer.apple.com/account> → **Membership Details**.
2. انسخ **Team ID** (10 أحرف، مثل `A1B2C3D4E5`).

### الخطوة 2: App ID (معرّف الحزمة)

1. **Certificates, Identifiers & Profiles** → **Identifiers** → زر **+**
2. **App IDs** → **App** → Continue.
3. **Bundle ID** صريح (Explicit) مثل `ly.muezzin.app`
   — لا تستخدم `com.example.*` (لن يُقبل في App Store Connect).
4. Continue → Register.

### الخطوة 3: شهادة التوزيع Apple Distribution (.p12)

على جهاز **Mac** (أو أي جهاز مع Keychain Access):

1. **Keychain Access** → قائمة **Keychain Access** → **Certificate Assistant**
   → **Request a Certificate From a Certificate Authority…**
   - أدخل بريدك، اختر **Saved to disk** → احفظ `CertificateSigningRequest.certSigningRequest`.
2. في Developer Portal → **Certificates** → **+** → **Apple Distribution**
   (أو *iOS Distribution*) → ارفع ملف الـ CSR → **Download** ملف `.cer`.
3. انقر الملف `.cer` مرّتين لإضافته إلى Keychain.
4. في Keychain Access → تبويب **My Certificates** → ابحث عن
   `Apple Distribution: …` → **كليك يمين → Export…** → صيغة `.p12`
   → ضع **كلمة سر قوية** واحفظها (ستصبح `APPLE_CERTIFICATE_PASSWORD`).

### الخطوة 4: Provisioning Profile للتوزيع

1. Developer Portal → **Profiles** → **+**
2. **Distribution** → **App Store Connect** → Continue.
3. اختر **App ID** الذي أنشأته في الخطوة 2.
4. اختر شهادة **Apple Distribution** من الخطوة 3.
5. أدخل **Profile Name** واضحاً (مثل `Muezzin Libya AppStore`) → Generate → **Download**.
   - هذا الاسم بالحرف هو `APPLE_PROVISIONING_PROFILE_NAME`.

### بديل: إنشاء الشهادة على Windows بلا Mac (OpenSSL)

`openssl` موجود في Git for Windows، فيمكن إنشاء الشهادة كلها من جهازك:

```bash
# 0) في Git Bash داخل مجلد آمن (لا تضعه داخل المشروع)
# 1) مفتاح خاص + طلب شهادة (CSR)
openssl req -new -newkey rsa:2048 -nodes \
  -keyout distribution.key \
  -out distribution.csr \
  -subj "/emailAddress=your@email.com/CN=Muezzin Libya Distribution/C=LY"

# 2) ارفع distribution.csr في: Certificates → + → Apple Distribution → Continue
#    ثم نزّل ملف الشهادة distribution.cer

# 3) حوّل الشهادة ثم ادمجها مع المفتاح في ملف .p12 واحد
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey distribution.key -in distribution.pem \
  -out distribution.p12 -name "Apple Distribution"
# سيسألك عن كلمة سر للـ p12 → هذه هي APPLE_CERTIFICATE_PASSWORD

# 4) تحقّق أن الـ p12 يحوي المفتاح والشهادة معاً
openssl pkcs12 -info -in distribution.p12 -noout
```

> ⚠️ لا ترفع `distribution.key` أو `distribution.p12` إلى المستودع أبداً — فقط
> محتواهما بصيغة Base64 كأسرار في GitHub. وإن فقدت `distribution.key` فلن
> يمكن استعمال الشهادة بعد ذلك وستحتاج إنشاء واحدة جديدة.

### الخطوة 5: تحويل الملفات إلى Base64

GitHub Secrets لا يقبل ملفات، فقط نص. حوّل الملفات إلى Base64:

```bash
# على macOS / Linux
base64 -w 0 AppleDistribution.p12        > cert.b64     # إن لم يعمل -w استخدم: base64 -i
base64 -w 0 Muezzin_Libya_AppStore.mobileprovision > profile.b64
```

```powershell
# على Windows (PowerShell) — إخراج في سطر واحد
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AppleDistribution.p12")) | Set-Content cert.b64 -NoNewline
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Muezzin_Libya_AppStore.mobileprovision")) | Set-Content profile.b64 -NoNewline
```

### الخطوة 6: الأسرار في GitHub

**Settings → Secrets and variables → Actions → New repository secret**

| السر | إلزامي؟ | القيمة |
|---|---|---|
| `APPLE_CERTIFICATE_P12` | ✅ | محتوى `cert.b64` (شهادة Apple Distribution) |
| `APPLE_CERTIFICATE_PASSWORD` | ✅ | كلمة سر الـ `.p12` من الخطوة 3 |
| `APPLE_TEAM_ID` | ✅ | Team ID من الخطوة 1 |
| `APPLE_BUNDLE_ID` | ✅ | معرّف الحزمة من الخطوة 2 (`ly.muezzin.app`) |
| `APPLE_PROVISIONING_PROFILE_NAME` | ✅ | اسم البروفايل من الخطوة 4 بالحرف |
| `APPLE_PROVISIONING_PROFILE` | ⭐ مُستحسن | محتوى `profile.b64` (يُثبَّت داخل الـ runner) |
| `KEYCHAIN_PASSWORD` | اختياري | أي كلمة سر قوية للـ keychain المؤقت |
| `APPLE_EXPORT_METHOD` | اختياري | `app-store-connect` (افتراضي) / `ad-hoc` / `development` |
| `APP_STORE_CONNECT_KEY_ID` | اختياري | لرفع TestFlight تلقائياً |
| `APP_STORE_CONNECT_ISSUER_ID` | اختياري | لرفع TestFlight تلقائياً |
| `APP_STORE_CONNECT_PRIVATE_KEY` | اختياري | محتوى ملف `AuthKey_XXXXXXXXXX.p8` |

### الخطوة 7: التشغيل

بمجرد وجود الأسرار الثلاثة الأساسية (P12 + كلمة السر + Team ID) سيعمل
**job «Sign & Export IPA»** تلقائياً في كل بناء، بلا تعديل أي ملف:

- يفحص `preflight` وجود الأسرار → يضبط `signing_ready`.
- إن لم تكن موجودة: البناء يستمر عادي و**يُنتج IPA غير موقّع فقط** (لا يفشل شيء).
- إن كانت موجودة: تُنتج نسخة موقّعة `muezzin-ios-signed-<رقم>`.

### الخطوة 8: TestFlight (اختياري)

1. أنشئ تطبيقاً في <https://appstoreconnect.apple.com> بنفس **Bundle ID** من الخطوة 2.
2. Developer Portal → **Keys** → **+** → اسم المفتاح → صلاحية **App Manager**
   → نزّل `AuthKey_XXXXXXXXXX.p8` (يُحمَّل مرّة واحدة فقط!) وانسخ **Key ID** و**Issuer ID**.
3. أضفها في Secrets بالأسرار الثلاثة أعلاه — وسيرفع البناء الموقّع تلقائياً بعد النجاح.
   > إن فشل الرفع التلقائي: نزّل أرتيفاكت `muezzin-ios-signed-<رقم>` وارفعه يدوياً
   > بتطبيق **Transporter** (مجاني على Mac) أو من Xcode.

### أسرار التوقيع في سير العمل — ماذا تفعل كل خطوة تقنياً

| الخطوة في `build_ios.yml` | عملها |
|---|---|
| `Import Apple Distribution certificate` | يفكّ base64، ينشئ keychain مؤقتاً، يستورد `.p12`، ويضبط `set-key-partition-list` (بدونها يطلب macOS تأكيداً تفاعلياً) |
| `Install provisioning profile` | يقرأ UUID من الملف ويسجّله باسمه في `~/Library/MobileDevice/Provisioning Profiles` (Xcode يبحث بالـ UUID لا باسم الملف) |
| `Configure bundle id, team & manual signing` | يستبدل `com.example.muezzinLibyaApp` بمعرّفك في `project.pbxproj` ويضبط `DEVELOPMENT_TEAM` و`CODE_SIGN_STYLE = Manual` و`PROVISIONING_PROFILE_SPECIFIER` |
| `Generate ExportOptions.plist` | يولّد ملف التصدير من أسرارك (method + teamID + profile) ويتحقق منه بـ `plutil -lint` |
| `Build signed IPA` | `flutter build ipa --export-options-plist=…` → المخرج في `build/ios/ipa/` |

> ملاحظتان: اسم المفتاح في الأسرار **حسّاس لحالة الأحرف** ولا تضع مسافات
> زائدة. والبروفايل يجب أن يطابق **نفس** معرّف الحزمة والشهادة، وإلا فشل
> التوقيع بخطأ `No signing certificate / No profiles` (انظر قسم الأخطاء أدناه).

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

## 4. لقطات شاشة App Store (بدون جهاز حقيقي)

سير العمل **iOS Screenshots (App Store)** ينتج اللقطات تلقائياً من المحاكي:

1. Actions → **iOS Screenshots (App Store)** → Run workflow.
   - حقل `only`: `both` (آيفون + آيباد) أو `iphone` أو `ipad`.
2. يختار أحدث محاكي متاح (iPhone 6.9" و iPad 13")، يمنح صلاحية الموقع مسبقاً،
   ويشغّل الاختبار `integration_test/app_store_screenshots_test.dart` عبر `flutter drive`
   مع `--dart-define=SCREENSHOT_MODE=true`.
3. الاختبار ينتقل بين التبويبات الخمسة (الرئيسية، المكتبة، القبلة، الإعدادات، عن التطبيق)
   ويلتقط لقطة لكل شاشة بأسماء مرتّبة (`01-…` حتى `05-…`).
4. الأرتيفاكتات: `appstore-screenshots-<device>-<رقم>` (الصور) و`…-log-…` (سجل التحفيز).
5. خطوة `Verify screenshot sizes` تطبع مقاس كل صورة وتنبّه إن لم يطابق
   المقاسات المطلوبة (1320×2868 للآيفون 6.9" و2064×2752 للآيباد 13").

**محلياً على Mac** (نفس ما يفعله السير العمل):

```bash
UDID=$(xcrun simctl list devices available | grep -m1 "iPhone 1" | \
       sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$UDID" || true
xcrun simctl privacy "$UDID" grant location-always com.example.muezzinLibyaApp
flutter drive --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/app_store_screenshots_test.dart \
  --dart-define=SCREENSHOT_MODE=true -d "$UDID"
# الصور في مجلد screenshots/
```

> **لماذا `SCREENSHOT_MODE`؟** على محاكي CI لا يوجد من يضغط «السماح» في حوار
> صلاحيات الإشعارات، وهذا الحوار يظهر داخل `NotificationService.init()` **قبل**
> `runApp` فيبقى الإقلاع معلّقاً ولا تظهر أي واجهة إطلاقاً (يظهر ذلك في سجل
> الاختبار كخطأ «انتهت المهلة قبل ظهور GlassNavIcon» مع طباعة محتوى الشاشة).
> العلم يُصفّر طلب صلاحيات iOS في الإقلاع، وقيمته الافتراضية `false` فلا
> يتأثر التطبيق المنشور.

> ملاحظة تقنية: اللقطات تُرسم من نوافذ التطبيق (`capturePngScreenshot`)، فإن
> غاب شريط الحالة العلوي في صورة ما فتلك مسألة تجميلية لا ترفضها Apple —
> ويمكن تجاوزها بأخذ لقطة من مستوى النظام: `xcrun simctl io booted screenshot out.png`.

> التطبيق يستهدف آيفون وآيباد معاً (`TARGETED_DEVICE_FAMILY = "1,2"`)، ولذلك
> تطلب Apple لقطات iPad أيضاً. إن أردت آيفون فقط فاجعل القيمة `"1"` في
> `ios/Runner.xcodeproj/project.pbxproj` (ثلاث مواضع) وستُستغنى عن لقطات iPad.

---

## ملاحظات وظيفية على iOS

- **الأذان في الخلفية:** يعتمد iOS على إشعارات مجدولة (`UNUserNotificationCenter`)
  بصوت مخصص `.caf` — كود Dart يمرر `$soundName.caf` وهذه الملفات مُضمّنة في
  `ios/Runner/sounds/` وحزمة المشروع. الصوت الحرج
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
| `No signing certificate "Apple Distribution" found` | الشهادة في `APPLE_CERTIFICATE_P12` ليست Distribution، أو كلمة السر خاطئة |
| `No profiles for 'com.example…' were found` | اضبط `APPLE_BUNDLE_ID` و`APPLE_PROVISIONING_PROFILE` — و`com.example.*` لا يُقبل للنشر |
| `Provisioning profile doesn't match …` | البروفايل ومعرّف الحزمة والشهادة يجب أن تكون من **نفس** الحساب |
| رفض `ITMS-90717 Invalid App Store Icon` | الأيقونات هنا معتمة أصلاً؛ تأكد أنك لم تستبدل `Icon-1024.png` بملف فيه شفافية |
| `ITMS-90076` أو خطأ رفع TestFlight | أنشئ سجل التطبيق في App Store Connect بنفس Bundle ID أولاً |
| لا صوت أذان على iOS | تأكد من وجود `.caf` في الحزمة: `ls build/ios/iphoneos/Runner.app/*.caf` |
| إشعارات لا تظهر | اسمح بالإشعارات من إعدادات التطبيق عند أول تشغيل |
