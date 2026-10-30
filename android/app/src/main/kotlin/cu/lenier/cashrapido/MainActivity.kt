package cu.lenier.cashrapido

import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Actividad principal de la app.
 *
 * El icono de la pantalla de inicio no se puede cambiar con `android:icon` en
 * tiempo de ejecución: cada icono es un `<activity-alias>` y aquí se activa
 * exactamente uno mediante `PackageManager`. Las mismas reglas viven en
 * `lib/services/app_icon_service.dart`:
 *
 * 1. Si hay una temporada activa (Halloween o Navidad) se usa su icono.
 * 2. Si no, se usa el icono guardado, pero solo con licencia Empresarial.
 * 3. En cualquier otro caso, el icono por defecto.
 *
 * Al aplicar un icono se habilitan primero el elegido y después se deshabilitan
 * los demás, de modo que nunca haya dos iconos en la pantalla de inicio.
 */
class MainActivity : FlutterFragmentActivity() {

    /** Alias de lanzador declarados en AndroidManifest.xml. */
    private val iconAliases = mapOf(
        "default" to "LauncherDefault",
        "playa" to "LauncherPlaya",
        "mar" to "LauncherMar",
        "halloween" to "LauncherHalloween",
        "navidad" to "LauncherNavidad",
    )

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Re-aplica el icono al arrancar (p. ej. tras una actualización o al
        // cambiar de temporada). Si el build no declara los aliases (debug y
        // profile los eliminan), la llamada no hace nada.
        applyLauncherIcon(resolveAlias())
    }

    /**
     * Alias que debe mostrarse ahora, con las mismas prioridades que
     * `AppIconService.resolve` en Dart.
     */
    private fun resolveAlias(): String {
        seasonalAlias()?.let { return it }

        val prefs = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val savedKey = prefs.getString(KEY_SELECTED_ICON, "default") ?: "default"
        val alias = iconAliases[savedKey] ?: DEFAULT_ALIAS

        if (alias == DEFAULT_ALIAS) return DEFAULT_ALIAS
        return if (hasEnterpriseLicense(prefs)) alias else DEFAULT_ALIAS
    }

    /** Icono estacional activo, o `null` si no hay temporada. */
    private fun seasonalAlias(): String? {
        val now = Calendar.getInstance()
        val month = now.get(Calendar.MONTH) + 1 // 1-12
        val day = now.get(Calendar.DAY_OF_MONTH)

        // Halloween: 25 al 31 de octubre.
        if (month == 10 && day >= 25) return "LauncherHalloween"

        // Navidad: 20 de diciembre al 6 de enero.
        if ((month == 12 && day >= 20) || (month == 1 && day <= 6)) {
            return "LauncherNavidad"
        }
        return null
    }

    /**
     * Refleja `AppProvider.isEnterpriseActive` sin depender de Flutter.
     *
     * `LicenseType` se persiste por índice (ver `lib/licences/license_type.dart`):
     * 2, 5 y 8 son las variantes semanal, mensual y anual Empresarial; 9 es free.
     * La fecha exacta de vencimiento la valida Dart al arrancar, que además
     * corrige el icono si el plan venció.
     */
    private fun hasEnterpriseLicense(prefs: SharedPreferences): Boolean {
        val type = prefs.getInt(KEY_LICENSE_TYPE, LICENSE_TYPE_FREE)
        return type == LICENSE_TYPE_WEEKLY_ENTERPRISE ||
            type == LICENSE_TYPE_MONTHLY_ENTERPRISE ||
            type == LICENSE_TYPE_ANNUAL_ENTERPRISE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val key = call.argument<String>("key")
                        val alias = iconAliases[key]
                        if (alias == null) {
                            result.error("bad_arg", "Icono desconocido: $key", null)
                        } else {
                            try {
                                // `false` = el build no declara el alias (debug/profile).
                                result.success(applyLauncherIcon(alias))
                            } catch (e: Exception) {
                                result.error("icon_error", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Activa [enabledAlias] y desactiva los demás.
     *
     * Devuelve `true` solo si el alias existe en este build y pudo habilitarse.
     * En debug/profile los aliases se eliminan del manifest, así que se
     * devuelve `false` sin tocar ningún componente.
     */
    private fun applyLauncherIcon(enabledAlias: String): Boolean {
        val pm = packageManager

        // Habilita el alias activo primero: el lanzador nunca queda sin icono.
        if (!setAliasState(pm, enabledAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED)) {
            return false
        }

        // Deshabilita los demás para que solo exista un icono.
        for (alias in iconAliases.values) {
            if (alias == enabledAlias) continue
            setAliasState(pm, alias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
        }
        return true
    }

    /**
     * Cambia el estado de un alias y devuelve si el componente existe.
     *
     * `setComponentEnabledSetting` lanza `IllegalArgumentException` cuando el
     * alias no está declarado en el manifest de este build; ese caso no es un
     * error en desarrollo y se ignora.
     */
    private fun setAliasState(pm: PackageManager, alias: String, state: Int): Boolean {
        return try {
            pm.setComponentEnabledSetting(
                ComponentName(this, "$packageName.$alias"),
                state,
                PackageManager.DONT_KILL_APP,
            )
            true
        } catch (e: IllegalArgumentException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    private companion object {
        const val CHANNEL = "cashrapido/app_icon"
        const val PREFERENCES_NAME = "FlutterSharedPreferences"
        const val KEY_SELECTED_ICON = "flutter.app_icon_selected"
        const val KEY_LICENSE_TYPE = "flutter.license_type"
        const val LICENSE_TYPE_FREE = 9
        const val LICENSE_TYPE_WEEKLY_ENTERPRISE = 2
        const val LICENSE_TYPE_MONTHLY_ENTERPRISE = 5
        const val LICENSE_TYPE_ANNUAL_ENTERPRISE = 8
        const val DEFAULT_ALIAS = "LauncherDefault"
    }
}
