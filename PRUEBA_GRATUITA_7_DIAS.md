# Prueba gratuita de 7 días y bloqueo de cuentas

> Alcance del documento: solo la prueba gratuita implementada en la app Flutter
> (`lib/`). No describe el sitio web ni cambios de backend.

## Regla de producto

| Momento | Comportamiento |
|---|---|
| Instalación nueva | Empieza una prueba de **7 días** con casi todas las funciones desbloqueadas. |
| Durante la prueba | IA, Google Drive/nube y respaldo local siguen requiriendo un plan de pago. |
| Compra durante la prueba | El plan se activa y los datos se conservan. |
| Fin de la prueba sin plan | **No se borra ningún dato.** La cuenta principal sigue disponible. |
| Cuentas adicionales al vencer | Quedan bloqueadas hasta que se active una licencia vigente. |
| Activación posterior | Las cuentas adicionales y sus movimientos vuelven a estar disponibles. |
| Instalaciones anteriores | Se marcan como exentas para no retirar cuentas que ya existían. |
| Windows | No aplica la prueba; se considera desbloqueado tras la activación del equipo. |

El bloqueo **no modifica ni elimina** tarjetas, movimientos, categorías, negocio,
préstamos ni chats. Solo cambia lo que la interfaz muestra y permite operar.

## Flujo de arranque

1. `main()` llama a `TrialService.enforceAtStartup()` antes de abrir Hive.
2. `TrialService.startIfNeeded()` lee `trial_start_date` o la crea.
   - Si detecta datos previos o `seenOnboarding`, marca `trial_exempt` para no
     bloquear instalaciones anteriores a esta política.
3. Si no hay plan vigente y pasaron los 7 días, se marca
   `trial_lock_notice_shown` para mostrar el aviso una sola vez.
4. `AppProvider` lee el estado de la prueba y de la licencia.
5. La app abre normalmente: no hay borrado de cajas ni de preferencias.

Al reanudar la app, y también cada minuto mientras permanece abierta,
`AuthWrapper` comprueba si el vencimiento ocurrió mientras estaba en segundo
plano o si la ventana terminó con la app abierta:

1. `TrialService.isExpiredWithoutPlan()` verifica el estado actual.
2. `AppProvider.refreshAccessState()` vuelve a leer licencia y prueba.
3. `TrialService.lockIfExpired()` marca el aviso si corresponde.
4. Se muestra el diálogo de fin de prueba con acceso a la pantalla de licencias.

## Estado persistido

| Clave | Uso |
|---|---|
| `trial_start_date` | Fecha ISO-8601 de inicio de la prueba. |
| `trial_lock_notice_shown` | Evita repetir el aviso de fin de prueba. |
| `trial_exempt` | Instalación anterior: conserva todas las cuentas sin bloqueo. |
| `trial_converted` | Marca histórica de compra durante la prueba. Se conserva por compatibilidad. |
| `license_type` | Índice de `LicenseType`. |
| `license_expiration_date` | Vencimiento exacto de la licencia. |
| `license_activation_date` | Formato legado; se recalcula con `durationDays`. |

`TrialService.hasActivePlan()` es la comprobación que decide si las cuentas
adicionales están desbloqueadas. Ignora `trial_converted`: si el plan caducó,
las cuentas vuelven a bloquearse. `hasPaidPlan()` se mantiene para la
conservación histórica de datos y sí tiene en cuenta `trial_converted`.

## Implementación en `AppProvider`

- `_allAccountsUnlocked`: verdadero durante la prueba, en instalaciones exentas,
  con plan de pago vigente o en Windows.
- `isAccountBlockedByTrial(card)`: bloquea todas las cuentas menos la primera
  cuando no hay acceso completo. La primera cuenta es la principal.
- `cards`: solo cuentas utilizables. Es el getter que usan las pantallas normales.
- `allCards`: todas las cuentas almacenadas, incluidas las bloqueadas.
- `lockedCards` / `hasLockedAccounts` / `lockedAccountsCount`: estado para la UI.
- `transactions`: excluye movimientos de cuentas bloqueadas, pero no los borra.
- `getTotalBalance*`, `getSpentThisMonth*`, `getIncomeThisMonth*` y
  `getSpentForCategoryThisMonth`: solo suman cuentas y movimientos accesibles.
- `_processRecurringTransactions()`: omite recurrentes de cuentas bloqueadas.
- `addTransaction()`, `editTransaction()`, `deleteTransaction()`,
  `transferBetweenCards()` y `validateCardForTransaction()`: rechazan operaciones
  sobre cuentas bloqueadas aunque se invoquen fuera de la UI.
- `canDeleteCard()` impide eliminar la principal mientras haya cuentas
  bloqueadas, para que no se desbloquee otra cuenta sin licencia.
- `refreshAccessState()` actualiza el bloqueo al reanudar la app sin reiniciar.

## Interfaz

- **Inicio**: durante la prueba muestra el tiempo restante. Al vencer muestra un
  aviso de que los datos están a salvo y las cuentas adicionales bloqueadas, con
  acceso a licencias.
- **Billetera**: lista las cuentas utilizables y, debajo, una sección de cuentas
  bloqueadas. Las bloqueadas muestran nombre, moneda y candado, pero no su saldo.
- **Licencias**: el mensaje de fin de prueba explica que no se borraron datos y
  que las cuentas adicionales se desbloquean al activar un plan.
- Las pantallas que usan `provider.cards` (Inicio, Movimientos, Estadísticas,
  TransferMóvil, recurrentes, formularios de movimientos y préstamos) dejan de
  mostrar las cuentas bloqueadas automáticamente.

## Copias de seguridad y nube

El bloqueo es una condición de acceso, no un cambio en los datos:

- Las 18 cajas Hive siguen completas, incluidas las cuentas bloqueadas y sus
  movimientos.
- El ZIP local y Google Drive incluyen esas cajas.
- El snapshot de Supabase incluye las mismas colecciones.
- `SharedPreferences` no forma parte de las copias. La licencia, el inicio de la
  prueba, el tema y las tasas de cambio no se restauran desde un respaldo.

Al restaurar en un dispositivo con licencia vigente, las cuentas adicionales se
verán normalmente. En un dispositivo sin licencia, se mantienen bloqueadas hasta
activarla.

## Pruebas

`test/trial_service_test.dart` cubre:

1. La prueba dura 7 días.
2. El cálculo de fin y tiempo restante.
3. Un plan vigente cuenta como pago.
4. Un plan caducado no cuenta como activo.
5. `trial_converted` conserva datos, pero no desbloquea cuentas con plan vencido.
6. `isExpiredWithoutPlan()` detecta el vencimiento sin plan.
7. Un plan vigente o una instalación exenta no exigen bloqueo.
8. Dentro de la prueba no se bloquea ni se borra nada.
9. Con plan vigente tampoco se bloquea al pasar los 7 días.
10. Sin plan se muestra el aviso una sola vez y los datos siguen intactos.
11. El vencimiento en caliente solo avisa una vez.
12. Las instalaciones anteriores quedan exentas.

Ejecutar:

```bash
flutter test test/trial_service_test.dart
flutter analyze lib/services/trial_service.dart lib/providers/app_provider.dart \
  lib/main.dart lib/screens/home_screen.dart lib/screens/wallet_screen.dart
```

## Validación manual sugerida

1. Instalación limpia: Inicio muestra «Prueba gratis de 7 días».
2. Crear 2 o 3 cuentas y varios movimientos.
3. Adelantar `trial_start_date` más de 7 días y reiniciar.
4. Verificar que:
   - No desaparece ningún dato.
   - La cuenta principal sigue operable.
   - Las demás aparecen como bloqueadas en Billetera.
   - Los totales y movimientos solo incluyen cuentas disponibles.
5. Activar una licencia y comprobar que todas las cuentas y movimientos vuelven.
6. Vencer la licencia y confirmar que se bloquean de nuevo sin borrar nada.

## Limitaciones

- La prueba es local. Reinstalar la app o cambiar la hora del dispositivo puede
  alterar el vencimiento; no sustituye una validación de servidor.
- El bloqueo es de interfaz y de lógica de negocio. No cifra Hive ni impide que
  una persona con acceso físico y herramientas externas lea la base local.
- Las copias de seguridad no incluyen `SharedPreferences`; restaurar datos no
  restaura la licencia ni el estado de la prueba.
