/* Copyright Airship and Contributors */

import AirshipKit

import Gimbal

// Keys
fileprivate let hideBlueToothAlertViewKey = "gmbl_hide_bt_power_alert_view"
fileprivate let shouldTrackCustomEntryEventsKey = "gmbl_should_track_custom_entry"
fileprivate let shouldTrackCustomExitEventsKey = "gmbl_should_track_custom_exit"
fileprivate let shouldTrackRegionEventsKey = "gmbl_should_track_region_events"
fileprivate let wasStartedKey = "gmbl_was_adapter_started_key"
fileprivate let apiKeyStringKey = "gmbl_api_key_string_key"
fileprivate let defaultsSuiteName = "arshp_gmbl_def_suite"

@objc open class AirshipAdapter : NSObject {

    /**
     * Singleton access.
     */
    @objc public static let shared = AirshipAdapter()

    /**
     * Receives forwarded callbacks from the PlaceManagerDelegate
     */
    @objc open var delegate: PlaceManagerDelegate?

    private let placeManager: PlaceManager
    private let gimbalDelegate: AirshipGimbalDelegate
    private let deviceAttributesManager: DeviceAttributesManager
    private var isAdapterStarted = false
    
    /**
     * Returns true if the adapter is started, otherwise false.
     */
    @objc open var isStarted: Bool {
        get {
            return Gimbal.isStarted() && self.isAdapterStarted
        }
    }
  

    /**
     * Enables alert when Bluetooth is powered off. Defaults to NO.
     */
    @objc open var bluetoothPoweredOffAlertEnabled : Bool {
        get {
            return defaults.bool(forKey: hideBlueToothAlertViewKey)
        }
        set {
            defaults.set(!newValue, forKey: hideBlueToothAlertViewKey)
        }
    }
    
    /**
     * Enables creation of UrbanAirship CustomEvents when Gimbal place entries are detected.
     */
    @objc open var shouldTrackCustomEntryEvents : Bool {
        get {
            return defaults.bool(forKey: shouldTrackCustomEntryEventsKey)
        }
        set {
            defaults.set(newValue, forKey: shouldTrackCustomEntryEventsKey)
        }
    }
    
    /**
     * Enables creation of UrbanAirship CustomEvents when Gimbal place exits are detected.
     */
    @objc open var shouldTrackCustomExitEvents : Bool {
        get {
            return defaults.bool(forKey: shouldTrackCustomExitEventsKey)
        }
        set {
            defaults.set(newValue, forKey: shouldTrackCustomExitEventsKey)
        }
    }
    
    /**
     * Enables creation of Urban Airship RegionEvents when Gimbal place events are detected.
     */
    @objc open var shouldTrackRegionEvents : Bool {
        get {
            return defaults.bool(forKey: shouldTrackRegionEventsKey)
        }
        set {
            defaults.set(newValue, forKey: shouldTrackRegionEventsKey)
        }
    }
    
    @objc private var defaults: UserDefaults = UserDefaults.standard
    
    private override init() {
        placeManager = PlaceManager()
        defaults = UserDefaults(suiteName: defaultsSuiteName) ?? UserDefaults.standard
        gimbalDelegate = AirshipGimbalDelegate(withDefaults: defaults)
        deviceAttributesManager = DeviceAttributesManager()
        super.init();
        migrateDefaults()
        placeManager.delegate = gimbalDelegate

        // Hide the BLE power status alert to prevent duplicate alerts
        if (defaults.value(forKey: hideBlueToothAlertViewKey) == nil) {
            defaults.set(true, forKey: hideBlueToothAlertViewKey)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AirshipAdapter.updateDeviceAttributes),
                                               name: AirshipNotifications.ChannelCreated.name,
                                               object: nil)
        
        self.isAdapterStarted = defaults.bool(forKey: wasStartedKey)
    }

    /**
     * Restores the adapter's running state. If the adapter was previously started, it will restart. Should be called in didFinishLaunchingWithOptions.
     */
    @objc open func restore() {
        guard let apiKey = defaults.string(forKey: apiKeyStringKey) else {
            return
        }
        let wasStarted = defaults.bool(forKey: wasStartedKey)
        
        if (wasStarted) {
            print("Restoring Gimbal Adapter")
            self.start(apiKey)
            DispatchQueue.main.async {
                if (self.isStarted) {
                    print("Gimbal adapter restored")
                } else {
                    print("Failed to restore Gimbal adapter")
                }
            }
        } else {
            print("Gimbal Airship adapter not previously started, nothing to restore")
        }
    }

    /**
     * Starts the adapter.
     * @param apiKey The Gimbal API key.
     */
    @objc open func start(_ apiKey: String?) {
        guard let key = apiKey else {
            print("Unable to start Gimbal Adapter, missing key")
            return
        }
        
        guard !self.isAdapterStarted else {
            print("Calling 'start' when adapter is already started has no effect")
            return
        }
        
        let storedApiKey = defaults.string(forKey: apiKeyStringKey)
        
        guard key != storedApiKey else {
            return
        }
        
        print("Detected API key change: \(storedApiKey ?? "nil") -> \(key)")
        
        defaults.set(key, forKey: apiKeyStringKey)
        defaults.set(true, forKey: wasStartedKey)
        self.isAdapterStarted = true

        Gimbal.setAPIKey(key, options: ["MANAGE_PERMISSIONS" : false])
        Gimbal.start()
        updateDeviceAttributes()
        print("Started Gimbal Adapter. Gimbal application instance identifier: \(Gimbal.applicationInstanceIdentifier() ?? "⚠️ Empty Gimbal application instance identifier")")
    }

    /**
     * Stops the adapter.
     */
    @objc open func stop() {
        Gimbal.stop()
        defaults.set(false, forKey: wasStartedKey)
        self.isAdapterStarted = false
        print("Stopped Gimbal Adapter");
    }
    
    @objc open func set(userAnalyticsId: String) {
        AnalyticsManager.sharedInstance().setUserAnalyticsID(userAnalyticsId)
    }

    @objc private func updateDeviceAttributes() {
        guard Airship.isFlying else {
            print("Unable to update device attributes; Airship is not running")
            return
        }
        
        Task {
            if let namedUserID = await Airship.contact.namedUserID {
                deviceAttributesManager.setDeviceAttribute("ua.nameduser.id", value: namedUserID)
            }
            
            if let channelID = Airship.channel.identifier {
                deviceAttributesManager.setDeviceAttribute("ua.channel.id", value: channelID)
            }

            let identifiers = Airship.analytics.currentAssociatedDeviceIdentifiers()
            identifiers.set(identifier: Gimbal.applicationInstanceIdentifier(), key: "com.urbanairship.gimbal.aii")
            Airship.analytics.associateDeviceIdentifiers(identifiers)
            print("Successfully updated Gimbal Adapter device attributes")
        }
    }
    
    @objc private func migrateDefaults() {
        if UserDefaults.standard.object(forKey: hideBlueToothAlertViewKey) != nil {
            bluetoothPoweredOffAlertEnabled = UserDefaults.standard.bool(forKey: hideBlueToothAlertViewKey)
            UserDefaults.standard.removeObject(forKey: hideBlueToothAlertViewKey)
        }
        if UserDefaults.standard.object(forKey: shouldTrackCustomEntryEventsKey) != nil {
            shouldTrackCustomEntryEvents = UserDefaults.standard.bool(forKey: shouldTrackCustomEntryEventsKey)
            UserDefaults.standard.removeObject(forKey:shouldTrackCustomEntryEventsKey)
        }
        if UserDefaults.standard.object(forKey: shouldTrackCustomExitEventsKey) != nil {
            shouldTrackCustomExitEvents = UserDefaults.standard.bool(forKey: shouldTrackCustomExitEventsKey)
            UserDefaults.standard.removeObject(forKey:shouldTrackCustomExitEventsKey)
        }
        if UserDefaults.standard.object(forKey: shouldTrackRegionEventsKey) != nil {
            shouldTrackRegionEvents = UserDefaults.standard.bool(forKey: shouldTrackRegionEventsKey)
            UserDefaults.standard.removeObject(forKey:shouldTrackRegionEventsKey)
        }
    }
}

private class AirshipGimbalDelegate : NSObject, PlaceManagerDelegate {
    private let source: String = "Gimbal"
    private let keyBoundaryEvent = "boundaryEvent"
    private let customEntryEventName = "gimbal_custom_entry_event"
    private let customExitEventName = "gimbal_custom_exit_event"
    private let defaults: UserDefaults
    
    private var shouldCreateCustomEntryEvent : Bool {
        get {
            return defaults.bool(forKey: shouldTrackCustomEntryEventsKey)
        }
    }
    private var shouldCreateCustomExitEvent : Bool {
        get {
            return defaults.bool(forKey: shouldTrackCustomExitEventsKey)
        }
    }
    private var shouldCreateRegionEvents : Bool {
        get {
            return defaults.bool(forKey: shouldTrackRegionEventsKey)
        }
    }
    
    init(withDefaults defaults: UserDefaults) {
        self.defaults = defaults
        super.init()
    }

    func placeManager(_ manager: PlaceManager, didBegin visit: Visit) {
        print("Entered place: \(visit.place.name) Arrival date: \(visit.arrivalDate)")
        trackPlaceEventFor(visit, boundaryEvent: .enter)
        
        AirshipAdapter.shared.delegate?.placeManager?(manager, didBegin: visit)
    }

    func placeManager(_ manager: PlaceManager, didBegin visit: Visit, withDelay delayTime: TimeInterval) {
        print("Entered place: \(visit.place.name) date: \(visit.arrivalDate) withDelay: \(delayTime)")
        trackPlaceEventFor(visit, boundaryEvent: .enter)
        
        AirshipAdapter.shared.delegate?.placeManager?(manager, didBegin: visit, withDelay: delayTime)
    }

    func placeManager(_ manager: PlaceManager, didEnd visit: Visit) {
        print("Exited place: \(visit.place.name) Arrival date: \(visit.arrivalDate) Exit Date: \(visit.departureDate?.description ?? "n/a")")
        trackPlaceEventFor(visit, boundaryEvent: .exit)
        
        AirshipAdapter.shared.delegate?.placeManager?(manager, didEnd: visit)
    }

    func placeManager(_ manager: PlaceManager, didReceive sighting: BeaconSighting, forVisits visits: [Any]) {
        AirshipAdapter.shared.delegate?.placeManager?(manager, didReceive: sighting, forVisits: visits)
    }

    func placeManager(_ manager: PlaceManager, didDetect location: CLLocation) {
        print("Detected location \(location.coordinate)")
        AirshipAdapter.shared.delegate?.placeManager?(manager, didDetect: location)
    }
    
    private func trackPlaceEventFor(_ visit: Visit, boundaryEvent: AirshipBoundaryEvent) {
        guard Airship.isFlying else {
            print("Unable to track event \(boundaryEvent.rawValue) for place with ID \(visit.place.identifier); Airship is not running")
            return
            
        }
        if shouldCreateRegionEvents,
           let regionEvent = RegionEvent(regionID: visit.place.identifier,
                                           source: source,
                                    boundaryEvent: boundaryEvent) {
            Airship.analytics.recordRegionEvent(regionEvent)
        }

        if boundaryEvent == .enter, shouldCreateCustomEntryEvent {
            createAndTrackEvent(withName: customEntryEventName, forVisit: visit, boundaryEvent: boundaryEvent)
        } else if boundaryEvent == .exit, shouldCreateCustomExitEvent {
            createAndTrackEvent(withName: customExitEventName, forVisit: visit, boundaryEvent: boundaryEvent)
        }
    }
    
    private func createAndTrackEvent(withName eventName: String,
                                     forVisit visit: Visit,
                                     boundaryEvent: AirshipBoundaryEvent) {
        // create event properties
        var visitProperties:[String : Any] = [:]
        visitProperties["visitID"] = visit.visitID
        visitProperties["placeIdentifier"] = visit.place.identifier
        visitProperties["placeName"] = visit.place.name
        visitProperties["source"] = source
        visitProperties["boundaryEvent"] = boundaryEvent.rawValue
        var placeAttributes = Dictionary<String, Any>()
        for attributeKey in visit.place.attributes.allKeys() {
            if let value = visit.place.attributes.string(forKey: attributeKey) {
                placeAttributes[attributeKey] = value
                visitProperties.updateValue(value, forKey: "GMBL_PA_\(attributeKey)")
            }
        }
        if boundaryEvent == .exit {
            visitProperties["dwellTimeInSeconds"] = visit.dwellTime
        }
        
        do {
            var event = CustomEvent(name: eventName)
            try event.setProperties(visitProperties)
            event.track()
            
        } catch {
            print(error)
        }
    }
}
