-- ══════════════════════════════════════════════════════════════════════════════
--  مؤذن ليبيا — ترقية قاعدة بيانات Supabase (app_config + broadcasts)
-- ══════════════════════════════════════════════════════════════════════════════
--
--  لماذا هذا الملف؟
--  التطبيق يقرأ/يكتب أعمدة في `app_config` لم تكن مضافة في المشروع، فكانت
--  عمليات النشر (نص الشريط · تنسيقه · النص المتحرك في الرئيسية · رقم الغرفة)
--  تفشل بصمت: الحفظ المحلي ينجح، والوصول لبقية الأجهزة لا يصل.
--
--  تنظيم الملف: **كل أعمدة الجدول الواحد متتالية في أمر `alter table` واحد**،
--  وعلى سطر كل عمود قيمته الافتراضية بجانبه مباشرة (`default`). فلا توجد قائمة
--  أعمدة هنا وقائمة افتراضيات هناك. عمود بلا `default` مقصود: قيمته تعني
--  «اترك القرار للتطبيق» (لون النص المتحرك يتبع ألوان الصلاة، ونص الدعاء ورقم
--  الغرفة يأتيان من الكود) — فلا نُثبّتها في القاعدة.
--
--  هذا الملف يضيفها كلها بأوامر **آمنة التكرار** (IF NOT EXISTS) فلا يتأثر أي
--  عمود أو صف موجود، ولا يُنشئ رسالة تجريبية (رسالة في `broadcasts` تُطلق
--  إشعاراً على كل الأجهزة).
--
--  طريقة التنفيذ:
--    Supabase Dashboard ← SQL Editor ← New query ← الصق الملف كاملاً ← Run.
--    ثم تحقّق من الربط:   dart run tools/check_supabase_link.dart
-- ══════════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────────
-- 1) الجدولان اللذان يستخدمهما التطبيق (يُنشآن فقط إن لم يوجدا إطلاقاً)
-- ──────────────────────────────────────────────────────────────────────────────
create table if not exists public.app_config (
  id         integer primary key,
  updated_at timestamptz default now()
);

create table if not exists public.broadcasts (
  id         text primary key,
  title      text,
  message    text,
  btn_text   text,
  btn_url    text,
  target_uid text,
  target_city text,
  created_at timestamptz default now()
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 2) عمود الإعدادات المفرد (id = 1) — كل شاشات التطبيق تقرأ منه
--    INSERT ... DO NOTHING: لا يمسّ صفاً موجوداً.
-- ──────────────────────────────────────────────────────────────────────────────
insert into public.app_config (id) values (1)
on conflict (id) do nothing;

-- ──────────────────────────────────────────────────────────────────────────────
-- 3) أعمدة app_config — كلها وراء بعضها، ولكل عمود افتراضيه بجانبه
--    marquee_*     = الشريط العلوي لشاشة الإعدادات (أسماء الله الحسنى / الأحاديث)
--    home_dua_*    = النص المتحرك في الشاشة الرئيسية
--    room_passcode = رقم غرفة المراسلة المخفية
--    (updated_at ليس عموداً للتطبيق، فهو في تعريف الجدول لا هنا)
-- ──────────────────────────────────────────────────────────────────────────────
alter table public.app_config
  -- الشريط العلوي في شاشة الإعدادات
  add column if not exists marquee_text           text,
  add column if not exists marquee_messages       text    default '',
  add column if not exists marquee_interval_ms    integer default 6000,          -- وقت الظهور 6 ثوانٍ
  add column if not exists marquee_color          bigint  default 4294967295,    -- أبيض 0xFFFFFFFF
  add column if not exists marquee_font           text    default 'Amiri',
  add column if not exists marquee_font_size      integer default 12,
  -- النص المتحرك في الشاشة الرئيسية
  add column if not exists home_dua_enabled       boolean default true,
  add column if not exists home_dua_text          text,                          -- فارغ = الأسماء المضمّنة في الكود
  add column if not exists home_dua_color         bigint,                        -- بلا افتراضي: يتبع ألوان أوقات الصلاة
  add column if not exists home_dua_font          text    default 'Cairo',
  add column if not exists home_dua_font_size     integer default 10,
  add column if not exists home_dua_interval_ms   integer default 2800,
  add column if not exists home_dua_bold          boolean default false,
  add column if not exists home_dua_after_minutes integer default 15,
  -- رقم غرفة المراسلة المخفية
  add column if not exists room_passcode          text;

-- ──────────────────────────────────────────────────────────────────────────────
-- 4) أعمدة جدول الرسائل (broadcasts) — كلها وراء بعضها كذلك
-- ──────────────────────────────────────────────────────────────────────────────
alter table public.broadcasts
  add column if not exists btn_text    text,
  add column if not exists btn_url     text,
  add column if not exists target_uid  text,
  add column if not exists target_city text,
  add column if not exists views       integer default 0,
  add column if not exists created_at  timestamptz default now();

-- ──────────────────────────────────────────────────────────────────────────────
-- 5) فهارس للأداء على المدى الطويل: الرسائل تنمو بلا توقّف، والتطبيق يسأل
--    دائماً عن (الأحدث أولاً) و(معرّف مستخدم/جهاز) و(معرّفات dm_*)
-- ──────────────────────────────────────────────────────────────────────────────
create index if not exists broadcasts_created_at_idx
  on public.broadcasts (created_at desc);
create index if not exists broadcasts_target_uid_idx
  on public.broadcasts (target_uid);
create index if not exists broadcasts_id_pattern_idx
  on public.broadcasts (id text_pattern_ops);

-- ──────────────────────────────────────────────────────────────────────────────
-- 6) جدول الرسائل داخل قناة Realtime (يصل الإشعار فوراً بلا فتح التطبيق)
--    داخل كتلة try: التكرار يعطي duplicate_object فيُتجاهل.
-- ──────────────────────────────────────────────────────────────────────────────
do $$
begin
  alter publication supabase_realtime add table public.broadcasts;
exception
  when duplicate_object then null;
  when undefined_object then null;  -- لم تُفعَّل Realtime في المشروع
end $$;

-- ──────────────────────────────────────────────────────────────────────────────
-- 7) ملاحظة أمنية (لا تُغيَّر هنا عن قصد):
--    التطبيق يكتب بمفتاح anon من لوحة التحكم (1918)، لذا يجب أن تسمح سياسات
--    RLS على الجدولين بالقراءة والكتابة لمفتاح anon كما هي عليه الآن.
--    لا نلمس السياسات في هذا الملف حتى لا نُغلق الوصول على نسخة تعمل — إن
--    كنت ستُشغّل هذا على مشروع جديد، فعّل RLS وأضِف سياسات allow لـ anon.
-- ──────────────────────────────────────────────────────────────────────────────

-- تحقّق سريع بعد التنفيذ: يجب أن يعرض كل عمود بـ«موجود»
--   select column_name, column_default from information_schema.columns
--    where table_name = 'app_config' order by ordinal_position;
