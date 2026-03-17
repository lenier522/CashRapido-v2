import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../services/localization_service.dart';

class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _captureAndScan() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = "Analizando tarjeta con IA...";
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
        setState(() {
          _statusText = "Tarjeta no detectada. Acércala más.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      print("Error escaneando tarjeta con IA: $e");
      setState(() {
        _statusText = "Reintenta alinear mejor la tarjeta.";
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPreview(_controller!),

          Container(
            decoration: const ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: Colors.deepPurple,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 5,
                cutOutSize: 300,
                cutOutHeight: 200, // Card ratio roughly
              ),
            ),
          ),

          // Scanning Animation (Laser Line)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 300,
                  height: 200,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, _animation.value * 200),
                    child: Container(
                      height: 2,
                      width: 300,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.deepPurpleAccent.withOpacity(0.8),
                            Colors.transparent,
                          ],
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusText,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),
                const Spacer(),
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 50.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50.0),
                    child: ElevatedButton.icon(
                      onPressed: _captureAndScan,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(
                        "Capturar Tarjeta",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
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

// Custom Painter for Overlay
class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;
  final double cutOutHeight;

  const _ScannerOverlayShape({
    required this.borderColor,
    this.borderWidth = 10.0,
    this.borderLength = 20.0,
    this.borderRadius = 10.0,
    this.cutOutSize = 250.0,
    this.cutOutHeight = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutHeight,
          ),
          Radius.circular(borderRadius),
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = cutOutSize;
    final height = cutOutHeight;
    // final borderOffset = borderWidth / 2; // Unused
    final double halfBorderLength = borderLength / 2;
    // final double halfWidth = width / 2; // Unused
    // final double halfHeight = height / 2; // Unused

    final backgroundPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxRect = Rect.fromCenter(
      center: rect.center,
      width: width,
      height: height,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(
          RRect.fromRectAndRadius(boxRect, Radius.circular(borderRadius)),
        ),
      ),
      backgroundPaint,
    );

    // Draw corners
    // Top Left
    canvas.drawLine(
      Offset(boxRect.left, boxRect.top + halfBorderLength),
      Offset(boxRect.left, boxRect.top - halfBorderLength + borderLength),
      borderPaint,
    );
    // ... (simplify drawing for brevity, could draw 4 corners)
    // Actually let's just draw the RRect border for simplicity and aesthetics
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      cutOutSize: cutOutSize,
      cutOutHeight: cutOutHeight,
    );
  }
}
