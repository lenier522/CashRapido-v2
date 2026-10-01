package cu.lenier.cashrapido

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        try {
            val streakCount = widgetData.getString("streak_count", "0") ?: "0"
            val streakSubtitle = widgetData.getString("streak_subtitle", "¡Comienza tu racha hoy!")
                ?: "¡Comienza tu racha hoy!"
            val streakTarget = widgetData.getString("streak_target", "🎁 0/50") ?: "🎁 0/50"
            val streakMotivation = widgetData.getString("streak_motivation", "¡Mantén encendido tu hábito diario!")
                ?: "¡Mantén encendido tu hábito diario!"
            val streakWeekStr = widgetData.getString("streak_week", "0,0,0,0,0,0,0") ?: "0,0,0,0,0,0,0"
            val todayIndex = widgetData.getString("streak_today_index", "0")?.toIntOrNull() ?: 0

            // Parse week days: 7 booleans (Mon..Sun)
            val weekCompleted = BooleanArray(7)
            val parts = streakWeekStr.split(",")
            for (i in 0 until 7) {
                if (i < parts.size) {
                    weekCompleted[i] = parts[i].trim() == "1" || parts[i].trim().equals("true", ignoreCase = true)
                }
            }

            // Draw the 7-day Duolingo-style tracker bitmap
            val weekBitmap = createWeekBitmap(context, weekCompleted, todayIndex)

            // Intent to open app when tapping widget
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = if (launchIntent != null) {
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                PendingIntent.getActivity(context, 0, launchIntent, flags)
            } else null

            appWidgetIds.forEach { widgetId ->
                try {
                    val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                        setTextViewText(R.id.streak_count, streakCount)
                        setTextViewText(R.id.streak_subtitle, streakSubtitle)
                        setTextViewText(R.id.streak_target, streakTarget)
                        setTextViewText(R.id.streak_motivation, streakMotivation)
                        setImageViewBitmap(R.id.streak_week_image, weekBitmap)

                        if (pendingIntent != null) {
                            setOnClickPendingIntent(R.id.streak_widget_root, pendingIntent)
                        }
                    }
                    appWidgetManager.updateAppWidget(widgetId, views)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createWeekBitmap(
        context: Context,
        completed: BooleanArray,
        todayIndex: Int
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val widthPx = (280 * density).toInt().coerceAtLeast(360)
        val heightPx = (54 * density).toInt().coerceAtLeast(70)

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val days = arrayOf("L", "M", "X", "J", "V", "S", "D")

        // Layout measurements
        val circleRadius = 12f * density
        val cy = heightPx - circleRadius - (4f * density)
        val textY = cy - circleRadius - (4f * density)

        // Paints
        val activePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FF7A00")
            style = Paint.Style.FILL
        }
        val activeGlowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#33FF7A00")
            style = Paint.Style.FILL
        }
        val inactivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1C2430")
            style = Paint.Style.FILL
        }
        val inactiveStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#334155")
            strokeWidth = 1.5f * density
            style = Paint.Style.STROKE
        }
        val todayStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FF9600")
            strokeWidth = 2f * density
            style = Paint.Style.STROKE
        }
        val checkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            strokeWidth = 2.2f * density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            style = Paint.Style.STROKE
        }
        val pathPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            strokeWidth = 3f * density
            style = Paint.Style.STROKE
        }
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 10f * density
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        // Calculate positions
        val usableWidth = widthPx - 28f * density
        val stepX = usableWidth / 6f
        val centersX = FloatArray(7) { i -> 14f * density + stepX * i }

        // 1. Draw connecting track lines behind circles
        for (i in 0 until 6) {
            val isSegmentActive = completed[i] && completed[i + 1]
            pathPaint.color = if (isSegmentActive) Color.parseColor("#FF7A00") else Color.parseColor("#222E3C")
            canvas.drawLine(centersX[i], cy, centersX[i + 1], cy, pathPaint)
        }

        // 2. Draw circles & day contents
        for (i in 0 until 7) {
            val cx = centersX[i]
            val isDone = completed[i]
            val isToday = (i == todayIndex)

            // Day Letter
            labelPaint.color = when {
                isDone -> Color.parseColor("#FF9600")
                isToday -> Color.WHITE
                else -> Color.parseColor("#64748B")
            }
            canvas.drawText(days[i], cx, textY, labelPaint)

            if (isDone) {
                // Glow around completed circle
                canvas.drawCircle(cx, cy, circleRadius + 2f * density, activeGlowPaint)
                // Filled orange circle
                canvas.drawCircle(cx, cy, circleRadius, activePaint)

                // White checkmark
                val checkPath = Path().apply {
                    moveTo(cx - 4.5f * density, cy + 0.2f * density)
                    lineTo(cx - 1.2f * density, cy + 3.5f * density)
                    lineTo(cx + 4.5f * density, cy - 2.8f * density)
                }
                canvas.drawPath(checkPath, checkPaint)
            } else if (isToday) {
                // Today pending: dark background + pulsing/bright orange border
                canvas.drawCircle(cx, cy, circleRadius, inactivePaint)
                canvas.drawCircle(cx, cy, circleRadius, todayStrokePaint)
                // Small orange inner dot
                canvas.drawCircle(cx, cy, 3f * density, activePaint)
            } else {
                // Inactive day
                canvas.drawCircle(cx, cy, circleRadius, inactivePaint)
                canvas.drawCircle(cx, cy, circleRadius, inactiveStrokePaint)
                // Small subtle inner dot
                val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = Color.parseColor("#334155")
                    style = Paint.Style.FILL
                }
                canvas.drawCircle(cx, cy, 2.5f * density, dotPaint)
            }
        }

        return bitmap
    }
}
