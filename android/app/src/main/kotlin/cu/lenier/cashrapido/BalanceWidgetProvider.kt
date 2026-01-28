package cu.lenier.cashrapido

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.balance_widget).apply {
                val balance = widgetData.getString("balance", "0.00") ?: "0.00"
                val currency = widgetData.getString("currency", "CUP") ?: "CUP"
                
                setTextViewText(R.id.widget_balance, "$$balance")
                setTextViewText(R.id.widget_currency, currency)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
