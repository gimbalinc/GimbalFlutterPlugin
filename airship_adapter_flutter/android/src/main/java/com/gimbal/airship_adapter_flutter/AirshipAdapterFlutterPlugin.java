package com.gimbal.airship_adapter_flutter;

import android.app.Application;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;

import com.gimbal.airship.AirshipAdapter;
import com.gimbal.android.Visit;
import com.gimbal.android.Gimbal;
import com.urbanairship.UAirship;
import com.urbanairship.AirshipConfigOptions;

public class AirshipAdapterFlutterPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private static final String TAG = "AirshipAdapterFlutter";
  private final Logger logger = Logger.getInstance();

  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private EventChannel.EventSink eventSink;

  private FlutterPluginBinding pluginBinding;
  private AirshipAdapter adapter;
  private String gimbalKey;
  private boolean listenersRegistered = false;
  private boolean isConfigured = false;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    logger.d("Plugin attached to engine");
    pluginBinding = binding;

    methodChannel = new MethodChannel(binding.getBinaryMessenger(), "airship_adapter_flutter/methods");
    methodChannel.setMethodCallHandler(this);

    eventChannel = new EventChannel(binding.getBinaryMessenger(), "airship_adapter_flutter/events");
    eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object args, EventChannel.EventSink sink) {
        logger.d("Event stream started listening");
        eventSink = sink;
      }

      @Override
      public void onCancel(Object args) {
        logger.d("Event stream cancelled");
        eventSink = null;
      }
    });
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    logger.d("Method called: " + call.method);
    Context context = pluginBinding.getApplicationContext();
    if (context == null) {
      result.error("INIT_ERROR", "Application context is null", null);
      return;
    }
    Application application = (Application) context;

    switch (call.method) {
      case "configure":
        try {
          String airshipAppKey = call.argument("airshipAppKey");
          String airshipAppSecret = call.argument("airshipAppSecret");
          String androidKey = call.argument("gimbalApiKeyAndroid");
          Boolean inProduction = call.argument("inProduction");
          Boolean enableDebug = call.argument("enableDebugLogging");
          
          // Validate required arguments
          if (airshipAppKey == null || airshipAppKey.trim().isEmpty()) {
            result.error("INVALID_ARGUMENTS", "airshipAppKey cannot be null or empty", null);
            return;
          }
          if (airshipAppSecret == null || airshipAppSecret.trim().isEmpty()) {
            result.error("INVALID_ARGUMENTS", "airshipAppSecret cannot be null or empty", null);
            return;
          }
          
          // Validate optional Gimbal key if provided
          if (androidKey != null && androidKey.trim().isEmpty()) {
            result.error("INVALID_ARGUMENTS", "gimbalApiKeyAndroid cannot be an empty string. Omit the parameter if not using Gimbal on Android.", null);
            return;
          }
          
          if (inProduction == null) {
            inProduction = false;
          }
          if (enableDebug == null) {
            enableDebug = false;
          }
          logger.setEnableDebugLogging(enableDebug);
          gimbalKey = androidKey;
          
          // Trim whitespace from keys
          airshipAppKey = airshipAppKey.trim();
          airshipAppSecret = airshipAppSecret.trim();
          if (androidKey != null) {
            androidKey = androidKey.trim();
            gimbalKey = androidKey;
          }

          logger.d("Configuring with Airship + Gimbal keys (android), inProduction: " + inProduction);

          AirshipConfigOptions.Builder optionsBuilder = AirshipConfigOptions.newBuilder();
          if (inProduction) {
            optionsBuilder.setProductionAppKey(airshipAppKey)
                    .setProductionAppSecret(airshipAppSecret);
          } else {
            optionsBuilder.setDevelopmentAppKey(airshipAppKey)
                    .setDevelopmentAppSecret(airshipAppSecret);
          }
          AirshipConfigOptions options = optionsBuilder
                  .setInProduction(inProduction)
                  .build();

          UAirship.takeOff(application, options);
          logger.d("Airship takeOff completed");

          adapter = AirshipAdapter.shared(context);

          configureAdapterSettings();

          adapter.restore();
          isConfigured = true;
          result.success("Configured successfully");
        } catch (Exception e) {
          logger.e("Error configuring: " + e.getMessage(), e);
          result.error("CONFIG_ERROR", e.getMessage(), null);
        }
        break;

      case "start":
        try {
          if (!isConfigured) {
            result.error("NOT_CONFIGURED", "Must call configure() before start()", null);
            return;
          }
          if (adapter != null && gimbalKey != null) {
            String missingPermissions = getMissingPermissionsDescription(context);
            if (!missingPermissions.isEmpty()) {
              logger.w("Required permissions not granted. Missing: " + missingPermissions);
              result.error("PERMISSION_DENIED", "Required permissions not granted. Missing: " + missingPermissions, null);
              return;
            }
            logger.d("Gimbal isStarted: " + Gimbal.isStarted());
            logger.d("Gimbal API Key: " + gimbalKey);
            logger.d("All required permissions granted. Preparing listeners");

            if (!listenersRegistered) {
              adapter.addListener(new AirshipAdapter.Listener() {
              @Override
              public void onRegionEntered(@NonNull com.urbanairship.analytics.location.RegionEvent event, @NonNull Visit visit) {
                logger.d("AirshipAdapter: Region entered - " + visit.getPlace().getName());
                sendEvent("AirshipAdapter: Entered place: " + visit.getPlace().getName());
              }

              @Override
              public void onRegionExited(@NonNull com.urbanairship.analytics.location.RegionEvent event, @NonNull Visit visit) {
                logger.d("AirshipAdapter: Region exited - " + visit.getPlace().getName());
                sendEvent("AirshipAdapter: Exited place: " + visit.getPlace().getName());
              }

              @Override
              public void onCustomRegionEntry(@NonNull com.urbanairship.analytics.CustomEvent event, @NonNull Visit visit) {
                sendEvent("Custom entry: " + visit.getPlace().getName());
              }

              @Override
              public void onCustomRegionExit(@NonNull com.urbanairship.analytics.CustomEvent event, @NonNull Visit visit) {
                sendEvent("Custom exit: " + visit.getPlace().getName());
              }
              });
              listenersRegistered = true;
            }

            adapter.restore();
            Gimbal.setApiKey((Application) context, gimbalKey);
            adapter.start(gimbalKey);
            logger.d("AirshipAdapter started");
            logger.d("Adapter started with listeners");
            result.success("Started");
          } else {
            result.error("NOT_CONFIGURED", "Adapter not configured or gimbalKey is null", null);
          }
        } catch (Exception e) {
          logger.e("Error starting: " + e.getMessage(), e);
          result.error("START_ERROR", e.getMessage(), null);
        }
        break;

      case "restart":
        try {
            if (adapter != null) {
            adapter.stop();
            logger.d("Adapter stopped for restart");
          }
          result.success("Stopped");
        } catch (Exception e) {
          logger.e("Error restarting: " + e.getMessage(), e);
          result.error("RESTART_ERROR", e.getMessage(), null);
        }
        break;

      case "stop":
        try {
          if (adapter != null) {
            adapter.stop();
            logger.d("Adapter stopped");
            result.success("Stopped");
          } else {
            result.error("NOT_CONFIGURED", "Adapter not configured yet", null);
          }
        } catch (Exception e) {
          logger.e("Error stopping: " + e.getMessage(), e);
          result.error("STOP_ERROR", e.getMessage(), null);
        }
        break;

      default:
        logger.w("Unknown method: " + call.method);
        result.notImplemented();
    }
  }

  private void configureAdapterSettings() {
    if (adapter != null) {
      adapter.setShouldTrackCustomEntryEvent(true);
      adapter.setShouldTrackCustomExitEvent(true);
      adapter.setShouldTrackRegionEvent(true);
    }
  }

  private void sendEvent(String message) {
    logger.d("Sending event: " + message);
    if (eventSink != null) {
      eventSink.success(message);
    } else {
      logger.w("EventSink is null, cannot send event: " + message);
    }
  }
  
  private void cleanupListeners() {
    if (adapter != null && listenersRegistered) {
      // Note: AirshipAdapter doesn't have removeListener, but adapter.stop() should handle it
      listenersRegistered = false;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    logger.d("Plugin detached from engine");
    cleanupListeners();
    if (methodChannel != null) {
      methodChannel.setMethodCallHandler(null);
    }
    if (adapter != null) {
      adapter.stop();
    }
    methodChannel = null;
    eventChannel = null;
    eventSink = null;
    pluginBinding = null;
    isConfigured = false;
  }

  /**
   * Returns a comma-separated list of missing runtime permissions required for location/Bluetooth/notifications.
   * Empty string if none are missing.
   */
  private String getMissingPermissionsDescription(Context context) {
    StringBuilder missing = new StringBuilder();

    // Location: COARSE or FINE for foreground
    boolean hasCoarse = ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    boolean hasFine = ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    if (!hasCoarse && !hasFine) {
      appendMissing(missing, "ACCESS_COARSE_LOCATION or ACCESS_FINE_LOCATION");
    }

    // Background location on Android Q (29) and above
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      int bg = ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION);
      if (bg != PackageManager.PERMISSION_GRANTED) {
        appendMissing(missing, "ACCESS_BACKGROUND_LOCATION");
      }
    }

    // Bluetooth scan/connect on Android 12 (31) and above
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      int scan = ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_SCAN);
      int connect = ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_CONNECT);
      if (scan != PackageManager.PERMISSION_GRANTED) {
        appendMissing(missing, "BLUETOOTH_SCAN");
      }
      if (connect != PackageManager.PERMISSION_GRANTED) {
        appendMissing(missing, "BLUETOOTH_CONNECT");
      }
    }

    // Notifications on Android 13 (33) and above
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      int notif = ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS);
      if (notif != PackageManager.PERMISSION_GRANTED) {
        appendMissing(missing, "POST_NOTIFICATIONS");
      }
    }

    return missing.toString();
  }

  private void appendMissing(StringBuilder builder, String value) {
    if (builder.length() > 0) {
      builder.append(", ");
    }
    builder.append(value);
  }
}
