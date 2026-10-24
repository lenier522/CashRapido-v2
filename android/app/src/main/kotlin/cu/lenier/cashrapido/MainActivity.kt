package cu.lenier.cashrapido

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    /// Alias de lanzador declarados en AndroidManifest.xml.
    /// Cada clave corresponde a un icono seleccionable desde la app.
    private val iconAliases = mapOf(
        "default"   to "LauncherDefault",
        "playa"     to "LauncherPlaya",
        "mar"       to "LauncherMar",
        "halloween" to "LauncherHalloween",
        "navidad"   to "LauncherNavidad",
    )

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Re-aplica el icono guardado al iniciar la app (ej. tras actualización de APK).
        // AppIconService persiste con _selectedKey = 'app_icon_selected'; Flutter
        // prefija automáticamente las claves con "flutter." en SharedPreferences.
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedKey = prefs.getString("flutter.app_icon_selected", "default") ?: "default"
        val alias = iconAliases[savedKey] ?: "LauncherDefault"
        applyLauncherIcon(alias)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cashrapido/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val key = call.argument<String>("key")
                        val alias = iconAliases[key]
                        if (alias == null) {
                            result.error("bad_arg", "Icono desconocido: $key", null)
                        } else {
                            try {
                                applyLauncherIcon(alias)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("icon_error", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Activa el alias [enabledAlias] y desactiva los demás.
    ///
    /// Se activa el nuevo primero para que el lanzador nunca quede sin icono.
    /// Los aliases inactivos se ponen en COMPONENT_ENABLED_STATE_DEFAULT (no
    /// DISABLED): así siguen el valor `android:enabled` del manifiesto (todos
    /// tienen `enabled="false"`). Esto garantiza que tras reinstalar el APK
    /// los estados se restablecen automáticamente a "deshabilitado", permitiendo
    /// que `flutter run --release` encuentre y lance la app sin error.
    private fun applyLauncherIcon(enabledAlias: String) {
        val pm = packageManager

        // Habilita el alias activo primero (nunca sin icono)
        setAliasState(pm, enabledAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED)

        // Los inactivos vuelven a su estado de manifiesto (enabled=false → deshabilitado)
        for (alias in iconAliases.values) {
            if (alias == enabledAlias) continue
            setAliasState(pm, alias, PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
        }
    }

    /// Cambia el estado de un alias ignorando los que no existan.
    ///
    /// Los builds de depuración y perfil no eliminan ningún alias del manifiesto.
    /// En release, el overlay elimina el intent-filter de MAIN/LAUNCHER de
    /// MainActivity, delegando el lanzamiento exclusivamente a los aliases.
    private fun setAliasState(pm: PackageManager, alias: String, state: Int) {
        try {
            pm.setComponentEnabledSetting(
                ComponentName(this, "$packageName.$alias"),
                state,
                PackageManager.DONT_KILL_APP,
            )
        } catch (e: IllegalArgumentException) {
            // Componente no declarado en este build: no hay nada que hacer.
        }
    }
}
