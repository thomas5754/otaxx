import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CpanelPage extends StatefulWidget {
  final String username;
  final String role;

  const CpanelPage({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<CpanelPage> createState() => _CpanelPageState();
}

class _CpanelPageState extends State<CpanelPage> with SingleTickerProviderStateMixin {
  final Color primaryDark = const Color(0xFF0C0C0F);
  final Color deepRed = const Color(0xFFD96B6B);
  final Color accentRed = const Color(0xFFD96B6B);
  final Color bloodRed = const Color(0xFFC25A5A);
  final Color cardDark = const Color(0xFF131318);
  final Color primaryWhite = Colors.white;
  final Color successGreen = const Color(0xFF52B788);
  final Color cyberBlue = const Color(0xFF7B8FF7);
  final Color cyberPurple = const Color(0xFF7B8FF7);

  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _ptlaController = TextEditingController();
  final TextEditingController _ptlcController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  final TextEditingController _panelNameController = TextEditingController();
  final TextEditingController _telegramIdController = TextEditingController();

  List<Map<String, dynamic>> _adpList = [];
  List<Map<String, dynamic>> _panelsList = [];
  String? _selectedAdpKey;
  double _memorySize = 1.0;
  String NODE_PACKAGES = '';
  String UNNODE_PACKAGES = '';
  String CMD_RUN = 'npm start';
  bool _isUnlimited = false;
  bool _isCreating = false;
  bool _isLoading = true;
  Map<String, dynamic>? _createdPanel;
  int _activeTab = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _storageKey = 'otax_adp_data';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAdpFromLocal(),
      _loadPanelsFromLocal(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadAdpFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encryptedData = prefs.getString('${_storageKey}_${widget.username}');
      
      if (encryptedData != null) {
        final jsonData = jsonDecode(encryptedData);
        setState(() {
          _adpList = List<Map<String, dynamic>>.from(jsonData);
          if (_adpList.isNotEmpty) _selectedAdpKey = _adpList.first['alias'];
        });
      }
    } catch (e) {
      _showSnackBar('Error loading ADP: $e', isError: true);
    }
  }

  Future<void> _saveAdpToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_storageKey}_${widget.username}',
        jsonEncode(_adpList)
      );
    } catch (e) {
      _showSnackBar('Error saving ADP: $e', isError: true);
    }
  }

  Future<void> _loadPanelsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? panelsData = prefs.getString('${_storageKey}_panels_${widget.username}');
      
      if (panelsData != null) {
        final jsonData = jsonDecode(panelsData);
        setState(() {
          _panelsList = List<Map<String, dynamic>>.from(jsonData);
        });
      }
    } catch (e) {
      // Silent error for panels load
    }
  }

  Future<void> _savePanelsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_storageKey}_panels_${widget.username}',
        jsonEncode(_panelsList)
      );
    } catch (e) {
      // Silent error for panels save
    }
  }

  Future<void> _saveAdp() async {
    if (_aliasController.text.isEmpty) {
      _showSnackBar('Alias harus diisi!', isError: true);
      return;
    }
    if (_ptlaController.text.isEmpty) {
      _showSnackBar('PTLA harus diisi!', isError: true);
      return;
    }
    if (_domainController.text.isEmpty) {
      _showSnackBar('Domain harus diisi!', isError: true);
      return;
    }

    final newAdp = {
      'alias': _aliasController.text.trim(),
      'ptla': _ptlaController.text.trim(),
      'ptlc': _ptlcController.text.trim(),
      'domain': _domainController.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _adpList.add(newAdp);
      _selectedAdpKey = newAdp['alias'];
    });

    await _saveAdpToLocal();

    _aliasController.clear();
    _ptlaController.clear();
    _ptlcController.clear();
    _domainController.clear();
    
    _showSnackBar('✅ ADP berhasil disimpan!');
    setState(() => _activeTab = 1);
  }

  Future<Map<String, dynamic>> _createUserPterodactyl(String domain, String ptla, String username, bool isAdmin) async {
    try {
      final email = isAdmin ? 
        '$username@admin.OTAX' : 
        (_isUnlimited ? '$username@unli.OTAX' : '$username@panel.OTAX');
      
      final password = isAdmin ? '${username}117' : '${username}001';

      final response = await http.post(
        Uri.parse('$domain/api/application/users'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $ptla',
        },
        body: jsonEncode({
          'email': email,
          'username': username,
          'first_name': username,
          'last_name': username,
          'language': 'en',
          'root_admin': isAdmin,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': data['attributes'],
          'email': email,
          'password': password,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['errors']?[0]['detail'] ?? 'Gagal membuat user',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _createServerPterodactyl(String domain, String ptla, Map<String, dynamic> user, String username, int memory, {bool isUnlimited = false}) async {
    try {
      const eggId = 15;
      const dockerImage = 'ghcr.io/parkervcp/yolks:nodejs_22';

      final startupCommand = 
        'if [[ -d .git ]] && [[ {{AUTO_UPDATE}} == "1" ]]; then git pull; fi; '
        'if [[ ! -z {{NODE_PACKAGES}} ]]; then /usr/local/bin/npm install {{NODE_PACKAGES}}; fi; '
        'if [[ ! -z {{UNNODE_PACKAGES}} ]]; then /usr/local/bin/npm uninstall {{UNNODE_PACKAGES}}; fi; '
        'if [ -f /home/container/package.json ]; then /usr/local/bin/npm install; fi; '
        '/usr/local/bin/{{CMD_RUN}}';

      final serverName = isUnlimited ? '${username}unli' : username;
      final locations = [1, 2, 3, 4, 5];
      final List<String> failedServerIds = [];

      for (final location in locations) {
        final response = await http.post(
          Uri.parse('$domain/api/application/servers'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $ptla',
          },
          body: jsonEncode({
            'name': serverName,
            'description': '',
            'user': user['id'],
            'egg': eggId,
            'docker_image': dockerImage,
            'startup': startupCommand,
            'environment': {
              'INST': 'npm',
              'USER_UPLOAD': '0',
              'AUTO_UPDATE': '0',
              'NODE_PACKAGES': NODE_PACKAGES,
              'UNNODE_PACKAGES': UNNODE_PACKAGES,
              'CMD_RUN': CMD_RUN,
            },
            'limits': {
              'memory': isUnlimited ? 0 : memory,
              'swap': 0,
              'disk': isUnlimited ? 0 : memory * 2,
              'io': 500,
              'cpu': isUnlimited ? 0 : 100,
            },
            'feature_limits': {
              'databases': 5,
              'backups': 5,
              'allocations': 1,
            },
            'deploy': {
              'locations': [location],
              'dedicated_ip': false,
              'port_range': [],
            },
          }),
        );

        final data = jsonDecode(response.body);
        
        if (response.statusCode == 201 && data['attributes'] != null) {
          for (final serverId in failedServerIds) {
            await http.delete(
              Uri.parse('$domain/api/application/servers/$serverId'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $ptla',
              },
            );
          }
          
          return {
            'success': true,
            'server': data['attributes'],
            'location': location,
          };
        } else if (data['meta']?['server_id'] != null) {
          failedServerIds.add(data['meta']['server_id'].toString());
        }
      }

      return {
        'success': false,
        'error': 'Gagal membuat server di semua lokasi',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<void> _createPanel() async {
    if (_selectedAdpKey == null) {
      _showSnackBar('Pilih ADP terlebih dahulu!', isError: true);
      return;
    }
    if (_panelNameController.text.isEmpty) {
      _showSnackBar('Nama panel wajib diisi!', isError: true);
      return;
    }

    setState(() {
      _isCreating = true;
      _createdPanel = null;
    });

    try {
      final selectedAdp = _adpList.firstWhere((adp) => adp['alias'] == _selectedAdpKey);
      final domain = _ensureHttps(selectedAdp['domain']);
      final ptla = selectedAdp['ptla'];
      final username = _panelNameController.text.trim();
      final memory = (_memorySize * 1024).toInt();

      final userResult = await _createUserPterodactyl(domain, ptla, username, false);
      
      if (!userResult['success']) {
        _showSnackBar(userResult['error'], isError: true);
        return;
      }

      final user = userResult['user'];
      final serverResult = await _createServerPterodactyl(
        domain, ptla, user, username, memory, 
        isUnlimited: _isUnlimited
      );
      
      if (!serverResult['success']) {
        _showSnackBar(serverResult['error'], isError: true);
        return;
      }

      final panelData = {
        'domain': domain,
        'username': user['username'],
        'email': userResult['email'],
        'password': userResult['password'],
        'userId': user['id'],
        'serverId': serverResult['server']['id'],
        'memory': _isUnlimited ? 0 : memory,
        'disk': _isUnlimited ? 0 : memory * 2,
        'cpu': _isUnlimited ? 0 : 100,
        'isUnlimited': _isUnlimited,
        'location': serverResult['location'],
        'createdAt': DateTime.now().toIso8601String(),
        'alias': _selectedAdpKey,
        'ptla': ptla,
        'ptlc': selectedAdp['ptlc'],
      };

      setState(() {
        _panelsList.add(panelData);
        _createdPanel = panelData;
      });

      await _savePanelsToLocal();

      _panelNameController.clear();
      _telegramIdController.clear();
      
      _showSnackBar('✨ Panel berhasil dibuat!');
      setState(() => _activeTab = 2);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _createAdminPanel() async {
    if (_selectedAdpKey == null) {
      _showSnackBar('Pilih ADP terlebih dahulu!', isError: true);
      return;
    }
    if (_panelNameController.text.isEmpty) {
      _showSnackBar('Nama admin wajib diisi!', isError: true);
      return;
    }

    setState(() => _isCreating = true);
    try {
      final selectedAdp = _adpList.firstWhere((adp) => adp['alias'] == _selectedAdpKey);
      final domain = _ensureHttps(selectedAdp['domain']);
      final ptla = selectedAdp['ptla'];
      final username = _panelNameController.text.trim();

      final userResult = await _createUserPterodactyl(domain, ptla, username, true);
      
      if (!userResult['success']) {
        _showSnackBar(userResult['error'], isError: true);
        return;
      }

      final user = userResult['user'];
      
      _showSnackBar('👑 Admin panel berhasil dibuat!');
      _panelNameController.clear();

      final adminData = '''
TYPE: user
➟ ID: ${user['id']}
➟ USERNAME: ${user['username']}
➟ EMAIL: ${userResult['email']}
➟ NAME: ${user['first_name']} ${user['last_name']}
➟ LANGUAGE: ${user['language']}
➟ ADMIN: ${user['root_admin']}
➟ CREATED AT: ${user['created_at']}
      ''';

      _copyToClipboard(adminData);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<List<Map<String, dynamic>>> _listServersPterodactyl(String domain, String ptla) async {
    try {
      final List<Map<String, dynamic>> servers = [];
      int page = 1;
      
      while (true) {
        final response = await http.get(
          Uri.parse('$domain/api/application/servers?page=$page&per_page=100'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $ptla',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> serverList = data['data'] ?? [];
          
          for (final server in serverList) {
            final attrs = server['attributes'];
            servers.add({
              'id': attrs['id'],
              'identifier': attrs['identifier'],
              'name': attrs['name'],
              'memory': attrs['limits']['memory'],
              'disk': attrs['limits']['disk'],
              'cpu': attrs['limits']['cpu'],
              'status': 'unknown',
            });
          }

          final pagination = data['meta']['pagination'];
          if (page >= pagination['total_pages']) break;
          page++;
        } else {
          break;
        }
      }

      return servers;
    } catch (e) {
      return [];
    }
  }

  Future<String> _getServerStatus(String domain, String ptlc, String serverIdentifier) async {
    try {
      final response = await http.get(
        Uri.parse('$domain/api/client/servers/$serverIdentifier/resources'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $ptlc',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final state = data['attributes']['current_state'];
        
        if (state == 'running') return '⸙ Online';
        if (state == 'offline') return '⦸ Offline';
        return '⌬ Unknown';
      }
      return '⌬ Unknown';
    } catch (e) {
      return '⌬ Unknown';
    }
  }

  Future<bool> _deleteServerPterodactyl(String domain, String ptla, String serverId) async {
    try {
      final response = await http.delete(
        Uri.parse('$domain/api/application/servers/$serverId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $ptla',
        },
      );

      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteAdp(String alias) async {
    final confirm = await _showConfirmDialog('Hapus ADP?', 'Yakin ingin menghapus ADP "$alias"?');
    if (!confirm) return;

    setState(() {
      _adpList.removeWhere((adp) => adp['alias'] == alias);
      if (_selectedAdpKey == alias) {
        _selectedAdpKey = _adpList.isNotEmpty ? _adpList.first['alias'] : null;
      }
    });

    await _saveAdpToLocal();
    _showSnackBar('🗑️ ADP berhasil dihapus!');
  }

  Future<void> _deletePanel(String serverId) async {
    final confirm = await _showConfirmDialog('Hapus Panel?', 'Yakin ingin menghapus panel ini?');
    if (!confirm) return;

    final panelIndex = _panelsList.indexWhere((panel) => panel['serverId'] == serverId);
    if (panelIndex == -1) return;

    final panel = _panelsList[panelIndex];
    
    try {
      final domain = _ensureHttps(panel['domain']);
      final ptla = panel['ptla'];
      
      if (ptla != null && ptla.isNotEmpty) {
        final success = await _deleteServerPterodactyl(domain, ptla, serverId);
        
        if (!success) {
          _showSnackBar('Gagal menghapus server dari Pterodactyl', isError: true);
          return;
        }
      }
    } catch (e) {
      _showSnackBar('Error menghapus server: $e', isError: true);
    }

    setState(() {
      _panelsList.removeAt(panelIndex);
    });

    await _savePanelsToLocal();
    _showSnackBar('🗑️ Panel berhasil dihapus!');
  }

  Future<void> _listServers() async {
    if (_selectedAdpKey == null) {
      _showSnackBar('Pilih ADP terlebih dahulu!', isError: true);
      return;
    }

    final selectedAdp = _adpList.firstWhere((adp) => adp['alias'] == _selectedAdpKey);
    final domain = _ensureHttps(selectedAdp['domain']);
    final ptla = selectedAdp['ptla'];
    final ptlc = selectedAdp['ptlc'] ?? '';

    setState(() => _isLoading = true);

    try {
      final servers = await _listServersPterodactyl(domain, ptla);
      
      if (servers.isEmpty) {
        _showSnackBar('Tidak ada server ditemukan', isError: false);
        return;
      }

      List<String> serverLines = [];
      for (int i = 0; i < servers.length; i++) {
        final server = servers[i];
        String status = '⌬ Unknown';
        
        if (ptlc.isNotEmpty) {
          status = await _getServerStatus(domain, ptlc, server['identifier']);
        }
        
        serverLines.add(
          '#${i + 1}. ${server['name']} — $status (id:${server['id']})'
        );
      }

      final message = '''
⸙ 𝙊𝙏𝘼𝙓 — 𝙇𝙄𝙎𝙏 𝙎𝙀𝙍𝙑𝙀𝙍
ADP: $_selectedAdpKey | Domain: $domain

${serverLines.join('\n')}
      ''';

      await _showServerListDialog(message);
    } catch (e) {
      _showSnackBar('Gagal mengambil data server: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showServerListDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, const Color(0xFF1A1A1A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.list, color: cyberBlue, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'DAFTAR SERVER',
                      style: TextStyle(
                        color: primaryWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'ShareTechMono',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('TUTUP'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _copyToClipboard(message);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cyberBlue.withOpacity(0.15),
                              foregroundColor: cyberBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: cyberBlue.withOpacity(0.4)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text('SALIN'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ensureHttps(String url) {
    if (!url.startsWith('http')) {
      return 'https://$url';
    }
    return url.replaceFirst('http://', 'https://');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('✅ Disalin ke clipboard!');
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, const Color(0xFF1A1A1A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: accentRed, size: 48),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(
                  color: primaryWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                )),
                const SizedBox(height: 12),
                Text(message, 
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white70,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('BATAL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepRed.withOpacity(0.15),
                          foregroundColor: deepRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: deepRed.withOpacity(0.5)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('HAPUS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, 
              color: isError ? const Color(0xFFD96B6B) : const Color(0xFF52B788)),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFF4A1A1A) : const Color(0xFF1A2E1F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cyberBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyberBlue.withOpacity(0.25)),
                ),
                child: const Icon(Icons.dashboard_customize, color: Color(0xFF7B8FF7), size: 28),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.white.withOpacity(0.4), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.username,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "OTAX Create Panel",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Fitur Create Panel Untuk Memudahkan Anda",
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
              fontFamily: 'ShareTechMono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Simpan ADP', Icons.save_alt),
          _buildTabButton(1, 'Buat Panel', Icons.add_box),
          _buildTabButton(2, 'Panel Saya', Icons.dashboard),
          _buildTabButton(3, 'List Server', Icons.list),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (index == 3) {
              _listServers();
            } else {
              setState(() => _activeTab = index);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: isActive ? LinearGradient(
                colors: [cyberBlue.withOpacity(0.15), cyberBlue.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: isActive ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: cyberBlue.withOpacity(0.35)) : null,
            ),
            child: Column(
              children: [
                Icon(icon, 
                  color: isActive ? cyberBlue : Colors.white.withOpacity(0.35), 
                  size: 22,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? cyberBlue : Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontFamily: 'Orbitron',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdpForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildGlassCard(
              child: Column(
                children: [
                  Text(
                    'TAMBAH ADP BARU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Orbitron',
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simpan informasi ADP untuk digunakan nanti',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInputField('Alias/Nickname', _aliasController, Icons.label_important, 'Contoh: server-utama'),
            const SizedBox(height: 16),
            _buildInputField('PTLA', _ptlaController, Icons.vpn_key, 'Token akses panel'),
            const SizedBox(height: 16),
            _buildInputField('PTLC (Opsional)', _ptlcController, Icons.vpn_key_outlined, 'Token tambahan jika ada'),
            const SizedBox(height: 16),
            _buildInputField('Domain Panel', _domainController, Icons.public, 'https://panel.domain.com'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveAdp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: cyberBlue.withOpacity(0.5),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  color: cyberBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyberBlue.withOpacity(0.4)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: cyberBlue),
                      const SizedBox(width: 12),
                      Text('SIMPAN ADP', style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cyberBlue,
                        letterSpacing: 0.5,
                      )),
                    ],
                  ),
                ),
              ),
            ),
            if (_adpList.isNotEmpty) ...[
              const SizedBox(height: 30),
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: cyberBlue),
                        const SizedBox(width: 10),
                        Text(
                          'ADP TERSIMPAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._adpList.map((adp) => _buildAdpCard(adp)).toList(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdpCard(Map<String, dynamic> adp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cyberBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cyberBlue.withOpacity(0.2)),
            ),
            child: Icon(Icons.cloud, color: cyberBlue.withOpacity(0.7), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adp['alias'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Domain: ${adp['domain']}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (adp['createdAt'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ditambahkan: ${_formatDate(adp['createdAt'])}',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteAdp(adp['alias']),
            icon: Icon(Icons.delete_outline, color: deepRed.withOpacity(0.8)),
            tooltip: 'Hapus ADP',
          ),
        ],
      ),
    );
  }

  Widget _buildCreatePanelForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildGlassCard(
              child: Column(
                children: [
                  Text(
                    'BUAT PANEL BARU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Orbitron',
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih ADP dan konfigurasi panel Anda',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_adpList.isNotEmpty)
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_queue, color: cyberBlue),
                        const SizedBox(width: 10),
                        Text(
                          'PILIH ADP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAdpKey,
                          isExpanded: true,
                          dropdownColor: cardDark,
                          icon: Icon(Icons.arrow_drop_down, color: cyberBlue),
                          style: TextStyle(color: primaryWhite, fontFamily: 'ShareTechMono'),
                          items: _adpList.map((adp) {
                            return DropdownMenuItem<String>(
                              value: adp['alias'],
                              child: Row(
                                children: [
                                  Icon(Icons.cloud, color: cyberBlue, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(adp['alias'], style: TextStyle(color: Colors.white)),
                                        Text(
                                          adp['domain'],
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedAdpKey = value),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildGlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white30, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada ADP',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simpan ADP terlebih dahulu di tab "Simpan ADP"',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildInputField('Nama Panel', _panelNameController, Icons.badge, 'Contoh: mypanel01'),
            const SizedBox(height: 16),
            _buildInputField('ID Telegram (Opsional)', _telegramIdController, Icons.telegram, '@username atau ID numerik'),
            const SizedBox(height: 20),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory, color: cyberBlue),
                      const SizedBox(width: 10),
                      Text(
                        'KONFIGURASI MEMORY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RAM Allocation:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        _isUnlimited ? 'UNLIMITED' : '${_memorySize.toInt()} GB',
                        style: TextStyle(
                          color: cyberBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: cyberBlue,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayColor: cyberBlue.withOpacity(0.3),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _memorySize,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: _isUnlimited
                          ? null
                          : (value) => setState(() => _memorySize = value),
                    ),
                  ),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: _isUnlimited,
                          activeColor: cyberBlue,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: (value) => setState(() => _isUnlimited = value!),
                        ),
                      ),
                      Text(
                        'Unlimited Memory',
                        style: TextStyle(color: Colors.white, fontFamily: 'Orbitron'),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isUnlimited ? cyberBlue.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isUnlimited ? cyberBlue : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: _isUnlimited ? cyberBlue : Colors.white30,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isCreating ? null : _createPanel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  color: cyberBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cyberBlue.withOpacity(0.4)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isCreating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch, color: cyberBlue),
                            const SizedBox(width: 12),
                            Text('BUAT PANEL', style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: cyberBlue,
                              letterSpacing: 0.5,
                            )),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isCreating ? null : _createAdminPanel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cyberPurple.withOpacity(0.5)),
                ),
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings, color: cyberPurple),
                      const SizedBox(width: 12),
                      Text('BUAT ADMIN PANEL', style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cyberPurple,
                        letterSpacing: 0.5,
                      )),
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

  Widget _buildMyPanelsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: cyberBlue,
          strokeWidth: 2,
        ),
      );
    }

    if (_panelsList.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(Icons.dashboard_customize, color: Colors.white30, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum ada panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Buat panel pertama Anda di tab "Buat Panel"',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => setState(() => _activeTab = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: cyberBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cyberBlue),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 20),
                    const SizedBox(width: 8),
                    Text('Buat Panel', style: TextStyle(fontFamily: 'Orbitron')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPanelsFromLocal,
      backgroundColor: cardDark,
      color: cyberBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _panelsList.length,
        itemBuilder: (context, index) {
          final panel = _panelsList[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPanelCard(panel),
          );
        },
      ),
    );
  }

  Widget _buildPanelCard(Map<String, dynamic> panel) {
    final domain = panel['domain'] ?? '';
    final username = panel['username'] ?? '';
    final password = panel['password'] ?? '';
    final userId = panel['userId']?.toString() ?? '';
    final serverId = panel['serverId']?.toString() ?? '';
    final memory = panel['memory'] ?? 0;
    final isUnlimited = panel['isUnlimited'] == true;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPanelDetails(panel),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isUnlimited ? cyberPurple.withOpacity(0.2) : cyberBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isUnlimited ? cyberPurple : cyberBlue,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUnlimited ? Icons.all_inclusive : Icons.memory,
                            color: isUnlimited ? cyberPurple : cyberBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isUnlimited ? 'UNLIMITED' : '${memory ~/ 1024} GB',
                            style: TextStyle(
                              color: isUnlimited ? cyberPurple : cyberBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deletePanel(serverId),
                      icon: Icon(Icons.delete_outline, color: deepRed.withOpacity(0.8)),
                      tooltip: 'Hapus Panel',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cyberBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cyberBlue.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.cloud, color: cyberBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            domain,
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (panel['createdAt'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Dibuat: ${_formatDate(panel['createdAt'])}',
                              style: TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final panelData = '''
Login: $domain
Username: $username
Password: $password
ID: $userId
Memory: ${isUnlimited ? "Unlimited" : "$memory MB"}
Disk: ${isUnlimited ? "Unlimited" : "${(memory * 2)} MB"}
CPU: ${panel['cpu'] ?? 100}%
                          '''.trim();
                          _copyToClipboard(panelData);
                        },
                        icon: Icon(Icons.copy, size: 18),
                        label: Text('SALIN DATA', style: TextStyle(fontSize: 12, fontFamily: 'Orbitron')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _showPanelDetails(panel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyberBlue.withOpacity(0.15),
                        foregroundColor: cyberBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: cyberBlue.withOpacity(0.4)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 18),
                          const SizedBox(width: 6),
                          Text('DETAIL', style: TextStyle(fontSize: 12, fontFamily: 'Orbitron')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPanelDetails(Map<String, dynamic> panel) {
    final domain = panel['domain'] ?? '';
    final username = panel['username'] ?? '';
    final password = panel['password'] ?? '';
    final email = panel['email'] ?? '';
    final userId = panel['userId']?.toString() ?? '';
    final serverId = panel['serverId']?.toString() ?? '';
    final memory = panel['memory'] ?? 0;
    final disk = panel['disk'] ?? 0;
    final cpu = panel['cpu'] ?? 0;
    final location = panel['location'] ?? 'N/A';
    final isUnlimited = panel['isUnlimited'] == true;

    final panelData = '''
Login: $domain
Username: $username
Password: $password
Email: $email
User ID: $userId
Server ID: $serverId
Memory: ${isUnlimited ? "Unlimited" : "$memory MB"}
Disk: ${isUnlimited ? "Unlimited" : "$disk MB"}
CPU: $cpu%
Location: $location
    '''.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cardDark.withOpacity(0.95),
                const Color(0xFF0F0F0F).withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'DETAIL PANEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: cyberBlue.withOpacity(0.2),
                              child: Icon(Icons.cloud, color: cyberBlue, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              username,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              domain,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._buildDetailRow('🌐 Domain', domain),
                      ..._buildDetailRow('👤 Username', username),
                      ..._buildDetailRow('🔐 Password', password),
                      ..._buildDetailRow('📧 Email', email),
                      ..._buildDetailRow('🆔 User ID', userId),
                      ..._buildDetailRow('🆔 Server ID', serverId),
                      ..._buildDetailRow('🧠 Memory', isUnlimited ? 'Unlimited' : '$memory MB'),
                      ..._buildDetailRow('💾 Disk', isUnlimited ? 'Unlimited' : '$disk MB'),
                      ..._buildDetailRow('⚡ CPU', '$cpu%'),
                      ..._buildDetailRow('📍 Location', location.toString()),
                      ..._buildDetailRow('📅 Dibuat', panel['createdAt']?.toString().split('T')[0] ?? ''),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => _copyToClipboard(panelData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: cyberBlue.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cyberBlue.withOpacity(0.4)),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_all, color: cyberBlue),
                                const SizedBox(width: 12),
                                Text('SALIN SEMUA DATA', style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: cyberBlue,
                                  letterSpacing: 0.5,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _deletePanel(serverId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: deepRed,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: deepRed),
                          ),
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, color: deepRed),
                                const SizedBox(width: 12),
                                Text('HAPUS PANEL', style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: deepRed,
                                  letterSpacing: 0.5,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailRow(String label, String value) {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'ShareTechMono',
                  )),
                  const SizedBox(height: 4),
                  Text(value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'ShareTechMono',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _copyToClipboard(value),
              icon: Icon(Icons.content_copy, color: cyberBlue),
              tooltip: 'Salin',
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: primaryWhite, fontFamily: 'ShareTechMono', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          prefixIcon: Icon(icon, color: cyberBlue.withOpacity(0.7), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0C0C0F),
              const Color(0xFF0E0E12),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: cyberBlue,
                                strokeWidth: 2,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Memuat data...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'ShareTechMono',
                                ),
                              ),
                            ],
                          ),
                        )
                      : IndexedStack(
                          index: _activeTab,
                          children: [
                            _buildAdpForm(),
                            _buildCreatePanelForm(),
                            _buildMyPanelsTab(),
                            Container(),
                          ],
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