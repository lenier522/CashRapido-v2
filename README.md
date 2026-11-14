# CashRapido

Aplicación de finanzas personales **local-first** desarrollada en **Flutter/Dart**. Permite gestionar cuentas y tarjetas, ingresos y gastos, presupuestos, análisis financieros, negocios, préstamos y respaldos, con soporte multi-moneda y un sistema de licencias integrado.

> **Alcance de este documento:** describe únicamente la aplicación Flutter (`lib/`). No documenta el sitio web, su panel administrativo ni su despliegue.

**Versión de la app:** `2.8.45+40000000` (definida en `pubspec.yaml`)

**Paquete:** `cu.lenier.cashrapido`

**Plataforma principal:** Android (`minSdk 26`). El proyecto también incluye iOS (`deployment target 16.0`), Windows, Linux, macOS y Web. Varias funciones dependen de APIs nativas de Android.

---

## Tabla de contenido

- [Visión general](#visión-general)
- [Stack tecnológico](#stack-tecnológico)
- [Arquitectura](#arquitectura)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Arranque y ciclo de vida](#arranque-y-ciclo-de-vida)
- [Persistencia y datos](#persistencia-y-datos)
- [Modelos de datos](#modelos-de-datos)
- [Módulos y funcionalidades](#módulos-y-funcionalidades)
- [Sistema de licencias](#sistema-de-licencias)
- [Pagos y activación](#pagos-y-activación)
- [Proveedores de estado](#proveedores-de-estado)
- [Servicios](#servicios)
- [Pantallas y navegación](#pantallas-y-navegación)
- [Internacionalización](#internacionalización)
- [Respaldo, exportación y nube](#respaldo-exportación-y-nube)
- [Requisitos y configuración](#requisitos-y-configuración)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Compilación](#compilación)
- [Variables de entorno](#variables-de-entorno)
- [Supabase y migraciones](#supabase-y-migraciones)
- [Pruebas y análisis estático](#pruebas-y-análisis-estático)
- [Limitaciones y estado actual](#limitaciones-y-estado-actual)

---

## Visión general

CashRapido está pensada como una aplicación **offline-first**:

- Los datos financieros viven en **Hive**, en el dispositivo.
- La app funciona sin cuenta, sin internet y sin backend.
- **Supabase** se usa como espejo opcional para cuenta, respaldo en la nube y soporte.
- **Google Drive** se usa como respaldo adicional de archivos.
- La licencia y la prueba gratuita se gestionan localmente con `SharedPreferences`.
- La nube y Google Drive nunca son requisitos para usar el núcleo de la app.

Módulos principales:

| Área | Qué incluye |
|---|---|
| Finanzas personales | Cuentas, tarjetas, efectivo, ingresos, gastos, categorías, presupuestos, recurrentes |
| Análisis | Periodos, filtros, gráficas, proyección mensual, calendario de actividad, presupuestos |
| Multi-moneda | Moneda principal, monedas personalizadas, tasas por pares, conversión inversa y cruzada |
| Negocio | Productos, inventario, POS, vendedores, gastos, cierres, ROI, punto de equilibrio |
| Préstamos | Deudores, préstamos, cuotas, intereses, mora, pagos, refinanciación, reportes |
| IA | Chat financiero con Gemini, historial persistente |
| Respaldo | ZIP local, Google Drive, snapshot completo en Supabase |
| Licencias | Free, Personal, Pro y Enterprise, con pagos y prueba de 7 días |
| Extras | Notificaciones, rachas, widgets, escáner, TransferMóvil, iconos, soporte |

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Lenguaje | Dart `>=3.13.5 <4.0.0` |
| Framework | Flutter `>=3.47.0` con Material 3 (`material_ui`) |
| Estado | `provider` + `ChangeNotifier` |
| Base local | Hive + `hive_flutter` + adaptadores generados |
| Preferencias | `shared_preferences` |
| Nube y cuenta | `supabase_flutter` |
| Autenticación Google | `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth` |
| Respaldo en Drive | Google Drive API v3 |
| IA | `google_generative_ai` con Gemini `gemini-2.5-flash-lite` |
| Pagos | QvaPay, Apklis, Art-Pay, PayPal y anuncios (visibilidad según configuración) |
| Anuncios | `google_mobile_ads` |
| Gráficas | `fl_chart` |
| Excel | `syncfusion_flutter_xlsio` |
| PDF | `pdf` |
| Compartir archivos | `share_plus`, `file_picker`, `path_provider` |
| Notificaciones | `flutter_local_notifications`, `timezone` |
| Seguridad | `local_auth`, `crypto`, PIN/contraseña locales, AES para Hive de préstamos |
| Escáner | `camera`, `mobile_scanner` |
| SMS | `flutter_sms_inbox` |
| Widgets Android | `home_widget` |
| Tipografía | `google_fonts` (Outfit) |
| Animaciones | `lottie`, `animated_bottom_navigation_bar` |
| Tour | `tutorial_coach_mark` |
| i18n | `flutter_localizations` + localización propia |

Dependencias de desarrollo relevantes:

- `build_runner`
- `hive_generator`
- `flutter_lints`
- `flutter_test`

---

## Arquitectura

CashRapido sigue una arquitectura **local-first por capas**, sin un backend obligatorio para las operaciones diarias.

```text
main()
 ├─ AppInfo.initialize()
 ├─ Hive.initFlutter()
 ├─ dotenv.load()
 ├─ SupabaseService.initialize()          // no bloqueante si falla
 ├─ Registro de adaptadores Hive
 ├─ TrialService.enforceAtStartup()       // marca vencimiento; no borra datos
 ├─ Apertura de cajas Hive
 ├─ MultiProvider
 │   ├─ AppProvider
 │   ├─ BusinessProvider
 │   └─ LoanProvider
 └─ MyApp
     └─ AuthWrapper
         ├─ Onboarding (primera vez)
         ├─ Bloqueo de acceso (biometría/PIN/contraseña)
         ├─ Hardware lock en Windows
         ├─ MainScreen
         └─ Servicios en segundo plano
```

### Principios

1. **Hive es la fuente de verdad.** La interfaz lee y escribe primero en local.
2. **La nube es una copia, no la base principal.** Supabase y Drive se usan para respaldo o restauración.
3. **La app arranca sin red.** `SupabaseService.initialize()` no lanza errores fatales.
4. **Los proveedores concentran estado y reglas de negocio.** Las pantallas consumen `AppProvider`, `BusinessProvider` y `LoanProvider`.
5. **Las capacidades se controlan con getters de licencia.** La UI consulta `canUseAI`, `canSyncDrive`, `canExportExcel`, etc.
6. **La navegación principal es fija.** `MainScreen` usa un `IndexedStack` para conservar el estado de cada pestaña.

### Navegación

- Barra inferior con cuatro destinos reales: **Inicio**, **Movimientos**, **Análisis** y **Perfil**.
- El slot central está reservado para la **acción de IA**, que no es una pestaña.
- La IA solo abre el chat si el plan lo permite y si el usuario la habilitó en Ajustes.
- Las pantallas secundarias se abren con `Navigator.push`.
- `mainTabRequest` permite que una pantalla externa solicite volver a una pestaña concreta.

---

## Estructura del proyecto

```text
cashrapido/
├── android/                         # Configuración nativa Android
├── assets/
│   ├── animations/                  # Animaciones Lottie
│   ├── icons/app_icons/             # Iconos de la app
│   └── onboarding/                  # Imágenes del onboarding
├── ios/
├── lib/
│   ├── licences/
│   │   ├── apklis.dart              # Verificación/compra con Apklis
│   │   ├── art_pay.dart             # Pagos y precios con Art-Pay
│   │   ├── license_type.dart        # Niveles, periodos y duración
│   │   ├── payment_config.dart      # Métodos habilitados por licencia
│   │   └── README.md                # Notas internas del sistema de licencias
│   ├── models/
│   │   ├── models.dart              # Category, InternalTransaction, AccountCard,
│   │   │                            # ChatMessage y ChatConversation
│   │   ├── models.g.dart            # Código Hive generado
│   │   ├── borrower.dart            # Borrower
│   │   ├── business.dart            # Business
│   │   ├── business_expense.dart    # BusinessExpense
│   │   ├── closing.dart             # Closing
│   │   ├── currency_conversion.dart # CurrencyConversion (pares de monedas)
│   │   ├── loan.dart                # Loan, LoanPayment e Installment
│   │   ├── loan_activity.dart       # LoanActivity
│   │   ├── notification_item.dart   # NotificationItem
│   │   ├── payment_method.dart      # PaymentMethod
│   │   ├── product.dart             # Product
│   │   ├── product_category.dart    # ProductCategory
│   │   ├── recurring_transaction.dart
│   │   ├── sale.dart                # Sale y SaleItem
│   │   ├── seller.dart              # Seller
│   │   └── seller_inventory.dart    # SellerInventory
│   ├── providers/
│   │   ├── app_provider.dart        # Estado central, licencias, monedas, respaldos
│   │   ├── business_provider.dart   # Negocio, inventario, ventas, cierres
│   │   └── loan_provider.dart       # Préstamos, cuotas, mora y reportes
│   ├── screens/
│   │   ├── business/                # Módulo completo de negocio
│   │   ├── loans/                   # Módulo completo de préstamos
│   │   ├── profile/                 # Cuenta, Drive, nube, ajustes de perfil
│   │   ├── stats/                   # Vistas de proyección y calendario
│   │   ├── support/                 # Chat, bandeja y campañas de soporte
│   │   ├── add_card_screen.dart
│   │   ├── add_category_screen.dart
│   │   ├── ai_chat_screen.dart
│   │   ├── all_transactions_screen.dart
│   │   ├── card_scanner_screen.dart
│   │   ├── default_license_screen.dart
│   │   ├── home_screen.dart
│   │   ├── info_screens.dart
│   │   ├── licenses_screen.dart
│   │   ├── main_screen.dart
│   │   ├── money_counter_screen.dart
│   │   ├── notification_settings_screen.dart
│   │   ├── notifications_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── qvapay_checkout_screen.dart
│   │   ├── recurring_transaction_form_screen.dart
│   │   ├── recurring_transactions_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── stats_screen.dart
│   │   ├── streak_calendar_screen.dart
│   │   ├── transfermovil_screen.dart
│   │   └── wallet_screen.dart
│   ├── services/
│   │   ├── ad_service.dart
│   │   ├── ai_service.dart
│   │   ├── ai_service_mobile.dart
│   │   ├── app_icon_service.dart
│   │   ├── app_info.dart
│   │   ├── backup_service.dart
│   │   ├── changelog_service.dart
│   │   ├── cloud_codec.dart
│   │   ├── cloud_sync_service.dart
│   │   ├── currency_conversion_service.dart
│   │   ├── drive_service.dart
│   │   ├── export_service.dart
│   │   ├── feedback_service.dart
│   │   ├── google_auth_service.dart
│   │   ├── localization_service.dart
│   │   ├── notification_service.dart
│   │   ├── official_links.dart
│   │   ├── paypal_service.dart
│   │   ├── qvapay_service.dart
│   │   ├── stats_aggregator.dart
│   │   ├── supabase_service.dart
│   │   ├── support_chat_service.dart
│   │   ├── tour_service.dart
│   │   ├── trial_service.dart
│   │   └── widget_service.dart
│   ├── theme/                       # Colores, tipografía, radios, sombras
│   ├── utils/                       # Iconos, formatos, recibos, tour
│   ├── widgets/
│   │   ├── design/                  # Componentes visuales reutilizables
│   │   ├── add_transaction_modal.dart
│   │   └── smooth_switch.dart
│   └── main.dart
├── supabase/
│   └── migrations/                  # Esquema de nube, soporte y licencias
├── test/                            # Pruebas unitarias y de widget
├── CHANGELOG.md
├── PRUEBA_GRATUITA_7_DIAS.md        # Detalle de la prueba y el bloqueo de cuentas
├── pubspec.yaml
└── README.md
```

---

## Arranque y ciclo de vida

### Secuencia de `main()`

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `AppInfo.initialize()` carga nombre, paquete, versión y build desde `package_info_plus`.
3. `Hive.initFlutter()`, formatos de fecha en español y carga de `.env`.
4. `SupabaseService.initialize()`. Si no hay red, la app continúa.
5. Registro de adaptadores Hive:
   - Cartera, negocio, préstamos, chat, recurrentes y notificaciones.
6. `TrialService.enforceAtStartup()`:
   - Se ejecuta **antes** de abrir las cajas de datos.
   - Si la prueba de 7 días terminó sin plan, marca el aviso de fin de prueba.
   - **No borra datos**: solo bloquea las cuentas adicionales hasta que se active una licencia.
7. Se abre la caja `ai_chats` y se registra para la sincronización.
8. Se lee `seenOnboarding` de `SharedPreferences`.
9. Se crean los tres providers con `MultiProvider`.
10. `MyApp` aplica tema, modo oscuro, locale y delegados de localización.
11. `AuthWrapper` decide entre onboarding, bloqueo de acceso o `MainScreen`.
12. Al completar el onboarding, la app abre `WalletScreen` para crear la primera cuenta.

### Onboarding

El onboarding usa cuatro imágenes a pantalla completa (`assets/onboarding/onb1.png` a `onb4.png`), con opción de saltar. Al terminar, guarda `seenOnboarding` y navega a `WalletScreen` para crear la primera cuenta.

### `AuthWrapper`

`AuthWrapper` es el guardián de entrada:

- Muestra el **onboarding** de cuatro imágenes si es la primera ejecución.
- Comprueba el bloqueo de acceso:
  - biometría;
  - PIN de app;
  - contraseña de app.
- En **Windows**, exige un equipo autorizado por MAC y un código de activación.
- Escucha los cambios de sesión de Supabase.
- Al iniciar sesión con Google, sincroniza el perfil visible.
- Conecta la sincronización automática con Supabase.
- Al reanudar la app, y cada minuto mientras permanece abierta, comprueba si la prueba gratuita venció.

### Servicios en segundo plano

Después del arranque, `AppProvider` inicializa de forma no bloqueante:

- anuncios;
- notificaciones locales;
- widgets;
- sesión de Google Drive;
- perfil de Google y su caché.

La app no espera a estos servicios para mostrar la pantalla principal.

---

## Persistencia y datos

### Cajas Hive

| Caja | Modelo | TypeId | Uso |
|---|---|---:|---|
| `transactions` | `InternalTransaction` | 1 | Ingresos, gastos y movimientos |
| `categories` | `Category` | 0 | Categorías de movimientos |
| `cards` | `AccountCard` | 2 | Tarjetas, cuentas y efectivo |
| `recurring_transactions` | `RecurringTransaction` | 20 | Movimientos recurrentes |
| `notifications` | `NotificationItem` | 21 | Centro de notificaciones |
| `businesses` | `Business` | 10 | Negocios |
| `products` | `Product` | 3 | Productos e inventario |
| `sales` | `Sale` | 11 | Ventas del negocio |
| `business_expenses` | `BusinessExpense` | 13 | Gastos del negocio |
| `closings` | `Closing` | 14 | Cierres de caja |
| `product_categories` | `ProductCategory` | 22 | Categorías y subcategorías de productos |
| `sellers` | `Seller` | 30 | Vendedores |
| `seller_inventory` | `SellerInventory` | 32 | Inventario asignado por vendedor |
| `loans` | `Loan` | 25 | Préstamos |
| `loan_payments` | `LoanPayment` | 26 | Pagos de préstamos |
| `borrowers` | `Borrower` | 27 | Deudores |
| `loan_activities` | `LoanActivity` | 29 | Historial de actividad de préstamos |
| `ai_chats` | `ChatConversation` | 16 | Conversaciones de IA |

Modelos embebidos:

- `SaleItem` (TypeId 12) dentro de `Sale`.
- `Installment` (TypeId 28) dentro de `Loan`.
- `ChatMessage` (TypeId 15) dentro de `ChatConversation`.

`CurrencyConversion` **no usa Hive**: se guarda como JSON en `SharedPreferences`.

### `SharedPreferences`

Las preferencias se agrupan en:

| Grupo | Claves representativas |
|---|---|
| Licencia | `license_type`, `license_expiration_date`, `license_activation_date` |
| Prueba | `trial_start_date`, `trial_lock_notice_shown`, `trial_exempt`, `trial_converted` |
| Seguridad | `app_pin_hash`, `app_password_hash`, `biometrics_enabled` |
| Apariencia | `theme_mode`, `app_language`, `decimal_separator`, `chart_type` |
| Monedas | `main_currency`, `custom_currencies`, `exchange_rate_pairs`, `exchange_rates`, `exchange_rate` (legacy) |
| Bancos | `custom_banks` |
| Notificaciones | `notifications_enabled`, `daily_reminder_enabled`, `daily_reminder_hour`, `daily_reminder_minute`, `tips_enabled` |
| Google | `google_user_display_name`, `google_user_email`, `google_user_photo_url`, `google_user_photo_path`, `google_user_is_connected` |
| Supabase/Drive | `cloud_auto_sync`, `cloud_last_sync` |
| Pagos | `qvapay_client_id`, `ads_watched` |
| Extras | `transfermovil_enabled`, `streak_days`, `login_dates`, `last_login_date` |

### Cifrado

- Las cajas de préstamos (`loans`, `loan_payments`, `borrowers`, `loan_activities`) se abren con `HiveAesCipher`.
- Solo esas cajas de préstamos están cifradas; el resto de cajas Hive no usa cifrado.
- La clave se deriva con SHA-256 de una sal fija de la app.
- Si una caja antigua no se puede abrir cifrada, se usa el modo sin cifrado como compatibilidad.
- Las copias ZIP contienen los archivos `.hive`; deben tratarse como información sensible.
- El PIN y la contraseña de la app se guardan como hash SHA-256, no en texto plano.

### Monedas y tasas

`CurrencyConversion` representa un par `fromCode -> toCode` con una tasa. Reglas:

- Se guarda **una fila por par**.
- La tasa inversa se calcula como `1 / rate`.
- `CurrencyConversionService.findRate()` construye un grafo bidireccional y busca la ruta más corta con BFS.
- Esto permite tasas cruzadas sin guardar todos los pares, por ejemplo `USD -> CUP` y `EUR -> CUP` para deducir `USD -> EUR`.
- Si no hay ruta, `convert()` devuelve el importe sin cambios.
- La opción **Todas las Cuentas** de Inicio suma los saldos de todas las tarjetas convirtiendo cada uno a la moneda principal.
- Las tasas antiguas (`exchange_rates`) se migran a pares mediante `fromLegacyRates()`.
- Los cambios de tasas se aplican solo al pulsar **Guardar**; **Cancelar** descarta los cambios pendientes.

---

## Modelos de datos

| Modelo | Campos principales / propósito |
|---|---|
| `Category` | Nombre, icono, color, tipo y marca de categoría personalizada |
| `InternalTransaction` | Fecha, importe, moneda, categoría, tarjeta, título y tipo |
| `AccountCard` | Nombre, banco, número, saldo, moneda, efectivo, bloqueo, límite y PIN |
| `RecurringTransaction` | Plantilla de movimiento con frecuencia y próxima ejecución |
| `NotificationItem` | Notificación local/centro de notificaciones |
| `Business` | Nombre, tipo, icono, color, capital inicial, moneda y estado |
| `Product` | Nombre, SKU, stock, costo, precio, moneda, categoría y unidad |
| `ProductCategory` | Categoría jerárquica de productos |
| `Sale` / `SaleItem` | Venta, ítems, descuento, método de pago, vendedor y estado |
| `BusinessExpense` | Gasto del negocio con categoría y moneda |
| `Closing` | Corte de caja con métricas, productos vendidos y estadísticas |
| `Seller` | Datos personales, rol, salario, comisión y estado |
| `SellerInventory` | Producto y cantidad asignados a un vendedor |
| `Loan` | Principal, interés, moneda, frecuencia, cuotas, mora y estado |
| `Installment` | Número de cuota, vencimiento, importe y pago acumulado |
| `LoanPayment` | Pago aplicado a un préstamo, fecha, importe y cuenta |
| `Borrower` | Deudor con contacto, dirección y nivel de riesgo |
| `LoanActivity` | Auditoría de acciones sobre préstamos |
| `ChatConversation` / `ChatMessage` | Historial del asistente financiero |
| `CurrencyConversion` | Par de monedas y tasa; se guarda en preferencias |
| `PaymentMethod` | Método de pago visible, habilitado y metadatos de UI |

---

## Módulos y funcionalidades

### Inicio

`HomeScreen` funciona como panel principal:

- Saludo según la hora y racha de días.
- Banner de prueba gratuita con tiempo restante.
- Tarjeta de perfil con avatar y correo de Google, incluyendo caché offline.
- Selector de cuenta/tarjeta, con **Todas las Cuentas** activo por defecto.
- Balance total de todas las cuentas convertido a la moneda principal, además de ingresos y gastos del mes.
- Resumen financiero y gráfico de los últimos días.
- Movimientos recientes con acciones de editar/eliminar.
- Acciones rápidas:
  - gasto;
  - ingreso;
  - transferencia entre cuentas;
  - negocio;
  - recurrentes;
  - TransferMóvil (si está habilitado y es Cuba);
  - **Más**, con historial, balances, préstamos, escáner y ayuda.
- Campana de notificaciones.

La transferencia, recarga y solicitud de dinero se abren desde el flujo de acciones de la cuenta. Si la cuenta tiene PIN, se solicita antes de confirmar.

### Movimientos

La pestaña **Movimientos** reutiliza `AllTransactionsScreen` con:

- Periodo inicial de 30 días y selector de rango personalizado.
- Búsqueda por texto.
- Filtros por cuenta y por tipo (ingreso/gasto).
- Resumen del periodo: balance, ingresos, gastos y cantidad de movimientos.
- Agrupación por día.
- Edición y eliminación con confirmación.
- Estado vacío diferenciado entre “sin movimientos” y “sin resultados”.

### Análisis

`StatsScreen` tiene tres vistas:

| Vista | Contenido |
|---|---|
| Analítica | Resumen, tasa de ahorro, evolución, distribución, gastos principales, presupuesto, métricas e insights |
| Proyección | Estimación del cierre mensual basada en los días transcurridos |
| Calendario | Actividad diaria, ingresos/gastos del día y movimientos seleccionados |

Periodos disponibles: día, semana, mes, año y rango personalizado.

Funciones adicionales:

- Filtro por cuenta (Pro+) y por cuenta individual (Enterprise).
- Tipo de gráfica pastel, barras o líneas; la personalización avanzada es Enterprise.
- Comparación con el periodo anterior.
- Presupuesto mensual por categoría.
- Compartir el análisis como imagen.
- Consejos/insights calculados a partir de los datos.

### Billetera y cuentas

Aunque **Billetera** ya no ocupa una pestaña inferior, sigue existiendo y se abre desde Inicio o Perfil:

- Crear, editar y eliminar tarjetas/cuentas.
- Cuentas de efectivo y cuentas bancarias.
- Saldo y moneda por cuenta.
- Bloqueo/desbloqueo de tarjeta.
- PIN de tarjeta y límites de gasto.
- Reordenar tarjetas (Pro+).
- Límite de tarjetas según el plan.
- Transferencias, recargas y solicitudes desde el panel de Inicio.

### Monedas y tasas de cambio

Configuración disponible en **Ajustes → Tasas de cambio**:

- Moneda principal.
- Monedas predefinidas: CUP, USD, EUR, MLC.
- Monedas personalizadas con código, símbolo y descripción.
- Lista de pares en ambos sentidos.
- Agregar, editar, eliminar e invertir pares.
- Validación de tasas positivas y finitas.
- Cálculo de tasas inversas y cruzadas mediante BFS.
- Aplicación de cambios solo al guardar.
- Uso de las tasas en estadísticas, negocio, préstamos, transferencias de ganancias y exportaciones.

### Negocio

Módulo disponible desde **Pro/Enterprise** o durante la prueba gratuita (`BusinessGatekeeper`).

Incluye:

- Múltiples negocios con tipo, icono, color, capital y moneda.
- Productos con SKU, categorías, subcategorías, stock, costo, precio y unidad.
- Alertas de stock bajo.
- Punto de venta (POS) con carrito, descuentos, métodos de pago y vendedor opcional.
- Vendedores con salario, comisión, estado y datos de contacto.
- Inventario asignado por vendedor y descuento automático al vender.
- Reporte financiero por vendedor.
- Gastos del negocio con categorías y filtros.
- Cierres de caja por periodo:
  - ingresos, gastos y ganancia neta;
  - costo de productos vendidos;
  - ROI;
  - productos más vendidos;
  - métodos de pago;
  - gastos por categoría;
  - rendimiento por vendedor.
- Transferencia de ganancias a una cuenta personal, con conversión si la moneda difiere.
- Analíticas generales y punto de equilibrio.
- Exportación de cierres a PDF/Excel.
- Importación de cierres de vendedores.

### Préstamos

Módulo disponible desde **Enterprise** o durante la prueba (`LoansGatekeeper`):

- Deudores con contacto, dirección y riesgo.
- Préstamos con interés simple, compuesto o fijo.
- Frecuencias diaria, semanal, mensual o pago único.
- Generación automática de cuotas.
- Penalizaciones por mora fijas o porcentuales.
- Registro de pagos y aplicación a cuotas.
- Refinanciación y renegociación.
- Marcado como perdido/cancelado.
- Reportes y métricas por moneda.
- Reportes en Excel y CSV; PDF del detalle/recibo de un préstamo.
- Exportación/importación JSON de respaldo de préstamos.
- Recordatorios de pago.
- Cajas Hive cifradas con AES.

### IA

- Acceso desde el botón central de la barra inferior.
- Requiere plan **Enterprise** y que la IA esté habilitada en Ajustes.
- Usa Gemini `gemini-2.5-flash-lite`.
- Rota entre hasta cinco claves `GEMINI_API_KEY_1..5`.
- Construye un prompt con cuentas, moneda, categorías, transacciones recientes y ajustes.
- Guarda conversaciones y mensajes en Hive.
- Renderiza Markdown en las respuestas.
- La prueba gratuita **no** desbloquea la IA.

### Seguridad y acceso

- **Biometría** (Enterprise): huella/Face ID mediante `local_auth`.
- **PIN de app** (Pro+): hash SHA-256.
- **Contraseña de app** (Pro+): hash SHA-256.
- **PIN de tarjeta** (Pro+).
- **Bloqueo de tarjeta** (Personal+).
- **Hardware lock en Windows**: lista de MACs autorizadas y códigos de activación; la versión Windows se considera Enterprise tras la activación.
- La configuración de seguridad se conserva aunque la prueba gratuita termine.

### Notificaciones

- Recordatorio diario de registro de gastos.
- Resumen semanal.
- Consejos financieros.
- Recordatorios de cuotas de préstamos.
- Hora configurable.
- Programación con `flutter_local_notifications` y `timezone`.
- Permisos de notificación y alarmas exactas en Android.

### Herramientas adicionales

- **Recurrentes**: plantillas de ingresos/gastos automáticos.
- **Escáner de tarjetas**: cámara y reconocimiento básico de datos.
- **Escáner de códigos de barras** en el módulo de negocio.
- **TransferMóvil**: lectura de SMS y categorización de transferencias (Android, Cuba).
- **Contador de dinero**.
- **Racha diaria** y calendario de racha, con recompensa de un plan aleatorio cada 50 días.
- **Widgets Android**: balance, consejos, estadísticas y racha.
- **Iconos de app**: default, playa, mar, Halloween y Navidad; cambio desde Perfil.
- **Soporte**: chat, bandeja de soporte y campañas para administradores. El chat usa Supabase y, para usuarios normales, requiere acceso Enterprise (`canSyncDrive`); las cuentas de soporte con rol de administrador pueden entrar sin ese plan.
- **Comunidad**: enlaces a grupo, noticias y redes sociales.
- **Feedback**: diálogo periódico con enlaces a Telegram, Apklis y Play Store.
- **Tour guiado** de la navegación principal.

---

## Sistema de licencias

### Niveles y duración

`LicenseType` contiene nueve licencias de pago y la licencia gratuita:

| Periodo | Días | Personal | Pro | Enterprise |
|---|---:|---|---|---|
| Semanal | 7 | `weeklyPersonal` | `weeklyPro` | `weeklyEnterprise` |
| Mensual | 30 | `monthlyPersonal` | `monthlyPro` | `monthlyEnterprise` |
| Anual | 365 | `annualPersonal` | `annualPro` | `annualEnterprise` |
| Gratis | — | — | — | `free` |

### Precios mostrados por la app

La app obtiene los precios de `ArtPayService`:

| Plan | Semanal | Mensual | Anual |
|---|---:|---:|---:|
| Personal | $0.15 USD / 30 CUP | $0.50 USD / 60 CUP | $5 USD / 200 CUP |
| Pro | $0.25 USD / 65 CUP | $1 USD / 95 CUP | $10 USD / 310 CUP |
| Enterprise | $0.35 USD / 100 CUP | $1.50 USD / 125 CUP | $15 USD / 420 CUP |

La compilación actual está configurada con `_isCuba = false`, por lo que la interfaz muestra los precios en **USD**. La variante Cuba muestra precios en CUP. Los precios efectivos del cobro deben coincidir con el plan configurado en el backend de pagos.

### Prueba gratuita de 7 días

Reglas implementadas por `TrialService`:

| Situación | Comportamiento |
|---|---|
| Primeros 7 días desde la instalación | Casi todo desbloqueado |
| IA, Google Drive y respaldo local | Siguen bloqueados durante la prueba |
| Compra dentro de la prueba | Los datos se conservan y se activa el plan |
| Fin de la prueba sin plan | **No se borra nada**; la cuenta principal sigue disponible |
| Cuentas adicionales al vencer | Quedan bloqueadas hasta activar una licencia |
| Datos de cuentas bloqueadas | Permanecen en Hive y en las copias de seguridad |
| Licencia activada después | Las cuentas adicionales y sus movimientos vuelven a estar disponibles |
| Instalaciones anteriores | Se marcan como exentas y conservan todas sus cuentas |
| Windows | No aplica la prueba; se considera desbloqueado tras la activación del equipo |

La comprobación del vencimiento se ejecuta en tres momentos:

1. En `main()`, antes de abrir Hive, para marcar el aviso de fin de prueba.
2. Al reanudar la app, si venció mientras estaba en segundo plano.
3. Cada minuto mientras la app permanece abierta, para bloquear las cuentas adicionales en cuanto termina la ventana de 7 días.

El bloqueo es dinámico: no modifica ni elimina las tarjetas. `AppProvider.cards` devuelve solo las cuentas utilizables, mientras que `allCards` y `lockedCards` permiten mostrar el estado en la interfaz. Los movimientos, totales, gráficas, recurrentes y transferencias de cuentas bloqueadas se excluyen hasta que haya una licencia vigente.

### Matriz de capacidades

| Capacidad | Free | Personal | Pro | Enterprise |
|---|:---:|:---:|:---:|:---:|
| Tarjetas máximas | 1 | 3 | 4 | Ilimitadas |
| Transferencias | — | ✓ | ✓ | ✓ |
| Bloquear tarjeta | — | ✓ | ✓ | ✓ |
| Estadísticas avanzadas | — | ✓ | ✓ | ✓ |
| Cambiar contraseña | — | ✓ | ✓ | ✓ |
| Monedas personalizadas | — | ✓ | ✓ | ✓ |
| Importar datos | — | ✓ | ✓ | ✓ |
| TransferMóvil | — | ✓ | ✓ | ✓ |
| Respaldo local | — | ✓ | ✓ | ✓ |
| Categorías personalizadas | — | — | ✓ | ✓ |
| PIN de app/tarjeta | — | — | ✓ | ✓ |
| Filtros por cuenta | — | — | ✓ | ✓ |
| Reordenar tarjetas | — | — | ✓ | ✓ |
| Gestionar bancos | — | — | ✓ | ✓ |
| Exportar Excel | — | — | ✓ | ✓ |
| Negocio | — | — | ✓ | ✓ |
| IA | — | — | — | ✓ |
| Google Drive / nube | — | — | — | ✓ |
| Biometría | — | — | — | ✓ |
| Escáner | — | — | — | ✓ |
| Más acciones | — | — | — | ✓ |
| Filtro por cuenta individual | — | — | — | ✓ |
| Gráficas personalizables | — | — | — | ✓ |
| Exportar PDF | — | — | — | ✓ |
| Widgets | — | — | — | ✓ |
| Préstamos | — | — | — | ✓ |

Durante la prueba de 7 días se desbloquean las capacidades de los niveles superiores **excepto** IA, Google Drive/nube y respaldo local.

Nota de implementación: la entrada al módulo de Negocio se resuelve en `BusinessGatekeeper`, que permite **Pro/Enterprise** (o prueba). El getter `canUseBusinessModule` está fijado a Enterprise y no es la puerta usada por esa pantalla; si se unifica el criterio, conviene actualizar ambos.

### Persistencia de la licencia

- `license_type`: índice de `LicenseType`.
- `license_expiration_date`: fecha exacta de vencimiento (ISO-8601).
- `license_activation_date`: formato legado; se recalcula con `durationDays`.
- Al comprar un plan se marca `trial_converted = true` para conservar los datos aunque el plan caduque después.
- Al vencer una licencia, la app vuelve a `LicenseType.free`.
- En Windows, `licenseType` se fuerza a `monthlyEnterprise` tras la activación del hardware.

---

## Pagos y activación

### Métodos implementados

| Método | Estado actual | Notas |
|---|---|---|
| **QvaPay** | Visible en la compilación actual | Flujo principal para la variante internacional |
| **Apklis** | Implementado; solo variante Cuba | Requiere UUIDs de producto; parte de la configuración está pendiente |
| **Art-Pay** | Implementado; oculto en la configuración actual | Pago con billetera `.lic`; tokens parcialmente configurados |
| **PayPal** | Implementado; oculto en la configuración actual | Usa `flutter_paypal_payment`; credenciales de sandbox en el servicio |
| **Anuncios** | Implementado; oculto en la configuración actual | Desbloqueo viendo anuncios; objetivo según plan/periodo |
| **Test** | Solo pruebas internas | No usar en producción |

La visibilidad real depende de:

1. `AppProvider.paymentMethods` y la bandera regional `_isCuba`.
2. `PaymentMethod.isVisible`.
3. `LicensePaymentConfig`, que define qué métodos admite cada licencia.
4. Filtros adicionales de la pantalla de licencias.

En la compilación actual (`_isCuba = false`), **QvaPay es el único método visible**. El código conserva las demás integraciones para cuando se habilite su configuración. También existen entradas ocultas de marcador de posición para **Stripe** y **Google Play**; no tienen flujo de pago implementado en esta versión.

### Flujo de QvaPay

La app **no habla directamente con QvaPay ni guarda secretos de QvaPay**. Usa el backend de CashRapido en `https://www.cashrapidoapp.cu/api`:

1. La app crea una factura con `POST /crear-factura.php`.
   - Envía `plan` y `client_id`.
   - `client_id` es un UUID estable guardado en `SharedPreferences`.
2. El backend responde con:
   - `order_id`;
   - `access_token`;
   - `status`;
   - `payment_url`.
3. La app abre `payment_url` en el navegador externo.
4. La app consulta el estado con `POST /consultar-pedido.php` cada 3 segundos, hasta 100 intentos (5 minutos).
5. La licencia solo se activa si:
   - el pedido está en `paid`;
   - la licencia está lista (`license_ready` o `license_code` presente);
   - el plan devuelto coincide exactamente con el plan comprado.
6. La app guarda la licencia localmente con `setLicenseType`, usando `expires_at` si el backend lo devuelve.
7. Si el pago ya estaba confirmado pero la licencia aún no está lista, la app sigue esperando y muestra el mensaje correspondiente.

`QvaPayService.planIdFor()` mapea cada `LicenseType` al ID de plan que entiende el backend:

```text
weekly_personal, weekly_pro, weekly_enterprise
monthly_personal, monthly_pro, monthly_enterprise
annual_personal, annual_pro, annual_enterprise
```

Estos IDs deben coincidir con `LICENSE_PLANS` del backend. Un cambio en la app sin actualizar el servidor haría que la factura fuera rechazada.

### Apklis y Art-Pay

- **Apklis** valida licencias mediante `apklis_license_validator`.
- **Art-Pay** usa `artpay_lib` y tokens de producto.
- Según la configuración actual de `lib/licences/README.md`, algunos UUIDs/tokens semanales y anuales aún están pendientes de configurar.
- Los precios de Art-Pay son los que muestra la app para CUP y USD.

### PayPal

- `PayPalService` construye las transacciones y los precios en USD.
- La pantalla de licencias abre el checkout de `flutter_paypal_payment`.
- Actualmente el método está oculto en la lista de pagos visibles.
- Las credenciales de PayPal están en el código con valores de sandbox y deben moverse a un backend seguro antes de habilitar pagos reales.

### Licencias en Supabase

La migración `20261110000000_licenses.sql` crea la tabla `public.licenses`:

- `license_code` único.
- `user_id` opcional para compras anónimas.
- `client_id` para asociar la compra al dispositivo.
- `plan_id`, `plan_level`, `plan_period`.
- `status`: `pending`, `active`, `expired`, `revoked`, `refunded`, `cancelled`.
- `provider`, `provider_order_id`, `provider_transaction_id`, importe, moneda y fechas.
- Restricciones de unicidad para evitar duplicados por pedido/transacción.

Seguridad:

- RLS activo.
- Los clientes autenticados solo pueden **leer sus propias licencias**.
- Las escrituras quedan reservadas a `service_role`, al backend o al panel de Supabase.
- La función `my_current_license()` devuelve la mejor licencia activa del usuario autenticado.

La app actual activa la licencia a partir de la respuesta de QvaPay y la guarda localmente. La tabla y la función quedan preparadas para consultar la licencia desde la nube en una integración posterior.

---

## Proveedores de estado

### `AppProvider`

Es el proveedor central. Gestiona:

- Transacciones, categorías, cuentas y movimientos recurrentes.
- Preferencias de tema, idioma, moneda y formato numérico.
- Licencias, prueba gratuita y capacidades.
- Monedas personalizadas, bancos y conversiones por pares.
- Perfil de Google cacheado offline.
- Pagos y métodos de pago.
- Notificaciones y rachas.
- Respaldo local, Google Drive y sincronización con Supabase.
- Exportación a Excel/PDF.
- Widgets, iconos y servicios de fondo.
- Autenticación de acceso (PIN, contraseña, biometría).
- Chat de IA y su estado.

### `BusinessProvider`

Gestiona el módulo de negocio:

- CRUD de negocios, productos, categorías, vendedores y ventas.
- Inventario por vendedor y descuento automático al vender.
- Gastos, cierres y métricas.
- Comisiones y reportes por vendedor.
- Conversión de moneda usando la configuración global de pares.
- Transferencia de ganancias a cuentas personales.
- Importación de cierres de vendedores.
- Limpieza completa de datos del negocio.

### `LoanProvider`

Gestiona el módulo de préstamos:

- CRUD de préstamos, deudores, pagos y actividades.
- Cálculo de intereses simple, compuesto y fijo.
- Generación de cuotas.
- Aplicación de pagos y reversión.
- Mora automática y detección de atrasos.
- Refinanciación, préstamos perdidos y reportes.
- Exportación/importación JSON.
- Apertura de cajas Hive con AES.

Los tres proveedores se registran como fuentes de cambio para la sincronización automática con Supabase.

---

## Servicios

| Servicio | Responsabilidad |
|---|---|
| `AdService` | Carga y muestra anuncios de Google Mobile Ads |
| `AIService` | Interfaz/implementación del chat con Gemini y rotación de claves |
| `AppIconService` | Cambia el icono de la app mediante `MethodChannel` |
| `AppInfo` | Nombre, paquete, versión y build desde `package_info_plus` |
| `BackupService` | Crea y restaura ZIP de las cajas Hive |
| `ChangelogService` | Carga el changelog desde assets |
| `CloudCodec` | Serializa/deserializa los modelos para Supabase |
| `CloudSyncService` | Snapshot completo, automático y manual, en Supabase |
| `CurrencyConversionService` | Tasas inversas, cruzadas y conversión de importes |
| `DriveService` | Respaldo/restauración en Google Drive |
| `ExportService` | Excel y PDF de movimientos, cierres y préstamos |
| `FeedbackService` | Diálogo de feedback y enlaces a tiendas/Telegram |
| `GoogleAuthService` | Inicio de sesión nativo con Google |
| `LocalizationService` | Traducciones manuales es/en/fr y delegate |
| `NotificationService` | Recordatorios diarios, semanales, tips y préstamos |
| `OfficialLinks` | Enlaces oficiales de comunidad y soporte |
| `PayPalService` | Precios y transacciones de PayPal |
| `QvaPayService` | Creación y consulta de facturas QvaPay |
| `StatsAggregator` | Agregaciones, series y proyección mensual |
| `SupabaseService` | Inicialización, sesión y autenticación con Google |
| `SupportChatService` | Chat y tickets de soporte sobre Supabase |
| `TourService` | Tour guiado de la interfaz |
| `TrialService` | Prueba de 7 días, detección de vencimiento y bloqueo de cuentas |
| `WidgetService` | Actualización de widgets Android |

---

## Pantallas y navegación

### Pestañas principales

| Orden | Pestaña | Pantalla |
|---:|---|---|
| 1 | Inicio | `HomeScreen` |
| 2 | Movimientos | `AllTransactionsScreen` |
| 3 | Acción central | `AIChatScreen` (no es pestaña) |
| 4 | Análisis | `StatsScreen` |
| 5 | Perfil | `ProfileScreen` |

### Pantallas secundarias

| Pantalla | Archivo | Descripción |
|---|---|---|
| Onboarding | `screens/onboarding_screen.dart` | Cuatro páginas de bienvenida |
| Billetera | `screens/wallet_screen.dart` | Gestión de cuentas y tarjetas |
| Agregar tarjeta | `screens/add_card_screen.dart` | Crear/editar cuenta |
| Agregar categoría | `screens/add_category_screen.dart` | Categoría personalizada |
| Todas las transacciones | `screens/all_transactions_screen.dart` | Historial, búsqueda y filtros |
| Análisis | `screens/stats_screen.dart` | Analítica, proyección y calendario |
| Ajustes | `screens/settings_screen.dart` | Tema, idioma, seguridad, monedas, bancos |
| Licencias | `screens/licenses_screen.dart` | Planes, compra y activación |
| Checkout QvaPay | `screens/qvapay_checkout_screen.dart` | Factura, pago y polling |
| Chat IA | `screens/ai_chat_screen.dart` | Asistente financiero |
| Notificaciones | `screens/notifications_screen.dart` | Centro de notificaciones |
| Ajustes de notificaciones | `screens/notification_settings_screen.dart` | Recordatorios y hora |
| Recurrentes | `screens/recurring_transactions_screen.dart` | Lista y formulario |
| Racha | `screens/streak_calendar_screen.dart` | Calendario de racha |
| TransferMóvil | `screens/transfermovil_screen.dart` | Transferencias desde SMS |
| Contador de dinero | `screens/money_counter_screen.dart` | Conteo de billetes/monedas |
| Escáner de tarjetas | `screens/card_scanner_screen.dart` | Captura y datos de tarjeta |
| Pantallas informativas | `screens/info_screens.dart` | Ayuda, privacidad y acerca de |
| Perfil / cuenta | `screens/profile/*` | Google, nube, iconos, comunidad, noticias |
| Soporte | `screens/support/*` | Chat, bandeja y campañas |
| Negocio | `screens/business/*` | POS, productos, vendedores, cierres |
| Préstamos | `screens/loans/*` | Deudores, préstamos, pagos y reportes |

### Flujo de Perfil

`ProfileScreen` agrupa:

- **Mi cuenta**: sesión de Google, licencias, nube, icono de app, canje, soporte, exportación, respaldo, importación y restablecimiento.
- **Comunidad**: grupo, noticias, valoración, redes sociales y contacto.
- **Funciones principales**: catálogo de funcionalidades y accesos.
- **Ajustes**: seguridad, preferencias, notificaciones, IA, idioma, moneda, tasas, bancos, tema y TransferMóvil.
- **Invitar amigos**.
- **Ayuda y privacidad**.

### Flujo de Google

- El inicio de sesión es solo con Google; no hay registro ni contraseña propia.
- El selector nativo de Android devuelve un `idToken`.
- Supabase valida el token con `signInWithIdToken`.
- La misma sesión de Google se reutiliza para Google Drive.
- El perfil se cachea en `SharedPreferences` y la foto se guarda en disco.
- Al abrir la app se muestran primero los bytes cacheados, aunque no haya red.
- Al cerrar sesión o cambiar de cuenta se limpia la caché del perfil.

---

## Internacionalización

El sistema es propio, basado en `AppLocalizations` y `BuildContext.t()`.

Idiomas soportados:

- Español (`es`)
- Inglés (`en`)
- Francés (`fr`)

Características:

- Delegado de localización propio integrado con `MaterialApp`.
- `GlobalMaterialLocalizations` para widgets de Material.
- `initializeDateFormatting('es')` al arrancar.
- Formato de fechas y números con `intl`.
- Separador decimal configurable (`.` o `,`).
- Si el idioma del sistema no es es/en/fr, se usa español.
- El tema, el idioma, el formato numérico y los datos se conservan aunque la prueba termine.

Uso típico:

```dart
Text(context.t('nav_home'));
```

---

## Respaldo, exportación y nube

### Respaldo local

`BackupService` crea un ZIP llamado `cashrapido_backup.zip` con los archivos `.hive` de las 18 colecciones.

- Incluye cartera, negocio, préstamos y chat de IA.
- Se comparte con `share_plus`.
- Se restaura seleccionando un `.zip` con `file_picker`.
- Solo disponible con cualquier plan de pago; **no** durante la prueba gratuita.
- No incluye las preferencias de `SharedPreferences` (licencia, tema, etc.).
- Las cajas de préstamos están cifradas; el resto de cajas puede contener datos legibles. Proteger el ZIP.

### Google Drive

`DriveService`:

- Usa la misma cuenta de Google de la app.
- Guarda los ZIP en la carpeta `CashRapido_Backups`.
- Mantiene los **5 respaldos más recientes**.
- Permite restaurar el más reciente.
- Expone la fecha del último respaldo.
- Usa el mismo ZIP que el respaldo local, por lo que tampoco incluye `SharedPreferences`.
- Requiere plan **Enterprise**.

### Supabase

`CloudSyncService` replica un snapshot completo del usuario:

- 18 tablas, las mismas colecciones que el respaldo local.
- No incluye `SharedPreferences`: moneda principal, tasas de cambio, monedas personalizadas, licencia o tema no viajan en el snapshot.
- Subida atómica con `cloud_replace_data`.
- Descarga con `cloud_export_data`.
- RLS por `user_id`.
- Sincronización automática con debounce de 6 segundos después de cada cambio.
- Se puede desactivar con `cloud_auto_sync`.
- Requiere sesión de Supabase y plan **Enterprise**.
- Si la nube está vacía o la respuesta no se puede decodificar, **no** borra los datos locales.
- Se registran las cajas abiertas por los providers para no reabrir Hive con tipos incompatibles.

### Exportación

`ExportService` genera:

- **Excel** de movimientos y reportes.
- **Excel** de préstamos.
- **PDF** de reportes generales.
- **PDF/Excel** de cierres de negocio.
- Archivos con nombre `CashRapido_Reporte_<timestamp>.xlsx/.pdf` o `Cierre_<periodo>_<timestamp>`.
- Compartición con `share_plus`.

Capacidades:

- Exportar Excel: Pro+.
- Exportar PDF: Enterprise.
- Exportar datos generales: Pro+.
- Importar datos: Personal+, y además requiere respaldo local habilitado.
- Respaldo local: cualquier plan de pago.

---

## Requisitos y configuración

### Desarrollo

- Flutter `>=3.47.0` y Dart `>=3.13.5 <4.0.0` (valores tomados de `pubspec.lock`).
- Android SDK con `minSdk 26` para la app Android.
- iOS con deployment target `16.0` (definido en `ios/Podfile` y en el proyecto Xcode).
- Un dispositivo/emulador Android para las funciones nativas:
  - SMS;
  - widgets;
  - cámara/escáner;
  - notificaciones;
  - biometría.
- Para Google:
  - `android/app/google-services.json`;
  - `GOOGLE_WEB_CLIENT_ID` correcto.
- Para IA:
  - al menos una clave `GEMINI_API_KEY_1..5`.
- Para nube:
  - proyecto Supabase y migraciones aplicadas;
  - `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` opcionales si se usan los valores por defecto del código.

### Variables de entorno

Archivo `.env` en la raíz. Está incluido como asset en `pubspec.yaml`, por lo que **se empaqueta con la app**. No colocar secretos de servidor (`service_role`, secretos de PayPal, etc.) en este archivo.

| Variable | Obligatoria | Uso |
|---|:---:|---|
| `GEMINI_API_KEY_1` | Para IA | Clave de Gemini |
| `GEMINI_API_KEY_2` | No | Clave de respaldo/rotación |
| `GEMINI_API_KEY_3` | No | Clave de respaldo/rotación |
| `GEMINI_API_KEY_4` | No | Clave de respaldo/rotación |
| `GEMINI_API_KEY_5` | No | Clave de respaldo/rotación |
| `GOOGLE_WEB_CLIENT_ID` | Para Google | Client ID OAuth web para obtener el `idToken` |
| `ADMIN_EMAILS` | Para soporte admin | Correos con acceso a campañas de soporte, separados por comas |
| `SUPABASE_URL` | No | Sobrescribe la URL por defecto |
| `SUPABASE_PUBLISHABLE_KEY` | No | Sobrescribe la clave pública por defecto |

La app usa por defecto el proyecto Supabase configurado en `SupabaseService`. La clave pública puede estar en el cliente; la clave `service_role` **nunca** debe incluirse en la app.

---

## Instalación y ejecución

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd cashrapido

# 2. Instalar dependencias
flutter pub get

# 3. Crear/editar .env con las claves necesarias
#    GEMINI_API_KEY_1=...
#    GOOGLE_WEB_CLIENT_ID=...
#    ADMIN_EMAILS=...

# 4. Ejecutar en desarrollo
flutter run

# 5. Si se modifican modelos Hive, regenerar adaptadores
dart run build_runner build --delete-conflicting-outputs
```

Para Android, verificar que `android/app/google-services.json` corresponda al proyecto de Google configurado.

---

## Compilación

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requiere macOS y firma)
flutter build ios --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release

# Web
flutter build web --release
```

La plataforma objetivo principal es **Android**. Las funciones que dependen de SMS, widgets, cámara, biometría o almacenamiento externo pueden requerir configuración adicional o no estar disponibles en otras plataformas.

---

## Supabase y migraciones

Migraciones incluidas en `supabase/migrations/`:

| Migración | Propósito |
|---|---|
| `20261106000000_cashrapido_cloud.sql` | Perfil, tablas de datos, RLS y funciones `cloud_replace_data` / `cloud_export_data` |
| `20261106010000_support_chat.sql` | Chat y tickets de soporte |
| `20261106030000_support_ticket_lifecycle.sql` | Ciclo de vida de tickets |
| `20261110000000_licenses.sql` | Tabla `licenses`, RLS y `my_current_license()` |

### Estado

- Las migraciones están versionadas en el repositorio.
- La migración de licencias debe ejecutarse **después** de la migración de nube.
- La app funciona sin Supabase si no hay red o si el proyecto no está inicializado.
- La sincronización de datos y las licencias en la nube requieren que las migraciones estén aplicadas en el proyecto real.

### Orden recomendado

1. `20261106000000_cashrapido_cloud.sql`
2. `20261106010000_support_chat.sql`
3. `20261106030000_support_ticket_lifecycle.sql`
4. `20261110000000_licenses.sql`

Aplicar desde el SQL Editor de Supabase o con la CLI. Las migraciones están escritas para ser idempotentes.

---

## Pruebas y análisis estático

```bash
# Análisis
flutter analyze

# Pruebas
flutter test
```

Archivos de prueba actuales:

| Archivo | Cobertura |
|---|---|
| `test/app_currency_conversion_test.dart` | Conversión de monedas en `AppProvider` |
| `test/currency_conversion_test.dart` | Tasas inversas, BFS y casos límite |
| `test/cloud_codec_test.dart` | Serialización para Supabase |
| `test/cloud_sync_boxes_test.dart` | Cajas y snapshot de nube |
| `test/qvapay_service_test.dart` | Planes, parseo de fechas y errores de QvaPay |
| `test/trial_service_test.dart` | Ventana de 7 días, plan y bloqueo sin borrado |
| `test/widget_test.dart` | Prueba básica de widget/onboarding |

Recomendación antes de publicar:

1. `flutter analyze`
2. `flutter test`
3. Probar en dispositivo real:
   - onboarding;
   - registro de movimientos;
   - compra/activación de licencia;
   - respaldo/restauración;
   - notificaciones;
   - Google/Drive;
   - sincronización con Supabase.

---

## Limitaciones y estado actual

- **La prueba de 7 días es local.** Reinstalar la app puede reiniciarla; cambiar la hora del dispositivo puede alterar el vencimiento. No sustituye una validación de servidor.
- **Al vencer la prueba no se borran datos.** La cuenta principal sigue usable y las cuentas adicionales se bloquean; al activar una licencia vuelven a estar disponibles. El límite es local y no impide acceder a Hive mediante herramientas externas.
- **La sincronización con Supabase es de pago (Enterprise)** y depende de que las migraciones estén aplicadas.
- **Las migraciones no se aplican automáticamente desde la app.** Deben ejecutarse en el proyecto de Supabase; la migración de licencias está versionada pero requiere aplicación manual.
- **Google Drive y la IA no se desbloquean durante la prueba.**
- **El respaldo local no incluye `SharedPreferences`.** Restaura las cajas de datos, no la licencia, el tema ni la configuración.
- **El ZIP de respaldo contiene cajas Hive.** Aunque los préstamos estén cifrados, el resto de datos puede ser legible; hay que proteger el archivo.
- **La compilación actual solo muestra QvaPay como método de pago.** Apklis, Art-Pay, PayPal y anuncios están implementados, pero ocultos o pendientes de configuración.
- **PayPal conserva credenciales de sandbox en el código.** Deben moverse a un backend antes de producción.
- **Apklis y Art-Pay tienen UUIDs/tokens pendientes** según la configuración interna actual.
- **La tabla `licenses` y `my_current_license()` están listas, pero la app activa la licencia principalmente con la respuesta de QvaPay.** La consulta de licencia desde Supabase queda como integración futura.
- **El hardware lock de Windows usa listas locales de MACs y códigos.** Es una medida de distribución, no un sistema de licencias robusto.
- **La app no sustituye asesoría financiera.** Los cálculos y proyecciones son estimaciones sobre los datos locales.

---

## Licencia

Este proyecto es privado. Su distribución y uso están sujetos al sistema de licencias integrado en la aplicación.
