import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'ble_screen.dart';

class SelectionScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const SelectionScreen({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bus Navigator - Choose Method')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'How would you like to detect buses?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt, size: 30),
              label: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Camera OCR', style: TextStyle(fontSize: 18)),
                    Text('Point camera at bus number', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(250, 80),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.bluetooth_searching, size: 30),
              label: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('BLE Scanner', style: TextStyle(fontSize: 18)),
                    Text('Detect nearby bus signals', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(250, 80),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BleScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
