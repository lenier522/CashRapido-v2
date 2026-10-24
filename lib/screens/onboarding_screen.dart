import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/localization_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/design/cash_button.dart';
import 'default_license_screen.dart';
import 'wallet_screen.dart';

/// Pantalla de bienvenida / introducción (onboarding).
///
/// Se muestra una sola vez, antes de la licencia por defecto, a los usuarios
/// que todavía no han completado la introducción. Al finalizar se guarda la
/// preferencia `seenOnboarding` y se continúa hacia [DefaultLicenseScreen].
///
/// ## Diseño de las páginas
///
/// Cada página es **una única imagen** (`assets/onboarding/onb*.png`) que ya
/// lleva horneados el título, la descripción y el indicador circular de
/// páginas. Por eso esta pantalla **no** vuelve a dibujar esos elementos: hacer
/// lo contrario los duplicaría.
///
/// Las medidas de layout se han tomado midiendo los propios PNG (ver
/// [_imageBoxRatio] e [_indicatorFraction]) para que el indicador horneado
/// quede siempre visible por encima del botón.
///
/// ## Apariencia
///
/// Las imágenes son opacas y su fondo horneado coincide con
/// [AppColors.backgroundLight] (diferencia de 1 unidad de color). Por eso el
/// onboarding se fuerza a apariencia clara mediante [AppTheme.light]: en tema
/// oscuro, el fondo blanco horneado se dibujaría como un rectángulo claro con
/// bordes duros sobre la superficie oscura.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Páginas del onboarding, en orden.
  static const List<String> _pages = <String>[
    'assets/onboarding/onb1.png',
    'assets/onboarding/onb2.png',
    'assets/onboarding/onb3.png',
    'assets/onboarding/onb4.png',
  ];

  /// Relación alto/ancho de las imágenes (onb1 mide 308x621).
  ///
  /// Las cuatro varían menos de un 4 % entre sí, así que usar una caja de
  /// relación fija mantiene el indicador circular horneado en la misma
  /// posición al deslizar (se desplaza como mucho 2 px entre páginas).
  static const double _imageBoxRatio = 621 / 308;

  /// Fracción de la altura de la imagen en la que cae el indicador circular
  /// horneado. Medido en los PNG: los puntos están en y≈581 de 621.
  ///
  /// Los controles se reservan por debajo de esta línea para no taparlos.
  static const double _indicatorFraction = 0.936;

  /// Altura reservada para el bloque inferior.
  ///
  /// Los controles van en **una sola fila** (omitir + botón principal), así
  /// que la reserva es mínima: padding superior 12 + fila 54 + padding
  /// inferior 16. Reservar lo justo es lo que permite que la imagen ocupe el
  /// ancho completo: al compartir altura con los controles en vez de cederla,
  /// las bandas laterales desaparecen en los móviles actuales.
  ///
  /// Una banda lateral, por pequeña que sea, cortaría la ilustración de
  /// `onb4`, cuyo contenido verde llega al borde exacto del PNG.
  static const double _controlsHeight = 82;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Comportamiento existente: se solicita el permiso de notificaciones al
    // iniciar la introducción en móvil (Android/iOS). Se conserva tal cual.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      NotificationService().requestPermissions();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          // Iconos oscuros de barra de estado: el fondo es claro en ambos temas.
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.backgroundLight,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          // La imagen va a sangre y se dibuja también por detrás de la barra
          // de estado. La app corre edge-to-edge (targetSdk 36), así que ese
          // inset superior restaba altura y obligaba a encoger la imagen,
          // generando las bandas laterales que cortaban el contenido de `onb4`
          // (su ilustración verde llega al borde exacto del PNG).
          //
          // Es seguro: la franja superior del PNG está vacía de contenido (el
          // título empieza en y≈41 de 621 = 6,6 % de la altura ≈ 55 dp en un
          // móvil actual), muy por encima de los ~28 dp de la barra de estado.
          // Solo se respeta el inset inferior, para que los controles queden
          // por encima de la barra de navegación por gestos.
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double height = constraints.maxHeight;

                // La imagen ocupa toda la altura disponible salvo el espacio
                // de los controles y una holgura. Repartir así el espacio
                // permite que el fondo de la imagen llegue al borde de la
                // pantalla (evita las bandas laterales), algo necesario en
                // onb4, cuyo contenido llega al borde exacto del PNG.
                final double maxHeightForImage =
                    (height - _controlsHeight - AppSpacing.md) /
                    _indicatorFraction;

                double imageHeight = width * _imageBoxRatio;
                if (imageHeight > maxHeightForImage) {
                  imageHeight = maxHeightForImage;
                }
                if (imageHeight > height) imageHeight = height;
                if (imageHeight < 1) imageHeight = 1;

                // Anchura derivada de la altura: a lo sumo el ancho disponible.
                final double imageWidth = imageHeight / _imageBoxRatio;

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: imageWidth,
                        height: imageHeight,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _pages.length,
                          onPageChanged: (int index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (BuildContext context, int index) {
                            // El texto va dentro de la imagen y para los
                            // lectores de pantalla es invisible, así que se
                            // expone con etiqueta propia.
                            return Semantics(
                              label:
                                  'CashRapido — ${index + 1}/${_pages.length}',
                              image: true,
                              child: Image.asset(_pages[index]),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildControls(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Controles inferiores en una única fila: omitir + avanzar (o entrar).
  ///
  /// No incluye indicador de páginas porque ese indicador circular ya va
  /// horneado dentro de cada imagen.
  ///
  /// La fila mantiene una altura fija de 54 px en todas las páginas (el
  /// botón de omitir se oculta en la última, pero la fila no cambia de
  /// tamaño), de modo que el tamaño de la imagen no salta al deslizar.
  Widget _buildControls(BuildContext context) {
    final bool isLast = _currentIndex == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        // Altura de la fila = altura del botón principal (54). El botón de
        // omitir usa el mismo mínimo, así que ambos quedan alineados y la
        // reserva [_controlsHeight] se cumple en todas las páginas.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (!isLast) ...<Widget>[
            TextButton(
              onPressed: _completeOnboarding,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 54),
                // Color fijo: el fondo del onboarding es claro en ambos temas,
                // por lo que el color heredado del tema oscuro sería ilegible.
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(context.t('skip')),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: CashButton(
              label: isLast
                  ? context.t('onboarding_get_started')
                  : context.t('continue_btn'),
              height: 54,
              onPressed: isLast ? _completeOnboarding : _goToNextPage,
            ),
          ),
        ],
      ),
    );
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    // Al terminar el onboarding, ir directamente a la billetera
    // para crear la primera cuenta con los nuevos tipos disponibles.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );
  }
}
