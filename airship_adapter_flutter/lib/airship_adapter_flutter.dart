
import 'dart:async';
import 'package:flutter/services.dart';

class AirshipAdapterFlutter {
  static const MethodChannel _methodChannel =
  MethodChannel("airship_adapter_flutter/methods");

  static const EventChannel _eventChannel =
  EventChannel("airship_adapter_flutter/events");

  /// Configure Airship + Gimbal
  /// 
  /// [inProduction] determines which Airship environment to use:
  /// - `false` (default): Uses development environment
  /// - `true`: Uses production environment
  /// 
  /// When [inProduction] is true, ensure you pass production app keys.
  /// When [inProduction] is false, ensure you pass development app keys.
  /// 
  /// [enableDebugLogging] enables verbose debug logging from Gimbal SDK.
  /// Set to `false` in production for better performance and privacy.
  /// 
  /// Throws [ArgumentError] if API keys are null or empty.
  /// Throws [PlatformException] if native configuration fails.
  static Future<void> configure({
    required String airshipAppKey,
    required String airshipAppSecret,
    String? gimbalApiKeyAndroid,
    String? gimbalApiKeyIOS,
    bool inProduction = false,
    bool enableDebugLogging = false,
  }) async {
    // Validate required arguments
    if (airshipAppKey.trim().isEmpty) {
      throw ArgumentError.value(airshipAppKey, 'airshipAppKey', 'Cannot be null or empty');
    }
    if (airshipAppSecret.trim().isEmpty) {
      throw ArgumentError.value(airshipAppSecret, 'airshipAppSecret', 'Cannot be null or empty');
    }
    
    // Validate optional Gimbal keys if provided
    if (gimbalApiKeyAndroid != null && gimbalApiKeyAndroid.trim().isEmpty) {
      throw ArgumentError.value(gimbalApiKeyAndroid, 'gimbalApiKeyAndroid', 'Cannot be empty string. Omit the parameter if not using Gimbal on Android.');
    }
    if (gimbalApiKeyIOS != null && gimbalApiKeyIOS.trim().isEmpty) {
      throw ArgumentError.value(gimbalApiKeyIOS, 'gimbalApiKeyIOS', 'Cannot be empty string. Omit the parameter if not using Gimbal on iOS.');
    }

    final Map<String, dynamic> args = {
      "airshipAppKey": airshipAppKey.trim(),
      "airshipAppSecret": airshipAppSecret.trim(),
      "inProduction": inProduction,
      "enableDebugLogging": enableDebugLogging,
    };
    if (gimbalApiKeyAndroid != null) args["gimbalApiKeyAndroid"] = gimbalApiKeyAndroid.trim();
    if (gimbalApiKeyIOS != null) args["gimbalApiKeyIOS"] = gimbalApiKeyIOS.trim();

    try {
      await _methodChannel.invokeMethod("configure", args);
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Failed to configure Airship adapter',
        details: e.details,
      );
    }
  }

  /// Request location permissions (iOS only)
  /// 
  /// This method requests "Always" location authorization which is required
  /// for Gimbal to work properly in the background.
  /// 
  /// On Android, use permission_handler package to request permissions.
  /// 
  /// Throws [PlatformException] if native request fails.
  static Future<void> requestLocationPermissions() async {
    try {
      await _methodChannel.invokeMethod("requestLocationPermissions");
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Failed to request location permissions',
        details: e.details,
      );
    }
  }

  /// Start SDKs
  /// 
  /// Throws [PlatformException] if native start fails.
  static Future<void> start() async {
    try {
      await _methodChannel.invokeMethod("start");
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Failed to start Airship adapter',
        details: e.details,
      );
    }
  }

  /// Stop SDKs
  /// 
  /// Throws [PlatformException] if native stop fails.
  static Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod("stop");
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Failed to stop Airship adapter',
        details: e.details,
      );
    }
  }

  /// Restart SDKs (stop then start). Intended for dev/testing to reattach listeners.
  /// 
  /// Throws [PlatformException] if native restart fails.
  static Future<void> restart() async {
    try {
      await _methodChannel.invokeMethod("restart");
      await _methodChannel.invokeMethod("start");
    } on PlatformException catch (e) {
      throw PlatformException(
        code: e.code,
        message: e.message ?? 'Failed to restart Airship adapter',
        details: e.details,
      );
    }
  }

  /// Stream of log + event updates
  static Stream<String> get events =>
      _eventChannel.receiveBroadcastStream().map((e) => e as String);
}
