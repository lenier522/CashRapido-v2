# Roadmap - CashRapido

Mejoras y nuevas funcionalidades propuestas para futuras versiones.

---

## 1. Metas de Ahorro

**Estado:** Pendiente | **Prioridad:** Alta

Actualmente existe un `StreakCalendarScreen` que registra la racha de inicios de sesión, pero no hay un sistema de metas de ahorro.

### Implementación sugerida

- Nueva pantalla `savings_goals_screen.dart` en `lib/screens/`.
- Nuevo modelo `SavingGoal` con Hive adapter: `id`, `name`, `targetAmount`, `currentAmount`, `currency`, `deadline`, `createdAt`, `color`.
- Nuevo provider o extender `AppProvider` con métodos CRUD para metas.
- Barra de progreso visual (circular o lineal) con porcentaje cumplido.
- Sugerencias automáticas: basado en el promedio de gastos mensuales, calcular cuánto podría ahorrar el usuario por mes y estimar fecha de cumplimiento.
- Notificación al alcanzar el 50%, 75% y 100% de la meta.

### Dependencias
- Ninguna nueva. Usar `fl_chart` (ya incluido) para gráficos de progreso.

---

## 2. Presupuestos vs Realidad

**Estado:** Pendiente | **Prioridad:** Alta

El modelo `Category` ya incluye el campo `monthlyBudget` pero no hay una pantalla que compare lo presupuestado vs lo gastado.

### Implementación sugerida

- Nueva sección en `StatsScreen` o pantalla dedicada `budget_comparison_screen.dart`.
- Para cada categoría con `monthlyBudget > 0`, mostrar:
  - Presupuesto mensual.
  - Total gastado en el mes actual.
  - Porcentaje usado.
  - Barra de progreso con color dinámico (verde < 70%, amarillo < 90%, rojo ≥ 90%).
- Alerta visual cuando una categoría excede el presupuesto (icono de advertencia, texto en rojo).

### Datos existentes
- `Category.monthlyBudget` — presupuesto definido por el usuario.
- `InternalTransaction` — filtrado por `categoryId` y fecha del mes actual.

---

## 3. Importación de Estados de Cuenta (CSV/OFX)

**Estado:** Pendiente | **Prioridad:** Alta

Permitir a los usuarios importar extractos bancarios en formato CSV o OFX para evitar el registro manual de transacciones.

### Implementación sugerida

- Nueva pantalla `import_screen.dart` con selector de archivo (usar `file_picker` ya incluido).
- Servicio `import_service.dart` con parseadores para CSV y OFX.
- Mapeo de columnas configurable por el usuario (ej: "columna A = fecha, columna B = monto, columna C = descripción").
- Categorización automática por palabras clave en la descripción (ej: "NETFLIX" → categoría "Entretenimiento").
- Vista previa de transacciones detectadas antes de importar.
- Detección de duplicados para evitar transacciones repetidas.

### Dependencias
- Ninguna nueva. `file_picker` ya está incluido.

---

## 4. Dashboard de Patrimonio Neto

**Estado:** Pendiente | **Prioridad:** Media

Pantalla que muestre la evolución del patrimonio neto del usuario en el tiempo: (Activos - Pasivos).

### Implementación sugerida

- Nueva sección en `StatsScreen` o pantalla dedicada `net_worth_screen.dart`.
- **Activos:** Suma de saldos de todas las tarjetas (`AccountCard.balance`), valor del inventario de productos (`Product.salePrice × Product.currentStock`), efectivo.
- **Pasivos:** Saldo pendiente de préstamos (`Loan.remainingAmount`).
- **Patrimonio Neto:** Activos - Pasivos.
- Gráfico de líneas con `fl_chart` mostrando la evolución mensual.
- snapshot mensual automático (guardar fecha + valor del patrimonio cada mes en Hive).

### Datos existentes
- `AccountCard.balance` — saldo de tarjetas.
- `Loan.remainingAmount` — deuda pendiente.
- `Product` — valor del inventario.

---

## 5. Programación de Tema Oscuro

**Estado:** Pendiente | **Prioridad:** Media

Permitir que el dark mode se active y desactive automáticamente a horas configurables por el usuario.

### Implementación sugerida

- Nuevas opciones en `SettingsScreen`:
  - "Activar modo oscuro automáticamente" (toggle).
  - "Hora de inicio" (TimePicker).
  - "Hora de fin" (TimePicker).
- En `AppProvider`, agregar un `Timer` periódico (cada minuto) que verifique la hora actual y cambie `themeMode` automáticamente.
- Si el usuario establece una hora personalizada manualmente, desactivar la programación automática.

### Código existente
- `AppProvider.themeMode` ya controla el tema. Solo agregar lógica de temporizador.

---

## 6. Escáner de Código de Barras para Productos

**Estado:** Pendiente | **Prioridad:** Media

El módulo de negocio maneja inventario de productos. Agregar escaneo de códigos de barras para agilizar la entrada de productos y las ventas POS.

### Implementación sugerida

- Usar `camera` (ya incluido) o agregar `mobile_scanner` / `flutter_barcode_scanner`.
- Nueva pantalla `barcode_scanner_screen.dart`.
- En el POS (`pos_screen.dart`), agregar botón de escáner para agregar productos rápidamente.
- En `product_form_screen.dart`, opción de escanear en lugar de escribir el SKU manualmente.
- Al escanear en POS, buscar producto por código de barras y agregarlo automáticamente al carrito.

### Dependencias
- `camera` ya incluido. Opcional: `mobile_scanner` (más especializado para códigos de barras).

---

## 7. Envío de Reportes por Correo

**Estado:** Pendiente | **Prioridad:** Media

La exportación a PDF y Excel ya existe. Agregar la opción de enviar el reporte directamente por correo electrónico.

### Implementación sugerida

- En `ExportService`, después de generar el archivo, agregar un método `shareViaEmail(filePath)`.
- Usar `url_launcher` (ya incluido) con el esquema `mailto:` para abrir el cliente de correo con el archivo adjunto.
- Alternativa: usar `share_plus` (ya incluido) que permite compartir archivos con cualquier app, incluyendo correo.
- En las pantallas de exportación, agregar botón "Compartir" o "Enviar por correo" junto al de "Guardar".

### Código existente
- `ExportService` — ya genera Excel y PDF.
- `share_plus` — ya incluido para compartir archivos.

---

## 8. Notificaciones de Presupuesto Excedido

**Estado:** Pendiente | **Prioridad:** Alta

Disparar una notificación local cuando una categoría supera su presupuesto mensual.

### Implementación sugerida

- En `AppProvider`, después de agregar o editar una transacción, verificar si alguna categoría con `monthlyBudget > 0` ha excedido el presupuesto.
- Calcular: suma de transacciones del mes actual para la categoría vs `monthlyBudget`.
- Si se excede, disparar notificación usando `NotificationService` (ya existente).
- Agregar configuración en `NotificationSettingsScreen` para activar/desactivar esta alerta.
- Notificación con acción rápida "Ver gastos" que navegue a la categoría específica.

### Datos existentes
- `Category.monthlyBudget` — presupuesto de la categoría.
- `InternalTransaction` — transacciones del mes.
- `NotificationService` — servicio de notificaciones ya implementado.
- `NotificationSettingsScreen` — pantalla de configuración de notificaciones.

---

## Criterios para Priorización

| Característica | Esfuerzo | Impacto | Prioridad |
|----------------|:--------:|:-------:|:---------:|
| Metas de Ahorro | Medio | Alto | Alta |
| Presupuestos vs Realidad | Bajo | Alto | Alta |
| Importación CSV/OFX | Alto | Alto | Alta |
| Notif. Presupuesto Excedido | Bajo | Alto | Alta |
| Patrimonio Neto | Medio | Medio | Media |
| Tema Oscuro Programado | Bajo | Medio | Media |
| Escáner Código Barras | Medio | Medio | Media |
| Envío Reportes por Correo | Bajo | Medio | Media |

---

*Última actualización: Junio 2026*
