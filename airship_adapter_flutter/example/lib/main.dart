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

    // Listen for logs/events from native-adapters
    AirshipAdapterFlutter.events.listen((event) {
      setState(() {
        _logs.insert(0, event.toString()); // newest at top
      });
    });

    _initializePlugin();

  }

  Future<void> _requestPermissions() async {
    var locationWhenInUse = await Permission.locationWhenInUse.request();
    var locationAlways = await Permission.locationAlways.request();

    var bluetoothScan = await Permission.bluetoothScan.request();
    var bluetoothConnect = await Permission.bluetoothConnect.request();

    // Notifications (for Airship push)
    var notification = await Permission.notification.request();
  }

  Future<void> _initializePlugin() async {
    try {
      await _requestPermissions();
      
      
      await AirshipAdapterFlutter.configure(
        airshipAppKey: '<AIRSHIP_APP_KEY>',
        airshipAppSecret: '<AIRSHIP_APP_SECRET>',
        gimbalApiKeyAndroid: '<GIMBAL_API_KEY_ANDROID>',
        gimbalApiKeyIOS: '<GIMBAL_API_KEY_IOS>',
      );

      await AirshipAdapterFlutter.start();
      
    } catch (e) {
      if (e.toString().contains("Exception")) {
        print(" This is an exception - check the error details above");
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