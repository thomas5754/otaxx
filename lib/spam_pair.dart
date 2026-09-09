// spam_pair.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' as flutter_services;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart';
class SpamPairPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const SpamPairPage({
    Key? key,
    required this.sessionKey,
    required this.username,
    required this.role,
  }) : super(key: key);

  @override
  State<SpamPairPage> createState() => _SpamPairPageState();
}

class _SpamPairPageState extends State<SpamPairPage> {
  
  static String get SAVE_API_URL => "http://127.0.0.1:4113/api/telegram/save-api";
static String get GET_APIS_URL => "http://127.0.0.1:4113/api/telegram/apis";
static String get DELETE_API_URL => "http://127.0.0.1:4113/api/telegram/delete-api";
static String get UPDATE_API_URL => "http://127.0.0.1:4113/api/telegram/update-api";
static String get SPAM_HISTORY_URL => "http://127.0.0.1:4113/api/spam/history";
static String get TELEGRAM_SPAM_URL => "http://127.0.0.1:4113/api/telegram/spam-otp";
static String get WHATSAPP_SPAM_URL => "http://127.0.0.1:4113/api/spam/whatsapp";
  
  int _selectedMenu = 0;
  bool _isLoading = false;
  String _statusMessage = "";
  bool _statusSuccess = false;
  bool _isConnectionTested = false;
  
  final TextEditingController _waPhoneController = TextEditingController();
  final TextEditingController _waDelayController = TextEditingController(text: "1000");
  final TextEditingController _waCountController = TextEditingController(text: "3");
  
  final TextEditingController _telegramPhoneController = TextEditingController();
  final TextEditingController _telegramDelayController = TextEditingController(text: "3000");
  final TextEditingController _telegramCountController = TextEditingController(text: "2");
  
  final TextEditingController _apiIdController = TextEditingController();
  final TextEditingController _apiHashController = TextEditingController();
  final TextEditingController _apiAliasController = TextEditingController();
  
  String _resultCode = "";
  String _debugOtp = "";
  List<String> _allDebugOtps = [];
  
  List<Map<String, dynamic>> _telegramApis = [];
  int _selectedApiIndex = -1;
  
  List<Map<String, dynamic>> _spamHistory = [];
  
  final Color _darkBg = const Color(0xFF0F172A);
  final Color _cardBg = const Color(0xFF1E293B);
  final Color _primaryColor = const Color(0xFF3B82F6);
  final Color _secondaryColor = const Color(0xFF10B981);
  final Color _accentColor = const Color(0xFF8B5CF6);
  final Color _telegramColor = const Color(0xFF229ED9);
  final Color _whatsappColor = const Color(0xFF25D366);
  final Color _textPrimary = const Color(0xFFF1F5F9);
  final Color _textSecondary = const Color(0xFF94A3B8);
  final Color _borderColor = const Color(0xFF334155);
  final Color _successColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _infoColor = const Color(0xFF3B82F6);
  
  final LinearGradient _primaryGradient = const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  final LinearGradient _successGradient = const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  final LinearGradient _telegramGradient = const LinearGradient(
    colors: [Color(0xFF229ED9), Color(0xFF2AABEE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  final LinearGradient _whatsappGradient = const LinearGradient(
    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _waPhoneController.dispose();
    _waDelayController.dispose();
    _waCountController.dispose();
    _telegramPhoneController.dispose();
    _telegramDelayController.dispose();
    _telegramCountController.dispose();
    _apiIdController.dispose();
    _apiHashController.dispose();
    _apiAliasController.dispose();
    super.dispose();
  }

  void _initializeApp() {
    _testBackendConnection();
    _loadTelegramApis();
    _loadSpamHistory();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isLoading) {
        _loadTelegramApis();
        _loadSpamHistory();
      }
    });
  }

  Future<void> _testBackendConnection() async {
    setState(() => _isLoading = true);
    _statusMessage = "🔄 Menguji koneksi ke backend...";
    
    try {
      final response = await http.get(
        Uri.parse("http://127.0.0.1:4113/health"),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        setState(() {
          _isConnectionTested = true;
          _statusSuccess = true;
          _statusMessage = "✅ Tersambung ke backend OTAX";
        });
        _showSnackBar("✅ Tersambung ke backend OTAX", _successColor);
      } else {
        throw Exception("Server merespons ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isConnectionTested = false;
        _statusSuccess = false;
        _statusMessage = "⚠️ Gagal terkoneksi: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal terkoneksi: ${e.toString().replaceAll('Exception: ', '')}", _warningColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTelegramApis() async {
    try {
      final response = await http.get(
        Uri.parse("$GET_APIS_URL?username=${widget.username}&session_key=${widget.sessionKey}"),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _telegramApis = List<Map<String, dynamic>>.from(data['apis'] ?? []);
            _selectedApiIndex = _telegramApis.isNotEmpty ? 0 : -1;
          });
        }
      }
    } catch (e) {
      print("Error loading APIs: $e");
    }
  }

  Future<void> _addTelegramApi() async {
    if (_apiIdController.text.isEmpty || _apiHashController.text.isEmpty) {
      _showSnackBar("API ID dan Hash harus diisi", _errorColor);
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(_apiIdController.text)) {
      _showSnackBar("API ID harus berupa angka", _errorColor);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "🔄 Menambahkan API Telegram...";
    });

    try {
      final payload = {
        "api_id": _apiIdController.text.trim(),
        "api_hash": _apiHashController.text.trim(),
        "alias": _apiAliasController.text.trim().isEmpty 
            ? "API-${_telegramApis.length + 1}" 
            : _apiAliasController.text.trim(),
        "username": widget.username,
        "session_key": widget.sessionKey,
      };

      final response = await http.post(
        Uri.parse(SAVE_API_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _statusSuccess = true;
          _statusMessage = "✅ API berhasil ditambahkan";
        });
        
        await _loadTelegramApis();
        
        _apiIdController.clear();
        _apiHashController.clear();
        _apiAliasController.clear();
        
        _showSnackBar("✅ API berhasil ditambahkan", _successColor);
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _selectedMenu = 1;
            });
          }
        });
      } else {
        throw Exception(data['message'] ?? "Gagal menambahkan API");
      }
    } catch (e) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = "❌ Gagal: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal: ${e.toString().replaceAll('Exception: ', '')}", _errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeTelegramApi(int index) async {
    if (index < 0 || index >= _telegramApis.length) return;

    final api = _telegramApis[index];
    final confirmed = await _showConfirmationDialog(
      title: "Hapus API",
      message: "Yakin menghapus API '${api['alias']}'?",
      confirmColor: _errorColor,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "🔄 Menghapus API...";
    });

    try {
      final payload = {
        "api_id": api['id'],
        "username": widget.username,
        "session_key": widget.sessionKey,
      };

      final response = await http.delete(
        Uri.parse(DELETE_API_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _statusSuccess = true;
          _statusMessage = "✅ API berhasil dihapus";
        });
        
        await _loadTelegramApis();
        _showSnackBar("✅ API berhasil dihapus", _successColor);
      } else {
        throw Exception(data['message'] ?? "Gagal menghapus API");
      }
    } catch (e) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = "❌ Gagal: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal: ${e.toString().replaceAll('Exception: ', '')}", _errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleApiStatus(int index) async {
    if (index < 0 || index >= _telegramApis.length) return;

    final api = _telegramApis[index];
    final newStatus = !(api['is_active'] ?? true);

    setState(() {
      _isLoading = true;
      _statusMessage = "🔄 Memperbarui status API...";
    });

    try {
      final payload = {
        "api_id": api['id'],
        "is_active": newStatus,
        "username": widget.username,
        "session_key": widget.sessionKey,
      };

      final response = await http.put(
        Uri.parse(UPDATE_API_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _statusSuccess = true;
          _statusMessage = newStatus ? "✅ API diaktifkan" : "✅ API dinonaktifkan";
        });
        
        await _loadTelegramApis();
        _showSnackBar(newStatus ? "API diaktifkan" : "API dinonaktifkan", _successColor);
      } else {
        throw Exception(data['message'] ?? "Gagal memperbarui API");
      }
    } catch (e) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = "❌ Gagal: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal: ${e.toString().replaceAll('Exception: ', '')}", _errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeWhatsAppSpam() async {
    if (_waPhoneController.text.isEmpty) {
      _showSnackBar("Masukkan nomor WhatsApp terlebih dahulu", _errorColor);
      return;
    }

    String phone = _formatPhoneNumber(_waPhoneController.text);
    
    if (!_isValidInternationalPhone(phone)) {
      _showSnackBar("Format nomor internasional tidak valid", _errorColor);
      return;
    }

    final count = int.tryParse(_waCountController.text) ?? 3;
    if (count <= 0 || count > 20) {
      _showSnackBar("Jumlah spam hanya 1-20", _errorColor);
      return;
    }

    final delay = int.tryParse(_waDelayController.text) ?? 1000;
    if (delay < 500 || delay > 10000) {
      _showSnackBar("Delay hanya 500-10000 ms", _errorColor);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "🚀 Memulai spam WhatsApp...";
      _statusSuccess = false;
      _resultCode = "";
      _allDebugOtps.clear();
    });

    try {
      final payload = {
        "phone": phone,
        "delay": delay,
        "count": count,
        "username": widget.username,
        "session_key": widget.sessionKey,
        "anti_flood": count <= 5,
      };

      final response = await http.post(
        Uri.parse(WHATSAPP_SPAM_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _resultCode = data['pairing_code'] ?? data['code'] ?? data['debug_code'] ?? "Tidak ada kode";
          _statusSuccess = true;
          _statusMessage = "✅ Berhasil! ${data['message'] ?? 'Kode pairing dikirim ke $phone'}";
          if (data['all_debug_otps'] != null) {
            _allDebugOtps = List<String>.from(data['all_debug_otps']);
          }
        });
        
        await _saveSpamHistory("WhatsApp", phone, _resultCode);
        _showSnackBar("Spam WhatsApp berhasil", _successColor);
      } else {
        throw Exception(data['message'] ?? "Gagal mengirim spam WhatsApp");
      }
    } catch (e) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = "❌ Gagal: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal: ${e.toString().replaceAll('Exception: ', '')}", _errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeTelegramSpam() async {
    if (_telegramPhoneController.text.isEmpty) {
      _showSnackBar("Masukkan nomor Telegram terlebih dahulu", _errorColor);
      return;
    }

    if (_telegramApis.isEmpty) {
      _showSnackBar("Tambahkan API Telegram terlebih dahulu di tab API", _errorColor);
      return;
    }

    if (_selectedApiIndex < 0 || _selectedApiIndex >= _telegramApis.length) {
      _showSnackBar("Pilih API Telegram terlebih dahulu", _errorColor);
      return;
    }

    String phone = _formatPhoneNumber(_telegramPhoneController.text);
    
    if (!_isValidInternationalPhone(phone)) {
      _showSnackBar("Format nomor internasional tidak valid", _errorColor);
      return;
    }

    final count = int.tryParse(_telegramCountController.text) ?? 2;
    if (count <= 0 || count > 20) {
      _showSnackBar("Jumlah spam hanya 1-20", _errorColor);
      return;
    }

    final delay = int.tryParse(_telegramDelayController.text) ?? 3000;
    if (delay < 1000 || delay > 10000) {
      _showSnackBar("Delay hanya 1000-10000 ms", _errorColor);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "🚀 Memulai spam Telegram...";
      _statusSuccess = false;
      _debugOtp = "";
      _allDebugOtps.clear();
    });

    try {
      final selectedApi = _telegramApis[_selectedApiIndex];
      final payload = {
        "phone_number": phone,
        "api_id": selectedApi['id'],
        "delay": delay,
        "count": count,
        "username": widget.username,
        "session_key": widget.sessionKey,
        "anti_flood": true,
      };

      final response = await http.post(
        Uri.parse(TELEGRAM_SPAM_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 40));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _debugOtp = data['debug_otp'] ?? data['all_debug_otps']?.first ?? "Tidak ada OTP";
          _statusSuccess = true;
          _statusMessage = "✅ ${data['message'] ?? 'OTP berhasil dikirim'} (API: ${selectedApi['alias']})";
          if (data['all_debug_otps'] != null) {
            _allDebugOtps = List<String>.from(data['all_debug_otps']);
          }
        });
        
        await _saveSpamHistory("Telegram", phone, _debugOtp);
        _showSnackBar("Spam Telegram berhasil", _successColor);
      } else {
        throw Exception(data['message'] ?? "Gagal mengirim spam Telegram");
      }
    } catch (e) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = "❌ Gagal: ${e.toString().replaceAll('Exception: ', '')}";
      });
      _showSnackBar("Gagal: ${e.toString().replaceAll('Exception: ', '')}", _errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSpamHistory() async {
    try {
      final response = await http.get(
        Uri.parse("$SPAM_HISTORY_URL?username=${widget.username}&session_key=${widget.sessionKey}"),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _spamHistory = List<Map<String, dynamic>>.from(data['history'] ?? []);
          });
        }
      }
    } catch (e) {
      print("Error loading history: $e");
    }
  }

  Future<void> _saveSpamHistory(String type, String phone, String code) async {
    try {
      final payload = {
        "type": type,
        "phone": phone,
        "code": code,
        "username": widget.username,
        "session_key": widget.sessionKey,
        "timestamp": DateTime.now().toIso8601String(),
      };

      await http.post(
        Uri.parse(SPAM_HISTORY_URL),
        headers: _buildHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      
      await _loadSpamHistory();
    } catch (e) {
      print("Error saving history: $e");
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await _showConfirmationDialog(
      title: "Hapus Riwayat",
      message: "Yakin menghapus semua riwayat spam?",
      confirmColor: _errorColor,
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse("$SPAM_HISTORY_URL/clear?username=${widget.username}&session_key=${widget.sessionKey}"),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _spamHistory.clear();
          });
          _showSnackBar("Riwayat berhasil dihapus", _successColor);
        }
      }
    } catch (e) {
      _showSnackBar("Gagal menghapus riwayat: $e", _errorColor);
    }
  }

  bool _isValidInternationalPhone(String phone) {
    if (phone.length < 12) return false;
    if (!phone.startsWith('+')) return false;
    final digits = phone.substring(1);
    if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
    return true;
  }

  String _formatPhoneNumber(String input) {
    String digits = input.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digits.isEmpty) return '';
    
    if (digits.startsWith('0')) {
      return '+62${digits.substring(1)}';
    }
    
    if (digits.startsWith('62')) {
      return '+$digits';
    }
    
    if (input.startsWith('+')) {
      return input;
    }
    
    if (!digits.startsWith('+')) {
      return '+$digits';
    }
    
    return digits;
  }

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.sessionKey}',
      'X-OTAX-User': widget.username,
      'X-OTAX-Timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isConnectionTested ? _successGradient : LinearGradient(
                    colors: [_warningColor, _warningColor.withOpacity(0.7)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isConnectionTested ? Icons.check_circle : Icons.wifi_find_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Status Koneksi",
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isConnectionTested ? "Terhubung ke server" : "Menghubungkan...",
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: _primaryColor, size: 20),
                onPressed: _isLoading ? null : _testBackendConnection,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                _buildStatusRow("Status Server", _isConnectionTested ? "Online" : "Offline", 
                    _isConnectionTested ? _successColor : _errorColor),
                _buildStatusRow("Total API", "${_telegramApis.length} API", _telegramColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSelector() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        children: [
          _buildMenuButton(
            index: 0,
            icon: FontAwesomeIcons.whatsapp,
            label: "WhatsApp",
            gradient: _whatsappGradient,
          ),
          Container(width: 1, height: 30, color: _borderColor),
          _buildMenuButton(
            index: 1,
            icon: Icons.telegram,
            label: "Telegram",
            gradient: _telegramGradient,
          ),
          Container(width: 1, height: 30, color: _borderColor),
          _buildMenuButton(
            index: 2,
            icon: Icons.api,
            label: "API",
            gradient: _primaryGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required int index,
    required FaIconData icon,
    required String label,
    required LinearGradient gradient,
  }) {
    final isSelected = _selectedMenu == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMenu = index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? gradient : null,
            borderRadius: BorderRadius.circular(16),
            color: isSelected ? null : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : _textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormHeader(
          icon: FontAwesomeIcons.whatsapp,
          title: "SPAM WHATSAPP",
          subtitle: "Kirim kode pairing ke nomor WhatsApp",
          gradient: _whatsappGradient,
        ),
        const SizedBox(height: 20),
        
        _buildPhoneInput(
          controller: _waPhoneController,
          label: "Nomor WhatsApp",
          hint: "Contoh: +6281234567890",
          color: _whatsappColor,
        ),
        
        const SizedBox(height: 20),
        
        Text(
          "PENGATURAN",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(
                controller: _waDelayController,
                label: "DELAY (ms)",
                icon: Icons.timer,
                color: _whatsappColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberInput(
                controller: _waCountController,
                label: "JUMLAH",
                icon: Icons.repeat,
                color: _whatsappColor,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        _buildActionButton(
          label: "MULAI SPAM WHATSAPP",
          color: _whatsappColor,
          onPressed: _executeWhatsAppSpam,
          icon: Icons.send,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildTelegramForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormHeader(
          icon: Icons.telegram,
          title: "SPAM TELEGRAM",
          subtitle: "Kirim OTP spam ke nomor Telegram",
          gradient: _telegramGradient,
        ),
        const SizedBox(height: 20),
        
        if (_telegramApis.isNotEmpty) ...[
          _buildApiSelector(),
          const SizedBox(height: 20),
        ],
        
        _buildPhoneInput(
          controller: _telegramPhoneController,
          label: "Nomor Telegram",
          hint: "Contoh: +6281234567890",
          color: _telegramColor,
        ),
        
        const SizedBox(height: 20),
        
        Text(
          "PENGATURAN",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildNumberInput(
                controller: _telegramDelayController,
                label: "DELAY (ms)",
                icon: Icons.timer,
                color: _telegramColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNumberInput(
                controller: _telegramCountController,
                label: "JUMLAH",
                icon: Icons.repeat,
                color: _telegramColor,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        _buildActionButton(
          label: _telegramApis.isEmpty ? "TAMBAH API TERLEBIH DAHULU" : "MULAI SPAM TELEGRAM",
          color: _telegramApis.isEmpty ? _borderColor : _telegramColor,
          onPressed: _telegramApis.isEmpty ? () => setState(() => _selectedMenu = 2) : _executeTelegramSpam,
          icon: Icons.telegram,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildApiSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PILIH API",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: DropdownButton<int>(
              value: _selectedApiIndex,
              dropdownColor: _darkBg,
              underline: const SizedBox(),
              isExpanded: true,
              items: List.generate(_telegramApis.length, (index) {
                final api = _telegramApis[index];
                final isActive = api['is_active'] ?? true;
                return DropdownMenuItem<int>(
                  value: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? _telegramColor.withOpacity(0.1) : _errorColor.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                color: isActive ? _telegramColor : _errorColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                api['alias'] ?? "API-${index + 1}",
                                style: TextStyle(
                                  color: isActive ? _textPrimary : _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Digunakan: ${api['used_count'] ?? 0}x",
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedApiIndex = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiManagerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormHeader(
          icon: Icons.api,
          title: "KELOLA API TELEGRAM",
          subtitle: "Kelola kredensial API untuk spam Telegram",
          gradient: _primaryGradient,
        ),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TAMBAH API BARU",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Dapatkan kredensial dari my.telegram.org",
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildInputField(
                controller: _apiIdController,
                label: "API ID",
                hint: "Masukkan API ID (angka)",
                icon: Icons.vpn_key,
                isNumeric: true,
              ),
              const SizedBox(height: 16),
              
              _buildInputField(
                controller: _apiHashController,
                label: "API HASH",
                hint: "Masukkan 32 karakter API Hash",
                icon: Icons.fingerprint,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              _buildInputField(
                controller: _apiAliasController,
                label: "ALIAS (opsional)",
                hint: "Nama untuk API ini",
                icon: Icons.title,
              ),
              const SizedBox(height: 24),
              
              _buildActionButton(
                label: "TAMBAH API",
                color: _primaryColor,
                onPressed: _addTelegramApi,
                icon: Icons.add,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
        
        if (_telegramApis.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            "API TERDAFTAR",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._telegramApis.asMap().entries.map((entry) {
            final index = entry.key;
            final api = entry.value;
            return _buildApiCard(api, index);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildApiCard(Map<String, dynamic> api, int index) {
    final isActive = api['is_active'] ?? true;
    final isSelected = index == _selectedApiIndex;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _primaryColor : _borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _primaryColor.withOpacity(0.1) : _errorColor.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              (index + 1).toString(),
              style: TextStyle(
                color: isActive ? _primaryColor : _errorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        title: Text(
          api['alias'] ?? "API-${index + 1}",
          style: TextStyle(
            color: isActive ? _textPrimary : _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          "ID: ${api['api_id']} • Digunakan: ${api['used_count'] ?? 0}x",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isActive ? Icons.toggle_on : Icons.toggle_off,
                color: isActive ? _successColor : _errorColor,
                size: 30,
              ),
              onPressed: () => _toggleApiStatus(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete, color: _errorColor, size: 20),
              onPressed: () => _removeTelegramApi(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required FaIconData icon,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: color.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(
              isLoading ? "MEMPROSES..." : label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader({
    required FaIconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    "+",
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 30, color: _borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\+]')),
                    ],
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Format: +[kode negara][nomor]  Contoh: +62, +1, +44",
          style: TextStyle(
            color: _textSecondary.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
    required FaIconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required FaIconData icon,
    bool isNumeric = false,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(icon, color: _textSecondary, size: 20),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: controller,
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    obscureText: obscureText,
                    inputFormatters: isNumeric
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    if (_statusMessage.isEmpty) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusSuccess 
            ? _successColor.withOpacity(0.1)
            : _errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusSuccess ? _successColor : _errorColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _statusSuccess ? Icons.check_circle : Icons.error,
                color: _statusSuccess ? _successColor : _errorColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18),
                color: _textSecondary,
                onPressed: () {
                  setState(() {
                    _statusMessage = "";
                  });
                },
              ),
            ],
          ),
          
          if ((_resultCode.isNotEmpty || _allDebugOtps.isNotEmpty) && _statusSuccess)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedMenu == 0 ? "KODE PAIRING" : "KODE OTP",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      children: [
                        if (_resultCode.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _resultCode,
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.copy, size: 20),
                                color: _primaryColor,
                                onPressed: () {
                                  flutter_services.Clipboard.setData(
                                    flutter_services.ClipboardData(text: _resultCode),
                                  ).then((_) {
                                    _showSnackBar("Disalin ke clipboard", _successColor);
                                  });
                                },
                              ),
                            ],
                          ),
                        if (_allDebugOtps.isNotEmpty) ...[
                          if (_resultCode.isNotEmpty) const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allDebugOtps.map((otp) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _telegramColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _telegramColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      otp,
                                      style: TextStyle(
                                        color: _telegramColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(Icons.copy, size: 14),
                                      color: _telegramColor,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        flutter_services.Clipboard.setData(
                                          flutter_services.ClipboardData(text: otp),
                                        ).then((_) {
                                          _showSnackBar("OTP disalin", _successColor);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: _infoColor, size: 24),
              const SizedBox(width: 12),
              Text(
                "INFORMASI PENTING",
                style: TextStyle(
                  color: _infoColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildInfoItem("Gunakan format internasional: +[kode negara][nomor]", Icons.check, _successColor),
              _buildInfoItem("Maksimal 20 spam per eksekusi", Icons.warning, _warningColor),
              _buildInfoItem("Delay: 500-10000ms untuk WhatsApp", FontAwesomeIcons.whatsapp, _whatsappColor),
              _buildInfoItem("Delay: 1000-10000ms untuk Telegram", Icons.telegram, _telegramColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required Color confirmColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _borderColor, width: 1),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
            ),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "KONFIRMASI",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory() async {
    await _loadSpamHistory();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: _primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "RIWAYAT SPAM",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: _textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_spamHistory.isNotEmpty)
                Row(
                  children: [
                    Text(
                      "Total: ${_spamHistory.length} data",
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearHistory,
                      icon: Icon(Icons.delete_sweep, color: _errorColor, size: 16),
                      label: Text(
                        "Hapus Semua",
                        style: TextStyle(color: _errorColor),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: _spamHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, color: _textSecondary, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Belum ada riwayat",
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _spamHistory.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final entry = _spamHistory[_spamHistory.length - 1 - index];
                          return _buildHistoryItem(entry);
                        },
                      ),
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "TUTUP",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> entry) {
    final isWhatsApp = entry['type'] == 'WhatsApp';
    final time = DateTime.parse(entry['timestamp']);
    final timeStr = "${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    final code = entry['code'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhatsApp ? _whatsappColor.withOpacity(0.1) : _telegramColor.withOpacity(0.1),
          ),
          child: Center(
            child: Icon(
              isWhatsApp ? FontAwesomeIcons.whatsapp : null,
              color: isWhatsApp ? _whatsappColor : _telegramColor,
              size: 20,
            ),
          ),
        ),
        title: Text(
          entry['phone'],
          style: TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          "${isWhatsApp ? "WhatsApp" : "Telegram"} • $timeStr",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isWhatsApp ? _whatsappColor : _telegramColor,
              width: 1,
            ),
          ),
          child: Text(
            code.length > 6 ? "${code.substring(0, 6)}..." : code,
            style: TextStyle(
              color: isWhatsApp ? _whatsappColor : _telegramColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: _textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OTAX SPAM PAIR",
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Sistem Manajemen Spam Profesional",
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.history, color: _primaryColor),
                    onPressed: _showHistory,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildConnectionStatus(),
              
              const SizedBox(height: 24),
              
              _buildMenuSelector(),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor, width: 1),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: [
                    _buildWhatsAppForm(),
                    _buildTelegramForm(),
                    _buildApiManagerForm(),
                  ][_selectedMenu],
                ),
              ),
              
              _buildResultCard(),
              
              const SizedBox(height: 24),
              
              _buildInfoCard(),
              
              const SizedBox(height: 20),
              
              Center(
                child: Text(
                  "OTAX TEAM © 2026",
                  style: TextStyle(
                    color: _textSecondary.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}