import UIKit
import GimbalAirshipAdapter
import AirshipKit
import CoreLocation
import Gimbal
import Flutter

public class AirshipAdapterFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, PlaceManagerDelegate {
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var placeManager: PlaceManager?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AirshipAdapterFlutterPlugin()

    // Method channel
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
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

extension AirshipAdapterFlutterPlugin {
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "configure":
      if let args = call.arguments as? [String: Any],
         let airshipKey = args["airshipAppKey"] as? String,
         let airshipSecret = args["airshipAppSecret"] as? String {

          let iosKey = (args["gimbalApiKeyIOS"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
          let gimbalKey = iosKey ?? ""

          let locManager = LocationManager()
          locManager.requestPermissions()

          do {
              var config = try AirshipConfig.default()
              config.developmentAppKey = airshipKey
              config.developmentAppSecret = airshipSecret
              config.inProduction = false
              DispatchQueue.main.async {
                  do {
                      try Airship.takeOff(config, launchOptions: nil)
                      print("Airship.takeOff succeeded")
                  } catch {
                      print("Airship.takeOff failed: \(error)")
                  }
              }
          } catch {
              print("Airship.takeOff failed: \(error)")
          }

          // Configure Gimbal Adapter
          AirshipAdapter.shared.shouldTrackCustomEntryEvents = true
          AirshipAdapter.shared.shouldTrackCustomExitEvents = true
          AirshipAdapter.shared.shouldTrackRegionEvents = true
          AirshipAdapter.shared.delegate = self
          AirshipAdapter.shared.start(gimbalKey)
          
          AirshipAdapter.shared.restore()
          self.eventSink?("iOS: AirshipAdapter restored")

          
          Debugger.enableDebugLogging()
          Debugger.enableBeaconSightingsLogging()
          Debugger.enablePlaceLogging()

          result(nil)
      }

    case "start":
      if self.placeManager == nil {
        self.placeManager = PlaceManager()
      }
      self.placeManager?.delegate = self
      AirshipAdapter.shared.delegate = self
      AirshipAdapter.shared.shouldTrackCustomEntryEvents = true
      AirshipAdapter.shared.shouldTrackCustomExitEvents = true
      AirshipAdapter.shared.shouldTrackRegionEvents = true
      AirshipAdapter.shared.restore()
      Gimbal.start()
      eventSink?("iOS: Gimbal monitoring started")

      print("DEBUG: PlaceManager delegate set: \(self.placeManager?.delegate != nil)")
      eventSink?("iOS: Gimbal started")
      result("Started")

    case "stop":
      Gimbal.stop()
      eventSink?("iOS: Gimbal stopped")
      result("Stopped")

    case "restart":
      Gimbal.stop()
      eventSink?("iOS: Gimbal stopped")
      result("Stopped")

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - PlaceManagerDelegate
extension AirshipAdapterFlutterPlugin {
  public func placeManager(_ manager: PlaceManager, didBegin visit: Visit, withDelay delayTime: TimeInterval) {
      print("\n\n\nDEBUG: PlaceManager didBegin - Entered place: \(visit.place.name)")
      print("DEBUG: Sending entry event to Flutter")
      eventSink?("Entered place: \(visit.place.name)")
  }

  public func placeManager(_ manager: PlaceManager, didEnd visit: Visit) {
      print("\n\n\nDEBUG: PlaceManager didEnd - Exited place: \(visit.place.name)")
      print("DEBUG: Sending exit event to Flutter")
      eventSink?("Exited place: \(visit.place.name)")
  }

  public func placeManager(_ manager: PlaceManager, didReceive sighting: BeaconSighting, forVisits visits: [Any]) {
    let msg = "Beacon Sighting"
    print("DEBUG: Beacon Sighting - \(msg)")
    DispatchQueue.main.async {
      self.eventSink?(msg)
    }
  }
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            print("Location authorized: Always")
        case .authorizedWhenInUse:
            print("Location authorized: When In Use")
        case .denied, .restricted:
            print("Location denied/restricted")
        case .notDetermined:
            print("Location not determined yet")
        @unknown default:
            break
        }
    }
}
