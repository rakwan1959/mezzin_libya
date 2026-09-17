/**
 * Gemini Proxy Worker — بوابة آمنة لـ Gemini API
 *
 * يحتفظ بمفتاح Gemini على السيرفر ولا يظهر أبداً داخل التطبيق.
 * التطبيق يرسل الطلبات إلى هذا العامل بدلاً من Google مباشرة.
 *
 * الطلبات المدعومة:
 *   POST /ask        { "prompt": "..." }  →  { "text": "..." }
 *   GET  /health     → { "ok": true }
 *
 * الأمان:
 *   - APP_SECRET: كلمة سر مشتركة يرسلها التطبيق في ترويسة Authorization.
 *   - حد يومي بسيط لكل IP (افتراضياً 100 طلب/يوم) لمنع الاستهلاك المفرط.
 *   - لا يسجل محتوى الطلبات (خصوصية).
 *
 * النشر:
 *   1) npx wrangler login
 *   2) npx wrangler secret put GEMINI_API_KEY
 *   3) npx wrangler secret put APP_SECRET
 *   4) npx wrangler deploy
 */

/**
 * @typedef {Object} Env
 * @property {string} GEMINI_API_KEY مفتاح Gemini المُخزّن سرّياً على السيرفر
 * @property {string} [APP_SECRET] كلمة سر مشتركة اختيارية للتطبيق
 */

/** @type {Env} */
let envType;
void envType;

const MODELS = [
  'gemini-3.5-flash',
  'gemini-3.6-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
];

const BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

// حد بسيط لكل IP: 100 طلب / 24 ساعة (يُحفظ في Cache API المجاني)
const DAILY_LIMIT = 100;

const SYSTEM_INSTRUCTIONS = `أنت مساعد «اوقات الصلاه» الذكي — تطبيق إسلامي ليبياي لمواقيت الصلاة والقرآن الكريم والأذكار.
أجب دائماً باللغة العربية الفصحى الواضحة وبأسلوب مهذب ومختصر قدر الإمكان.
عند الأسئلة الشرعية اعتمد القرآن الكريم والسنة النبوية الصحيحة، وإن لم تعرف الجواب قل بصراحة: "لا أملك معلومات كافية عن هذا".
لا تختلق آيات أو أحاديث أو أرقاماً، وإذا ذُكرت آية أو حديث فتأكد من دقتها.
عند سؤال عن آية اشرحها بأسلوب بسيط يشمل المعنى العام، وسبب النزول إذا كان معروفاً، والعبر المستفادة.
عند سؤال عن مواقيت الصلاة لمدينة ليبية فاذكر أن الحساب الدقيق داخل التطبيق في قسم المواقيت.
استخدم أسلوباً محفزاً على الطاعة لا متشدداً.`;

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'POST, GET, OPTIONS',
      'access-control-allow-headers': 'content-type, authorization',
    },
  });

/** حد يومي بسيط لكل IP باستخدام Cache API */
async function checkRateLimit(request: Request): Promise<boolean> {
  const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const cacheKey = new Request(`https://rate-limit.local/${ip}`, {
    method: 'POST',
  });
  const cache = caches.default;
  let count = 0;
  const cached = await cache.match(cacheKey);
  if (cached) {
    count = parseInt(await cached.text(), 10) || 0;
  }
  count += 1;
  if (count > DAILY_LIMIT) return false;
  const res = new Response(String(count), {
    headers: { 'cache-control': 's-maxage=86400' },
  });
  await cache.put(cacheKey, res);
  return true;
}

async function callGemini(
  model: string,
  prompt: string,
  apiKey: string,
): Promise<string> {
  const url = `${BASE_URL}/${model}:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: `${SYSTEM_INSTRUCTIONS}\n\nالسؤال/الطلب:\n${prompt}` },
          ],
        },
      ],
      generationConfig: { temperature: 0.6, maxOutputTokens: 1500 },
    }),
  });

  const data = (await res.json()) as any;
  if (!res.ok) {
    const msg = data?.error?.message ?? `HTTP ${res.status}`;
    const err: any = new Error(msg);
    err.status = res.status;
    throw err;
  }

  const parts = data?.candidates?.[0]?.content?.parts;
  const text = parts?.[0]?.text?.trim();
  if (!text) throw Object.assign(new Error('جواب فارغ من الذكاء الاصطناعي'), { status: 502 });
  return text;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') return json({ ok: true });

    const url = new URL(request.url);

    // فحص كلمة السر المشتركة (إن كانت مضبوطة)
    if (env.APP_SECRET) {
      const auth = request.headers.get('authorization') ?? '';
      if (auth !== `Bearer ${env.APP_SECRET}`) {
        return json({ error: 'غير مصرح' }, 401);
      }
    }

    // فحص الحد اليومي
    if (!(await checkRateLimit(request))) {
      return json(
        { error: 'تم تجاوز الحد اليومي للطلبات — حاول غداً' },
        429,
      );
    }

    if (url.pathname === '/health') {
      return json({ ok: true, service: 'gemini-proxy' });
    }

    if (url.pathname === '/ask' && request.method === 'POST') {
      if (!env.GEMINI_API_KEY) {
        return json({ error: 'المفتاح غير مضبوط على السيرفر' }, 500);
      }
      let prompt = '';
      try {
        const body = (await request.json()) as { prompt?: string };
        prompt = (body.prompt ?? '').trim();
      } catch {
        return json({ error: 'طلب غير صالح' }, 400);
      }
      if (!prompt) return json({ error: 'السؤال فارغ' }, 400);
      if (prompt.length > 2000) {
        return json({ error: 'السؤال طويل جداً' }, 400);
      }

      let lastErr: any = null;
      for (const model of MODELS) {
        try {
          const text = await callGemini(model, prompt, env.GEMINI_API_KEY);
          return json({ text });
        } catch (e: any) {
          lastErr = e;
          // جرّب النموذج التالي فقط لأخطاء التوفر (404/400/403)
          if ([400, 403, 404].includes(e?.status)) continue;
          break;
        }
      }

      const status = lastErr?.status ?? 502;
      return json({ error: lastErr?.message ?? 'خطأ غير معروف' }, status);
    }

    return json({ error: 'غير موجود' }, 404);
  },
};
