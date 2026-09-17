# تثبيت الـ IPA على iPhone عبر Sideloadly (Windows)

دليل خطوة بخطوة لتثبيت الملف الناتج من البناء:
`muezzin_libya_app_v<رقم>.ipa` (من أرتيفاكت `muezzin-ios-ipa-<رقم>` في GitHub Actions).

الطريقة لا تحتاج حساب مطوّر مدفوع ولا Mac — يكفي حساب Apple عادي (مجاني).

> **قبل أن تبدأ — القيود التي يجب أن تعرفها:**
> - التوقيع المجاني صالح **7 أيام** فقط، ثم يتوقف التطبيق عن العمل ويجب
>   إعادة تركيبه بنفس الطريقة (البيانات تبقى محفوظة عند إعادة التركيب).
> - الحد الأقصى **3 تطبيقات** موقّعة بحساب مجاني في الوقت نفسه.
> - يفضّل **app-specific password** بدل كلمة سر Apple ID، أو Passkey — ولا
>   تعطِ كلمة سرك لأي أداة لا تثق بها.

---

## 1) المتطلبات

| المطلوب | ملاحظة |
|---|---|
| Windows 10/11 | 64-bit |
| **iTunes** من موقع Apple | من <https://www.apple.com/itunes/> — **لا** نسخة Microsoft Store (تحديث DRIVERS فقط هو المهم فيها) |
| كيبل USB أصلي أو جيد | كيبلات الشحن الرخيصة سبب شائع لفشل التعرّف على الجهاز |
| iPhone بكلمة سر (Passcode) | — |
| حساب Apple ID | مجاني وكافٍ |
| ملف `muezzin_libya_app_v*.ipa` | بلا فكّ ضغط — Sideloadly يقبل الـ IPA مباشرة |

---

## 2) تجهيز الجهاز (مرّة واحدة)

1. **افتح قفل الآيفون** ووصّله بالكمبيوتر بالكيبل.
2. عند ظهور **Trust This Computer?** على الجهاز → **Trust** → أدخل رمز القفل.
3. على **iOS 16 وأحدث**: فعّل **Developer Mode**
   `Settings → Privacy & Security → Developer Mode → On` ثم **أعد تشغيل الجهاز**
   وأكّد التفعيل بعد الإقلاع.
   (قد لا يظهر الخيار إلا بعد أول عملية Sideload — إن لم تجده، كرّر هذه الخطوة
   بعد الخطوة 5.)
4. تأكد أن الجهاز يظهر في **File Explorer → This PC** قبل المتابعة.

---

## 3) تنزيل Sideloadly وتشغيله

1. نزّل Sideloadly من الموقع الرسمي: <https://sideloadly.io/> → **Download for Windows**.
2. ثبّته (Next → Next → Finish) ثم **شغّله كمسؤول** (Run as administrator)
   لتجنّب مشاكل تشغيل خدمة Apple Mobile Device.
3. سيتعرّف Sideloadly على جهازك تلقائياً ويظهر اسم الجهاز في الأعلى —
   إن لم يظهر: أعد تشغيل خدمة **Apple Mobile Device Service**:
   ```
   Win + R → services.msc → Apple Mobile Device Service → Restart
   ```

---

## 4) التثبيت (نفس الخطوات في كل مرّة)

1. **اسحب ملف الـ IPA** وأفلته في مربع **IPA** في نافذة Sideloadly
   (أو اضغط على المربع واختر الملف).
2. تأكد أن **Apple ID** مكتوب في حقل `Apple ID` (بريدك).
   - اترك `Sideloadly!` فارغاً و`sideloadly.io` فارغاً.
3. اضغط **Start**.
4. سيسألك عن كلمة سر Apple ID:
   - إن كان حسابك بلا مصادقة ثنائية: اكتب كلمة السر.
   - إن كان بمصادقة ثنائية: **لا تكتب كلمة سرك** — أنشئ
     **app-specific password** من <https://account.apple.com> →
     Sign-In & Security → App-Specific Passwords → `+` → أدخلها هنا.
     (Sideloadly نفسه يعرض زرّاً يفتح نفس الصفحة.)
5. انتظر ظهور السجل: `Installing… → Done` (من 30 ثانية إلى 3 دقائق).
6. أول مرّة فقط: يطلب الجهاز **السماح بالتوقيع** → أكّد على الآيفون.

---

## 5) الثقة بالمطوّر داخل الآيفون

هذه الخطوة إلزامية وإلّا سيظهر خطأ **Untrusted Developer** عند فتح التطبيق:

1. `Settings → General → VPN & Device Management`
2. تحت **Developer App** اضغط على بريدك (Apple ID) → **Trust** → **Trust**.
3. **أوقف التطبيق تماماً** من مبدّل التطبيقات ثم افتحه من جديد.

---

## 6) بعد التثبيت

- التطبيق يعمل كأي تطبيق عادي، بما في ذلك **الإشعارات المجدولة للأذان**
  (ستُطلب منك الصلاحيات عند أول تشغيل).
- **بعد 7 أيام** يبدأ التطبيق بالرفض عند الفتح — هذا طبيعي بالنسبة للتوقيع المجاني:
  1. وصّل الجهاز بالكمبيوتر، افتح Sideloadly، وافتح نفس الـ IPA.
  2. **استخدم نفس Apple ID** واضغط Start — وفي حال ظهر خيار **Refresh** في
     Sideloadly فاضغطه لتحديث التوقيع فقط مع **الحفاظ على بياناتك**.
- لتفادي انتهاء التوقيع أسبوعياً: استخدم **AltStore/SideStore** (تحديث تلقائي
  عبر الواي فاي/الجهاز نفسه)، أو حساب Apple Developer مدفوع (سنة كاملة)
  مع الـ IPA الموقّع من سير العمل (`muezzin-ios-signed-<رقم>`).

---

## استكشاف الأخطاء (Sideloadly على Windows)

| الخطأ / المشكلة | الحل |
|---|---|
| الجهاز لا يظهر في Sideloadly | كيبل آخر + منفذ USB آخر، ثم **Restart** لخدمة Apple Mobile Device، ثم أعد تشغيل Sideloadly كمسؤول |
| `iTunes not detected` | ثبّت iTunes من موقع Apple (لا من Microsoft Store) وأعد تشغيل الجهاز |
| `Invalid password` مع حساب بمصادقة ثنائية | استخدم **app-specific password** وليس كلمة سر الحساب |
| `Unable to install "…"` / `AMFI` | امسح أي نسخة سابقة من التطبيق من الجهاز، أعد التوصيل، وأعد المحاولة |
| `Untrusted Developer` عند الفتح | كرّر الخطوة 5 (الثقة بالمطوّر) وأعد فتح التطبيق |
| `This app cannot be installed because its integrity could not be verified` | فعّل **Developer Mode** (الخطوة 2.3) وأعد التشغيل |
| التطبيق يتوقف بعد أسبوع | توقيع مجاني — أعد التركيب بنفس الطريقة (البيانات تُحفظ) |
| التطبيق يُختفي بعد `Refresh` | استخدم **Register AltStore** أو أعد التركيب بنفس Bundle ID وستبقى البيانات |

---

## بدائل Sideloadly

| البديل | الأفضل لـ |
|---|---|
| **AltStore / SideStore** | تحديث التوقيع تلقائياً قبل انتهاء الأسبوع (يحتاج تشغيل AltServer على الكمبيوتر أو شبكة محلية) |
| **TrollStore** | توقيع دائم بلا Apple ID — لكنه يعمل فقط على إصدارات iOS المدعومة |
| **Xcode** (Mac فقط) | `flutter run`/`flutter install` على جهاز موصول بحساب مطوّر |
| **TestFlight** | الأفضل للتجربة الرسمية — يحتاج أسرار التوقيع في GitHub (انظر `docs/BUILD_IOS.md`) |
