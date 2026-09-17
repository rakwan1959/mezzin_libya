import 'package:shared_preferences/shared_preferences.dart';

abstract class QuranSettingsDataSource {
  Future<void> saveLastRead(int surahId, int ayahNumber);
  Map<String, int>? getLastRead();
  Future<void> clearLastRead();
  Future<void> setFontSize(double size);
  double getFontSize();
  Future<void> setReadingMode(String mode);
  String getReadingMode();
  Future<void> setFontWeight(String weight);
  String getFontWeight();
  Future<void> setBrightness(double brightness);
  double getBrightness();
  Future<void> setReciter(String reciter);
  String getReciter();
  Future<void> setSelectedTafsir(String tafsir);
  String getSelectedTafsir();
  Future<void> setFontFamily(String family);
  String getFontFamily();
}

class QuranSettingsDataSourceImpl implements QuranSettingsDataSource {
  final SharedPreferences sharedPreferences;
  static const String _lastSurahKey = "LAST_SURAH";
  static const String _lastAyahKey = "LAST_AYAH";
  static const String _fontSizeKey = "FONT_SIZE";
  static const String _readingModeKey = "READING_MODE";
  static const String _fontWeightKey = "FONT_WEIGHT";
  static const String _brightnessKey = "BRIGHTNESS_LEVEL";
  static const String _reciterKey = "RECITER";
  static const String _tafsirKey = "SELECTED_TAFSIR";
  static const String _fontFamilyKey = "QURAN_FONT_FAMILY";

  /// مفتاح ترحيل **مرّة واحدة**: يمنع تكرار فرض الوضع الليلي بعد التحديث الأول.
  static const String _darkDefaultAppliedKey = "QURAN_DARK_DEFAULT_APPLIED";

  QuranSettingsDataSourceImpl({required this.sharedPreferences});

  /// يعيد الوضع الليلي افتراضاً في شاشة القرآن **مرّة واحدة** ثم يُحترم اختيار
  /// المستخدم.
  ///
  /// سبب الحاجة: النسخ القديمة كانت الافتراضي فيها نهارياً وتكتب `white` في
  /// `READING_MODE` عند أول تشغيل، فيبقى الجهاز يفتح القرآن أبيض نهاري بعد كل
  /// تحديث مهما تغيّر الافتراضي في الكود — لأن القيمة المحفوظة تسبق الافتراضي.
  /// هذا الترحيل يمحو تلك القيمة القديمة مرّة واحدة، فلا يُستبدل اختيار
  /// المستخدم بعدها أبداً.
  static Future<void> migrateToDarkReadingMode(SharedPreferences prefs) async {
    if (prefs.containsKey(_darkDefaultAppliedKey)) return;
    await prefs.setString(_readingModeKey, "black");
    await prefs.setBool(_darkDefaultAppliedKey, true);
  }

  @override
  Future<void> saveLastRead(int surahId, int ayahNumber) async {
    await sharedPreferences.setInt(_lastSurahKey, surahId);
    await sharedPreferences.setInt(_lastAyahKey, ayahNumber);
  }

  @override
  Map<String, int>? getLastRead() {
    final surahId = sharedPreferences.getInt(_lastSurahKey);
    final ayahNumber = sharedPreferences.getInt(_lastAyahKey);
    if (surahId != null && ayahNumber != null) {
      return {"surahId": surahId, "ayahNumber": ayahNumber};
    }
    return null;
  }

  @override
  Future<void> clearLastRead() async {
    await sharedPreferences.remove(_lastSurahKey);
    await sharedPreferences.remove(_lastAyahKey);
  }

  @override
  Future<void> setFontSize(double size) async {
    await sharedPreferences.setDouble(_fontSizeKey, size);
  }

  @override
  double getFontSize() {
    return sharedPreferences.getDouble(_fontSizeKey) ?? 22.0;
  }

  @override
  Future<void> setReadingMode(String mode) async {
    await sharedPreferences.setString(_readingModeKey, mode);
  }

  @override
  String getReadingMode() {
    // الافتراضي عند التثبيت الأول: الوضع الليلي
    return sharedPreferences.getString(_readingModeKey) ?? "black";
  }

  @override
  Future<void> setFontWeight(String weight) async {
    await sharedPreferences.setString(_fontWeightKey, weight);
  }

  @override
  String getFontWeight() {
    return sharedPreferences.getString(_fontWeightKey) ?? "semi_bold";
  }

  @override
  Future<void> setBrightness(double brightness) async {
    await sharedPreferences.setDouble(_brightnessKey, brightness);
  }

  @override
  double getBrightness() {
    return sharedPreferences.getDouble(_brightnessKey) ?? 1.0;
  }

  @override
  Future<void> setReciter(String reciter) async {
    await sharedPreferences.setString(_reciterKey, reciter);
  }

  @override
  String getReciter() {
    return sharedPreferences.getString(_reciterKey) ?? "ar.sudais";
  }

  @override
  Future<void> setSelectedTafsir(String tafsir) async {
    await sharedPreferences.setString(_tafsirKey, tafsir);
  }

  @override
  String getSelectedTafsir() {
    return sharedPreferences.getString(_tafsirKey) ?? "ibnkathir";
  }

  @override
  Future<void> setFontFamily(String family) async {
    await sharedPreferences.setString(_fontFamilyKey, family);
  }

  @override
  String getFontFamily() {
    // الافتراضي عند التثبيت الأول: خط أميري قياسي
    return sharedPreferences.getString(_fontFamilyKey) ?? "QuranAmiriRegular";
  }
}
