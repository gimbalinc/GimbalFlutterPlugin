# airship_adapter_flutter

Configures Airship and starts Gimbal place monitoring, and emits visit and debug events to Flutter via an event stream.

## Features
- Configure Airship (keys provided by host app)
- Start/stop Gimbal ↔ Airship adapter
- Event stream with:
  - Entered/Exited place: <place name>
  - Beacon sightings (if available)
  - Optional debug logs

## Install
Add to your `pubspec.yaml`:

```yaml
dependencies:
  airship_adapter_flutter: ^1.0.0
```

## Quick Start
```dart
import 'package:airship_adapter_flutter/airship_adapter_flutter.dart';

// 1) Request runtime permissions in your app (recommended via permission_handler)
// 2) Configure with your keys
await AirshipAdapterFlutter.configure(
  airshipAppKey: '<AIRSHIP_KEY>',
  airshipAppSecret: '<AIRSHIP_SECRET>',
  gimbalApiKeyAndroid: '<GIMBAL_ANDROID_KEY>',
  gimbalApiKeyIOS: '<GIMBAL_IOS_KEY>',
);

// 3) Start monitoring
await AirshipAdapterFlutter.start();

// 4) Listen for events
AirshipAdapterFlutter.events.listen((e) {
  print('Adapter event: $e');
});
```

## Required setup

### Gimbal and Airship dashboards
- Register your app IDs (Android applicationId, iOS bundle identifier)
- Create Places (geofences/beacons) in Gimbal for testing
- Obtain Gimbal API keys for Android and iOS
- Obtain Airship development app key/secret

### Android
- Runtime permissions you should request before `start()`:
  - Foreground location: `ACCESS_COARSE_LOCATION` or `ACCESS_FINE_LOCATION`
  - Background location (Android 10+): `ACCESS_BACKGROUND_LOCATION`
  - Bluetooth (Android 12+ when using beacons): `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
  - Notifications (Android 13+): `POST_NOTIFICATIONS`
- Notes:
  - If using Airship Push, add `urbanairship-fcm` and configure FCM (otherwise the SDK logs a benign warning).
  - Airship URL allow list: configure `urlAllowListScopeOpenUrl` per Airship docs (or allow all in dev) to silence warnings.

### iOS
- Minimum iOS: 15.0
- Info.plist keys the host app should include:
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `NSLocationWhenInUseUsageDescription`
  - If using notifications: the appropriate usage descriptions
- Background Modes: enable "Location updates" if you want background enter/exit.
- After adding the plugin, run `pod install` in your iOS project.

## Event model
- Transition-based: you will only see "Entered/Exited place …" when the device actually crosses a Place boundary or detects a beacon visit. Staying inside a Place will not produce new events.
- Initial sync can take a couple of minutes after first run; ensure network is available.

## API surface
- `configure({ airshipAppKey, airshipAppSecret, gimbalApiKeyAndroid?, gimbalApiKeyIOS? })`
- `start()`
- `stop()`
- `restart()` (dev/testing convenience: stop then start)
- `events` (Stream<String>)

## Troubleshooting
- No events after the first run
  - Ensure you exit and re-enter a Place or approach/leave a beacon.
  - Verify permissions (Always on iOS; background location on Android 10+).
  - For dev, try `await AirshipAdapterFlutter.restart();`.
- "No push providers found!"
  - Add `urbanairship-fcm` and configure FCM if you plan to use push; otherwise ignore.
- Airship allow list warning
  - Add `urlAllowListScopeOpenUrl` per Airship docs; during dev you can allow all.

## To Release
- Create a release branch using the updated version number
- Increment the plugin version in pubspec.yaml
- Update the CHANGELOG.md
- Notify QA of availability for testing
- Commit any outstanding changes
- Push outstanding commits
- Create a tag corresponding to the updated version
- Push the tag
- Run `flutter pub publish --dry-run` to validate
- If validation passes, run `flutter pub publish`
- Verify package appears on pub.dev

## Versioning and licensing
- Version: 1.0.0
- License: Apache 2.0 (see LICENSE)

## Notes
- Keys are supplied by the host app at runtime.
- The plugin does not itself request runtime permissions; do this in your app.

## Example app
See `example/` for a runnable demo that:
- Requests permissions
- Configures the adapter
- Starts monitoring
- Displays events in a list
