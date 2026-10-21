package cu.lenier.cashrapido

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    /// Alias de lanzador declarados en AndroidManifest.xml.
    /// Cada clave corresponde a un icono seleccionable desde la app.
    private val iconAliases = mapOf(
        "default" to "LauncherDefault",
        "playa" to "LauncherPlaya",
        "mar" to "LauncherMar",
        "halloween" to "LauncherHalloween",
        "navidad" to "LauncherNavidad",
    )

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
    /// Se activa el nuevo primero para que el lanzador nunca quede sin
    /// icono; `DONT_KILL_APP` evita matar el proceso en curso.
    private fun applyLauncherIcon(enabledAlias: String) {
        val pm = packageManager

        setAliasEnabled(pm, enabledAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED)

        for (alias in iconAliases.values) {
            if (alias == enabledAlias) continue
            setAliasEnabled(pm, alias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
        }
    }

    /// Cambia el estado de un alias ignorando los que no existan.
    ///
    /// Los builds de depuración y perfil eliminan los aliases del manifest
    /// (el lanzador es la propia `MainActivity`, para que `flutter run` nunca
    /// falle), de modo que aquí puede no haber nada que cambiar: un componente
    /// ausente no debe convertir el cambio de icono en un error.
    private fun setAliasEnabled(pm: PackageManager, alias: String, state: Int) {
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
