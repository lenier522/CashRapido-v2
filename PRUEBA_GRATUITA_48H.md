# Prueba gratuita de 48 h con borrado de datos

Documento de revisión de la funcionalidad implementada el **5 de noviembre de 2026**
en la rama `redesign/cashrapido-2`.

> Alcance del documento: solo la prueba gratuita de 48 h. Los demás cambios que
> ya existían en la rama (rediseño de cartera, `CashButton`, textos de "Crear una
> cuenta", `_isCuba = true`) **no** forman parte de este trabajo.

---

## 1. Regla de negocio solicitada

| Situación | Comportamiento |
|---|---|
| Primeros 2 días (48 h) desde la instalación | Todo desbloqueado, **excepto** IA, copias en Google Drive y copias de seguridad locales. |
| El usuario compra un plan dentro del plazo | Los datos se conservan y se desbloquean las funciones del plan. |
| Terminan las 48 h sin plan | Se eliminan **todos** los datos de la app automáticamente (una sola vez). |
| Después del borrado | La app sigue siendo usable con el plan gratuito y datos nuevos. |

---

## 2. Resumen de lo implementado

- Nuevo servicio `lib/services/trial_service.dart` que concentra la ventana de
  48 h, la detección del plan y el borrado.
- `AppProvider` expone el estado de la prueba y lo aplica al *gating* de
  capacidades (un solo interruptor `_trialUnlocked`).
- El borrado se ejecuta en dos momentos: al arrancar (`main()`, antes de que los
  providers abran Hive) y al reanudar la app si la prueba venció en segundo plano.
- Las copias de seguridad locales quedan bloqueadas durante la prueba mediante
  un nuevo getter `canBackupLocal`.
- UI: banner con tiempo restante en Inicio, estado de la prueba en Licencias y
  diálogo de aviso tras el borrado.
- 4 claves nuevas de traducción en español, inglés y francés (paridad completa).
- 10 tests nuevos que cubren la ventana, la detección de plan y el borrado.

---

## 3. Cómo funciona

### 3.1 Ciclo de vida de la prueba

```
Primer arranque
   └─ TrialService.startIfNeeded()
        ├─ ¿ya había datos o onboarding visto?  → trial_exempt = true (no se borra nunca)
        └─ si no                                → guarda trial_start_date = ahora

Cada arranque
   └─ TrialService.enforceAtStartup()   (en main(), antes de abrir Hive)
        ├─ exento / ya borrado / plan activo  → no hace nada
        └─ pasaron 48 h                        → wipeStorage() + trial_data_wiped = true

App en segundo plano
   └─ AuthWrapper.didChangeAppLifecycleState(resumed)
        └─ TrialService.shouldWipe() → resetAllData() + clearAllData() + diálogo
```

### 3.2 Detección de "plan activo"

`TrialService.hasPaidPlan(prefs)` consulta:

1. Windows (versión de escritorio desbloqueada) → siempre pago.
2. `trial_converted` → el usuario compró durante la prueba: los datos se
   conservan **para siempre**, aunque el plan caduque luego.
3. `license_type` distinto de `free` y no vencido, usando
   `license_expiration_date` o, en su defecto,
   `license_activation_date + durationDays`.
4. Un plan de pago sin fecha conocida se considera válido (se conserva por
   seguridad).

---

## 4. Archivos

### Nuevos

| Archivo | Contenido |
|---|---|
| `lib/services/trial_service.dart` | Toda la lógica de la prueba: ventana, plan, borrado, cajas y prefs afectadas. |
| `test/trial_service_test.dart` | 10 tests unitarios. |

### Modificados

| Archivo | Cambio |
|---|---|
| `lib/main.dart` | Llama a `enforceAtStartup()` antes de abrir Hive, pasa `trialDataWiped` a `MyApp`/`AuthWrapper`, escucha el ciclo de vida y muestra el aviso. |
| `lib/providers/app_provider.dart` | Importa `TrialService`, expone `isTrialActive`, `trialRemaining`, `trialEndsAt`, `isTrialExempt`, `isTrialExpired`, `trialDataWiped`, `markTrialDataWiped()`, marca `trial_converted` al comprar plan, aplica `_trialUnlocked` a las capacidades y añade `canBackupLocal` + guardas en `backupToLocal`/`restoreFromLocal`. |
| `lib/screens/home_screen.dart` | Banner de prueba activa con el tiempo restante; toca y abre Licencias. |
| `lib/screens/licenses_screen.dart` | La tarjeta del plan gratuito muestra "prueba activa (tiempo restante)" o "prueba finalizada / datos eliminados". |
| `lib/screens/business/business_gatekeeper.dart` | Permite el módulo de negocio durante la prueba. |
| `lib/screens/loans/loans_gatekeeper.dart` | Permite préstamos durante la prueba. |
| `lib/screens/main_screen.dart` | El chat de IA exige `canUseAI` (la prueba no lo desbloquea). |
| `lib/screens/add_card_screen.dart` | El paywall tras crear la primera cuenta no se fuerza durante la prueba. |
| `lib/screens/profile/my_account_screen.dart` | Copia local, importación y el "copia y restablece" respetan `canBackupLocal`; fila atenuada. |
| `lib/screens/loans/loan_reports_screen.dart` | Exportar/importar JSON de préstamos bloqueado sin plan. |
| `lib/services/localization_service.dart` | 4 claves nuevas × 3 idiomas. |

---

## 5. Detalle técnico

### 5.1 Claves en `SharedPreferences`

| Clave | Significado |
|---|---|
| `trial_start_date` | ISO-8601 del inicio de la prueba. |
| `trial_data_wiped` | El borrado por fin de prueba ya se hizo (no se repite). |
| `trial_exempt` | Instalación anterior con datos: nunca se borra. |
| `trial_converted` | Compró plan durante la prueba: datos permanentes. |

### 5.2 Cajas Hive que se eliminan (`TrialService.dataBoxes`)

- **Cartera:** `transactions`, `categories`, `cards`, `recurring_transactions`, `notifications`
- **Negocio:** `businesses`, `products`, `sales`, `business_expenses`, `closings`, `product_categories`, `sellers`, `seller_inventory`
- **Préstamos:** `loans`, `loan_payments`, `borrowers`, `loan_activities`
- **Chat IA:** `ai_chats`

### 5.3 Preferencias que se eliminan (`TrialService.userDataPrefs`)

`custom_banks`, `custom_currencies`, `exchange_rates`, `exchange_rate`,
`google_user_display_name`, `google_user_email`, `google_user_photo_url`,
`google_user_is_connected`, `streak_days`, `login_dates`, `last_login_date`,
`available_random_plans`, `ads_watched`, `transfermovil_enabled`.

### 5.4 Lo que se conserva tras el borrado

Tema, idioma, licencia (`license_type`), PIN y biometría, configuración de
notificaciones, la propia prueba (`trial_*`) y el estado de onboarding. Así la
app sigue siendo usable sin volver a configurarse desde cero.

### 5.5 Capacidades desbloqueadas durante la prueba

Todas las que dependen de `_trialUnlocked`:

`isPremium`, `maxCards` (999), `canTransfer`, `canSecurizeCard`,
`canViewDetailedStats`, `canChangePassword`, `canAddCurrency`, `canImportData`,
`canExportData`, `canUseBiometrics`, `canUseScanner`, `canUseMoreActions`,
`canExportPDF`, `canChangeCardPIN`, `canChangeAppPIN`, `canCreateCategory`,
`canFilterStatsAccount`, `canFilterStatsByIndividualAccount`, `canReorderCards`,
`canManageBanks`, `canExportExcel`, `canCustomizeCharts`, `canUseTransferMovil`,
`canUseWidgets`, `canUseBusinessModule`, más los *gatekeepers* de negocio y
préstamos.

**Siguen bloqueadas:** `canUseAI` y `canSyncDrive` (nivel Enterprise) y
`canBackupLocal` (cualquier plan de pago).

### 5.6 Detalle del borrado

- **En arranque:** las cajas están cerradas; se usa
  `Hive.deleteBoxFromDisk` (o `clear()` si estuviera abierta). Corre en `main()`
  antes de `Hive.openBox('ai_chats')` y de crear los providers, así que estos
  arrancan vacíos y sin condiciones de carrera.
- **Al reanudar:** las cajas están abiertas; se delega en
  `AppProvider.resetAllData()`, `BusinessProvider.clearAllData()` y
  `LoanProvider.clearAllData()`, y después se marca `trial_data_wiped`.
  Un flag `_trialEnforcing` evita reentradas si llegan varias reanudaciones.
- Cada caja se limpia con *mejor esfuerzo*: una caja corrupta no impide limpiar
  el resto.

---

## 6. Traducciones añadidas

| Clave | Uso |
|---|---|
| `trial_active_title` | "Prueba gratis de 2 días" (banner y tarjeta de licencia). |
| `trial_active_desc` | "Te quedan {time}. Al terminar sin un plan activo se eliminarán todos los datos." |
| `trial_ended_title` | "Prueba finalizada". |
| `trial_ended_body` | Explica que se eliminaron los datos del dispositivo. |

Idiomas: `es`, `en`, `fr`. Paridad: 1684 claves en los tres.

---

## 7. Tests

`test/trial_service_test.dart` — 10 tests:

**Ventana de prueba**
1. Las primeras 48 h cuentan como prueba activa.
2. Al pasar las 48 h la prueba termina (y `remaining` es cero).

**Detección de plan**
3. Sin plan, la licencia gratuita no cuenta como pago.
4. Un plan vigente cuenta como pago.
5. Un plan caducado no cuenta como pago.
6. Convertir durante la prueba conserva los datos para siempre.

**Borrado**
7. Dentro de las 48 h no se borra nada.
8. Con plan adquirido no se borra aunque pasen 48 h.
9. Sin plan se borran cajas y prefs, y solo una vez.
10. Las instalaciones anteriores quedan exentas.

---

## 8. Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | **0 errores, 0 warnings** (los 49 infos son preexistentes: `withOpacity` deprecado y `print` en servicios). |
| `flutter test` | **11/11 pasan** (10 nuevos + el test de onboarding que ya existía). |
| Prueba manual en dispositivo/emulador | **No realizada**; no hay validación visual ni de flujo real. |

---

## 9. Decisiones tomadas (revisar)

1. **Usuarios existentes quedan exentos.** Si al actualizar la app ya había datos
   (o el onboarding estaba visto), se marca `trial_exempt` y no se borra nada.
   Para aplicar la prueba a *todos* basta con eliminar esa comprobación en
   `startIfNeeded` y `enforceAtStartup`.
2. **Copias locales = cualquier plan de pago** (Personal, Pro o Enterprise), no
   solo Pro/Enterprise. IA y Drive siguen en Enterprise.
3. **El borrado es local y de una sola vez.** No hay bloqueo permanente: tras el
   borrado el usuario continúa en el plan gratuito.
4. **Ventanas de borrado:** solo en arranque o al reanudar. Si la app queda
   abierta justo al cumplirse las 48 h, se aplica en la siguiente reanudación.
5. **Windows** no aplica la prueba (la versión de escritorio se considera
   desbloqueada tras la activación).

---

## 10. Limitaciones y riesgos

- **La prueba es puramente local.** Reinstalar la app reinicia las 48 h y
  adelantar/atrasar la hora del dispositivo altera el vencimiento. Para una
  garantía dura hace falta validar el inicio de la prueba en servidor (o
  vincularlo a la cuenta/licencia).
- **Borrado irreversible.** No hay papelera ni copia automática previa; si el
  usuario no tenía plan, pierde movimientos, cuentas, negocio y préstamos. Es el
  comportamiento pedido, pero conviene revisarlo con soporte/legal.
- **Google Drive no funciona como red de seguridad** durante la prueba: está
  bloqueado, igual que las copias locales.
- **Política de tiendas:** borrar datos del usuario automáticamente debe estar
  claramente informado en la ficha de la app y en el onboarding; hoy el aviso
  aparece en el banner de Inicio y en Licencias.
- **Sin prueba manual de UI**: el banner, el diálogo y el estado en Licencias no
  se verificaron en un dispositivo real.

---

## 11. Cómo probarlo manualmente

1. Instalar limpio (borrar datos de la app) y abrir.
2. Inicio debe mostrar el banner "Prueba gratis de 2 días · 47 h 59 min".
3. Comprobar que Negocio, Préstamos, estadísticas detalladas y tarjetas
   ilimitadas están accesibles; IA, Drive y "Copia de seguridad local" no.
4. Simular vencimiento sin plan: cerrar la app y escribir en las preferencias
   `trial_start_date` con una fecha de hace 49 h (o borrar el dato y ajustar la
   hora del dispositivo). Al abrir, deben desaparecer los datos y salir el
   diálogo "Prueba finalizada".
5. Repetir comprando un plan (o poniendo `trial_converted = true`): los datos
   deben conservarse aunque pasen las 48 h.

Para reiniciar la prueba en desarrollo: borrar `trial_start_date`,
`trial_data_wiped`, `trial_exempt` y `trial_converted`.

---

## 12. Posibles siguientes pasos

- Validar el inicio de la prueba en servidor para evitar reinstalaciones.
- Añadir un aviso explícito de borrado en el onboarding (hoy solo está en
  Inicio/Licencias).
- Exportar automáticamente un respaldo antes de borrar (requiere replantear la
  regla de copias locales como pago).
- Extraer la prueba a un `TrialProvider` si se quiere seguir aligerando
  `AppProvider`.
- Añadir una prueba de integración del flujo completo de arranque + borrado.
