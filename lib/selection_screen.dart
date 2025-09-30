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
      appBar: AppBar(title: Text('Choose Scan Method')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text('Camera OCR Scanning'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(cameras: cameras),
                  ),
                );
              },
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.bluetooth_searching),
              label: Text('BLE Scanning'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BleScreen()),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('BLE Scanning not implemented yet')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
