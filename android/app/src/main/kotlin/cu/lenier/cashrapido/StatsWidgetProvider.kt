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

class StatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        try {
            val incomeTotal = widgetData.getString("stats_income", "0.00") ?: "0.00"
            val expenseTotal = widgetData.getString("stats_expense", "0.00") ?: "0.00"
            val monthLabel = widgetData.getString("stats_month", "Este mes") ?: "Este mes"

            // Read weekly values safely without casting exceptions
            val weeklyIncome = FloatArray(4)
            val weeklyExpense = FloatArray(4)
            for (i in 0..3) {
                weeklyIncome[i] = getFloatSafe(widgetData, "stats_w${i + 1}_income")
                weeklyExpense[i] = getFloatSafe(widgetData, "stats_w${i + 1}_expense")
            }

            // Generate chart bitmap dynamically (runs safely on all Android versions)
            val chartBitmap = createChartBitmap(context, weeklyIncome, weeklyExpense)

            // Intent to open the app when tapping the widget
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
                    val views = RemoteViews(context.packageName, R.layout.stats_widget).apply {
                        setTextViewText(R.id.stats_income, "$$incomeTotal")
                        setTextViewText(R.id.stats_expense, "$$expenseTotal")
                        setTextViewText(R.id.stats_month, monthLabel)
                        setImageViewBitmap(R.id.stats_chart_image, chartBitmap)

                        if (pendingIntent != null) {
                            setOnClickPendingIntent(R.id.stats_widget_root, pendingIntent)
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

    private fun getFloatSafe(prefs: SharedPreferences, key: String): Float {
        return try {
            val raw = prefs.all[key] ?: return 0f
            when (raw) {
                is Float -> raw
                is Double -> raw.toFloat()
                is Long -> java.lang.Double.longBitsToDouble(raw).toFloat()
                is Number -> raw.toFloat()
                is String -> raw.toFloatOrNull() ?: 0f
                else -> 0f
            }
        } catch (_: Exception) {
            0f
        }
    }

    private fun createChartBitmap(
        context: Context,
        incomes: FloatArray,
        expenses: FloatArray
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val widthPx = (280 * density).toInt().coerceAtLeast(360)
        val heightPx = (100 * density).toInt().coerceAtLeast(140)

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Paints
        val incomePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#10B981")
            style = Paint.Style.FILL
        }
        val expensePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#EF4444")
            style = Paint.Style.FILL
        }
        val emptyBarPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#334155")
            style = Paint.Style.FILL
        }
        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1E293B")
            strokeWidth = 1.5f * density
            style = Paint.Style.STROKE
        }
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#94A3B8")
            textSize = 10f * density
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val legendPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#94A3B8")
            textSize = 9f * density
            textAlign = Paint.Align.LEFT
        }

        // Layout measurements
        val legendH = 14f * density
        val labelAreaH = 18f * density
        val baselineY = heightPx - labelAreaH
        val chartMaxH = (baselineY - legendH - 6f * density).coerceAtLeast(20f)

        // Draw Legend at top
        val dotRadius = 3f * density
        val legendY = 9f * density
        val legendStartX = 12f * density

        // Income legend
        canvas.drawCircle(legendStartX + dotRadius, legendY, dotRadius, incomePaint)
        canvas.drawText("Ingresos", legendStartX + dotRadius * 2 + 4f * density, legendY + 3f * density, legendPaint)

        // Expense legend
        val expenseStartX = legendStartX + 65f * density
        canvas.drawCircle(expenseStartX + dotRadius, legendY, dotRadius, expensePaint)
        canvas.drawText("Gastos", expenseStartX + dotRadius * 2 + 4f * density, legendY + 3f * density, legendPaint)

        // Draw baseline
        canvas.drawLine(8f * density, baselineY, widthPx - 8f * density, baselineY, linePaint)

        // Calculate max value for scaling
        var maxVal = 0f
        for (v in incomes) if (v > maxVal) maxVal = v
        for (v in expenses) if (v > maxVal) maxVal = v
        val effectiveMax = if (maxVal > 0f) maxVal else 1f

        // Draw 4 weekly columns
        val usableWidth = widthPx - 24f * density
        val colWidth = usableWidth / 4f
        val barWidth = 10f * density
        val barSpacing = 3f * density
        val cornerRadius = 3f * density

        for (i in 0..3) {
            val colCenterX = 12f * density + colWidth * i + colWidth / 2f

            // Week label (S1, S2, S3, S4)
            canvas.drawText("S${i + 1}", colCenterX, baselineY + 13f * density, labelPaint)

            val inc = incomes[i]
            val exp = expenses[i]

            // Income bar (left)
            val incLeft = colCenterX - barWidth - (barSpacing / 2f)
            val incRight = colCenterX - (barSpacing / 2f)
            if (maxVal > 0f && inc > 0f) {
                val incHeight = (inc / effectiveMax * chartMaxH).coerceAtLeast(3f * density)
                val incTop = baselineY - incHeight
                canvas.drawRoundRect(RectF(incLeft, incTop, incRight, baselineY), cornerRadius, cornerRadius, incomePaint)
            } else {
                canvas.drawRoundRect(RectF(incLeft, baselineY - 2f * density, incRight, baselineY), 1f * density, 1f * density, emptyBarPaint)
            }

            // Expense bar (right)
            val expLeft = colCenterX + (barSpacing / 2f)
            val expRight = colCenterX + barWidth + (barSpacing / 2f)
            if (maxVal > 0f && exp > 0f) {
                val expHeight = (exp / effectiveMax * chartMaxH).coerceAtLeast(3f * density)
                val expTop = baselineY - expHeight
                canvas.drawRoundRect(RectF(expLeft, expTop, expRight, baselineY), cornerRadius, cornerRadius, expensePaint)
            } else {
                canvas.drawRoundRect(RectF(expLeft, baselineY - 2f * density, expRight, baselineY), 1f * density, 1f * density, emptyBarPaint)
            }
        }

        return bitmap
    }
}
