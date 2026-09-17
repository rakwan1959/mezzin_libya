package com.example.muezzin_libya_app

import android.app.PendingIntent
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ════════════════════════════════════════════════════════════════════════════
 *  بطاقة إشعار أوقات الصلاة — رسمنا الخاص داخل شريط إشعارات النظام.
 * ════════════════════════════════════════════════════════════════════════════
 *
 * لماذا RemoteViews بدل `setColor` / `setColorized`؟
 * توثيق أندرويد يشترط وجود «custom content view» كي يُطبَّق تلوين خلفية
 * الإشعار؛ بدونه يبقى `setColor` مجرّد لون تمييز للأيقونة واسم التطبيق.
 *
 * ولماذا **بلا** `DecoratedCustomViewStyle`؟
 * لأن ذلك النمط يبقي «زخرفة النظام» — اسم التطبيق والوقت وإطار البطاقة —
 * ثم يضع بطاقتنا داخلها، فيظهر إشعار صغير داخل إشعار كبير: منظر مزدوج قبيح.
 * بإلغاء النمط تصبح بطاقتنا هي الإشعار كله، بلا إطار داخلي ولا تكرار.
 *
 * ونتيجة إلغاء النمط: **أزرار النظام تختفي معه** (فهي من زخرفته). لذلك ترسم
 * البطاقة حبّة إجراء خاصة بها مربوطة بنفس الـ PendingIntent — فزر إيقاف الأذان
 * يبقى موجوداً وأجمل، لا مفقوداً.
 *
 * كيف تُلوَّن البطاقة؟
 *  • البطاقة نفسها `ImageView` بشكله الأبيض الدائري الزوايا يُلوَّن وقت التشغيل
 *    بـ `setColorFilter` (SRC_ATOP) — فيأخذ أي لون مع الحفاظ على الزوايا
 *    والشفافية، بخلاف `setBackgroundColor` الذي يمسح الشكل فتضيع الزوايا.
 *  • خلفية الجذر تبقى كحلية ملكية ثابتة كطبقة احتياطية: إن فشل التلوين على
 *    جهاز معيّن تبقى البطاقة كحلية أنيقة، ولا تسقط أبداً إلى أبيض النظام
 *    الذي يجعل النص الأبيض غير مقروء.
 *
 * مسؤولية موازية: نسخة الإضافة المحلية `flutter_local_notifications` تبني نفس
 * البطاقة للإشعارات المجدولة من Dart (انظر setCustomNotificationLayout هناك) —
 * فتبقى هوية الإشعار واحدة أيّاً كان مصدره.
 */
object PrayerNotificationCard {

    /**
     * خلفية البطاقة — **أسود**.
     *
     * (والكحلي الملكي `#002855` باقٍ هوية التطبيق في الحوارات والتنبيهات داخل
     * الواجهة — هذا الثابت يخصّ بطاقة شريط الإشعارات وحدها.)
     */
    const val CARD_BLACK: Int = 0xFF000000.toInt()

    /** ذهبي التطبيق — شريط التمييز والنص الثانوي. */
    const val GOLD: Int = 0xFFDFBA6B.toInt()

    /**
     * نصّ زر إيقاف الأذان — يُستخدم في المسار الأصلي.
     *
     * ⚠️ **بلا أي محرف رمزي** (لا `⏹`): البطاقة بخطّ أميري وهو خط عربي لا يحوي
     * محارف الرموز، فيظهر المحرف مربّعاً فارغاً. أيقونة الإيقاف حقيقية مرسومة
     * (`@drawable/ic_notif_stop`) وموصولة بالزرّ من التخطيط نفسه.
     */
    const val STOP_LABEL_FULL: String = "إيقاف الأذان"

    /** نسخة مختصرة تظهر في البطاقة المطوية حيث المساحة ضيقة. */
    const val STOP_LABEL_COMPACT: String = "إيقاف"

    /** أبيض شفاف للقرص الدائري خلف الأيقونة. */
    private const val ICON_DISC: Int = 0x26FFFFFF

    /** الساعة الحالية بتنسيق عربي 12 ساعة — مثال: `5:42 م`. */
    fun clockText(date: Date = Date()): String =
        try {
            SimpleDateFormat("h:mm a", Locale.forLanguageTag("ar")).format(date)
        } catch (e: Exception) {
            ""
        }

    /**
     * البطاقة المطوية — الصف الظاهر في شريط الإشعارات.
     *
     * [actionLabel] و[actionIntent] اختياريان: عند تمريرهما تظهر حبّة الإجراء
     * **بدل** وقت الصلاة (المساحة في الصفّ المطوي تتّسع لواحد منهما فقط)،
     * وهذا ما يحفظ زر إيقاف الأذان في الإشعار غير الموسّع.
     */
    fun collapsed(
        context: Context,
        title: CharSequence?,
        body: CharSequence?,
        badge: CharSequence? = null,
        actionLabel: CharSequence? = null,
        actionIntent: PendingIntent? = null,
        cardColor: Int = CARD_BLACK,
        accentColor: Int = GOLD,
    ): RemoteViews = build(
        context = context,
        layoutId = R.layout.notification_prayer_collapsed,
        title = title,
        body = body,
        badge = badge,
        cardColor = cardColor,
        accentColor = accentColor,
        isExpanded = false,
        actionLabel = actionLabel,
        actionIntent = actionIntent,
    )

    /**
     * البطاقة الموسّعة — تظهر عند سحب الإشعار لأسفل.
     *
     * هنا الوقت في صفّ الرأس والإجراء في صفّ التذييل، فيظهران معاً بلا تضارب.
     */
    fun expanded(
        context: Context,
        title: CharSequence?,
        body: CharSequence?,
        badge: CharSequence? = null,
        footer: CharSequence? = null,
        actionLabel: CharSequence? = null,
        actionIntent: PendingIntent? = null,
        cardColor: Int = CARD_BLACK,
        accentColor: Int = GOLD,
    ): RemoteViews = build(
        context = context,
        layoutId = R.layout.notification_prayer_expanded,
        title = title,
        body = body,
        badge = badge,
        cardColor = cardColor,
        accentColor = accentColor,
        isExpanded = true,
        footer = footer,
        actionLabel = actionLabel,
        actionIntent = actionIntent,
    )

    /**
     * يطبّق البطاقة المخصّصة على أي [NotificationCompat.Builder].
     *
     * ⚠️ بلا `setStyle(DecoratedCustomViewStyle())` عن قصد: ذلك النمط هو سبب
     * ظهور «إشعار صغير داخل إشعار كبير» (إطار النظام + بطاقتنا بداخله).
     * وبإلغائه تصبح بطاقتنا هي الإشعار كله بمنظر واحد نظيف.
     */
    fun apply(
        context: Context,
        builder: NotificationCompat.Builder,
        title: CharSequence?,
        body: CharSequence?,
        badge: CharSequence? = null,
        footer: CharSequence? = null,
        actionLabel: CharSequence? = null,
        actionIntent: PendingIntent? = null,
        cardColor: Int = CARD_BLACK,
        accentColor: Int = GOLD,
    ): NotificationCompat.Builder {
        val collapsedView =
            collapsed(context, title, body, badge, actionLabel, actionIntent, cardColor, accentColor)
        builder
            .setColor(cardColor)
            .setColorized(true)
            .setCustomContentView(collapsedView)
            .setCustomHeadsUpContentView(collapsedView)
            .setCustomBigContentView(
                expanded(context, title, body, badge, footer, actionLabel, actionIntent, cardColor, accentColor)
            )
        return builder
    }

    /**
     * @param isExpanded هل نبني البطاقة الموسّعة؟ صفّ التذييل وعناصره
     *   (`notif_footer_row` و`notif_footer` و`notif_divider` وصفّ الإجراء داخله)
     *   موجودة في التخطيط الموسّع فقط، واستهداف عنصر غير موجود داخل RemoteViews
     *   يُفسد الإشعار — فلا نلمسها في البطاقة المطوية إطلاقاً.
     */
    private fun build(
        context: Context,
        layoutId: Int,
        title: CharSequence?,
        body: CharSequence?,
        badge: CharSequence?,
        cardColor: Int,
        accentColor: Int,
        isExpanded: Boolean,
        footer: CharSequence? = null,
        actionLabel: CharSequence? = null,
        actionIntent: PendingIntent? = null,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        val hasAction = actionIntent != null && !actionLabel.isNullOrBlank()

        // ① البطاقة الملوّنة + القرص الدائري + شريط التمييز
        views.setInt(R.id.notif_card_bg, "setColorFilter", cardColor)
        views.setInt(R.id.notif_icon_badge, "setColorFilter", ICON_DISC)
        views.setInt(R.id.notif_accent, "setColorFilter", accentColor)

        // ② العنوان
        if (title.isNullOrBlank()) {
            views.setViewVisibility(R.id.notif_title, View.GONE)
        } else {
            views.setViewVisibility(R.id.notif_title, View.VISIBLE)
            views.setTextViewText(R.id.notif_title, title)
        }

        // ③ النص
        if (body.isNullOrBlank()) {
            views.setViewVisibility(R.id.notif_body, View.GONE)
        } else {
            views.setViewVisibility(R.id.notif_body, View.VISIBLE)
            views.setTextViewText(R.id.notif_body, body)
        }

        // ④ وقت الصلاة
        if (badge.isNullOrBlank()) {
            views.setViewVisibility(R.id.notif_time, View.GONE)
        } else {
            views.setViewVisibility(R.id.notif_time, View.VISIBLE)
            views.setTextViewText(R.id.notif_time, badge)
        }

        if (isExpanded) {
            // ⑤ صفّ التذييل: يظهر عند وجود تذييل أو إجراء، وإلا يبقى مخفياً بالكامل
            val hasFooter = !footer.isNullOrBlank()
            if (hasFooter || hasAction) {
                views.setViewVisibility(R.id.notif_footer_row, View.VISIBLE)
                views.setViewVisibility(R.id.notif_divider, View.VISIBLE)
            }
            if (hasFooter) {
                views.setViewVisibility(R.id.notif_footer, View.VISIBLE)
                views.setTextViewText(R.id.notif_footer, footer)
            } else if (hasAction) {
                // بلا نصّ تذييل: يُبقى مُعبِّئ المساحة (TextView بوزن 1) ظاهراً بنصّ
                // فارغ كي يبقى زرّ الإجراء في **نهاية** الصفّ (أقصى اليسار في RTL)
                // بدل أن ينزلق إلى وسطه حين يختفي ما كان يدفعه.
                views.setViewVisibility(R.id.notif_footer, View.VISIBLE)
                views.setTextViewText(R.id.notif_footer, "")
            }
            if (hasAction) {
                views.setViewVisibility(R.id.notif_action, View.VISIBLE)
                views.setTextViewText(R.id.notif_action, actionLabel)
                views.setOnClickPendingIntent(R.id.notif_action, actionIntent)
            }
        } else if (hasAction) {
            // ⑥ في الصفّ المطوي: حبّة الإجراء تحلّ مكان الوقت (لا يتّسع للاثنين)
            views.setViewVisibility(R.id.notif_time, View.GONE)
            views.setViewVisibility(R.id.notif_action, View.VISIBLE)
            views.setTextViewText(R.id.notif_action, actionLabel)
            views.setOnClickPendingIntent(R.id.notif_action, actionIntent)
        }

        // ⑦ دلالة للقارئ الشاشي: البطاقة المخصّصة تحجب النص الافتراضي للإشعار
        val description = listOfNotNull(
            title?.toString()?.takeIf { it.isNotBlank() },
            body?.toString()?.takeIf { it.isNotBlank() },
            badge?.toString()?.takeIf { it.isNotBlank() },
        ).joinToString("، ")
        if (description.isNotEmpty()) {
            views.setContentDescription(R.id.notif_content, description)
        }

        return views
    }
}
