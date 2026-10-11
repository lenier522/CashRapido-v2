import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../widgets/design/cash_button.dart';

/// Escáner de tarjeta con cámara + IA (Gemini).
///
/// La **lógica no cambia**: permisos, inicialización de cámara, captura,
/// prompt de Gemini, parseo JSON y devolución del resultado a AddCardScreen.
/// Sólo se rediseñó la interfaz (overlay adaptativo, colores de marca,
/// textos localizados y lectura a pantalla de carga) manteniendo intacto el
/// flujo de negocio.
class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  late String _statusText;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statusText = context.t('scan_card_instruction');
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  /// Tamaño del recuadro de escaneo, adaptado al ancho real (320–430 px).
  double _overlayWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.86, 340);

  double _overlayHeight(double width) => width * 0.64; // Ratio de una tarjeta

  Future<void> _captureAndScan() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = context.t('scan_analyzing');
    });

    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

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
        if (mounted) {
          Navigator.pop(context, {
            'number': number,
            'expiry': expiry,
            'holder': holder,
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _statusText = context.t('scan_not_detected');
          _isProcessing = false;
        });
      }
    } catch (e) {
      print("Error escaneando tarjeta con IA: $e");
      if (!mounted) return;
      setState(() {
        _statusText = context.t('scan_align_error');
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  context.t('scan_camera_loading'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final double overlayWidth = _overlayWidth(context);
    final double overlayHeight = _overlayHeight(overlayWidth);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Recuadro de escaneo (oscurece fuera del área)
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: AppColors.primary,
                borderRadius: 16,
                borderWidth: 3,
                cutOutSize: overlayWidth,
                cutOutHeight: overlayHeight,
              ),
            ),
          ),

          // Línea láser animada
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Center(
                child: SizedBox(
                  width: overlayWidth,
                  height: overlayHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: Offset(0, _animation.value * overlayHeight),
                      child: Container(
                        height: 2.5,
                        width: overlayWidth - 24,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.6,
                              ),
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
          ),

          SafeArea(
            child: Column(
              children: [
                // Cabecera: cerrar + estado
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _CloseButton(onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              _statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Equilibra el botón de cierre
                    ],
                  ),
                ),
                const Spacer(),

                // Controles inferiores
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.t('scan_analyzing'),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        CashButton(
                          label: context.t('scan_capture_btn'),
                          icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          onPressed: _captureAndScan,
                        ),
                      const SizedBox(height: 12),
                      Text(
                        context.t('scan_frame_hint'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 24),
        ),
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
