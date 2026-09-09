import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'main.dart';
import 'dart:async';
class TesFuncPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const TesFuncPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<TesFuncPage> createState() => _TesFuncPageState();
}

class _TesFuncPageState extends State<TesFuncPage> {
  final TextEditingController _funcController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _delayController = TextEditingController(text: "1000");
  final TextEditingController _loopsController = TextEditingController(text: "1");
  
  bool _isSending = false;
  bool _isLoadingFile = false;
  String? _selectedFileName;
  String? _fileContent;
  List<Map<String, dynamic>> _history = [];
  
  final Color _primaryColor = const Color(0xFF0097A7);
  final Color _accentColor = const Color(0xFF00BCD4);
  final Color _backgroundColor = const Color(0xFF0F1419);
  final Color _cardColor = const Color(0xFF1A1F25);
  final Color _warningColor = Color(0xFFFFA000);
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('tes_func_history');
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      setState(() {
        _history = historyList.cast<Map<String, dynamic>>();
      });
    }
  }
  
  Future<void> _saveToHistory(Map<String, dynamic> data) async {
    _history.insert(0, {
      ...data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Batasi hanya 10 riwayat terbaru
    if (_history.length > 10) {
      _history = _history.sublist(0, 10);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tes_func_history', jsonEncode(_history));
  }
  
  Future<void> _pickJsFile() async {
    try {
      setState(() {
        _isLoadingFile = true;
      });
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        
        if (path != null) {
          final fileData = File(path);
          final content = await fileData.readAsString();
          
          setState(() {
            _selectedFileName = file.name;
            _fileContent = content;
            _funcController.text = content;
          });
          
          _showSuccessDialog('File Loaded', 'Berhasil memuat file: ${file.name}');
        }
      }
    } on PlatformException catch (e) {
      _showErrorDialog('Error', 'Gagal memuat file: ${e.message}');
    } catch (e) {
      _showErrorDialog('Error', 'Terjadi kesalahan: $e');
    } finally {
      setState(() {
        _isLoadingFile = false;
      });
    }
  }
  
  String? _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Handle format Indonesia
    if (cleaned.startsWith('08')) {
      return '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('0')) {
      return '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('62')) {
      return cleaned;
    } else if (cleaned.startsWith('+62')) {
      return cleaned.substring(1);
    }
    
    // Return as is for international numbers
    return cleaned.isNotEmpty ? cleaned : null;
  }
  Future<bool> _hasSender() async {
  try {
    final res = await http.get(
      Uri.parse(
        "http://127.0.0.1:4113/mySender?key=${widget.sessionKey}",
      ),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) return false;

    final data = jsonDecode(res.body);
    return data["valid"] == true &&
        data["connections"] != null &&
        (data["connections"] as List).isNotEmpty;
  } catch (_) {
    return false;
  }
}
Future<void> _sendFunction() async {
  final target = _formatPhoneNumber(_targetController.text.trim());
  final func = _funcController.text.trim();
  final delay = int.tryParse(_delayController.text.trim()) ?? 1000;
  final loops = int.tryParse(_loopsController.text.trim()) ?? 1;

  // ===== VALIDASI INPUT =====
  if (target == null || target.isEmpty) {
    _showErrorDialog('Target Required', 'Masukkan nomor target yang valid');
    return;
  }

  if (func.isEmpty) {
    _showErrorDialog('Function Required', 'Masukkan function atau pilih file .js');
    return;
  }

  // ===== CEK SENDER =====
  final hasSender = await _hasSender();
  if (!hasSender) {
    _showProfessionalDialog(
      "Sender Required",
      "Please connect your sender device before sending function.",
      Icons.wifi_find_rounded,
      _warningColor,
    );
    return;
  }

  setState(() {
    _isSending = true;
  });

  try {
    // ===== SIMPAN RIWAYAT =====
    await _saveToHistory({
      'target': target,
      'function': func.substring(0, min(100, func.length)) +
          (func.length > 100 ? '...' : ''),
      'delay': delay,
      'loops': loops,
      'fileName': _selectedFileName,
    });

    // ===== DEBUG LOG =====
    print('=' * 50);
    print('Sending function to: $target');
    print('Function length: ${func.length} chars');
    print('First 200 chars: ${func.substring(0, min(200, func.length))}');
    print('Delay: $delay, Loops: $loops');
    print('Session key: ${widget.sessionKey}');
    print('Username: ${widget.username}');
    print('Role: ${widget.role}');
    print('=' * 50);

    // ===== KIRIM KE SERVER =====
    final response = await http
        .post(
          Uri.parse('http://127.0.0.1:4113/test-function'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.sessionKey}',
          },
          body: jsonEncode({
            'key': widget.sessionKey,
            'username': widget.username,
            'target': target,
            'function': func,
            'delay': delay,
            'loops': loops,
            'role': widget.role,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        )
        .timeout(const Duration(seconds: 30));

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        _showSuccessDialog(
          'Success', 
          'Function berhasil dikirim!\n'
          'Role: ${data['role']}\n'
          'Targets: ${data['targets'] ?? target}\n'
          'Loops: ${data['loops'] ?? loops}\n'
          'Delay: ${data['delay'] ?? delay}ms'
        );
        _targetController.clear();
      } else {
        String errorMsg = data['message'] ?? 'Gagal mengirim function';
        if (data['cooldown'] == true) {
          errorMsg += '\nCooldown: ${data['wait']} detik';
        }
        _showErrorDialog('Failed', errorMsg);
      }
    } else {
      _showErrorDialog('Server Error', 'Status code: ${response.statusCode}\nBody: ${response.body}');
    }
  } on http.ClientException catch (e) {
    _showErrorDialog('Connection Error', 'Tidak dapat terhubung ke server: $e');
  } on TimeoutException catch (_) {
    _showErrorDialog('Timeout', 'Koneksi timeout setelah 30 detik');
  } catch (e) {
    _showErrorDialog('Error', 'Terjadi kesalahan: $e');
  } finally {
    setState(() {
      _isSending = false;
    });
  }
}
  void _showProfessionalDialog(
  String title,
  String message,
  IconData icon,
  Color color,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      );
    },
  );
}
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title,
        message,
        Icons.check_circle,
        Colors.green,
      ),
    );
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title,
        message,
        Icons.error,
        Colors.red,
      ),
    );
  }
  
  Widget _buildDialog(String title, String message, IconData icon, Color color) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _clearFields() {
    _funcController.clear();
    _targetController.clear();
    _delayController.text = "1000";
    _loopsController.text = "1";
    setState(() {
      _selectedFileName = null;
      _fileContent = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'TES FUNC',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              _showHistoryDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor.withOpacity(0.2), _accentColor.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryColor, _accentColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.code, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Function',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kirim function custom dengan delay & loops',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
_buildInputField(
  label: 'Nomor Target',
  hint: '62xxx (contoh: 6281234567890)',
  controller: _targetController,
  icon: Icons.phone,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
  ],
),
            
            const SizedBox(height: 20),
            
            // Function Input
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Function / Message',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedFileName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accentColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file, size: 14, color: _accentColor),
                            const SizedBox(width: 6),
                            Text(
                              _selectedFileName!,
                              style: TextStyle(color: _accentColor, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _funcController,
                    maxLines: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Paste function atau message di sini...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingFile ? null : _pickJsFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor.withOpacity(0.2),
                          foregroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: _primaryColor.withOpacity(0.3)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isLoadingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file, size: 18),
                        label: Text(_isLoadingFile ? 'Loading...' : 'Pilih File .js'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _funcController.clear();
                        setState(() {
                          _selectedFileName = null;
                          _fileContent = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Delay & Loops Row
            Row(
              children: [
                Expanded(
                  child: _buildNumberInput(
                    label: 'Delay (ms)',
                    hint: '1000',
                    controller: _delayController,
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberInput(
                    label: 'Jumlah Loops',
                    hint: '1',
                    controller: _loopsController,
                    icon: Icons.repeat,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendFunction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSending ? _accentColor.withOpacity(0.5) : _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 5,
                      shadowColor: _accentColor.withOpacity(0.5),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      _isSending ? 'SENDING...' : 'KIRIM FUNCTION',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _clearFields,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.refresh, size: 24),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Info Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: _accentColor, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Informasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Gunakan format nomor internasional (62xxx)\n'
                    '• File .js akan dibaca sebagai plain text\n'
                    '• Delay dalam milidetik (ms)\n'
                    '• Loops menentukan jumlah pengiriman\n'
                    '• Function akan dikirim sebagai payload',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInputField({
  required String label,
  required String hint,
  required TextEditingController controller,
  required IconData icon,
  // Tambahkan parameter baru untuk tipe keyboard (opsional)
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          controller: controller,
          // Atur keyboard type
          keyboardType: keyboardType ?? TextInputType.text,
          // Tambahkan input formatter untuk membatasi input
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
            prefixIcon: Icon(icon, color: _accentColor),
          ),
        ),
      ),
    ],
  );
}
  
  Widget _buildNumberInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(icon, color: _accentColor),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _accentColor.withOpacity(0.3), width: 1),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.history, color: _accentColor, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Riwayat Tes Func',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, color: Colors.white.withOpacity(0.3), size: 60),
                      const SizedBox(height: 20),
                      Text(
                        'Belum ada riwayat',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final timestamp = DateTime.parse(item['timestamp']);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item['target'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${item['delay']}ms',
                                  style: TextStyle(
                                    color: _accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    '${item['loops']}x',
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['function'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (item['fileName'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.insert_drive_file, size: 12, color: _accentColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['fileName'],
                                          style: TextStyle(
                                            color: _accentColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('TUTUP'),
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