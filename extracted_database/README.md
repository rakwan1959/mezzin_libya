# دليل قاعدة بيانات مواقيت الصلاة المستخرجة
# Prayer Times Database - Extracted Documentation

تم استخراج قاعدة بيانات مواقيت الصلاة بالكامل وبنجاح من ملف التطبيق:
`C:\Users\Admin\Desktop\المؤذن+-+ليبيا_4.02_APKPure.apk`

---

## 📁 المجلدات والملفات المتوفرة (Directory Structure)

### 1. ليبيا (Libya Database)
- **`Libya.sqlite`**: قاعدة بيانات SQLite الأصلية المستخرجة مباشرة من التطبيق.
- **`Libya_dump.sql`**: ملف تفريغ SQL كامل يحتوي على بنية الجداول وجميع البيانات (INSERT Statements).
- **`libya_cities.json` & `libya_cities.csv`**: قائمة المدن الليبية (40 مدينة) مع المعرفات، الأسماء بالعربية والإنجليزية، والإحداثيات الجغرافية (خط العرض وخط الطول).
- **`libya_prayer_times.csv`**: جدول مواقيت الصلاة الكامل في ملف CSV متوافق مع Excel (14,640 سجل).
- **`libya_prayer_times_all.json`**: جميع مواقيت الصلاة مجمعة في ملف JSON واحد.
- **`cities_json/`**: مجلد يحتوي على 40 ملف JSON منفصل لكل مدينة على حدة (366 يوماً لكل مدينة)، بتنسيق جاهز للتطبيقات:
  `[{"date": "01-01", "fajr": "06:08:00", "sunrise": "07:36:00", "dhuhr": "12:46:00", "asr": "15:29:00", "maghrib": "17:52:00", "isha": "19:16:00"}, ...]`
- **`sounds.json`**: بيانات قائمة أصوات الأذان والمؤذنين المعرفة في التطبيق.

---

### 2. الجزائر (Algeria Database)
- **`Algeria.sqlite`**: قاعدة بيانات SQLite لمواقيت صلاة الجزائر (مضمنة داخل التطبيق).
- **`Algeria_dump.sql`**: تفريغ SQL كامل لمواقيت الجزائر.
- **`algeria_cities.json` & `algeria_cities.csv`**: قائمة مدن الجزائر (68 مدينة).
- **`algeria_prayer_times.csv` & `algeria_prayer_times_all.json`**: مواقيت الصلاة لجميع مدن الجزائر (24,621 سجل).
- **`cities_json/`**: ملفات JSON منفصلة لكل مدينة جزائرية.
- **`sounds.json`**: قائمة أصوات الأذان.

---

## 📊 هيكل الجداول (Database Schema)

### جدول المدن (`CitesTable`):
- `id` (INTEGER PRIMARY KEY)
- `cityNameEN` (TEXT)
- `cityNameAR` (TEXT)
- `lat` (TEXT)
- `lng` (TEXT)

### جدول الصلوات (`Prayer`):
- `prayerId` (INTEGER PRIMARY KEY)
- `cityId` (INTEGER - Foreign Key to CitesTable)
- `monthh` (INTEGER - 1 to 12)
- `dayy` (INTEGER - 1 to 31)
- `fajerTime` (TEXT)
- `sunRiseTime` (TEXT)
- `duhirTime` (TEXT)
- `aserTime` (TEXT)
- `mugribTime` (TEXT)
- `eshaTime` (TEXT)

### جدول الأصوات (`Sounds`):
- `id` (INTEGER)
- `soundName` (TEXT)
- `soundFileName` (TEXT)
- `soundUri` (TEXT)
- `isDefault` (INTEGER)
- `soundSize` (INTEGER)
