import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/localization_service.dart';
// import 'package:flutter/foundation.dart'; // Removed

class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  late String _statusText;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statusText = context.t('scan_card_instruction');
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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

    _scanLoop();
  }

  Future<void> _scanLoop() async {
    while (mounted && _controller != null && _controller!.value.isInitialized) {
      if (_isProcessing) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      await Future.delayed(const Duration(seconds: 1)); // Throttle
      if (!mounted) break;
      _isProcessing = true;

      try {
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);

        final recognizedText = await _textRecognizer.processImage(inputImage);
        final cardData = _extractCardData(recognizedText);

        if (cardData['number'] != null) {
          if (mounted) Navigator.pop(context, cardData);
          break; // Stop loop
        }
      } catch (e) {
        // Ignore errors
      } finally {
        _isProcessing = false;
      }
    }
  }

  Map<String, String?> _extractCardData(RecognizedText text) {
    String? number;
    String? expiry;
    String? holder;

    final RegExp cardRegex = RegExp(r'\d{4}\s\d{4}\s\d{4}\s\d{4}');
    final RegExp expiryRegex = RegExp(r'\d{2}/\d{2}');

    // Sort blocks by position (roughly)
    text.blocks.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    for (var block in text.blocks) {
      final txt = block.text;

      // Detect Number
      if (number == null && cardRegex.hasMatch(txt)) {
        number = cardRegex.firstMatch(txt)?.group(0);
      }

      // Detect Expiry
      if (expiry == null && expiryRegex.hasMatch(txt)) {
        // Basic check for valid date logic if needed
        expiry = expiryRegex.firstMatch(txt)?.group(0);
      }

      // Heuristic for Holder: Uppercase line that isn't date or number and has length
      if (holder == null &&
          number != txt &&
          !txt.contains(RegExp(r'\d')) &&
          txt.length > 5 &&
          txt == txt.toUpperCase()) {
        holder = txt;
      }
    }

    if (number != null) {
      return {'number': number, 'expiry': expiry, 'holder': holder};
    }

    return {'number': null};
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
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

          // Overlay
          Container(
            decoration: ShapeDecoration(
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
                      Text(
                        _statusText,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  context.t('align_card_instruction'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 50),
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
