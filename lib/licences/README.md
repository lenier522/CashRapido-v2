# Licencias - CashRapido

Esta carpeta contiene toda la lógica relacionada con el sistema de licencias de CashRapido.

## Archivos

### `license_type.dart`
Define el enum `LicenseType` con los diferentes niveles de suscripción organizados por período:

**Licencias Semanales (7 días):**
- `weeklyPersonal` - 15 CUP / $0.15 USD
- `weeklyPro` - 25 CUP / $0.25 USD
- `weeklyEnterprise` - 35 CUP / $0.35 USD

**Licencias Mensuales (30 días):**
- `monthlyPersonal` - 50 CUP / $0.50 USD
- `monthlyPro` - 75 CUP / $1 USD
- `monthlyEnterprise` - 110 CUP / $1.50 USD

**Licencias Anuales (365 días):**
- `annualPersonal` - 500 CUP / $5 USD
- `annualPro` - 750 CUP / $10 USD
- `annualEnterprise` - 1000 CUP / $15 USD

**Gratuita:**
- `free` - Sin costo, funcionalidades limitadas

Incluye extensiones para obtener:
- `durationDays` - Duración en días (7, 30, 365)
- `level` - Nivel (free, personal, pro, enterprise)
- `period` - Período (weekly, monthly, annual, lifetime)

### `payment_config.dart`
**Configuración de métodos de pago por licencia.**

Permite habilitar o deshabilitar métodos de pago específicos para cada tipo de licencia.

**Configuración actual:**
| Licencia | Métodos Habilitados | Región |
|----------|-------------------|--------|
| Semanales | Art-Pay, Anuncios | Todas |
| Mensuales | Apklis, Art-Pay, Anuncios | Todas |
| Anuales | Art-Pay | Solo Cuba |

**Personalizar métodos de pago:**

Edita `defaultConfigs` en `payment_config.dart`:

```dart
static const Map<LicenseType, LicensePaymentConfig> defaultConfigs = {
  // Ejemplo: Semanal con solo Art-Pay
  LicenseType.weeklyPersonal: LicensePaymentConfig(
    enabledMethods: [artPay],  // Solo Art-Pay
  ),
  
  // Ejemplo: Mensual con todos los métodos
  LicenseType.monthlyPro: LicensePaymentConfig(
    enabledMethods: [apklis, artPay, watchAds],
  ),
  
  // Ejemplo: Anual solo para Cuba con Apklis y Art-Pay
  LicenseType.annualEnterprise: LicensePaymentConfig(
    enabledMethods: [apklis, artPay],
    isCubaOnly: true,
  ),
};
```

**Métodos disponibles:**
- `apklis` - Tienda Apklis
- `art_pay` - Billetera Art-Pay (.lic)
- `watch_ads` - Ver anuncios (Google Ads)
- `transfermovil` - Transfermóvil (deshabilitado)
- `enzona` - EnZona (deshabilitado)
- `test_cuba` - Test Cuba
- `test_intl` - Test Internacional

### `apklis.dart`
Servicio para validar licencias mediante la plataforma **Apklis**.
- Usa la librería `apklis_license_validator`
- Contiene los UUIDs de cada tipo de licencia
- Métodos: `purchase()`, `verify()`, `isPurchased()`, `getLicenseTypeFromUUID()`

**UUIDs de Licencias Apklis (configurar los de semanal y anual):**
```
// Semanales (CONFIGURAR)
weeklyPersonal:    UUID_WEEKLY_PERSONAL_AQUI
weeklyPro:         UUID_WEEKLY_PRO_AQUI
weeklyEnterprise:  UUID_WEEKLY_ENTERPRISE_AQUI

// Mensuales (CONFIGURADOS)
monthlyPersonal:   ef115f45-8736-4a21-a619-2d2f7b1d8781
monthlyPro:        1c6fa982-48e8-4b85-8bbb-56be3bb628c3
monthlyEnterprise: 3a72b071-a327-4336-9df9-4aebf04bd0e5

// Anuales (CONFIGURAR)
annualPersonal:    UUID_ANNUAL_PERSONAL_AQUI
annualPro:         UUID_ANNUAL_PRO_AQUI
annualEnterprise:  UUID_ANNUAL_ENTERPRISE_AQUI
```

### `art_pay.dart`
Servicio para gestionar pagos mediante la plataforma **Art-Pay**.
- Usa la librería `artpay_lib`
- Contiene los tokens de producto configurados en el panel de Art-Pay
- Métodos: `handlePayment()`, `getPriceCUP()`, `getPriceUSD()`, `getLicenseName()`, etc.

**Tokens de Producto Art-Pay (configurar los de semanal y anual):**
```
// Semanales (CONFIGURAR)
weeklyPersonal:    TOKEN_WEEKLY_PERSONAL_AQUI
weeklyPro:         TOKEN_WEEKLY_PRO_AQUI
weeklyEnterprise:  TOKEN_WEEKLY_ENTERPRISE_AQUI

// Mensuales (CONFIGURADOS)
monthlyPersonal:   00113e86-6bed-4e1c-a38e-d3130a536878
monthlyPro:        1d9f9688-6ac6-42b1-8274-334c64e2a875
monthlyEnterprise: c5f52c39-f316-4bb6-8d91-914089fc1c78

// Anuales (CONFIGURAR)
annualPersonal:    TOKEN_ANNUAL_PERSONAL_AQUI
annualPro:         TOKEN_ANNUAL_PRO_AQUI
annualEnterprise:  TOKEN_ANNUAL_ENTERPRISE_AQUI
```

## Uso

### Importar LicenseType
```dart
import '../licences/license_type.dart';

// Usar extensiones
final license = LicenseType.monthlyPro;
print(license.durationDays); // 30
print(license.level); // LicenseLevel.pro
print(license.period); // LicensePeriod.monthly
```

### Configurar Métodos de Pago por Licencia

```dart
import '../licences/payment_config.dart';

// Ver métodos habilitados para una licencia
final methods = LicensePaymentConfig.getEnabledMethods(
  LicenseType.monthlyPro,
);
// ['apklis', 'art_pay', 'watch_ads']

// Verificar si un método está habilitado
final isEnabled = LicensePaymentConfig.isMethodEnabledForLicense(
  LicenseType.annualPersonal,
  LicensePaymentConfig.apklis,
);
// false (anuales solo tienen art_pay)

// Crear configuración personalizada
final customConfig = LicensePaymentConfig.custom(
  methods: [LicensePaymentConfig.apklis, LicensePaymentConfig.artPay],
  cubaOnly: true,
);
```

### Usar ApklisService
```dart
import '../licences/apklis.dart';

// Verificar licencia
final status = await ApklisService.verify();
if (status.paid) {
  // Usuario tiene licencia activa
  final licenseType = ApklisService.getLicenseTypeFromUUID(status.license);
}

// Comprar licencia
final status = await ApklisService.purchase(LicenseType.monthlyPro);
if (status.paid) {
  // Pago exitoso
}
```

### Usar ArtPayService
```dart
import '../licences/art_pay.dart';

ArtPayService.handlePayment(
  context: context,
  licenseType: LicenseType.monthlyPro,
  onSuccess: (result) {
    // Licencia verificada exitosamente
    // result.accessExpiresAt contiene la fecha de expiración
  },
  onError: (error) {
    // Manejar error
  },
);

// Obtener información de precio
final priceCUP = ArtPayService.getPriceCUP(LicenseType.annualPro); // '750'
final priceUSD = ArtPayService.getPriceUSD(LicenseType.annualPro); // '10'
final name = ArtPayService.getLicenseName(LicenseType.annualPro); // 'Anual Pro'
```

## Duración de Licencias

| Período | Días |
|---------|------|
| Semanal | 7 |
| Mensual | 30 |
| Anual | 365 |

## Persistencia

Las licencias se almacenan en `SharedPreferences`:
- `license_type`: índice del enum LicenseType (0-9)
- `license_expiration_date`: fecha exacta de expiración (ISO8601)
- `license_activation_date`: fecha de activación (legacy)

## Niveles de Características

| Característica | Free | Personal | Pro | Enterprise |
|---------------|------|----------|-----|------------|
| Tarjetas máx. | 1 | 3 | 4 | Ilimitadas |
| Transferencias | ❌ | ✅ | ✅ | ✅ |
| Bloquear tarjeta | ❌ | ✅ | ✅ | ✅ |
| Estadísticas avanzadas | ❌ | ✅ | ✅ | ✅ |
| Categorías personalizadas | ❌ | ❌ | ✅ | ✅ |
| Exportar Excel | ❌ | ❌ | ✅ | ✅ |
| Biometría | ❌ | ❌ | ❌ | ✅ |
| Scanner QR | ❌ | ❌ | ❌ | ✅ |
| IA Chat | ❌ | ❌ | ❌ | ✅ |
| Sync Drive | ❌ | ❌ | ❌ | ✅ |
| Business Module | ❌ | ❌ | ❌ | ✅ |
| Widgets | ❌ | ❌ | ❌ | ✅ |

## Matriz de Métodos de Pago por Licencia

| Licencia | Apklis | Art-Pay | Anuncios |
|----------|--------|---------|----------|
| **Semanal Personal** | ❌ | ✅ | ✅ |
| **Semanal Pro** | ❌ | ✅ | ✅ |
| **Semanal Enterprise** | ❌ | ✅ | ✅ |
| **Mensual Personal** | ✅ | ✅ | ✅ |
| **Mensual Pro** | ✅ | ✅ | ✅ |
| **Mensual Enterprise** | ✅ | ✅ | ✅ |
| **Anual Personal** | ❌ | ✅ | ❌ |
| **Anual Pro** | ❌ | ✅ | ❌ |
| **Anual Enterprise** | ❌ | ✅ | ❌ |

**Nota:** Esta configuración puede personalizarse en `payment_config.dart`.
