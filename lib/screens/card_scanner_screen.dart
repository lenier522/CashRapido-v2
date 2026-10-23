import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_empty_state.dart';

/// Escáner de tarjeta con cámara + IA (Gemini).
///
/// Se conserva íntegra la lógica que ya funcionaba: solicitud del permiso de
/// cámara, captura de la foto, prompt de Gemini, parseo del JSON y devolución
/// del resultado a `AddCardScreen` con las mismas claves (`number`, `expiry`,
/// `holder`). Tampoco cambian el proveedor, el modelo ni el prompt.
///
/// Lo que mejora este grupo es la capa de presentación y la robustez del ciclo
/// de vida de la cámara:
/// - la cámara se libera al salir y al pasar a segundo plano, y se reanuda al
///   volver, sin interrumpir una captura en curso;
/// - no se inicializa la cámara dos veces a la vez ni se actualiza la pantalla
///   después de desmontarse;
/// - los fallos reales se distinguen (permiso denegado, permiso bloqueado,
///   cámara no disponible, error al iniciar, error de captura, error de
///   lectura) en lugar de un único mensaje genérico;
/// - el marco y el indicador reflejan el estado real y no se muestra éxito sin
///   datos válidos.
///
/// Privacidad: no se registran en logs números de tarjeta ni errores del
/// proveedor de IA, y no se añade ningún envío a servicios externos nuevos
/// (la lectura con Gemini ya formaba parte de la funcionalidad existente).
class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

/// Estado real de la cámara, limitado a lo que la implementación puede
/// distinguir de forma fiable.
enum _CameraStatus {
  initializing,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  error,
}

/// Estado real de una lectura, limitado a lo que la implementación puede
/// distinguir de forma fiable.
enum ScannerReadStatus {
  ready,
  processing,
  notDetected,
  captureError,
  readError;

  /// Lectura que no produjo datos válidos: el marco lo señala en rojo.
  bool get isProblem =>
      this == notDetected || this == captureError || this == readError;
}

class _CardScannerScreenState extends State<CardScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  _CameraStatus _cameraStatus = _CameraStatus.initializing;
  ScannerReadStatus _scanStatus = ScannerReadStatus.ready;

  /// Evita inicializaciones simultáneas de la cámara.
  bool _isInitializingCamera = false;

  /// Marca que la cámara se detuvo por un cambio de ciclo de vida, para
  /// reanudarla sólo al volver de verdad.
  bool _pausedByLifecycle = false;

  bool _torchOn = false;

  /// Se oculta el control de linterna si el dispositivo no la admite.
  bool _torchSupported = true;

  late AnimationController _animationController;
  late Animation<double> _animation;

  bool get _isProcessing => _scanStatus == ScannerReadStatus.processing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _initializeCamera(askPermission: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    final CameraController? controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      // Sólo se libera lo que ya está en uso. Si había una inicialización en
      // curso, su continuación detecta `!mounted` y libera el controlador.
      _controller = null;
      controller.dispose();
    }

    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_pausedByLifecycle) return;
      _pausedByLifecycle = false;
      // Se reanuda la cámara (o se reintenta si antes falló). No se vuelve a
      // pedir el permiso: si ya está concedido, `status` lo refleja sin
      // mostrar ningún diálogo.
      _releaseInitializedController();
      _initializeCamera();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pausedByLifecycle = true;

      final CameraController? controller = _controller;
      if (controller == null || _isProcessing) return;
      if (controller.value.isInitialized) {
        // No se interrumpe una captura en curso, pero sí se evita mantener la
        // cámara activa cuando la app pasa a segundo plano.
        _controller = null;
        controller.dispose();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CÁMARA
  // ---------------------------------------------------------------------------

  Future<void> _initializeCamera({bool askPermission = false}) async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;

    try {
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted && askPermission) {
        status = await Permission.camera.request();
      }

      if (!mounted) return;

      if (!status.isGranted) {
        _setCameraStatus(
          status.isPermanentlyDenied
              ? _CameraStatus.permissionPermanentlyDenied
              : _CameraStatus.permissionDenied,
        );
        return;
      }

      final List<CameraDescription> cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      if (cameras.isEmpty) {
        _setCameraStatus(_CameraStatus.unavailable);
        return;
      }

      final CameraController controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;

      await controller.initialize().timeout(const Duration(seconds: 15));

      if (!mounted) {
        // La pantalla se cerró mientras se inicializaba: se libera igualmente.
        if (identical(_controller, controller)) {
          _controller = null;
          await controller.dispose();
        }
        return;
      }

      _setCameraStatus(
        controller.value.isInitialized
            ? _CameraStatus.ready
            : _CameraStatus.error,
      );
    } catch (_) {
      // Nunca se registra el error en logs: puede contener datos del proveedor.
      _discardController();
      if (!mounted) return;
      _setCameraStatus(_CameraStatus.error);
    } finally {
      _isInitializingCamera = false;
    }
  }

  /// Libera el controlador sólo si ya está inicializado, para no interrumpir
  /// una inicialización en curso.
  void _releaseInitializedController() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _controller = null;
    controller.dispose();
  }

  /// Libera cualquier controlador, incluido uno a medio inicializar.
  void _discardController() {
    final CameraController? controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  void _setCameraStatus(_CameraStatus status) {
    if (!mounted) return;
    setState(() {
      _cameraStatus = status;
      if (status == _CameraStatus.ready) {
        _torchOn = false;
        _scanStatus = ScannerReadStatus.ready;
      }
    });
  }

  Future<void> _toggleTorch() async {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      if (!mounted) return;
      setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // El dispositivo no admite la linterna: se oculta el control.
      if (!mounted) return;
      setState(() {
        _torchSupported = false;
        _torchOn = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // LECTURA
  // ---------------------------------------------------------------------------

  /// Tamaño del recuadro de escaneo, adaptado al ancho real (320–430 px).
  double _overlayWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.86, 340);

  double _overlayHeight(double width) => width * 0.64; // Ratio de una tarjeta

  void _setScanStatus(ScannerReadStatus status) {
    if (!mounted) return;

    if (status == ScannerReadStatus.processing) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.value = 0;
    }

    setState(() => _scanStatus = status);
  }

  Future<void> _captureAndScan() async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessing) {
      return;
    }

    _setScanStatus(ScannerReadStatus.processing);

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();

      // La captura contiene el número completo de la tarjeta. Ya se tienen sus
      // bytes en memoria, así que se elimina el archivo temporal para no
      // dejarlo en el almacenamiento del dispositivo. Si el borrado falla no se
      // interrumpe la lectura.
      try {
        final File capture = File(image.path);
        if (await capture.exists()) {
          await capture.delete();
        }
      } catch (_) {
        // Sin efectos sobre el resultado de la lectura.
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: dotenv.get('GEMINI_API_KEY_1', fallback: ''),
      );

      final prompt = '''
Extrae la siguiente información de la imagen de esta tarjeta:
1. Número de la tarjeta (16 dígitos, a veces separados por espacios)
2. Fecha de expiración (MM/YY)
3. Nombre del titular (Si aparece)

Responde ÚNICAMENTE con un objeto JSON estricto en este formato exacto:
{"number": "1234 5678 1234 5678", "expiry": "12/26", "holder": "JUAN PEREZ"}
Si no encuentras algún dato, usa null. NO agregues ni una palabra más al texto ni formato de markdown.
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)]),
      ]);

      final String responseText = response.text ?? "{}";

      // Limpiar formato markdown si la IA fue terca
      final String cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(cleanJson);

      final String? number = data['number'] as String?;
      final String? expiry = data['expiry'] as String?;
      final String? holder = data['holder'] as String?;

      if (number != null && number.isNotEmpty && number != "null") {
        if (!mounted) return;
        Navigator.pop(context, {
          'number': number,
          'expiry': expiry,
          'holder': holder,
        });
        return;
      }

      // Lectura completada pero sin datos suficientes.
      _setScanStatus(ScannerReadStatus.notDetected);
    } on CameraException {
      _setScanStatus(ScannerReadStatus.captureError);
    } catch (_) {
      // Error de reconocimiento (red/IA/parseo). No se registra en logs.
      _setScanStatus(ScannerReadStatus.readError);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return _buildCameraPendingView(context);
    }

    return _buildScannerView(context, controller);
  }

  /// Vista mientras la cámara no está lista: carga o mensaje de error real.
  Widget _buildCameraPendingView(BuildContext context) {
    if (_cameraStatus == _CameraStatus.initializing ||
        _cameraStatus == _CameraStatus.ready) {
      return Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  context.t('scan_camera_loading'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildCameraMessageView(context);
  }

  Widget _buildCameraMessageView(BuildContext context) {
    final bool permissionIssue =
        _cameraStatus == _CameraStatus.permissionDenied ||
        _cameraStatus == _CameraStatus.permissionPermanentlyDenied;
    final bool permanentlyDenied =
        _cameraStatus == _CameraStatus.permissionPermanentlyDenied;

    final IconData icon;
    final String title;
    final String message;
    final String actionLabel;
    final VoidCallback onAction;

    if (permissionIssue) {
      icon = Icons.no_photography_outlined;
      title = context.t('scan_camera_permission_title');
      message = context.t(
        permanentlyDenied
            ? 'scan_camera_permission_settings_desc'
            : 'scan_camera_permission_desc',
      );
      if (permanentlyDenied) {
        actionLabel = context.t('open_system_settings');
        onAction = () => openAppSettings();
      } else {
        actionLabel = context.t('scan_allow_camera');
        onAction = () => _initializeCamera(askPermission: true);
      }
    } else if (_cameraStatus == _CameraStatus.unavailable) {
      icon = Icons.videocam_off_outlined;
      title = context.t('scan_camera_unavailable_title');
      message = context.t('scan_camera_unavailable_desc');
      actionLabel = context.t('scan_retry');
      onAction = () => _initializeCamera();
    } else {
      icon = Icons.videocam_off_outlined;
      title = context.t('scan_camera_error_title');
      message = context.t('scan_camera_error_desc');
      actionLabel = context.t('scan_retry');
      onAction = () => _initializeCamera();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('scan_card'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: CashEmptyState(
          icon: icon,
          title: title,
          message: message,
          buttonLabel: actionLabel,
          onButtonPressed: onAction,
          action: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('close')),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView(BuildContext context, CameraController controller) {
    final double overlayWidth = _overlayWidth(context);
    final double overlayHeight = _overlayHeight(overlayWidth);

    return CardScannerChrome(
      preview: CameraPreview(controller),
      overlayWidth: overlayWidth,
      overlayHeight: overlayHeight,
      status: _scanStatus,
      laserAnimation: _animation,
      torchSupported: _torchSupported,
      torchOn: _torchOn,
      onClose: () => Navigator.pop(context),
      onTorch: _toggleTorch,
      onCapture: _captureAndScan,
    );
  }
}

/// Composición visual del escáner: visor, marco, cabecera, estado y controles.
///
/// No depende de la cámara ni del reconocimiento: recibe el visor ya construido
/// y el estado real de la lectura. Mantenerla separada permite una única fuente
/// de verdad para el diseño y poder verificar su comportamiento responsive sin
/// una cámara real.
class CardScannerChrome extends StatelessWidget {
  /// Visor de cámara ya construido.
  final Widget preview;

  final double overlayWidth;
  final double overlayHeight;
  final ScannerReadStatus status;
  final Animation<double> laserAnimation;
  final bool torchSupported;
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onTorch;
  final VoidCallback onCapture;

  const CardScannerChrome({
    super.key,
    required this.preview,
    required this.overlayWidth,
    required this.overlayHeight,
    required this.status,
    required this.laserAnimation,
    required this.torchSupported,
    required this.torchOn,
    required this.onClose,
    required this.onTorch,
    required this.onCapture,
  });

  bool get _isProcessing => status == ScannerReadStatus.processing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          preview,

          // Recuadro de escaneo (oscurece lo que queda fuera del área).
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: status.isProblem
                    ? AppColors.error
                    : AppColors.primary,
                borderRadius: AppRadius.lg,
                borderWidth: 3,
                cutOutSize: overlayWidth,
                cutOutHeight: overlayHeight,
              ),
            ),
          ),

          // Línea láser: sólo mientras se está leyendo de verdad.
          if (_isProcessing) _buildLaser(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                _buildControls(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaser() {
    return AnimatedBuilder(
      animation: laserAnimation,
      builder: (context, child) {
        return Center(
          child: SizedBox(
            width: overlayWidth,
            height: overlayHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, laserAnimation.value * overlayHeight),
                child: Container(
                  height: 2.5,
                  width: overlayWidth - 24,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryLight.withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          _ScannerRoundButton(
            icon: Icons.close_rounded,
            tooltip: context.t('close'),
            onPressed: onClose,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.t('scan_card'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (torchSupported)
            _ScannerRoundButton(
              icon: torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              tooltip: context.t(torchOn ? 'scan_torch_off' : 'scan_torch_on'),
              active: torchOn,
              onPressed: onTorch,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusPill(context),
          const SizedBox(height: AppSpacing.lg),
          // El botón se atenúa y deja de responder mientras se procesa, sin
          // cambiar su estilo para no romper la identidad visual.
          AbsorbPointer(
            absorbing: _isProcessing,
            child: Opacity(
              opacity: _isProcessing ? 0.55 : 1,
              child: CashButton(
                label: context.t('scan_capture_btn'),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                onPressed: onCapture,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.t('scan_frame_hint'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.82),
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context) {
    final Widget leading;
    final String text;
    final Color accent;

    switch (status) {
      case ScannerReadStatus.processing:
        leading = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.primary,
          ),
        );
        text = context.t('scan_analyzing');
        accent = AppColors.primary;
      case ScannerReadStatus.notDetected:
        leading = const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.warning,
        );
        text = context.t('scan_not_detected');
        accent = AppColors.warning;
      case ScannerReadStatus.captureError:
        leading = const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.error,
        );
        text = context.t('scan_capture_error');
        accent = AppColors.error;
      case ScannerReadStatus.readError:
        leading = const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.error,
        );
        text = context.t('scan_reading_error');
        accent = AppColors.error;
      case ScannerReadStatus.ready:
        leading = const Icon(
          Icons.center_focus_strong_rounded,
          size: 18,
          color: AppColors.white,
        );
        text = context.t('scan_card_instruction');
        accent = AppColors.white;
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular translúcido para los controles sobre la cámara.
class _ScannerRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  const _ScannerRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? AppColors.primary.withValues(alpha: 0.9)
            : AppColors.black.withValues(alpha: 0.5),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        side: BorderSide(color: AppColors.white.withValues(alpha: 0.25)),
      ),
    );
  }
}

/// Overlay de escaneo: oscurece el exterior y dibuja recuadro + esquinas.
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double cutOutSize;
  final double cutOutHeight;

  const _ScannerOverlayShape({
    required this.borderColor,
    this.borderWidth = 3.0,
    this.borderRadius = 16.0,
    required this.cutOutSize,
    required this.cutOutHeight,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addRRect(
        RRect.fromRectAndRadius(_boxRect(rect), Radius.circular(borderRadius)),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  Rect _boxRect(Rect rect) => Rect.fromCenter(
    center: rect.center,
    width: cutOutSize,
    height: cutOutHeight,
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Rect boxRect = _boxRect(rect);
    final RRect rrect = RRect.fromRectAndRadius(
      boxRect,
      Radius.circular(borderRadius),
    );

    // Oscurece todo lo que queda fuera del recuadro.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(rrect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    // Borde del recuadro.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // Esquinas tipo "brújula".
    final double corner = math.min(42.0, cutOutSize * 0.30);
    final Paint cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth + 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Offset tl = boxRect.topLeft;
    final Offset tr = boxRect.topRight;
    final Offset bl = boxRect.bottomLeft;
    final Offset br = boxRect.bottomRight;

    canvas.drawPath(
      Path()
        ..moveTo(tl.dx, tl.dy + corner)
        ..lineTo(tl.dx, tl.dy)
        ..lineTo(tl.dx + corner, tl.dy),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tr.dx - corner, tr.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(tr.dx, tr.dy + corner),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bl.dx, bl.dy - corner)
        ..lineTo(bl.dx, bl.dy)
        ..lineTo(bl.dx + corner, bl.dy),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(br.dx - corner, br.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(br.dx, br.dy - corner),
      cornerPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      cutOutSize: cutOutSize * t,
      cutOutHeight: cutOutHeight * t,
    );
  }
}
