
import 'dart:async';
import 'package:flutter/services.dart';

class AirshipAdapterFlutter {
  static const MethodChannel _methodChannel =
  MethodChannel("airship_adapter_flutter/methods");

  static const EventChannel _eventChannel =
  EventChannel("airship_adapter_flutter/events");

  /// Configure Airship + Gimbal
  static Future<void> configure({
    required String airshipAppKey,
    required String airshipAppSecret,
    String? gimbalApiKeyAndroid,
    String? gimbalApiKeyIOS,
  }) async {
    final Map<String, dynamic> args = {
      "airshipAppKey": airshipAppKey,
      "airshipAppSecret": airshipAppSecret,
    };
    if (gimbalApiKeyAndroid != null) args["gimbalApiKeyAndroid"] = gimbalApiKeyAndroid;
    if (gimbalApiKeyIOS != null) args["gimbalApiKeyIOS"] = gimbalApiKeyIOS;

    await _methodChannel.invokeMethod("configure", args);
  }

  /// Start SDKs
  static Future<void> start() async {
    await _methodChannel.invokeMethod("start");
  }

  /// Stop SDKs
  static Future<void> stop() async {
    await _methodChannel.invokeMethod("stop");
  }

  /// Restart SDKs (stop then start). Intended for dev/testing to reattach listeners.
  static Future<void> restart() async {
    await _methodChannel.invokeMethod("restart");
    await _methodChannel.invokeMethod("start");
  }

  /// Stream of log + event updates
  static Stream<String> get events =>
      _eventChannel.receiveBroadcastStream().map((e) => e as String);
}
