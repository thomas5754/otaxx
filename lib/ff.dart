import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/services.dart';

class FreeFireToolsPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const FreeFireToolsPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<FreeFireToolsPage> createState() => _FreeFireToolsPageState();
}

class _FreeFireToolsPageState extends State<FreeFireToolsPage> with SingleTickerProviderStateMixin {
  // FIXED: Tambah baseUrl yang diperlukan
  final String baseUrl = 'http://127.0.0.1:4113';

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final Color background = const Color(0xFF0E1111);
  final Color surface = const Color(0xFF1A1E1E);
  final Color surfaceLight = const Color(0xFF252A2A);
  final Color accent = const Color(0xFF546E7A);
  final Color accentSoft = const Color(0xFF627B8B);
  final Color textPrimary = Colors.white;
  final Color textSecondary = const Color(0xFFB0BEC5);
  final Color success = const Color(0xFF81C784);
  final Color borderColor = const Color(0xFF37474F);

  final List<String> servers = ['ind', 'sg', 'br', 'vn', 'th', 'ph', 'id', 'my', 'us', 'eu'];
  final List<String> matchModes = ['CAREER', 'NORMAL', 'RANKED'];
  final List<String> gameModes = ['br', 'cs'];

  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _uidController2 = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _callSignController = TextEditingController(text: '7');

  String _selectedServer = 'ind';
  String _selectedMatchMode = 'CAREER';
  String _selectedGameMode = 'br';
  String _selectedServer2 = 'ind';
  String _selectedServer3 = 'ind';
  bool _needGalleryInfo = true;

  bool _isLoading1 = false;
  bool _isLoading2 = false;
  bool _isLoading3 = false;

  String _response1 = '';
  String _response2 = '';
  String _response3 = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _uidController.dispose();
    _uidController2.dispose();
    _keywordController.dispose();
    _callSignController.dispose();
    super.dispose();
  }

  Future<void> _getPlayerStats() async {
    if (_uidController.text.isEmpty) {
      _showPesan('UID tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading1 = true;
      _response1 = '';
    });

    try {
      final url = Uri.parse(
        'http://127.0.0.1:4113/get_player_stats'
        '?server=${_selectedServer}'
        '&uid=${_uidController.text}'
        '&matchmode=${_selectedMatchMode}'
        '&gamemode=${_selectedGameMode}'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 25));
      setState(() {
        _response1 = _formatJson(response.body);
      });
    } catch (e) {
      setState(() {
        _response1 = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() => _isLoading1 = false);
    }
  }

  Future<void> _getPlayerPersonalShow() async {
    if (_uidController2.text.isEmpty) {
      _showPesan('UID tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading2 = true;
      _response2 = '';
    });

    try {
      final url = Uri.parse(
        'http://127.0.0.1:4113/get_player_personal_show'
        '?server=${_selectedServer2}'
        '&uid=${_uidController2.text}'
        '&need_gallery_info=$_needGalleryInfo'
        '&call_sign_src=${_callSignController.text}'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 25));
      setState(() {
        _response2 = _formatJson(response.body);
      });
    } catch (e) {
      setState(() {
        _response2 = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() => _isLoading2 = false);
    }
  }

  Future<void> _searchAccountByKeyword() async {
    if (_keywordController.text.isEmpty) {
      _showPesan('Keyword tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading3 = true;
      _response3 = '';
    });

    try {
      final url = Uri.parse(
        'http://127.0.0.1:4113/get_search_account_by_keyword'
        '?server=${_selectedServer3}'
        '&keyword=${_keywordController.text}'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 25));
      setState(() {
        _response3 = _formatJson(response.body);
      });
    } catch (e) {
      setState(() {
        _response3 = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() => _isLoading3 = false);
    }
  }

  String _formatJson(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      return jsonString;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showPesan('Response disalin ke clipboard!');
  }

  void _showPesan(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      _buildToolSection1(),
                      const SizedBox(height: 24),
                      _buildToolSection2(),
                      const SizedBox(height: 24),
                      _buildToolSection3(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.sports_esports, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREE FIRE TOOLS',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tools Searching Player Free Fire',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolSection1() {
    return _buildCard(
      title: 'STATISTIK PLAYER',
      subtitle: 'Ambil data statistik player lengkap',
      icon: Icons.bar_chart,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('UID Player'),
          const SizedBox(height: 8),
          _buildTextField(_uidController, 'Masukkan UID player...', Icons.person),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildServerDropdown(_selectedServer, (v) => setState(() => _selectedServer = v!))),
              const SizedBox(width: 16),
              Expanded(child: _buildMatchModeDropdown(_selectedMatchMode, (v) => setState(() => _selectedMatchMode = v!))),
            ],
          ),
          const SizedBox(height: 16),
          _buildGameModeDropdown(_selectedGameMode, (v) => setState(() => _selectedGameMode = v!)),
        ],
      ),
      isLoading: _isLoading1,
      response: _response1,
      onExecute: _getPlayerStats,
    );
  }

  Widget _buildToolSection2() {
    return _buildCard(
      title: 'PROFIL PLAYER',
      subtitle: 'Lihat profil dan gallery player',
      icon: Icons.person_search,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('UID Player'),
          const SizedBox(height: 8),
          _buildTextField(_uidController2, 'Masukkan UID player...', Icons.person),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildServerDropdown(_selectedServer2, (v) => setState(() => _selectedServer2 = v!))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Call Sign'),
                    const SizedBox(height: 8),
                    _buildTextField(_callSignController, 'Default: 7', Icons.numbers, width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSwitchTile('Perlu Info Gallery', _needGalleryInfo, (v) => setState(() => _needGalleryInfo = v)),
        ],
      ),
      isLoading: _isLoading2,
      response: _response2,
      onExecute: _getPlayerPersonalShow,
    );
  }

  Widget _buildToolSection3() {
    return _buildCard(
      title: 'CARI AKUN',
      subtitle: 'Cari player berdasarkan nickname',
      icon: Icons.search,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Keyword Nickname'),
          const SizedBox(height: 8),
          _buildTextField(_keywordController, 'Masukkan nickname player...', Icons.search),
          const SizedBox(height: 16),
          _buildServerDropdown(_selectedServer3, (v) => setState(() => _selectedServer3 = v!)),
        ],
      ),
      isLoading: _isLoading3,
      response: _response3,
      onExecute: _searchAccountByKeyword,
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget content,
    required bool isLoading,
    required String response,
    required VoidCallback onExecute,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentSoft.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentSoft, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: borderColor, height: 1, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onExecute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.rocket_launch, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'AMBIL DATA',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (response.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildResponsePanel(response),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePanel(String response) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.code, color: success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'HASIL RESPONSE',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(response),
                  icon: Icon(Icons.copy, color: textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  tooltip: 'Salin ke Clipboard',
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceLight,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                response,
                style: TextStyle(
                  color: success,
                  fontFamily: 'Monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {double? width}) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          keyboardType: icon == Icons.person || icon == Icons.numbers ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(icon, color: textSecondary, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildServerDropdown(String value, ValueChanged<String?> onChanged) {
    return _buildDropdown(
      label: 'Server',
      value: value,
      items: servers,
      onChanged: onChanged,
    );
  }

  Widget _buildMatchModeDropdown(String value, ValueChanged<String?> onChanged) {
    return _buildDropdown(
      label: 'Match Mode',
      value: value,
      items: matchModes,
      onChanged: onChanged,
    );
  }

  Widget _buildGameModeDropdown(String value, ValueChanged<String?> onChanged) {
    return _buildDropdown(
      label: 'Game Mode',
      value: value,
      items: gameModes,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: surface,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: Icon(Icons.arrow_drop_down, color: textSecondary, size: 24),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      item.toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
            activeTrackColor: accent.withOpacity(0.5),
            inactiveThumbColor: textSecondary,
            inactiveTrackColor: surface,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}