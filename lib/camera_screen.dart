import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  TextRecognizer textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  String _detectedText = '';
  String _statusMessage = 'Point camera at bus number';
  Timer? _processingTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      _cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.high, // Higher resolution for better text detection
        // Force JPEG format - this is crucial for ML Kit compatibility
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      
      // Turn OFF flash - it can interfere with text detection
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
        print('✅ Flash turned OFF for better text detection');
      } catch (e) {
        print('Flash control not available: $e');
      }
      
      // Start processing every 1 second for INSTANT detection
      _processingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!_isProcessing && _cameraController!.value.isInitialized) {
          _captureAndProcessImage();
        }
      });
      
      setState(() {
        _statusMessage = 'Camera ready - looking for bus numbers';
      });
      
    } catch (e) {
      print('❌ Camera initialization error: $e');
      setState(() {
        _statusMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      _isProcessing = true;
      setState(() {
        _statusMessage = '📸 Processing image...';
      });
      
      // Take a picture and save to file
      final XFile image = await _cameraController!.takePicture();
      
      print('📸 Captured image: ${image.path}');
      
      // Create InputImage from the file path
      final inputImage = InputImage.fromFilePath(image.path);
      
      print('🔍 Starting text recognition...');
      
      // Process with ML Kit Text Recognition
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      print('📝 Recognition complete!');
      print('📊 Found ${recognizedText.blocks.length} text blocks');
      print('📄 Full text: "${recognizedText.text}"');
      
      // Update UI with results
      setState(() {
        _detectedText = recognizedText.text;
        if (recognizedText.text.isEmpty) {
          _statusMessage = 'No text detected - try different angle';
        } else {
          _statusMessage = '📝 Analyzing detected text...';
        }
      });
      
      // Look for bus numbers in the detected text
      if (recognizedText.text.isNotEmpty) {
        _checkForBusNumbers(recognizedText.text);
      }
      
    } catch (e) {
      print('❌ Processing error: $e');
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      _isProcessing = false;
    }
  }

  void _checkForBusNumbers(String text) {
    print('🔍 Checking text for bus numbers: "$text"');
    
    // Split text into lines for better context analysis
    final lines = text.split('\n');
    
    // Look for bus numbers, allowing some surrounding text but not long sentences
    for (final line in lines) {
      final cleanLine = line.trim();
      
      // Skip very long lines (likely documents/screens/paragraphs)
      if (cleanLine.length > 50) {
        print('⏭️ Skipping very long line: "$cleanLine"');
        continue;
      }
      
      // Skip lines that look like full sentences or documentation
      if (_looksLikeFullSentence(cleanLine)) {
        print('⏭️ Skipping sentence-like text: "$cleanLine"');
        continue;
      }
      
      // Look for bus number patterns in the line
      final patterns = [
        RegExp(r'\b\d{2,3}[A-Z]\b', caseSensitive: false), // 60A, 123B
        RegExp(r'\b\d{2,3}\b'), // 60, 123 (only 2-3 digits)
        RegExp(r'\b[A-Z]\d{2,3}\b', caseSensitive: false), // A60, B123
      ];
      
      for (final pattern in patterns) {
        final matches = pattern.allMatches(cleanLine);
        for (final match in matches) {
          final busNumber = match.group(0)!.toUpperCase();
          print('🚌 Found bus number: "$busNumber" in line: "$cleanLine"');
          
          if (_looksLikeBusNumber(busNumber)) {
            print('✅ Valid bus number: $busNumber');
            _openGoogleMaps(busNumber);
            return;
          }
        }
      }
    }
    
    setState(() {
      _statusMessage = '📱 Scanning for bus numbers...';
    });
  }

  bool _looksLikeFullSentence(String text) {
    // Check for sentence indicators
    final sentenceIndicators = [
      'here are', 'you can', 'use any', 'for example', 'e.g.', 'i.e.',
      'such as', 'let me know', 'if you want', 'this is', 'that is',
      'example', 'sample', 'test', 'demo', 'some of', 'any of these',
      'device name when', 'printed/written', 'terminal or', 'setting',
      'update dataspace', 'process', 'capture request'
    ];
    
    final lowerText = text.toLowerCase();
    
    // Check if it contains multiple sentence indicators or is very wordy
    int indicatorCount = sentenceIndicators.where((indicator) => 
        lowerText.contains(indicator)).length;
    
    if (indicatorCount >= 2) return true;
    
    // Check for lists or bullet points with multiple items
    if (text.contains('•') && text.split('•').length > 2) return true;
    
    // Check for multiple words that suggest documentation
    final wordCount = text.split(' ').length;
    if (wordCount > 8) return true;
    
    return false;
  }

  bool _looksLikeBusNumber(String text) {
    text = text.trim().toUpperCase();
    
    // Length check - bus numbers are typically 1-4 characters
    if (text.length < 1 || text.length > 4) return false;
    
    // Exclude obvious non-bus numbers
    final excludePatterns = [
      '0', '00', '000', // Just zeros
      '1', '2', '3', '4', '5', '6', '7', '8', '9', // Single digits (too generic)
    ];
    
    if (excludePatterns.contains(text)) {
      print('⏭️ Excluding too generic: $text');
      return false;
    }
    
    // Realistic bus number patterns
    final validPatterns = [
      RegExp(r'^\d{2,3}[A-Z]$'), // 60A, 123B (most common)
      RegExp(r'^[A-Z]\d{2,3}$'), // A60, B123 (some systems)
      RegExp(r'^\d{2,3}$'), // 60, 123 (only 2-3 digits, not single)
    ];
    
    for (final pattern in validPatterns) {
      if (pattern.hasMatch(text)) {
        // Additional validation: reasonable bus number ranges
        if (text.length >= 2) {
          final numberPart = text.replaceAll(RegExp(r'[A-Z]'), '');
          if (numberPart.isNotEmpty) {
            final number = int.tryParse(numberPart);
            if (number != null && number >= 10 && number <= 999) {
              return true;
            }
          }
        }
      }
    }
    
    return false;
  }

  Future<void> _openGoogleMaps(String busNumber) async {
    setState(() {
      _statusMessage = '🚌 Found Bus $busNumber! Opening Maps...';
    });
    
    // Try multiple URL formats for maximum compatibility
    final urls = [
      // Format 1: Simple Google Maps web search (most compatible)
      'https://www.google.com/maps/search/bus+$busNumber',
      // Format 2: Google Maps app with simple search
      'https://maps.google.com/?q=bus+$busNumber',
      // Format 3: Universal web search
      'https://www.google.com/search?q=bus+route+$busNumber+near+me',
      // Format 4: Plain geo search
      'geo:0,0?q=bus+$busNumber',
    ];
    
    bool opened = false;
    
    for (final urlString in urls) {
      try {
        final url = Uri.parse(urlString);
        print('🔗 Trying to open: $urlString');
        
        // Force external application mode for better compatibility
        await launchUrl(url, mode: LaunchMode.externalApplication);
        opened = true;
        print('✅ Successfully opened Maps with: $urlString');
        break;
      } catch (e) {
        print('❌ Error with URL $urlString: $e');
        continue;
      }
    }
    
    if (!opened) {
      // Last resort: open in web browser
      try {
        final fallbackUrl = Uri.parse('https://www.google.com/search?q=bus+route+$busNumber');
        await launchUrl(fallbackUrl, mode: LaunchMode.platformDefault);
        print('✅ Opened in web browser as fallback');
      } catch (e) {
        setState(() {
          _statusMessage = 'Found bus $busNumber but cannot open Maps - install Google Maps or browser';
        });
      }
    }
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _cameraController?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Number Scanner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera preview (full screen)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          
          // Overlay with scanning frame
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 250,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Point at bus number',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Status information at top
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_detectedText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Detected text:',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _detectedText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Manual capture button at bottom
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  FloatingActionButton.large(
                    onPressed: _isProcessing ? null : _captureAndProcessImage,
                    backgroundColor: _isProcessing ? Colors.grey : Colors.blue,
                    child: _isProcessing
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to scan manually',
                    style: TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
