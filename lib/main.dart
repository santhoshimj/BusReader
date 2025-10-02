import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'selection_screen.dart'; // <-- Add this import

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(MyApp());
}

class UserIdManager {
  static const String _userIdKey = 'user_id';

  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);

    if (userId == null) {
      userId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_userIdKey, userId);
      print('Generated new User ID: $userId');
    } else {
      print('Retrieved existing User ID: $userId');
    }

    return userId;
  }
}

Future<void> requestPermissions() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.location,
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Navigator',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: WelcomeScreen(cameras: _cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const WelcomeScreen({required this.cameras});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? userId;

  @override
  void initState() {
    super.initState();
    loadUserId(); // Load UID on screen startup
  }

  void loadUserId() async {
    final id = await UserIdManager.getOrCreateUserId();
    setState(() => userId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus, size: 100, color: Colors.deepPurple),
              SizedBox(height: 30),
              Text(
                'Welcome to BusReader',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Helping the visually impaired detect bus numbers easily!',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  await requestPermissions();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectionScreen(
                          cameras: widget.cameras), // <-- Changed here
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.deepPurple,
                ),
                child: Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
              if (userId != null) ...[
                Text('Your ID:', style: TextStyle(color: Colors.black87)),
                SizedBox(height: 4),
                Text(
                  userId!,
                  style: TextStyle(fontSize: 14, color: Colors.deepPurple),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
