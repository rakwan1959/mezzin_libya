import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

/// خدمة الذكاء الاصطناعي (Gemini) — تخزين المفتاح + الأسئلة العامة والمهام
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static const String _keyPref = 'ai_gemini_api_key';

  /// ★★★ مفتاح التطبيق الموحد (المدمج داخل الكود) ★★★
  /// الصق مفتاح Gemini الخاص بك بين علامتي التنصيص مرة واحدة فقط:
  ///
  ///     static const String _builtinApiKey = 'AIza...';
  ///
  /// وسيعمل الذكاء الاصطناعي لجميع مستخدمي التطبيق تلقائياً من أول تشغيل
  /// دون أن يحتاجوا للحصول على مفتاح أو أي إعداد.
  ///
  /// - احصل على مفتاحك مجاناً من: https://aistudio.google.com/app/apikey
  /// - اتركه فارغاً '' إذا أردت أن يضيف كل مستخدم مفتاحه بنفسه.
  ///
  /// ملاحظة أمنية: المفتاح داخل APK يمكن استخراجه نظرياً، لذا يُنصح
  /// بمراقبة الاستخدام من لوحة Google AI Studio (الحد المجاني سخي). 
  static const String _builtinApiKey = '';

  /// هل يوجد مفتاح مدمج داخل التطبيق؟
  bool get hasBuiltinKey => _builtinApiKey.trim().isNotEmpty;

  /// النماذج المجرّبة بالترتيب (من الأحدث إلى الأقدم احتياطياً)
  /// يُحاول الكود النموذج الأول فإن لم يتوفر انتقل للتالي تلقائياً
  static const List<String> _models = [
    'gemini-3.5-flash',       // الجيل الثالث — الأسرع والأكثر كفاءة
    'gemini-3.6-flash',       // محسّن للمهام المعقدة
    'gemini-3.0-flash',       // احتياطي جيل 3
    'gemini-2.5-flash',       // احتياطي جيل 2.5
    'gemini-2.5-flash-latest',// نسخة preview
    'gemini-2.5-pro',         // احتياطي pro
    'gemini-1.5-flash',       // احتياطي قديم
    'gemini-1.5-flash-latest',// احتياطي قديم preview
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// المفتاح الفعّال: مفتاح المستخدم إن وُجد، وإلا المفتاح المدمج بالتطبيق.
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref)?.trim() ?? '';
    if (key.isNotEmpty) return key;
    if (hasBuiltinKey) return _builtinApiKey.trim();
    return null;
  }

  /// المفتاح الذي أضافه المستخدم بنفسه فقط (بدون المفتاح المدمج بالتطبيق)
  Future<String?> getUserApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref)?.trim() ?? '';
    return key.isEmpty ? null : key;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key.trim());
  }

  Future<bool> hasApiKey() async => (await getApiKey()) != null;

  String _systemInstructions() => '''
أنت مساعد «اوقات الصلاه» الذكي — تطبيق إسلامي ليبياي لمواقيت الصلاة والقرآن الكريم والأذكار.
أجب دائماً باللغة العربية الفصحى الواضحة وبأسلوب مهذب ومختصر قدر الإمكان.
عند الأسئلة الشرعية اعتمد القرآن الكريم والسنة النبوية الصحيحة، وإن لم تعرف الجواب قل بصراحة: "لا أملك معلومات كافية عن هذا".
لا تختلق آيات أو أحاديث أو أرقاماً، وإذا ذُكرت آية أو حديث فتأكد من دقتها.
عند سؤال عن آية اشرحها بأسلوب بسيط يشمل المعنى العام، وسبب النزول إذا كان معروفاً، والعبر المستفادة.
عند سؤال عن مواقيت الصلاة لمدينة ليبية فاذكر أن الحساب الدقيق داخل التطبيق في قسم المواقيت.
استخدم أسلوباً محفزاً على الطاعة لا متشدداً.''';

  Future<String?> _requestModel(
    Dio dio,
    String model,
    String prompt,
  ) async {
    final key = await getApiKey();
    if (key == null) return null;
    final url = '$_baseUrl/$model:generateContent';
    final response = await dio.post<Map<String, dynamic>>(
      url,
      queryParameters: {'key': key},
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '${_systemInstructions()}\n\nالسؤال/الطلب:\n$prompt'},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.6,
          'maxOutputTokens': 1500,
        },
      },
    );
    final data = response.data;
    final candidates = data?['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final parts = (candidates.first as Map)['content']?['parts'];
      if (parts is List && parts.isNotEmpty) {
        final text = (parts.first as Map)['text']?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
    }
    throw Exception('جواب فارغ من الذكاء الاصطناعي');
  }

  /// جلب أول نموذج نشط من Google مباشرة (للحالات التي تفشل فيها كل النماذج المدرجة)
  Future<String?> _fetchFirstAvailableModel(Dio dio, String key) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: {'key': key, 'pageSize': 50},
      );
      final models = (response.data?['models'] ?? []) as List;
      // نُفضّل النماذج التي تحتوي على generateContent
      for (final priority in ['flash', 'pro', 'gemini']) {
        for (final m in models) {
          if (m is Map) {
            final name = m['name']?.toString() ?? '';
            final methods = (m['supportedGenerationMethods'] as List?) ?? [];
            if (name.contains(priority) &&
                methods.contains('generateContent')) {
              // الاسم يكون مثل: models/gemini-3.5-flash → نأخذ الجزء بعد /
              return name.contains('/') ? name.split('/').last : name;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// إرسال سؤال نصي ويعيد النص، أو null إذا لم يُضبط مفتاح API بعد.
  Future<String?> ask(String question, {String? context}) async {
    final key = await getApiKey();
    if (key == null) return null;

    String prompt = question;
    if (context != null && context.trim().isNotEmpty) {
      prompt = 'معلومات سياقية مساعدة (قد تكون نص آية أو تفسير):\n$context\n\n---\n$question';
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    ));

    Object? lastError;
    for (final model in _models) {
      try {
        final text = await _requestModel(dio, model, prompt);
        if (text != null && text.isNotEmpty) return text;
      } catch (e) {
        lastError = e;
        // ننتقل للنموذج التالي إذا كان النموذج غير متاح (404) أو محظور (400/403)
        if (e is DioException &&
            (e.response?.statusCode == 404 ||
             e.response?.statusCode == 400 ||
             e.response?.statusCode == 403)) {
          continue;
        }
        // خطأ آخر (شبكة، مفتاح، إلخ) → لا نكمل
        break;
      }
    }

    // إذا فشلت كل النماذج المدرجة بسبب 404 → نجرب استعلام النماذج الحية
    if (lastError is DioException &&
        (lastError as DioException).response?.statusCode == 404) {
      final key = await getApiKey();
      if (key != null) {
        final dynamic live = await _fetchFirstAvailableModel(dio, key);
        if (live != null && live is String) {
          try {
            final text = await _requestModel(dio, live as String, prompt);
            if (text != null && text.isNotEmpty) return text;
          } catch (e) {
            lastError = e;
          }
        }
      }
    }

    if (lastError != null) {
      throw Exception(_friendlyError(lastError!));
    }
    return null;
  }

  /// استخراج رسالة Google الفعلية من جسم الخطأ (إن وُجدت)
  /// مثال: {"error":{"message":"API key not enabled for the Generative Language API..."}}
  String? _googleErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final msg = err['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } else if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final err = decoded['error'];
          if (err is Map) {
            final msg = err['message']?.toString().trim();
            if (msg != null && msg.isNotEmpty) return msg;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// تحويل خطأ Google الشائع إلى رسالة عربية واضحة مع الإجراء المطلوب
  String _mapGoogleMessage(String raw, int? statusCode) {
    final m = raw.toLowerCase();
    if (m.contains('api key not enabled') || m.contains('enable it at')) {
      return 'المفتاح غير مفعّل ⚠️\nيجب تفعيله من Google AI Studio:\nافتح aistudio.google.com/app/apikey ثم اضغط على المفتاح وفعّل «Generative Language API» ثم احفظ.';
    }
    if (m.contains('api key not valid') || m.contains('invalid api key') || m.contains('api key expired')) {
      return 'المفتاح غير صحيح — تأكد من نسخه كاملاً (يبدأ بـ AIza) من aistudio.google.com/app/apikey.';
    }
    if (m.contains('permission denied') || m.contains('forbidden')) {
      return 'المفتاح لا يملك صلاحية الوصول — فعّل «Generative Language API» من aistudio.google.com/app/apikey.';
    }
    if (m.contains('quota') || m.contains('rate limit') || m.contains('resource exhausted')) {
      return 'تم تجاوز حد الاستخدام المجاني — حاول بعد قليل أو أضف مفتاحك الخاص.';
    }
    if (m.contains('unsupported country') || m.contains('country') || m.contains('region')) {
      return 'خدمة Gemini غير متاحة في بلدك حالياً — قد تحتاج لشبكة VPN.';
    }
    if (m.contains('model') && (m.contains('not found') || m.contains('no longer available'))) {
      return 'نموذج الذكاء الاصطناعي غير متاح — حدّث التطبيق لأحدث إصدار.';
    }
    // رسالة غير معروفة: نعرضها كما هي مع رمز الخطأ
    return 'خطأ من Google (${statusCode ?? '?'}): $raw';
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final googleMsg = _googleErrorMessage(error);
      if (googleMsg != null) {
        return _mapGoogleMessage(googleMsg, status);
      }
      if (status == 400) {
        return 'لم يتم قبول الطلب — تأكد من صحة مفتاح الخدمة.';
      }
      if (status == 403 || status == 401) {
        return 'مفتاح الخدمة غير صحيح أو غير مفعّل.';
      }
      if (status == 429) {
        return 'تم تجاوز حد الاستخدام المجاني الآن — حاول بعد قليل.';
      }
      if (status == 404) {
        return 'نموذج Gemini غير متاح (404) — يتم تجربة نماذج أخرى تلقائياً. إن استمرت المشكلة: حدّث التطبيق لأحدث إصدار.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم أعد المحاولة.';
      }
      return 'تعذر الوصول إلى خدمة الذكاء الاصطناعي (${status ?? 'خطأ شبكة'}). حاول مجدداً.';
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  /// اختبار المفتاح مباشرة: يرسل طلباً صغيراً ويُظهر نتيجة Google الحقيقية
  /// - إن نجح: يعرض أول نموذج متاح.
  /// - إن فشل: يعرض رسالة Google الحقيقية مع سبب واضح.
  Future<String> testConnection() async {
    final key = await getApiKey();
    if (key == null) return 'لم يتم ضبط مفتاح Gemini بعد — أضف مفتاحك أولاً.';

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // طلب سريع لقائمة النماذج للتحقق من صحة المفتاح وتفعيله
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: {
          'key': key,
          'pageSize': 100,
        },
      );
      final models = (response.data?['models'] ?? []) as List;
      if (models.isEmpty) return 'المفتاح يعمل ✅ لكن لا توجد نماذج متاحة.';

      // البحث عن أفضل نموذج flash متاح
      String? best;
      for (final name in _models) {
        if (models.any((m) => m is Map && m['name']?.toString().contains(name) == true)) {
          best = name;
          break;
        }
      }
      final sample = best ?? (models.first is Map ? models.first['name']?.toString() : null);
      return 'المفتاح يعمل ✅\nنموذج الذكاء الجاهز: $sample';
    } on DioException catch (e) {
      final googleMsg = _googleErrorMessage(e);
      if (googleMsg != null) return '❌ ' + _mapGoogleMessage(googleMsg, e.response?.statusCode);
      return '❌ ' + _friendlyError(e);
    }
  }
}
