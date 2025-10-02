import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class BleScreen extends StatefulWidget {
  @override
  _BleScreenState createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  List<ScanResult> scanResults = [];
  List<ScanResult> busDevices = []; // Filtered bus devices only
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  Timer? scanTimer;
  int scanTimeRemaining = 0; // Countdown timer for scan
  static const int SCAN_DURATION = 60; // Scan duration in seconds

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    scanTimer?.cancel(); // Clean up timer
    if (isScanning) {
      FlutterBluePlus.stopScan();
    }
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Request necessary permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    print("Permission statuses: $statuses");
  }

  Future<void> _startScan() async {
    // Check if Bluetooth is available
    if (await FlutterBluePlus.isAvailable == false) {
      _showSnackbar("Bluetooth not available on this device");
      return;
    }

    // Check if Bluetooth is turned on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _showSnackbar("Please turn on Bluetooth");
      return;
    }

    setState(() {
      scanResults.clear();
      isScanning = true;
      scanTimeRemaining = SCAN_DURATION; // Start countdown
    });

    // Start countdown timer
    scanTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        scanTimeRemaining--;
        if (scanTimeRemaining <= 0) {
          timer.cancel();
          _stopScan();
        }
      });
    });

    print("🔍 Starting BLE scan for ${SCAN_DURATION}s to detect nearby buses...");

    try {
      // Start scanning with more aggressive parameters for advertisements
      await FlutterBluePlus.startScan(
        timeout: Duration(
            seconds:
                SCAN_DURATION), // Extended timeout for better bus detection
        androidUsesFineLocation: true,
        withServices: [], // Scan for all services
        withRemoteIds: [], // Scan for all device IDs
      );

      print(
          "✅ Scan started successfully - looking for ALL BLE advertisements including nRF Connect");

      // Listen to scan results
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        print("📡 Found ${results.length} total devices");
        setState(() {
          scanResults = results;
          busDevices = _filterBusDevices(results); // Filter for buses only
        });

        // No longer announce new buses - screen reader will handle it

        // Log each device found with detailed info
        for (var result in results) {
          var isBusDevice = _isBusDevice(result);

          print(
              "🎯 Device: ${result.device.platformName.isEmpty ? 'Unknown' : result.device.platformName}");
          print("   ID: ${result.device.remoteId}");
          print("   RSSI: ${result.rssi}");
          print("   Local Name: '${result.advertisementData.localName}'");
          print("   Is Bus Device: $isBusDevice");

          if (isBusDevice) {
            print("🚌 BUS DETECTED: ${_getBusNumber(result)}");
          }
          print("   ---");
        }
      });

      // Stop scanning after extended timeout
      Future.delayed(Duration(seconds: SCAN_DURATION), () {
        _stopScan();
      });
    } catch (e) {
      print("❌ Scan error: $e");
      _showSnackbar("Scan error: $e");
      setState(() {
        isScanning = false;
      });
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    scanTimer?.cancel(); // Cancel countdown timer
    setState(() {
      isScanning = false;
      scanTimeRemaining = 0;
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Device Scanner'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Header section
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                  size: 60,
                  color: isScanning ? Colors.blue : Colors.grey,
                ),
                SizedBox(height: 10),
                Text(
                  isScanning
                      ? 'Scanning for buses... (${scanTimeRemaining}s remaining)'
                      : 'Ready to scan for buses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: isScanning ? _stopScan : _startScan,
                  child: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isScanning ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Results section
          Expanded(
            child: busDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isScanning ? Icons.search : Icons.directions_bus,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          isScanning
                              ? 'Searching for buses...'
                              : 'No buses detected.\nPress "Start Scan" to look for buses.',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        if (scanResults.isNotEmpty && busDevices.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Found ${scanResults.length} devices, but none are buses',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Bus count header
                      Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.green[50],
                        child: Row(
                          children: [
                            Icon(Icons.directions_bus, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Buses Detected: ${busDevices.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bus list
                      Expanded(
                        child: ListView.builder(
                          itemCount: busDevices.length,
                          itemBuilder: (context, index) {
                            final result = busDevices[index];
                            final busNumber = _getBusNumber(result);
                            final rssi = result.rssi;

                            return Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              color: Colors.green[50],
                              child: Semantics(
                                label:
                                    'Bus $busNumber, signal strength ${_getRSSIStrength(rssi)}, status ${_getBusStatus(rssi)}',
                                hint:
                                    'Tap to open Google Maps and find Bus $busNumber stops near you',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.directions_bus,
                                    color: Colors.green,
                                    size: 32,
                                  ),
                                  title: Text(
                                    'Bus $busNumber',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Signal: $rssi dBm'),
                                      Text('Status: ${_getBusStatus(rssi)}'),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.map,
                                              size: 16, color: Colors.blue),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap for bus stops',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getRSSIColor(rssi),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getRSSIStrength(rssi),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  onTap: () async {
                                    // Auto-intelligent system: One tap → Complete navigation
                                    await _openBusStopsInMaps(busNumber);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // Footer info - Bus count only
          Container(
            padding: EdgeInsets.all(8),
            child: Center(
              child: Text(
                'Buses Found: ${busDevices.length}',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRSSIColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  String _getRSSIStrength(int rssi) {
    if (rssi > -50) return 'Strong';
    if (rssi > -70) return 'Medium';
    return 'Weak';
  }

  // Bus Detection Methods
  bool _isBusDevice(ScanResult result) {
    String deviceName =
        _getBestDeviceName(result.device, result.advertisementData);
    String localName = result.advertisementData.localName;

    // Simple bus number patterns: 60A, 123B, 61A, etc.
    // Matches: numbers followed by optional letter, or letter followed by numbers
    RegExp busPattern =
        RegExp(r'^[0-9]+[A-Z]?$|^[A-Z]?[0-9]+$', caseSensitive: false);

    return busPattern.hasMatch(deviceName) ||
        busPattern.hasMatch(localName) ||
        result.advertisementData.manufacturerData.containsKey(4660);
  }

  List<ScanResult> _filterBusDevices(List<ScanResult> allResults) {
    return allResults.where((result) => _isBusDevice(result)).toList();
  }

  String _getBusNumber(ScanResult result) {
    // Use the full Bluetooth device name as the bus identifier
    String deviceName =
        _getBestDeviceName(result.device, result.advertisementData);

    // Return the complete device name (e.g., "Bus 60A", "60A", etc.)
    if (deviceName.isNotEmpty) {
      return deviceName;
    }

    // Fallback to local name if device name is empty
    if (result.advertisementData.localName.isNotEmpty) {
      return result.advertisementData.localName;
    }

    // Last resort fallback
    return "Unknown Bus";
  }

  String _getBusStatus(int rssi) {
    if (rssi > -50) return 'Very Close';
    if (rssi > -70) return 'Approaching';
    return 'Far Away';
  }

  // Direct Google Maps integration - simple and effective
  Future<void> _openBusStopsInMaps(String busNumber) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Opening Google Maps for Bus $busNumber...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Get current location
      Position? position = await _getCurrentLocation(busNumber);

      if (position == null) {
        // Location dialog will handle the error
        return;
      }

      // Create Google Maps URL for BUS/TRANSIT mode with current location
      String searchQuery = Uri.encodeComponent('Bus $busNumber');

      // Try multiple URL formats for better compatibility
      final urls = [
        // Format 1: Google Maps app with transit directions
        'google.navigation:q=bus+route+$busNumber&mode=transit',
        // Format 2: Simple Google Maps search with location
        'https://maps.google.com/maps?q=bus+route+$busNumber&center=${position.latitude},${position.longitude}',
        // Format 3: Original Google Maps API URL
        'https://www.google.com/maps/search/?api=1&query=$searchQuery&center=${position.latitude},${position.longitude}&zoom=15&travelmode=transit&dirflg=r',
        // Format 4: Geo URI with location
        'geo:${position.latitude},${position.longitude}?q=bus+route+$busNumber',
      ];

      print(
          "🗺️ Opening Google Maps in TRANSIT mode for Bus $busNumber at location: ${position.latitude}, ${position.longitude}");

      // Try to launch Google Maps with different URL formats
      bool opened = false;
      
      for (final urlString in urls) {
        try {
          final url = Uri.parse(urlString);
          print('🔗 Trying to open: $urlString');
          
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            opened = true;
            print('✅ Successfully opened Maps with: $urlString');
            break;
          } else {
            print('❌ Cannot launch: $urlString');
          }
        } catch (e) {
          print('❌ Error with URL $urlString: $e');
          continue;
        }
      }

      if (opened) {
        print("🗺️ Opened Google Maps for Bus $busNumber");

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opened Google Maps Transit for Bus $busNumber'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print("❌ All Google Maps URLs failed");
        _showSimpleMapsFallback(busNumber, position);
      }
    } catch (e) {
      print("❌ Error opening maps: $e");
      _showError('Error opening maps: $e');
    }
  }

  void _showSimpleMapsFallback(String busNumber, Position position) {
    String coords =
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    String searchText = 'Bus $busNumber stops near $coords';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Google Maps Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please search for:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              SelectableText(searchText, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text('Your location: $coords'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Position?> _getCurrentLocation(String busNumber) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show option to open location settings
        _showLocationServiceDialog(busNumber);
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDialog(busNumber);
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDialog(busNumber);
        return null;
      }

      // Try to get position with different accuracy levels
      Position? position;

      try {
        // Try high accuracy first
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        );
      } catch (e) {
        print("High accuracy failed, trying medium accuracy...");
        try {
          // Fallback to medium accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          );
        } catch (e) {
          print("Medium accuracy failed, trying low accuracy...");
          // Final fallback to low accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          );
        }
      }

      print("📍 Location: ${position.latitude}, ${position.longitude}");
      return position;
    } catch (e) {
      print("❌ Location error: $e");
      _showLocationErrorDialog(busNumber: busNumber);
      return null;
    }
  }

  void _showLocationServiceDialog(String busNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Services Disabled'),
          content: Text(
              'Please enable location services in your device settings to find nearby bus stops.'),
          actions: [
            TextButton(
              child: Text('Open Without Location'),
              onPressed: () {
                Navigator.of(context).pop();
                _openMapsWithoutLocation(busNumber);
              },
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDialog(String busNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Needed'),
          content: Text(
              'This app needs location permission to find nearby bus stops. Please grant permission in settings.'),
          actions: [
            TextButton(
              child: Text('Open Without Location'),
              onPressed: () {
                Navigator.of(context).pop();
                _openMapsWithoutLocation(busNumber);
              },
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLocationErrorDialog({required String busNumber}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Error'),
          content: Text(
              'Unable to get your current location. You can still search for Bus $busNumber stops manually.'),
          actions: [
            TextButton(
              child: Text('Search Manually'),
              onPressed: () {
                Navigator.of(context).pop();
                _openMapsWithoutLocation(busNumber);
              },
            ),
            TextButton(
              child: Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _openBusStopsInMaps(busNumber);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMapsWithoutLocation(String busNumber) async {
    try {
      // Search for bus stops without specific location
      String searchQuery = 'Bus $busNumber stops';
      String googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$searchQuery';

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl),
            mode: LaunchMode.platformDefault);
        print("🗺️ Opened Google Maps for Bus $busNumber (no location)");
        _showError('Opened Google Maps for Bus $busNumber stops');
      } else {
        _showError(
            'Unable to open maps. Please install Google Maps or search manually for "Bus $busNumber stops".');
      }
    } catch (e) {
      _showError(
          'Error opening maps: $e. Please search manually for "Bus $busNumber stops".');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _getBestDeviceName(
      BluetoothDevice device, AdvertisementData advertisementData) {
    // Try to get the best available name from multiple sources

    // 1. Check advertisement local name first (most reliable)
    if (advertisementData.localName.isNotEmpty) {
      return advertisementData.localName;
    }

    // 2. Check platform name (device name from OS)
    if (device.platformName.isNotEmpty) {
      return device.platformName;
    }

    // 3. Try to identify by manufacturer data
    if (advertisementData.manufacturerData.isNotEmpty) {
      // Common manufacturer IDs
      Map<int, String> manufacturers = {
        76: 'Apple',
        117: 'Samsung',
        6: 'Microsoft',
        15: 'Broadcom',
        224: 'Google',
        89: 'Qualcomm',
        13: 'Texas Instruments',
      };

      int? manufacturerId = advertisementData.manufacturerData.keys.first;
      if (manufacturers.containsKey(manufacturerId)) {
        return '${manufacturers[manufacturerId]} Device';
      } else {
        return 'Device (MFG: $manufacturerId)';
      }
    }

    // 4. Check service UUIDs for known services
    if (advertisementData.serviceUuids.isNotEmpty) {
      String uuid =
          advertisementData.serviceUuids.first.toString().toUpperCase();
      Map<String, String> knownServices = {
        '180F': 'Battery Service Device',
        '180A': 'Device Information Service',
        '1800': 'Generic Access Device',
        '1801': 'Generic Attribute Device',
        '110B': 'Audio Sink Device',
        '110E': 'A/V Remote Control Device',
        '1108': 'Headset Device',
        '111E': 'Hands-Free Device',
      };

      for (String serviceId in knownServices.keys) {
        if (uuid.contains(serviceId)) {
          return knownServices[serviceId]!;
        }
      }

      return 'BLE Device (Service)';
    }

    // 5. Fallback to unknown
    return 'Unknown Device';
  }
}
