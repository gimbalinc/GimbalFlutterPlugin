import UIKit
import GimbalAirshipAdapter
import AirshipKit
import Gimbal
import Flutter

public class AirshipAdapterFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, PlaceManagerDelegate {
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var placeManager: PlaceManager?
  private var enableDebugLogging: Bool = false
  private var isConfigured: Bool = false
  
  // Serial queue for thread-safe eventSink access
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
  
  // MARK: - Cleanup
  deinit {
      placeManager?.delegate = nil
      placeManager = nil
      log("AirshipAdapterFlutterPlugin deinitialized")
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AirshipAdapterFlutterPlugin()

    // Method channel.
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

      // Note: Gimbal SDK handles location services internally - no separate LocationManager needed
      // This reduces energy consumption by avoiding duplicate location monitoring

      // Create AirshipConfig programmatically (no plist file needed)
      var config = AirshipConfig()
      if inProduction {
          config.productionAppKey = trimmedAirshipKey
          config.productionAppSecret = trimmedAirshipSecret
      } else {
          config.developmentAppKey = trimmedAirshipKey
          config.developmentAppSecret = trimmedAirshipSecret
      }
      config.inProduction = inProduction
      
      // Suppress URL allow list warning (reduces console noise)
      config.urlAllowListScopeOpenURL = ["*"]
      
      // Optional: Disable remote data if not needed (reduces background tasks and energy)
      // Uncomment the next line if you don't need Airship remote data features:
      // config.remoteDataAPIEnabled = false
      
      DispatchQueue.main.async {
          do {
              try Airship.takeOff(config, launchOptions: nil)
              
              // Set up PlaceManager delegate to receive events (only if not already created)
              // Note: We use PlaceManager delegate, NOT AirshipAdapter delegate, to avoid duplicates
              if self.placeManager == nil {
                  self.placeManager = PlaceManager()
                  self.placeManager?.delegate = self
              }
              
              // Continue with adapter setup after successful Airship initialization
              self.configureAdapterSettings()
              // Do NOT set AirshipAdapter.shared.delegate = self (causes duplicate events)
              AirshipAdapter.shared.start(gimbalKey)
              
              Gimbal.setAPIKey(gimbalKey)
              Gimbal.start()  // Start Gimbal explicitly
              // Note: restore() is called in start() method, no need to call here
              
              // Mark as configured
              self.isConfigured = true
              
              // Inform Flutter UI that adapter restore completed (useful when no immediate place transitions)
              self.sendEvent("iOS: AirshipAdapter restored")

              // Debug logging - only if enabled
              if self.enableDebugLogging {
                  Debugger.enableDebugLogging()
                  Debugger.enableBeaconSightingsLogging()
                  Debugger.enablePlaceLogging()
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

    case "start":
      guard isConfigured else {
          result(FlutterError(
              code: "NOT_CONFIGURED",
              message: "Must call configure() before start()",
              details: nil
          ))
          return
      }
      
      // Ensure PlaceManager delegate is set up
      if self.placeManager == nil {
          self.placeManager = PlaceManager()
          self.placeManager?.delegate = self
      }
      
      configureAdapterSettings()
      AirshipAdapter.shared.restore()
      Gimbal.start()
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

// LocationManager removed - Gimbal SDK handles location services internally
// This reduces energy consumption by avoiding duplicate location monitoring
