// lib/services/app_monitor_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AppMonitorService {
  static const String MOBILE_LEGENDS_PACKAGE = 'com.mobile.legends';
  static const String MOBILE_LEGENDS_PACKAGE_INDONESIA = 'com.mobile.legends.indonesia';
  
  final ValueNotifier<bool> isGameRunning = ValueNotifier(false);
  final ValueNotifier<String> detectedGamePackage = ValueNotifier('');
  final ValueNotifier<DateTime> lastDetection = ValueNotifier(DateTime.now());
  
  Timer? _monitorTimer;
  
  // Method channel untuk komunikasi dengan native Android
  static const MethodChannel _channel = MethodChannel('app_monitor_channel');
  
  Future<void> startMonitoring() async {
    // Cek izin
    if (!await _checkPermissions()) return;
    
    // Set listener untuk notifikasi dari native
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAppForeground':
          final String packageName = call.arguments['package'] ?? '';
          final String appName = call.arguments['appName'] ?? '';
          _handleAppChange(packageName, appName);
          break;
        case 'onAppBackground':
          _handleAppBackground();
          break;
      }
    });
    
    // Mulai monitoring native
    try {
      await _channel.invokeMethod('startMonitoring');
      _startPeriodicCheck();
    } on PlatformException catch (e) {
      print("Failed to start monitoring: ${e.message}");
    }
  }
  
  void _handleAppChange(String packageName, String appName) {
    if (packageName == MOBILE_LEGENDS_PACKAGE || 
        packageName == MOBILE_LEGENDS_PACKAGE_INDONESIA) {
      isGameRunning.value = true;
      detectedGamePackage.value = packageName;
      lastDetection.value = DateTime.now();
      
      // Trigger auto-detect IP saat game terdeteksi
      _triggerIPDetection();
    } else {
      isGameRunning.value = false;
    }
  }
  
  void _handleAppBackground() {
    isGameRunning.value = false;
    detectedGamePackage.value = '';
  }
  
  void _startPeriodicCheck() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Cek apakah game masih running (fallback)
      _channel.invokeMethod('checkForegroundApp');
    });
  }
  
  Future<bool> _checkPermissions() async {
    // Izin untuk usage stats - handled via native MethodChannel (not in permission_handler 12.x)
    try {
      final bool hasUsageStats = await _channel.invokeMethod('checkUsageStatsPermission') ?? false;
      if (!hasUsageStats) {
        await _channel.invokeMethod('requestUsageStatsPermission');
        // User will be redirected to settings, return false and let user retry
        return false;
      }
    } catch (_) {
      // Fallback jika native channel belum ada
    }

    // Izin untuk notifikasi (untuk overlay)
    if (!await Permission.notification.isGranted) {
      final status = await Permission.notification.request();
      if (!status.isGranted) return false;
    }

    // VPN permission handled via native (VpnService.prepare) bukan permission_handler
    try {
      final bool vpnReady = await _channel.invokeMethod('checkVpnPermission') ?? false;
      if (!vpnReady) {
        await _channel.invokeMethod('requestVpnPermission');
        return false;
      }
    } catch (_) {
      // Fallback jika native channel belum ada
    }

    return true;
  }
  
  void _triggerIPDetection() {
    // Panggil VPN service untuk mulai capture
    print("Mobile Legends terdeteksi! Memulai packet capture...");
  }
  
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _channel.invokeMethod('stopMonitoring');
  }
  
  void dispose() {
    stopMonitoring();
    isGameRunning.dispose();
    detectedGamePackage.dispose();
    lastDetection.dispose();
  }
}