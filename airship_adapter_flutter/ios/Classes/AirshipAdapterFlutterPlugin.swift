import UIKit
import GimbalAirshipAdapter
import AirshipKit
import Gimbal
import Flutter
import CoreLocation

public class AirshipAdapterFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, PlaceManagerDelegate, CLLocationManagerDelegate {
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var placeManager: PlaceManager?
  private var enableDebugLogging: Bool = false
  private var isConfigured: Bool = false
  private var locationManager: CLLocationManager?

  private let eventQueue = DispatchQueue(label: "com.gimbal.airship.eventQueue", qos: .utility)

  // MARK: - Logger Helper
  private func log(_ message: String) {
      if enableDebugLogging {
          print("[AirshipAdapterFlutter] \(message)")
      }
  }
  
  // MARK: - Thread-safe Event Sending
  private func sendEvent(_ message: String) {
      eventQueue.async { [weak self] in
          guard let self = self else { return }
          DispatchQueue.main.async {
              if let sink = self.eventSink {
                  sink(message)
                  self.log("Event sent to Flutter: \(message)")
              } else {
                  self.log("WARNING: eventSink is nil when trying to send: \(message)")
              }
          }
      }
  }
  
  // MARK: - Location Permission Check
  private func checkLocationAuthorizationStatus() -> CLAuthorizationStatus {
      if locationManager == nil {
          locationManager = CLLocationManager()
          locationManager?.delegate = self
      }
      let status = locationManager?.authorizationStatus ?? .notDetermined
      let statusString: String
      
      switch status {
      case .notDetermined:
          statusString = "NOT_DETERMINED - User hasn't been asked yet"
      case .restricted:
          statusString = "RESTRICTED - Location access restricted (parental controls)"
      case .denied:
          statusString = "DENIED - User denied location access"
      case .authorizedWhenInUse:
          statusString = "AUTHORIZED_WHEN_IN_USE - Can only use location when app is in foreground"
      case .authorizedAlways:
          statusString = "AUTHORIZED_ALWAYS - Can use location in background (REQUIRED for Gimbal)"
      @unknown default:
          statusString = "UNKNOWN"
      }
      
      // Use logger instead of print
      self.log("📍 Location Authorization Status: \(statusString)")
      
      // Send status to Flutter for UI display
      if status == .authorizedAlways {
          sendEvent("Location: Authorized Always ✅")
      } else if status == .authorizedWhenInUse {
          sendEvent("Location: Authorized When In Use ⚠️ (Background location may not work)")
      } else if status == .denied {
          sendEvent("Location: DENIED ❌ (Gimbal will not work)")
      } else if status == .notDetermined {
          sendEvent("Location: Not Determined ⏳ (Request permissions first)")
      }
      
      return status
  }
  
  // MARK: - Request Location Permissions
  private func requestLocationPermissions() {
      // Ensure locationManager is created and retained
      if locationManager == nil {
          locationManager = CLLocationManager()
          locationManager?.delegate = self
          self.log("📍 Created CLLocationManager instance")
      }
      
      let currentStatus = locationManager?.authorizationStatus ?? .notDetermined
      self.log("📍 Current location status before request: \(currentStatus.rawValue)")
      
      // Always try to request "Always" authorization if not already granted
      if currentStatus != .authorizedAlways {
          if currentStatus == .notDetermined {
              // Request "Always" authorization (required for Gimbal background monitoring)
              locationManager?.requestAlwaysAuthorization()
              self.log("📍 Requested location permissions (Always) - dialog should appear")
              sendEvent("Location: Requesting permissions... (check your device)")
          } else if currentStatus == .authorizedWhenInUse {
              // Upgrade from "When In Use" to "Always"
              locationManager?.requestAlwaysAuthorization()
              self.log("📍 Requesting upgrade to Always authorization - dialog should appear")
              sendEvent("Location: Upgrading to Always authorization... (check your device)")
          } else {
              // Denied or restricted - can't request again, user must go to Settings
              self.log("📍 Location permissions denied/restricted. User must enable in Settings.")
              sendEvent("Location: DENIED - Please enable in Settings → Privacy → Location Services")
          }
      } else {
          self.log("📍 Location permissions already granted (Always)")
          sendEvent("Location: Already authorized Always ✅")
      }
  }
  
  // MARK: - Cleanup
  deinit {
      placeManager?.delegate = nil
      placeManager = nil
      log("AirshipAdapterFlutterPlugin deinitialized")
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AirshipAdapterFlutterPlugin()

    
    let methodChannel = FlutterMethodChannel(
      name: "airship_adapter_flutter/methods",
      binaryMessenger: registrar.messenger()
    )
    instance.methodChannel = methodChannel
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    // Event channel
    let eventChannel = FlutterEventChannel(
      name: "airship_adapter_flutter/events",
      binaryMessenger: registrar.messenger()
    )
    instance.eventChannel = eventChannel
    eventChannel.setStreamHandler(instance)
  }
}

extension AirshipAdapterFlutterPlugin {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    log("Event stream listener attached - eventSink set")
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    log("Event stream cancelled - eventSink cleared")
    self.eventSink = nil
    return nil
  }
}

extension AirshipAdapterFlutterPlugin {
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "configure":
      guard let args = call.arguments as? [String: Any],
            let airshipKey = args["airshipAppKey"] as? String,
            let airshipSecret = args["airshipAppSecret"] as? String else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing required arguments: airshipAppKey and airshipAppSecret are required",
          details: nil
        ))
        return
      }

      // Validate and trim API keys
      let trimmedAirshipKey = airshipKey.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedAirshipSecret = airshipSecret.trimmingCharacters(in: .whitespacesAndNewlines)
      
      if trimmedAirshipKey.isEmpty {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "airshipAppKey cannot be empty",
          details: nil
        ))
        return
      }
      
      if trimmedAirshipSecret.isEmpty {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "airshipAppSecret cannot be empty",
          details: nil
        ))
        return
      }

      let iosKey = (args["gimbalApiKeyIOS"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let gimbalKey: String
      
      // Note: Gimbal key can be empty (optional), but if provided, it should not be empty string
      if let providedKey = iosKey {
        if providedKey.isEmpty {
          result(FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "gimbalApiKeyIOS cannot be an empty string. Omit the parameter if not using Gimbal on iOS.",
            details: nil
          ))
          return
        }
        gimbalKey = providedKey
      } else {
        gimbalKey = ""
      }
      
      let inProduction = args["inProduction"] as? Bool ?? false
      self.enableDebugLogging = args["enableDebugLogging"] as? Bool ?? false

     
      var config = AirshipConfig()
      if inProduction {
          config.productionAppKey = trimmedAirshipKey
          config.productionAppSecret = trimmedAirshipSecret
      } else {
          config.developmentAppKey = trimmedAirshipKey
          config.developmentAppSecret = trimmedAirshipSecret
      }
      config.inProduction = inProduction
      

      config.urlAllowListScopeOpenURL = ["*"]
      
      
      DispatchQueue.main.async {
          do {
              try Airship.takeOff(config, launchOptions: nil)
              self.log("Airship.takeOff() completed")
              
              // Check location permissions and request if not determined
              let locationStatus = self.checkLocationAuthorizationStatus()
              if locationStatus == .notDetermined {
                  self.log("📍 Location permissions not determined - requesting automatically")
                  self.requestLocationPermissions()
              }
              
              // Set Gimbal API key FIRST (before creating PlaceManager or starting)
              Gimbal.setAPIKey(gimbalKey)
              self.log("Gimbal API key set")
              
              // Create PlaceManager and set delegate
              if self.placeManager == nil {
                  self.placeManager = PlaceManager()
                  self.placeManager?.delegate = self
                  self.log("PlaceManager created, delegate set")
              }
              
              // Configure adapter settings
              self.configureAdapterSettings()
              self.log("Adapter settings configured")
              
              // Start AirshipAdapter (this initializes the bridge, but doesn't start Gimbal yet)
              AirshipAdapter.shared.start(gimbalKey)
              self.log("AirshipAdapter.shared.start() called")
              
              // Mark as configured (but DON'T start Gimbal here - that happens in start())
              self.isConfigured = true
              
              // Restore adapter state
              AirshipAdapter.shared.restore()
              self.log("AirshipAdapter restored")
              
              self.sendEvent("iOS: AirshipAdapter configured")

              if self.enableDebugLogging {
                  Debugger.enableDebugLogging()
                  Debugger.enableBeaconSightingsLogging()
                  Debugger.enablePlaceLogging()
                  self.log("Gimbal Debugger logging enabled")
              }

              result(nil)
          } catch {
              result(FlutterError(
                code: "AIRSHIP_INIT_ERROR",
                message: "Failed to initialize Airship: \(error.localizedDescription)",
                details: nil
              ))
          }
      }

    case "requestLocationPermissions":
      DispatchQueue.main.async {
          self.log("📍 requestLocationPermissions() called from Flutter")
          self.requestLocationPermissions()
          // Don't wait for user response - it's async
          result("Location permission request initiated - check device for dialog")
      }
      break
      
    case "start":
      guard isConfigured else {
          result(FlutterError(
              code: "NOT_CONFIGURED",
              message: "Must call configure() before start()",
              details: nil
          ))
          return
      }
      
      // Check location permissions before starting
      let locationStatus = self.checkLocationAuthorizationStatus()
      
      // Warn if permissions not granted, but don't block (let user decide)
      if locationStatus == .notDetermined {
          self.log("⚠️ WARNING: Location permissions not determined. Gimbal may not work properly.")
          sendEvent("⚠️ WARNING: Location permissions not granted. Please request permissions first.")
      } else if locationStatus == .denied {
          self.log("❌ ERROR: Location permissions denied. Gimbal will not work.")
          sendEvent("❌ ERROR: Location permissions denied. Gimbal will not work.")
      } else if locationStatus == .authorizedWhenInUse {
          self.log("⚠️ WARNING: Only 'When In Use' permission granted. Background location may not work.")
          sendEvent("⚠️ WARNING: Only 'When In Use' permission. Background monitoring may not work.")
      }
      
      // Ensure PlaceManager delegate is set up
      if self.placeManager == nil {
          self.placeManager = PlaceManager()
          self.placeManager?.delegate = self
          self.log("PlaceManager created in start() method")
      }
      
      // Verify PlaceManager delegate is set
      if self.placeManager?.delegate == nil {
          self.placeManager?.delegate = self
          self.log("PlaceManager delegate re-set in start() method")
      }
      
      // Configure adapter settings (in case start is called separately)
      configureAdapterSettings()
      
      // Restore adapter state
      AirshipAdapter.shared.restore()
      self.log("AirshipAdapter restored in start()")
      
      // NOW start Gimbal (this is where actual monitoring begins)
      Gimbal.start()
      self.log("Gimbal.start() called - isStarted: \(Gimbal.isStarted())")
      
      sendEvent("iOS: Gimbal started")
      result("Started")

    case "stop":
      Gimbal.stop()
      sendEvent("iOS: Gimbal stopped")
      result("Stopped")

    case "restart":
      Gimbal.stop()
      sendEvent("iOS: Gimbal stopped")
      result("Stopped")

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - Adapter Settings Helper
extension AirshipAdapterFlutterPlugin {
  private func configureAdapterSettings() {
      AirshipAdapter.shared.shouldTrackCustomEntryEvents = true
      AirshipAdapter.shared.shouldTrackCustomExitEvents = true
      AirshipAdapter.shared.shouldTrackRegionEvents = true
  }
}

// MARK: - PlaceManagerDelegate
extension AirshipAdapterFlutterPlugin {
  public func placeManager(_ manager: PlaceManager, didBegin visit: Visit, withDelay delayTime: TimeInterval) {
      let message = "Entered place: \(visit.place.name)"
      self.log("PlaceManagerDelegate: didBegin - \(message)")
      sendEvent(message)
  }

  public func placeManager(_ manager: PlaceManager, didEnd visit: Visit) {
      let message = "Exited place: \(visit.place.name)"
      self.log("PlaceManagerDelegate: didEnd - \(message)")
      sendEvent(message)
  }

  public func placeManager(_ manager: PlaceManager, didReceive sighting: BeaconSighting, forVisits visits: [Any]) {
      let msg = "Beacon Sighting"
      sendEvent(msg)
  }
}

// MARK: - CLLocationManagerDelegate
extension AirshipAdapterFlutterPlugin {
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Always log this (not just when debug logging is enabled) since it's important
        print("[AirshipAdapterFlutter] 📍 Location authorization changed: \(status.rawValue)")
        self.log("📍 Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            sendEvent("Location: Authorized Always ✅")
            self.log("✅ Location permissions granted (Always) - Gimbal can now work")
        case .authorizedWhenInUse:
            sendEvent("Location: Authorized When In Use ⚠️ (Background may not work)")
            self.log("⚠️ Location permissions granted (When In Use) - Background monitoring may not work")
        case .denied:
            sendEvent("Location: Denied ❌ (Gimbal will not work)")
            self.log("❌ Location permissions denied - Gimbal will not work")
        case .restricted:
            sendEvent("Location: Restricted ❌ (Gimbal will not work)")
            self.log("❌ Location permissions restricted - Gimbal will not work")
        case .notDetermined:
            self.log("📍 Location permissions still not determined")
        @unknown default:
            break
        }
    }
}
