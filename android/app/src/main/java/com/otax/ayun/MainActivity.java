package com.otax.ayun;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        // Register AppMonitorPlugin — menangani 3 channel sekaligus:
        // 1. app_monitor_channel
        // 2. com.otax/usage_stats
        // 3. com.otax/network_scanner (NEW — scan /proc/net/tcp dari Java)
        flutterEngine.getPlugins().add(new AppMonitorPlugin());
    }
}
