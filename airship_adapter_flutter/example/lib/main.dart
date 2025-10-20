import 'package:flutter/material.dart';
import 'package:airship_adapter_flutter/airship_adapter_flutter.dart';
import 'package:permission_handler/permission_handler.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();

    // Listen for logs/events from native
    AirshipAdapterFlutter.events.listen((event) {
      setState(() {
        _logs.insert(0, event.toString()); // newest at top
      });
    });

    _initializePlugin();

  }

  Future<void> _requestPermissions() async {
    print("🔐 Requesting permissions...");
    
    // Location (needed for Gimbal)
    print("📍 Requesting location permissions...");
    var locationWhenInUse = await Permission.locationWhenInUse.request();
    var locationAlways = await Permission.locationAlways.request();
    print("📍 Location permissions: $locationWhenInUse, $locationAlways");

    // Bluetooth (for beacons)
    print("📶 Requesting Bluetooth permissions...");
    var bluetoothScan = await Permission.bluetoothScan.request();
    var bluetoothConnect = await Permission.bluetoothConnect.request();
    print("📶 Bluetooth permissions: $bluetoothScan, $bluetoothConnect");

    // Notifications (for Airship push)
    print("🔔 Requesting notification permissions...");
    var notification = await Permission.notification.request();
    print("🔔 Notification permission: $notification");
    
    print("✅ All permissions requested");
  }

  Future<void> _initializePlugin() async {
    try {
      print("🚀 Starting plugin initialization...");
      
      // FIRST: Wait for permissions to be granted
      print("⏳ Step 1: Requesting permissions...");
      await _requestPermissions();
      print("✅ Step 1: Permissions completed");
      
      // SECOND: Configure plugin only after permissions are granted
      print("⏳ Step 2: Configuring Airship + Gimbal...");
      print("🔧 Airship App Key: 1hElLCRwSFOZnSUNiZAofg");
      print("🔧 Gimbal API Key (Android): 236e4e22-e1b4-4cc2-b836-1c978d0c39e1");
      print("🔧 Gimbal API Key (iOS): 0a5fd536-7bd5-4e8e-bd59-2f5e192edf5b");
      
      await AirshipAdapterFlutter.configure(
        airshipAppKey: '1hElLCRwSFOZnSUNiZAofg',
        airshipAppSecret: 'i9pXIcsbQmGfdZH2w9AShQ',
        gimbalApiKeyAndroid: '236e4e22-e1b4-4cc2-b836-1c978d0c39e1',
        gimbalApiKeyIOS: '0a5fd536-7bd5-4e8e-bd59-2f5e192edf5b',
      );
      
      print("✅ Step 2: Configuration completed");

      // THIRD: Start the plugin only after configuration
      print("⏳ Step 3: Starting tracking...");
      await AirshipAdapterFlutter.start();
      print("✅ Step 3: Tracking started");

      print("🎉 Plugin initialized and started successfully!");
      print("📱 Now listening for location events...");
      
    } catch (e) {
      print("❌ Error initializing plugin: $e");
      print("❌ Error type: ${e.runtimeType}");
      if (e.toString().contains("Exception")) {
        print("❌ This is an exception - check the error details above");
      }
    }
  }

  Color _getEventColor(String log) {
    if (log.toLowerCase().contains("enter")) return Colors.green;
    if (log.toLowerCase().contains("exit")) return Colors.red;
    return Colors.grey.shade800;
  }

  IconData _getEventIcon(String log) {
    if (log.toLowerCase().contains("enter")) return Icons.login;
    if (log.toLowerCase().contains("exit")) return Icons.logout;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Airship + Gimbal Events")),
        body: ListView.builder(
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            return ListTile(
              leading: Icon(
                _getEventIcon(log),
                color: _getEventColor(log),
              ),
              title: Text(
                log,
                style: TextStyle(
                  color: _getEventColor(log),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}