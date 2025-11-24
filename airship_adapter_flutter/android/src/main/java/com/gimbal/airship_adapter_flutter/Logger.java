package com.gimbal.airship_adapter_flutter;

import android.util.Log;

/**
 * Centralized logger singleton for AirshipAdapterFlutter plugin.
 * All logging is controlled by a single enableDebugLogging flag.
 */
public class Logger {
  private static final String TAG = "AirshipAdapterFlutter";
  private static volatile Logger instance;
  private volatile boolean enableDebugLogging = false;

  private Logger() {
    // Private constructor for singleton
  }

  public static Logger getInstance() {
    if (instance == null) {
      synchronized (Logger.class) {
        if (instance == null) {
          instance = new Logger();
        }
      }
    }
    return instance;
  }

  public synchronized void setEnableDebugLogging(boolean enable) {
    this.enableDebugLogging = enable;
  }

  public synchronized boolean isDebugLoggingEnabled() {
    return enableDebugLogging;
  }

  public void d(String message) {
    if (enableDebugLogging) {
      Log.d(TAG, message);
    }
  }

  public void w(String message) {
    if (enableDebugLogging) {
      Log.w(TAG, message);
    }
  }

  public void i(String message) {
    if (enableDebugLogging) {
      Log.i(TAG, message);
    }
  }

  // Error logs are always enabled (important for production debugging)
  public void e(String message) {
    Log.e(TAG, message);
  }

  public void e(String message, Throwable throwable) {
    Log.e(TAG, message, throwable);
  }
}

