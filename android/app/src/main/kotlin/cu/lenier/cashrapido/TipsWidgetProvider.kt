package cu.lenier.cashrapido

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TipsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.tips_widget).apply {
                val tip = widgetData.getString("tip", "Ahorra al menos el 20% de tus ingresos mensuales.") 
                    ?: "Ahorra al menos el 20% de tus ingresos mensuales."
                
                setTextViewText(R.id.widget_tip, tip)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
