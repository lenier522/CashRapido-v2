# CashRapido

Aplicación de finanzas personales desarrollada en **Flutter** con **Dart**. CashRapido te permite gestionar tus tarjetas, transacciones, presupuestos, préstamos, negocios y más, con soporte para múltiples monedas (CUP, USD, EUR), exportación de datos, respaldo en Google Drive, y un sistema de licencias por suscripción.

---

## 📋 Tabla de Contenidos

- [Stack Tecnológico](#stack-tecnológico)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Modelos de Datos](#modelos-de-datos)
- [Módulos Principales](#módulos-principales)
- [Sistema de Licencias](#sistema-de-licencias)
- [Proveedores (State Management)](#proveedores-state-management)
- [Servicios](#servicios)
- [Pantallas](#pantallas)
- [Internacionalización](#internacionalización)
- [Requisitos](#requisitos)
- [Instalación y Ejecución](#instalación-y-ejecución)
- [Compilación](#compilación)
- [Variables de Entorno](#variables-de-entorno)
- [Dependencias Principales](#dependencias-principales)
- [Roadmap](ROADMAP.md)

---

## Stack Tecnológico

| Componente          | Tecnología                         |
|---------------------|------------------------------------|
| Lenguaje            | Dart 3.x                           |
| Framework           | Flutter 3.x (Material 3)           |
| State Management    | Provider (ChangeNotifier)          |
| Almacenamiento Local | Hive + SharedPreferences          |
| Localización        | Manual (`AppLocalizations`)        |
| Tipografía          | Google Fonts (Outfit)              |
| Backend Cloud       | Google Drive API (respaldo)        |
| AI Chat             | Google Generative AI (Gemini)      |
| Anuncios            | Google Mobile Ads                  |
| Pagos              | Apklis + Art-Pay                    |
| Exportación         | Syncfusion XlsIO + PDF             |
| Notificaciones      | flutter_local_notifications        |
| Licencias           | Widget: `home_widget`              |

---

## Estructura del Proyecto

```
cashrapido/
├── android/                          # Configuración nativa Android
├── assets/
│   └── animations/                   # Animaciones Lottie
├── ios/                              # Configuración nativa iOS
├── lib/
│   ├── licences/                     # Sistema de licencias
│   │   ├── apklis.dart               # Validación de licencias Apklis
│   │   ├── art_pay.dart              # Pagos mediante Art-Pay
│   │   ├── license_type.dart         # Enum de tipos de licencia
│   │   ├── payment_config.dart       # Config. métodos de pago por licencia
│   │   └── README.md                 # Documentación del sistema de licencias
│   ├── models/                       # Modelos de datos (Hive)
│   │   ├── models.dart               # Category, InternalTransaction, AccountCard, ChatMessage, ChatConversation
│   │   ├── models.g.dart             # Generado por Hive
│   │   ├── borrower.dart             # Borrower + LoanActivity
│   │   ├── business.dart             # Business entity
│   │   ├── business_expense.dart     # BusinessExpense entity
│   │   ├── closing.dart              # Closing entity
│   │   ├── loan.dart                 # Loan, LoanPayment, Installment
│   │   ├── loan_activity.dart        # LoanActivity entity
│   │   ├── notification_item.dart    # NotificationItem + .g.dart
│   │   ├── payment_method.dart       # PaymentMethod enum
│   │   ├── product.dart              # Product entity
│   │   ├── product_category.dart      # ProductCategory entity (categorías de productos)
│   │   ├── recurring_transaction.dart # RecurringTransaction + .g.dart
│   │   ├── sale.dart                 # Sale, SaleItem entities
│   │   ├── seller.dart               # Seller entity (vendedores)
│   │   └── seller_inventory.dart     # SellerInventory entity (inventario por vendedor)
│   ├── providers/                    # State Management (ChangeNotifier)
│   │   ├── app_provider.dart         # Provider principal (~2273 líneas)
│   │   ├── business_provider.dart    # Provider del módulo de negocios
│   │   └── loan_provider.dart        # Provider del módulo de préstamos
│   ├── screens/                      # Pantallas de la aplicación
│   │   ├── business/                 # Pantallas del módulo de negocios
│   │   │   ├── analytics_tab.dart
│   │   │   ├── barcode_scanner_screen.dart # Escáner de código de barras
│   │   │   ├── break_even_screen.dart      # Punto de equilibrio
│   │   │   ├── business_detail_screen.dart
│   │   │   ├── business_form_screen.dart
│   │   │   ├── business_gatekeeper.dart
│   │   │   ├── business_list_screen.dart
│   │   │   ├── business_locked_screen.dart
│   │   │   ├── category_manager_screen.dart # Gestión de categorías de productos
│   │   │   ├── closings_tab.dart
│   │   │   ├── expense_form_screen.dart
│   │   │   ├── expenses_tab.dart
│   │   │   ├── pos_screen.dart
│   │   │   ├── product_form_screen.dart
│   │   │   ├── products_tab.dart
│   │   │   ├── sales_tab.dart
│   │   │   ├── sellers_tab.dart             # Lista de vendedores
│   │   │   ├── seller_form_screen.dart      # Formulario de vendedor
│   │   │   ├── seller_detail_screen.dart    # Reporte financiero del vendedor
│   │   │   └── seller_assign_products_screen.dart # Asignar productos a vendedor
│   │   ├── loans/                    # Pantallas del módulo de préstamos
│   │   │   ├── borrower_form_screen.dart
│   │   │   ├── borrowers_list_screen.dart
│   │   │   ├── loan_calculator_screen.dart
│   │   │   ├── loan_detail_screen.dart
│   │   │   ├── loan_form_screen.dart
│   │   │   ├── loan_payment_form_screen.dart
│   │   │   ├── loan_reports_screen.dart
│   │   │   ├── loans_gatekeeper.dart
│   │   │   ├── loans_list_screen.dart
│   │   │   └── loans_locked_screen.dart
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
│   │   ├── recurring_transaction_form_screen.dart
│   │   ├── recurring_transactions_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── stats_screen.dart
│   │   ├── streak_calendar_screen.dart
│   │   ├── transfermovil_screen.dart
│   │   └── wallet_screen.dart
│   ├── services/                     # Servicios de la aplicación
│   │   ├── ad_service.dart           # Servicio de anuncios (Google Mobile Ads)
│   │   ├── ai_service.dart           # Interfaz de servicio AI (abstracta)
│   │   ├── ai_service_desktop.dart   # Implementación AI para Desktop
│   │   ├── ai_service_mobile.dart    # Implementación AI para Mobile
│   │   ├── backup_service.dart       # Servicio de respaldo local (.cashrapido)
│   │   ├── drive_service.dart        # Servicio de respaldo en Google Drive
│   │   ├── export_service.dart       # Exportación a Excel y PDF
│   │   ├── feedback_service.dart     # Feedback y valoración
│   │   ├── localization_service.dart # Traducciones (es, en, fr) ~2100 líneas
│   │   ├── notification_service.dart # Notificaciones locales
│   │   ├── tour_service.dart         # Tour guiado interactivo
│   │   └── widget_service.dart       # Widget de Android
│   ├── utils/                        # Utilidades
│   │   ├── business_icon_helper.dart # Iconos para tipos de negocio
│   │   ├── icon_constants.dart       # Constantes de iconos
│   │   ├── number_format_utils.dart  # Formateo de números
│   │   ├── receipt_helper.dart       # Generación de recibos
│   │   └── tour_keys.dart            # Keys para el tour guiado
│   ├── widgets/                      # Widgets reutilizables
│   │   ├── add_transaction_modal.dart # Modal para agregar transacciones
│   │   └── smooth_switch.dart        # Switch animado personalizado
│   └── main.dart                     # Punto de entrada de la aplicación
├── linux/
├── macos/
├── test/
├── web/
├── windows/
├── .env                              # Variables de entorno (API Keys)
├── analysis_options.yaml             # Configuración del linter
├── pubspec.yaml                      # Dependencias y metadata
├── pubspec.lock
├── README.md
└── .gitignore
```

---

## Modelos de Datos

Todos los modelos principales usan **Hive** como base de datos local NoSQL. A continuación se listan los TypeAdapters registrados:

| TypeId | Modelo               | Descripción                                    |
|--------|----------------------|------------------------------------------------|
| 0      | `Category`           | Categorías de transacciones                    |
| 1      | `InternalTransaction`| Transacciones financieras                      |
| 2      | `AccountCard`        | Tarjetas/cuentas bancarias                     |
| 3      | `Product`            | Productos del módulo de negocio                |
| 4      | `Business`           | Negocios                                       |
| 5      | `Sale`               | Ventas                                         |
| 6      | `SaleItem`           | Items de venta                                 |
| 7      | `BusinessExpense`    | Gastos de negocio                              |
| 8      | `Closing`            | Cierres de caja                                |
| 25     | `Loan`               | Préstamos                                      |
| 26     | `LoanPayment`        | Pagos de préstamos                             |
| 27     | `Borrower`           | Deudores                                       |
| 28     | `Installment`        | Cuotas/plazos de préstamos                     |
| 29     | `LoanActivity`       | Actividad/auditoría de préstamos               |
| 30     | `Seller`             | Vendedores                                     |
| 31     | `ProductCategory`    | Categorías de productos                        |
| 32     | `SellerInventory`    | Inventario asignado por vendedor               |
| 15     | `ChatMessage`        | Mensajes del chat AI                           |
| 16     | `ChatConversation`   | Conversaciones del chat AI                     |
| —      | `RecurringTransaction` | Transacciones recurrentes                    |
| —      | `NotificationItem`   | Items de notificaciones                        |

**Monedas soportadas:** CUP, USD, EUR, MLC (tasas de cambio configurables).

---

## Módulos Principales

### 1. 💰 Gestión de Finanzas Personales
- **Tarjetas/Cuentas:** Creación, edición, bloqueo, límites de gasto, soporte para efectivo.
- **Transacciones:** Ingresos y gastos por categoría, multi-moneda, búsqueda y filtros.
- **Categorías:** Predefinidas + personalizables (según licencia).
- **Estadísticas:** Gráficos de pastel y barras, filtros por período, tarjeta y categoría.
- **Presupuestos:** Límites mensuales por categoría.

### 2. 🏢 Módulo de Negocio (Enterprise)
- Gestión de múltiples negocios con tipo (Retail, Restaurante, Servicios, etc.).
- **Productos:** Inventario con precios, costo, stock, SKU auto-generado, categorías y subcategorías.
- **Categorías de Productos:** Organización jerárquica con subcategorías, generación de SKUs automática basada en iniciales del negocio y categoría.
- **Vendedores:** CRUD completo con datos personales, laborales, salario, comisión y estado activo/inactivo.
- **Inventario por Vendedor:** Asignación de productos con cantidades específicas a cada vendedor. Descuento automático al realizar una venta.
- **Reporte Financiero por Vendedor:** Valor asignado, vendido, por vender, comisión calculada y salario.
- **Ventas (POS):** Punto de venta integrado con carrito, selección de productos, descuentos, métodos de pago y selección opcional de vendedor.
- **Gastos:** Registro de gastos del negocio con categorías, filtros por período y categoría.
- **Cierres de Caja:** Corte de caja por período (diario, semanal, mensual) con cálculo de ingresos, gastos, beneficio bruto, ganancia neta (descontando costo de productos vendidos), ROI, productos más vendidos, métodos de pago, gastos por categoría y rendimiento por vendedor. Exportación a PDF y Excel.
- **Analíticas:** ROI general, ingresos totales, gastos totales, beneficio bruto, ganancia neta real, productos más vendidos y stock bajo.
- **Punto de Equilibrio:** Simulador con costos fijos, precio unitario, costo variable, margen de contribución y gráfico comparativo.

### 3. 💳 Módulo de Préstamos (Enterprise)
- Gestión de deudores con datos de contacto.
- Préstamos con interés simple, compuesto o monto fijo.
- Frecuencias: diario, semanal, mensual, pago único.
- Cuotas/plazos automáticos con seguimiento individual.
- Penalizaciones por mora (fijo o porcentaje).
- Recordatorios automáticos de pago.
- Historial de actividad y reportes.

### 4. 🤖 Chat con IA (Enterprise)
- Asistente financiero con Google Gemini AI.
- Múltiples conversaciones guardadas en Hive.
- Historial de mensajes persistente.
- Implementación separada para Mobile y Desktop.

### 5. 🔐 Seguridad
- **Bloqueo biométrico** (huella digital / Face ID).
- **Bloqueo por PIN** de hasta 6 dígitos.
- **Bloqueo por Contraseña.**
- **Hardware Lock** en Windows: vinculación por dirección MAC + código de activación.
- Datos cifrados con AES para módulo de préstamos.

### 6. 📤 Exportación y Respaldo
- **Exportar a Excel** (.xlsx) usando Syncfusion XlsIO.
- **Exportar a PDF** usando la librería `pdf`.
- **Compartir** archivos exportados vía Share Plus.
- **Respaldo local** en formato `.cashrapido` (archivo).
- **Respaldo en Google Drive** (sincronización automática).

### 7. 🔔 Notificaciones y Recordatorios
- Recordatorio diario de gastos.
- Recordatorio semanal de resumen.
- Tips financieros aleatorios.
- Recordatorios de pago de préstamos.
- Configuración de hora de notificación.

### 8. 📊 Estadísticas y Metas
- Gráfico de pastel por categoría.
- Gráfico de barras por período.
- Gasto diario promedio.
- **Daily Streak:** Racha de días iniciando sesión.
- Planes aleatorios de ahorro.

### 9. 🎴 Escáner de Tarjetas
- Captura de foto de tarjeta bancaria.
- Reconocimiento básico de datos.
- Almacenamiento de imagen de referencia.

### 10. 🌐 Transferencia (TransferMóvil)
- Historial de transferencias desde SMS.
- Lectura de SMS entrantes en Android.
- Categorización automática de transferencias.

---

## Sistema de Licencias

CashRapido cuenta con un sistema de suscripción basado en licencias. Los detalles completos están documentados en `lib/licences/README.md`.

### Niveles

| Nivel       | Períodos disponibles                     |
|-------------|------------------------------------------|
| **Free**    | Sin costo, funcionalidades limitadas     |
| **Personal**| Semanal (15 CUP), Mensual (50 CUP), Anual (500 CUP) |
| **Pro**     | Semanal (25 CUP), Mensual (75 CUP), Anual (750 CUP) |
| **Enterprise** | Semanal (35 CUP), Mensual (110 CUP), Anual (1000 CUP) |

### Métodos de Pago

| Método    | Descripción                          |
|-----------|--------------------------------------|
| Apklis    | Tienda de aplicaciones cubana        |
| Art-Pay   | Billetera digital (token .lic)       |
| Anuncios  | Ver anuncios de Google Ads           |

### Matriz de Funcionalidades por Nivel

| Característica           | Free | Personal | Pro | Enterprise |
|--------------------------|:----:|:--------:|:---:|:----------:|
| Tarjetas máx.            |  1   |    3     |  4  | Ilimitadas |
| Transferencias           |  ✗   |    ✓     |  ✓  |     ✓      |
| Bloquear tarjeta         |  ✗   |    ✓     |  ✓  |     ✓      |
| Estadísticas avanzadas   |  ✗   |    ✓     |  ✓  |     ✓      |
| Categorías personalizadas|  ✗   |    ✗     |  ✓  |     ✓      |
| Exportar Excel           |  ✗   |    ✗     |  ✓  |     ✓      |
| Biometría                |  ✗   |    ✗     |  ✗  |     ✓      |
| Scanner QR               |  ✗   |    ✗     |  ✗  |     ✓      |
| IA Chat                  |  ✗   |    ✗     |  ✗  |     ✓      |
| Sync Drive               |  ✗   |    ✗     |  ✗  |     ✓      |
| Business Module          |  ✗   |    ✗     |  ✗  |     ✓      |
| Loans Module             |  ✗   |    ✗     |  ✗  |     ✓      |
| Widgets                  |  ✗   |    ✗     |  ✗  |     ✓      |

---

## Proveedores (State Management)

### `AppProvider` (`lib/providers/app_provider.dart`)
Provider principal que gestiona:
- Tarjetas, transacciones, categorías.
- Preferencias de usuario (tema, moneda, formato numérico).
- Autenticación (biométrica, PIN, contraseña).
- Licencias y restricciones por nivel.
- Sistema de anuncios y licencias por anuncios.
- Chat AI, racha diaria, planes de ahorro.
- Exportación, respaldo, notificaciones.
- Métodos de pago y configuración general.

### `BusinessProvider` (`lib/providers/business_provider.dart`)
Gestiona el módulo de negocio:
- CRUD de negocios, productos, ventas, gastos, cierres.
- CRUD de vendedores, inventario por vendedor, categorías de productos.
- Asignación/desasignación de productos a vendedores con descuento automático de inventario al vender.
- Cálculos de ganancias (beneficio bruto, ganancia neta), ROI, comisiones de vendedores.
- Métricas por vendedor: total ventas, valor asignado, valor restante, comisión.
- Generación de SKU automática basada en negocio, categoría y fecha.
- Tasas de cambio y moneda principal del negocio.
- Filtros por fechas en ventas, gastos y cierres.

### `LoanProvider` (`lib/providers/loan_provider.dart`)
Gestiona el módulo de préstamos:
- CRUD de préstamos, pagos, deudores.
- Cálculo de intereses (simple, compuesto, fijo).
- Generación de cuotas/plazos.
- Penalizaciones por mora automáticas.
- Reportes y métricas.
- Datos cifrados con AES.

---

## Servicios

| Servicio                 | Archivo                        | Descripción                                      |
|--------------------------|--------------------------------|--------------------------------------------------|
| `AdService`              | `services/ad_service.dart`     | Gestión de anuncios Google Mobile Ads            |
| `AiService` (abstracto)  | `services/ai_service.dart`     | Interfaz para servicio de AI                     |
| `AiServiceDesktop`       | `services/ai_service_desktop.dart` | Implementación AI para Desktop usando HTTP   |
| `AiServiceMobile`        | `services/ai_service_mobile.dart`  | Implementación AI para Mobile usando SDK     |
| `BackupService`          | `services/backup_service.dart` | Respaldo local en formato `.cashrapido`          |
| `DriveService`           | `services/drive_service.dart`  | Sincronización con Google Drive                  |
| `ExportService`          | `services/export_service.dart` | Exportación a Excel/PDF                          |
| `FeedbackService`        | `services/feedback_service.dart` | Feedback y valoración en Telegram             |
| `LocalizationService`    | `services/localization_service.dart` | Traducciones (es, en, fr)                  |
| `NotificationService`    | `services/notification_service.dart` | Notificaciones locales                      |
| `TourService`            | `services/tour_service.dart`   | Tour guiado interactivo                          |
| `WidgetService`          | `services/widget_service.dart` | Widget de Android (home_widget)                  |

---

## Pantallas Principales

| Pantalla                     | Archivo                                   | Descripción                                    |
|------------------------------|-------------------------------------------|------------------------------------------------|
| **Onboarding**               | `screens/onboarding_screen.dart`          | Pantalla de bienvenida inicial                 |
| **Main**                     | `screens/main_screen.dart`                | Navegación principal con Bottom Bar + FAB      |
| **Home**                     | `screens/home_screen.dart`                | Resumen diario, balance, acciones rápidas      |
| **Wallet**                   | `screens/wallet_screen.dart`              | Gestión de tarjetas y cuentas                  |
| **Stats**                    | `screens/stats_screen.dart`               | Estadísticas y gráficos                        |
| **Settings**                 | `screens/settings_screen.dart`            | Configuración general                          |
| **Add Transaction Modal**    | `widgets/add_transaction_modal.dart`      | Modal para nueva transacción                   |
| **Add Card**                 | `screens/add_card_screen.dart`            | Crear/editar tarjeta                           |
| **All Transactions**         | `screens/all_transactions_screen.dart`    | Lista completa de transacciones                |
| **AI Chat**                  | `screens/ai_chat_screen.dart`             | Chat con inteligencia artificial               |
| **Card Scanner**             | `screens/card_scanner_screen.dart`        | Escáner de tarjetas con cámara                 |
| **Licenses**                 | `screens/licenses_screen.dart`            | Gestión de licencias y suscripción             |
| **Notifications**            | `screens/notifications_screen.dart`       | Centro de notificaciones                       |
| **Recurring Transactions**   | `screens/recurring_transactions_screen.dart` | Transacciones recurrentes                  |
| **Streak Calendar**          | `screens/streak_calendar_screen.dart`     | Calendario de racha diaria                     |
| **TransferMovil**            | `screens/transfermovil_screen.dart`       | Historial de transferencias desde SMS          |
| **Money Counter**            | `screens/money_counter_screen.dart`       | Contador de dinero                             |
| **Business** (múltiples)     | `screens/business/*`                      | Módulo completo de negocio                     |
| **Loans** (múltiples)        | `screens/loans/*`                         | Módulo completo de préstamos                   |

### Navegación Principal

La app usa un `AnimatedBottomNavigationBar` con 4 pestañas + un FAB central:

1. **Inicio** (Home) - Resumen y transacciones recientes.
2. **Billetera** (Wallet) - Tarjetas y saldos.
3. **Estadísticas** (Stats) - Gráficos y reportes.
4. **Ajustes** (Settings) - Configuración.
5. **Negocio** (Business) - FAB central, módulo empresarial.

---

## Internacionalización

El sistema de traducción es manual usando `AppLocalizations` en `services/localization_service.dart`.

**Idiomas soportados:**
- Español (`es`) — Completo
- Inglés (`en`) — Parcial
- Francés (`fr`) — Parcial

**Uso en código:**
```dart
Text(context.t('daily_summary'));
```

---

## Requisitos

- **Flutter SDK:** ^3.10.3 (Dart ^3.10.3)
- **Plataformas:** Android, iOS, Web, Windows, Linux, macOS
- **Google Services:** Firebase (para anuncios y autenticación Google)
- **Apklis:** Opcional, solo para distribución en Cuba
- **Claves de API:** Gemini (para chat AI), Google Ads

---

## Instalación y Ejecución

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd cashrapido

# 2. Instalar dependencias
flutter pub get

# 3. Configurar variables de entorno
# Crear/editar archivo .env con las API keys necesarias:
#   GEMINI_API_KEY_1=<key>
#   GEMINI_API_KEY_2=<key>
#   GEMINI_API_KEY_3=<key>
#   GEMINI_API_KEY_4=<key>
#   GEMINI_API_KEY_5=<key>

# 4. Ejecutar en modo desarrollo
flutter run

# 5. (Opcional) Generar código Hive si se modifican modelos
dart run build_runner build --delete-conflicting-outputs
```

---

## Compilación

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

---

## Variables de Entorno

Archivo `.env` en la raíz del proyecto:

| Variable           | Descripción                          |
|--------------------|--------------------------------------|
| `GEMINI_API_KEY_1` | API Key 1 para Google Gemini AI      |
| `GEMINI_API_KEY_2` | API Key 2 para Google Gemini AI      |
| `GEMINI_API_KEY_3` | API Key 3 para Google Gemini AI      |
| `GEMINI_API_KEY_4` | API Key 4 para Google Gemini AI      |
| `GEMINI_API_KEY_5` | API Key 5 para Google Gemini AI      |

---

## Dependencias Principales

| Paquete                              | Versión   | Uso                                    |
|--------------------------------------|-----------|----------------------------------------|
| `flutter`                            | SDK       | Framework principal                    |
| `provider`                           | ^6.1.5    | State Management                       |
| `hive` / `hive_flutter`              | ^2.2.3    | Base de datos local NoSQL              |
| `shared_preferences`                 | ^2.5.4    | Preferencias simples                   |
| `google_fonts`                       | ^6.3.3    | Tipografía Outfit                      |
| `lottie`                             | ^3.3.2    | Animaciones                            |
| `fl_chart`                           | ^1.1.1    | Gráficos estadísticos                  |
| `intl`                               | ^0.20.2   | Formateo de fechas/números             |
| `google_generative_ai`               | ^0.4.7    | Chat con IA Gemini                     |
| `google_mobile_ads`                  | ^7.0.0    | Anuncios Google Mobile Ads             |
| `google_sign_in` / `googleapis`      | ^6.2.1    | Autenticación Google y Drive API       |
| `camera`                             | ^0.10.5   | Cámara para escáner de tarjetas        |
| `local_auth`                         | ^3.0.0    | Autenticación biométrica               |
| `crypto`                             | ^3.0.7    | Hashing SHA-256                        |
| `flutter_local_notifications`        | ^19.5.0   | Notificaciones push locales            |
| `syncfusion_flutter_xlsio`           | ^31.2.18  | Exportación a Excel                    |
| `pdf`                                | ^3.11.3   | Exportación a PDF                      |
| `share_plus`                         | ^12.0.1   | Compartir archivos                     |
| `file_picker`                        | ^10.0.0   | Selección de archivos                  |
| `path_provider`                      | ^2.1.5    | Rutas del sistema de archivos          |
| `url_launcher`                       | ^6.3.2    | Abrir enlaces externos                 |
| `flutter_sms_inbox`                  | ^1.0.3    | Leer SMS (TransferMóvil)               |
| `apklis_license_validator`           | git       | Validación de licencias Apklis         |
| `artpay_lib`                         | ^0.0.8    | Pagos con Art-Pay                      |
| `flutter_dotenv`                     | ^6.0.0    | Variables de entorno (.env)            |
| `http`                               | ^1.6.0    | Peticiones HTTP                        |
| `uuid`                               | ^4.5.2    | Generación de UUIDs                    |
| `permission_handler`                 | ^11.3.1   | Permisos de plataforma                 |
| `timezone`                           | ^0.10.1   | Zonas horarias para notificaciones     |
| `archive`                            | ^4.0.7    | Compresión de archivos                 |
| `animated_bottom_navigation_bar`     | ^1.4.0    | Barra de navegación animada            |
| `tutorial_coach_mark`                | ^1.3.3    | Tour guiado interactivo                |
| `home_widget`                        | ^0.6.0    | Widget de pantalla de inicio Android   |

---

## Licencia

Este proyecto es privado. Su distribución y uso están sujetos al sistema de licencias integrado en la aplicación.
