import 'package:flutter/material.dart';

class BleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Scanning'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 80, color: Colors.blue),
            SizedBox(height: 30),
            Text(
              'BLE Scanning not implemented yet',
              style: TextStyle(fontSize: 18, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'This page will scan for BLE beacons and show approaching buses.',
              style: TextStyle(fontSize: 14, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
