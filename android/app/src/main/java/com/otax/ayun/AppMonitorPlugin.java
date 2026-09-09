package com.otax.ayun;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.AppOpsManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class AppMonitorPlugin implements FlutterPlugin, MethodCallHandler,
        EventChannel.StreamHandler, ActivityAware {

    private static final String TAG = "AppMonitorPlugin";

    private MethodChannel channel;
    private MethodChannel usageStatsChannel;
    private MethodChannel networkScannerChannel;
    private EventChannel eventChannel;
    private Context context;
    private Activity activity;
    private EventChannel.EventSink eventSink;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean vpnScanActive = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();

        channel = new MethodChannel(binding.getBinaryMessenger(), "app_monitor_channel");
        channel.setMethodCallHandler(this);

        usageStatsChannel = new MethodChannel(binding.getBinaryMessenger(), "com.otax/usage_stats");
        usageStatsChannel.setMethodCallHandler(this);

        networkScannerChannel = new MethodChannel(binding.getBinaryMessenger(), "com.otax/network_scanner");
        networkScannerChannel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), "app_events_channel");
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "startMonitoring":
            case "stopMonitoring":
                result.success(true);
                break;

            case "checkForegroundApp":
            case "getForegroundApp":
                result.success(getCurrentForegroundApp());
                break;

            case "checkUsageStatsPermission":
                result.success(hasUsageStatsPermission());
                break;

            case "requestUsageStatsPermission":
                openUsageStatsSettings();
                result.success(null);
                break;

            case "checkVpnPermission":
                result.success(isVpnGranted());
                break;

            case "requestVpnPermission":
                requestVpnPermission(result);
                break;

            case "isMLRunning":
            case "isGameRunning":
                result.success(isAnyGameRunning());
                break;

            // Cek game mana yang sedang running
            case "getRunningGame": {
                String pkg = getRunningGamePackage();
                if (pkg != null && MLVpnCaptureService.GAME_DB.containsKey(pkg)) {
                    Map<String, Object> info = new HashMap<>();
                    info.put("package", pkg);
                    info.put("name", MLVpnCaptureService.GAME_DB.get(pkg)[0]);
                    info.put("icon", MLVpnCaptureService.GAME_DB.get(pkg)[1]);
                    result.success(info);
                } else {
                    result.success(null);
                }
                break;
            }

            // Dapatkan semua game yang terinstall
            case "getInstalledGames": {
                List<Map<String, Object>> games = getInstalledGames();
                result.success(games);
                break;
            }

            case "startVpnScan":
                startVpnScan(call, result);
                break;

            case "stopVpnScan":
                stopVpnScan();
                result.success(null);
                break;

            default:
                result.notImplemented();
        }
    }

    // ─── VPN Scan ────────────────────────────────────────────────────────
    private void startVpnScan(MethodCall call, Result result) {
        if (vpnScanActive) { result.success(true); return; }

        // Set callback: IP ditemukan → kirim ke Dart
        MLVpnCaptureService.ipFoundListener = (ip, port, gameName, gamePkg) -> {
            Log.d(TAG, "IP found: " + ip + ":" + port + " game=" + gameName);
            handler.post(() -> {
                // Via EventChannel
                if (eventSink != null) {
                    Map<String, Object> data = new HashMap<>();
                    data.put("type", "ip_found");
                    data.put("ip", ip);
                    data.put("port", port);
                    data.put("game_name", gameName);
                    data.put("game_package", gamePkg);
                    eventSink.success(data);
                }
                // Via MethodChannel invokeMethod
                if (channel != null) {
                    Map<String, Object> data = new HashMap<>();
                    data.put("ip", ip);
                    data.put("port", port);
                    data.put("game_name", gameName);
                    data.put("game_package", gamePkg);
                    channel.invokeMethod("onMLIPFound", data);
                }
            });
        };

        // Dapatkan target packages dari argument (null = scan semua game)
        List<String> pkgList = call.argument("packages");
        Intent intent = new Intent(context, MLVpnCaptureService.class);
        intent.setAction(MLVpnCaptureService.ACTION_START);
        if (pkgList != null && !pkgList.isEmpty()) {
            intent.putExtra(MLVpnCaptureService.EXTRA_PACKAGES, pkgList.toArray(new String[0]));
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }

        vpnScanActive = true;
        result.success(true);
    }

    private void stopVpnScan() {
        Intent intent = new Intent(context, MLVpnCaptureService.class);
        intent.setAction(MLVpnCaptureService.ACTION_STOP);
        context.startService(intent);
        vpnScanActive = false;
        MLVpnCaptureService.ipFoundListener = null;
    }

    // ─── Game Detection ───────────────────────────────────────────────────
    private boolean isAnyGameRunning() {
        return getRunningGamePackage() != null;
    }

    private String getRunningGamePackage() {
        // Cara 1: RunningAppProcesses
        try {
            ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            List<ActivityManager.RunningAppProcessInfo> procs = am.getRunningAppProcesses();
            if (procs != null) {
                for (ActivityManager.RunningAppProcessInfo p : procs) {
                    // Cek processName
                    if (MLVpnCaptureService.GAME_DB.containsKey(p.processName)) {
                        updateActiveGame(p.processName);
                        return p.processName;
                    }
                    // Cek pkgList
                    if (p.pkgList != null) {
                        for (String pkg : p.pkgList) {
                            if (MLVpnCaptureService.GAME_DB.containsKey(pkg)) {
                                updateActiveGame(pkg);
                                return pkg;
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.d(TAG, "getRunningAppProcesses: " + e.getMessage());
        }

        // Cara 2: UsageStats
        String fg = getCurrentForegroundApp();
        if (fg != null && MLVpnCaptureService.GAME_DB.containsKey(fg)) {
            updateActiveGame(fg);
            return fg;
        }

        return null;
    }

    private void updateActiveGame(String pkg) {
        MLVpnCaptureService.activeGamePackage = pkg;
        String[] info = MLVpnCaptureService.GAME_DB.get(pkg);
        MLVpnCaptureService.activeGameName = (info != null) ? info[0] : pkg;
    }

    private List<Map<String, Object>> getInstalledGames() {
        List<Map<String, Object>> result = new ArrayList<>();
        PackageManager pm = context.getPackageManager();
        for (Map.Entry<String, String[]> entry : MLVpnCaptureService.GAME_DB.entrySet()) {
            String pkg = entry.getKey();
            try {
                pm.getApplicationInfo(pkg, 0); // throws if not installed
                Map<String, Object> game = new HashMap<>();
                game.put("package", pkg);
                game.put("name", entry.getValue()[0]);
                game.put("icon", entry.getValue()[1]);
                game.put("installed", true);
                result.add(game);
            } catch (PackageManager.NameNotFoundException ignored) {}
        }
        return result;
    }

    private String getCurrentForegroundApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (!hasUsageStatsPermission()) return null;
            try {
                UsageStatsManager usm = (UsageStatsManager)
                        context.getSystemService(Context.USAGE_STATS_SERVICE);
                long now = System.currentTimeMillis();
                List<UsageStats> stats = usm.queryUsageStats(
                        UsageStatsManager.INTERVAL_DAILY, now - 30_000L, now);
                if (stats == null || stats.isEmpty()) return null;
                Collections.sort(stats, (a, b) -> Long.compare(b.getLastTimeUsed(), a.getLastTimeUsed()));
                for (UsageStats s : stats) {
                    String pkg = s.getPackageName();
                    if (pkg == null || pkg.isEmpty()) continue;
                    if (pkg.equals(context.getPackageName())) continue;
                    if (pkg.contains("launcher") || pkg.equals("android")) continue;
                    if (pkg.startsWith("com.android.systemui")) continue;
                    return pkg;
                }
            } catch (Exception e) { Log.e(TAG, "UsageStats: " + e.getMessage()); }
        }
        return null;
    }

    // ─── Permissions ──────────────────────────────────────────────────────
    private boolean hasUsageStatsPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return true;
        try {
            AppOpsManager ops = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
            int mode = ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(), context.getPackageName());
            return mode == AppOpsManager.MODE_ALLOWED;
        } catch (Exception e) { return false; }
    }

    private void openUsageStatsSettings() {
        try {
            Intent i = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(i);
        } catch (Exception e) {
            try {
                Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                i.setData(android.net.Uri.parse("package:" + context.getPackageName()));
                i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(i);
            } catch (Exception ignored) {}
        }
    }

    private boolean isVpnGranted() {
        try { return VpnService.prepare(context) == null; }
        catch (Exception e) { return false; }
    }

    private void requestVpnPermission(Result result) {
        if (activity == null) { result.success(false); return; }
        try {
            Intent vi = VpnService.prepare(context);
            if (vi == null) { result.success(true); }
            else { activity.startActivityForResult(vi, 1001); result.success(false); }
        } catch (Exception e) { result.success(false); }
    }

    @Override public void onListen(Object a, EventChannel.EventSink s) { eventSink = s; }
    @Override public void onCancel(Object a) { eventSink = null; }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding b) {
        if (channel != null) channel.setMethodCallHandler(null);
        if (usageStatsChannel != null) usageStatsChannel.setMethodCallHandler(null);
        if (networkScannerChannel != null) networkScannerChannel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
        stopVpnScan();
    }

    @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding b) { activity = b.getActivity(); }
    @Override public void onDetachedFromActivityForConfigChanges() { activity = null; }
    @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding b) { activity = b.getActivity(); }
    @Override public void onDetachedFromActivity() { activity = null; }
}
