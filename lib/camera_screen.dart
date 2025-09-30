import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  final FlutterTts _tts = FlutterTts();
  final textRecognizer = TextRecognizer();
  String detectedText = '';

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("en-IN");
    _initCamera();
  }

  InputImageRotation rotationFromInt(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller.initialize();
    await _controller.setFocusMode(FocusMode.auto);
    await _controller.setExposureMode(ExposureMode.auto);
    await _controller.setFlashMode(FlashMode.off); // Better for paper scanning

    if (!mounted) return;
    setState(() => _isCameraReady = true);
    _controller.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      if (image.planes.isEmpty) {
        _isProcessing = false;
        return;
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (var plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = rotationFromInt(widget.cameras[0].sensorOrientation);
      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      if (format == null) {
        _isProcessing = false;
        return;
      }

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final recognizedText = await textRecognizer.processImage(inputImage);

      print('📝 Processing image: ${image.width}x${image.height}');

      for (TextBlock block in recognizedText.blocks) {
        String cleanText = block.text
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .toUpperCase();

        print('📝 Original text: "${block.text}"');
        print('🔍 Cleaned text: "$cleanText"');
        print('📏 Text height: ${block.boundingBox.height}');

        // Process both full text and individual words
        List<String> textsToCheck = [cleanText, ...cleanText.split(' ')];

        for (String text in textsToCheck) {
          if (_looksLikeBusNumber(text)) {
            double confidence = _getConfidence(block);

            if (text != detectedText && confidence >= 0.2) {
              // Lowered threshold
              setState(() {
                detectedText = text;
              });
              await _tts.speak("Detected bus number $text");
              print('✅ Found bus number: $text (Confidence: $confidence)');
              break;
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('Stack trace: $stackTrace');
    }

    await Future.delayed(Duration(milliseconds: 200)); // Faster processing
    _isProcessing = false;
  }

  double _getConfidence(TextBlock block) {
    double confidence = 0.0;

    // Size-based confidence
    double height = block.boundingBox.height;
    confidence += (height > 20 ? 0.5 : 0.3); // Adjusted thresholds

    // Text properties confidence
    String text = block.text.trim();
    confidence += (text.length >= 3 ? 0.3 : 0.1);
    confidence += (RegExp(r'\d').hasMatch(text) ? 0.2 : 0);

    return confidence;
  }

  bool _looksLikeBusNumber(String text) {
    if (text.isEmpty) return false;

    // Clean the text more aggressively
    text = text.replaceAll(RegExp(r'[^0-9A-Z]'), '').trim().toUpperCase();
    print('🔍 Cleaned text: "$text"'); // Debug print

    // Simplified pattern specifically for city bus numbers
    final cityBusRegex = RegExp(r'^\d{2,3}[A-Z]$', caseSensitive: false);
    bool isCityBus = cityBusRegex.hasMatch(text);

    print('🚌 City bus check: "$text" => $isCityBus'); // Debug print
    return isCityBus;
  }

  @override
  void dispose() {
    _controller.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraReady
          ? Stack(
              children: [
                CameraPreview(_controller),

                // Focus box
                Center(
                  child: Container(
                    height: 150,
                    width: 300, // Made wider for better bus number capture
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.yellow,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // Text display with orientation guidance
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detectedText.isEmpty
                                ? 'Waiting for text...'
                                : 'Detected: $detectedText',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '📱 Hold phone vertically and keep text horizontal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.yellow,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
