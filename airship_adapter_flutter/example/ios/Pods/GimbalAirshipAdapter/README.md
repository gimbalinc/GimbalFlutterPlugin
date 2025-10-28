# Airship iOS Gimbal Adapter

The Airship Gimbal Adapter is a drop-in class that allows users to integrate Gimbal place events with Airship.

## Resources
- [Gimbal Developer Guide](https://gimbal.com/doc/iosdocs/v2/devguide.html)
- [Gimbal Manager Portal](https://manager.gimbal.com)
- [Airship Getting Started guide](http://docs.airship.com/build/ios.html)
- [Airship and Gimbal Integration Guide](https://docs.airship.com/partners/gimbal/)

## Installation

The Airship Gimbal Adapter is available through CocoaPods. To install it, simply add the following line to your Podfile:
```
pod "GimbalAirshipAdapter"
```

## Usage

### Importing

#### Swift

```
import AirshipAdapter
```

#### Obj-C

```
@import AirshipAdapter
```

### Enabling Event Tracking
By default, event tracking is disabled, and thus must be explicitly enabled as described below.

##### RegionEvents
To enable or disable the tracking of Airship `RegionEvent` objects, use the  `shouldTrackRegionEvents` property:

```
AirshipAdapter.shared.shouldTrackRegionEvents = true // enabled
AirshipAdapter.shared.shouldTrackRegionEvents = false // disabled
```

##### CustomEvents
To enable or disable the tracking of Airship `CustomEvent` objects, use the `shouldTrackCustomEntryEvents` and `shouldTrackCustomExitEvents` properties to track events upon place entry and exit, as shown below. For more information regarding Airship Custom Events, see the documentation [here](https://docs.airship.com/guides/messaging/user-guide/data/custom-events/#overview).
```
// To enable CustomEvent tracking for place exits
AirshipAdapter.shared.shouldTrackCustomExitEvents = true
// To disable CustomEvent tracking for place exits
AirshipAdapter.shared.shouldTrackCustomExitEvents = false
// To enable CustomEvent tracking for place entries
AirshipAdapter.shared.shouldTrackCustomEntryEvents = true
// To disable CustomEvent tracking for place entries
AirshipAdapter.shared.shouldTrackCustomEntryEvents = false
```

### Restoring the adapter

In your application delegate call `restore` during `didFinishLaunchingWithOptions`:

#### Swift

```
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {

   // after Airship.takeOff   
   AirshipGimbalAdapter.shared.restore()

   ...
}
```

#### Obj-C

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

   // after UAirship.takeOff
   [[AirshpGimbalAdapter shared] restore];

   ...
}
```

Restore will automatically resume the adapter on application launch.


### Starting the adapter

#### Swift

```
AirshipGimbalAdapter.shared.start("## PLACE YOUR API KEY HERE ##")
```

#### Obj-C

```
[[AirshpGimbalAdapter shared] start:@"## PLACE YOUR API KEY HERE ##"];
```

### Stopping the adapter

#### Swift

```
AirshipGimbalAdapter.shared.stop()
```

#### Obj-C

```
[[AirshpGimbalAdapter shared] stop];
```

### Enabling Bluetooth Warning

In the event that Bluetooth is disabled during place monitoring, the Gimbal Adapter can prompt users with an alert view
to enable Bluetooth. This functionality is disabled by default, but can be enabled by setting AirshipGimbalAdapter's
`bluetoothPoweredOffAlertEnabled` property to true:

#### Swift

```
AirshipGimbalAdapter.shared.bluetoothPoweredOffAlertEnabled = true
```

#### Obj-C

```
[AirshpGimbalAdapter shared].bluetoothPoweredOffAlertEnabled = YES;
```

### Setting Analytics Id

```
AirshipAdapter.shared.set(userAnalyticsId: "YOUR_ANALYTICS_ID")
```

## AirshipGimbalAdapter Migration

The `AirshipGimbalAdapter` is an older version of this adapter; if you previously used the `AirshipGimblAdapter` and would like to migrate, see the following steps:
- If using Cocoapods, change the name of the pod from `AirshipGimbalAdapter` to `GimbalAirshipAdapter`
- In your code, references to the `AirshipGimbalAdapter` class should be changed to `AirshipAdapter`
- The older `AirshipGimbalAdapter` tracked Region Events but not Custom Events; if you would like to keep this type of functionality, disable `CustomEvent` tracking and enable `RegionEvent` tracking, as described above in the section entitled `Enabling Event Tracking`. 
