import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool continuous;
  final Function(String)? onScan;

  const BarcodeScannerScreen({
    super.key,
    this.continuous = false,
    this.onScan,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animationController;
  late Animation<double> _laserAnimation;

  bool _isFlashOn = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  String? _notificationText;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    final now = DateTime.now();

    if (widget.continuous) {
      // Throttle scans for the same code or very rapid scans (1.5 seconds)
      if (_lastScannedCode == code &&
          _lastScanTime != null &&
          now.difference(_lastScanTime!).inMilliseconds < 1500) {
        return;
      }

      _lastScannedCode = code;
      _lastScanTime = now;

      HapticFeedback.mediumImpact();

      // Trigger callback
      if (widget.onScan != null) {
        widget.onScan!(code);
      }

      // Show temporary screen notification
      setState(() {
        _notificationText = "Escaneado: $code";
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _notificationText == "Escaneado: $code") {
          setState(() {
            _notificationText = null;
          });
        }
      });
    } else {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Scanner View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Dark Overlay with Cutout Scan Window
          _buildScannerOverlay(context, scanWindowSize),

          // 3. Header Actions (Back & Flash)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    widget.continuous ? 'Modo Escáner Continuo' : 'Escanear Código',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        _controller.toggleTorch();
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Notification / Success Toast
          if (_notificationText != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _notificationText != null ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _notificationText!,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Instruction text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.continuous
                      ? 'Escanea múltiples productos uno tras otro'
                      : 'Alinea el código de barras dentro del recuadro',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context, double scanWindowSize) {
    final size = MediaQuery.of(context).size;
    final topOffset = (size.height - scanWindowSize) / 2;
    final leftOffset = (size.width - scanWindowSize) / 2;

    return Stack(
      children: [
        // Top shadow
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topOffset,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        // Bottom shadow
        Positioned(
          top: topOffset + scanWindowSize,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        // Left shadow
        Positioned(
          top: topOffset,
          left: 0,
          width: leftOffset,
          height: scanWindowSize,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        // Right shadow
        Positioned(
          top: topOffset,
          left: leftOffset + scanWindowSize,
          right: 0,
          height: scanWindowSize,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),

        // Scanning Window Box
        Positioned(
          top: topOffset,
          left: leftOffset,
          width: scanWindowSize,
          height: scanWindowSize,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner brackets (optional/custom)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(width: 20, height: 2, color: Colors.blue),
                ),
                // Laser animation line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _laserAnimation.value * (scanWindowSize - 20) + 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
