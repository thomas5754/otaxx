// lib/services/vpn_packet_capture.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VPNPacketCapture {
  static const MethodChannel _channel = MethodChannel('vpn_capture_channel');
  
  final ValueNotifier<bool> isCapturing = ValueNotifier(false);
  final ValueNotifier<List<NetworkPacket>> capturedPackets = ValueNotifier([]);
  final ValueNotifier<String?> detectedServerIP = ValueNotifier(null);
  
  // Daftar IP server Mobile Legends yang umum (untuk filtering)
  static const List<String> KNOWN_ML_SERVERS = [
    '52.74.0.0/16',    // AWS Singapore (kemungkinan)
    '54.254.0.0/16',   // AWS Asia
    '13.228.0.0/16',   // AWS Asia Pacific
    '203.116.0.0/16',  // Singtel
    '119.81.0.0/16',   // Singtel
  ];
  
  Future<bool> initialize() async {
    try {
      final bool result = await _channel.invokeMethod('initialize');
      _channel.setMethodCallHandler(_handleNativeCall);
      return result;
    } on PlatformException catch (e) {
      print("Failed to initialize VPN: ${e.message}");
      return false;
    }
  }
  
  Future<void> startCapture() async {
    try {
      await _channel.invokeMethod('startCapture');
      isCapturing.value = true;
      capturedPackets.value.clear();
      detectedServerIP.value = null;
    } on PlatformException catch (e) {
      print("Failed to start capture: ${e.message}");
    }
  }
  
  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod('stopCapture');
      isCapturing.value = false;
    } on PlatformException catch (e) {
      print("Failed to stop capture: ${e.message}");
    }
  }
  
  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPacketCaptured':
        final Map<String, dynamic> packet = Map.from(call.arguments);
        final networkPacket = NetworkPacket.fromJson(packet);
        
        capturedPackets.value = [...capturedPackets.value, networkPacket];
        
        // Analisis packet untuk mendeteksi IP server game
        _analyzePacket(networkPacket);
        break;
        
      case 'onServerIPDetected':
        final String ip = call.arguments['serverIP'];
        detectedServerIP.value = ip;
        print("✅ Server IP terdeteksi: $ip");
        break;
    }
  }
  
  void _analyzePacket(NetworkPacket packet) {
    // Filter packet ke/dari server game
    if (packet.protocol == 'TCP' || packet.protocol == 'UDP') {
      // Cek apakah ini koneksi ke server game (port game Mobile Legends)
      if (_isGameServerPort(packet.destinationPort)) {
        detectedServerIP.value = packet.destinationIP;
        print("🎯 IP Server Game Terdeteksi: ${packet.destinationIP}:${packet.destinationPort}");
      }
    }
  }
  
  bool _isGameServerPort(int port) {
    // Port umum untuk game Mobile Legends
    const gamePorts = [10000, 10001, 10002, 20000, 20001, 30000, 30001, 40000, 40001, 5000, 5001, 9000, 9001];
    return gamePorts.contains(port);
  }
  
  void dispose() {
    isCapturing.dispose();
    capturedPackets.dispose();
    detectedServerIP.dispose();
  }
}

class NetworkPacket {
  final String sourceIP;
  final int sourcePort;
  final String destinationIP;
  final int destinationPort;
  final String protocol;
  final int packetSize;
  final DateTime timestamp;
  final Map<String, dynamic> rawData;
  
  NetworkPacket({
    required this.sourceIP,
    required this.sourcePort,
    required this.destinationIP,
    required this.destinationPort,
    required this.protocol,
    required this.packetSize,
    required this.timestamp,
    required this.rawData,
  });
  
  factory NetworkPacket.fromJson(Map<String, dynamic> json) {
    return NetworkPacket(
      sourceIP: json['sourceIP'] ?? '',
      sourcePort: json['sourcePort'] ?? 0,
      destinationIP: json['destinationIP'] ?? '',
      destinationPort: json['destinationPort'] ?? 0,
      protocol: json['protocol'] ?? 'Unknown',
      packetSize: json['packetSize'] ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      rawData: json,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'sourceIP': sourceIP,
      'sourcePort': sourcePort,
      'destinationIP': destinationIP,
      'destinationPort': destinationPort,
      'protocol': protocol,
      'packetSize': packetSize,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}