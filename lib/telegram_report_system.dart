import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
void main() {
  print("=== APP STARTING ===");
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => SessionProvider(),
          lazy: false,
        ),
      ],
      child: const TelegramReportApp(),
    ),
  );
}

class TelegramReportApp extends StatelessWidget {
  const TelegramReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTAX TELEGRAM REPORT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
        ),
        primaryColor: const Color(0xFFC62828),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC62828),
          secondary: Color(0xFFEF5350),
          surface: Color(0xFF1A1A1A),
          background: Color(0xFF0A0A0A),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1A1A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF2A2A2A)),
          ),
        ),
      ),
      // UBAH: Jadikan DashboardPageTelegram sebagai home utama
      home: const DashboardPageTelegram(),
    );
  }
}

// ==============================
// MODELS
// ==============================

class UserSession {
  final String sessionKey;
  final String username;
  final String phoneNumber;
  final String userId;
  final String createdAt;
  bool isActive;

  UserSession({
    required this.sessionKey,
    required this.username,
    required this.phoneNumber,
    required this.userId,
    required this.createdAt,
    this.isActive = true,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionKey: json['session_key'] ?? json['sessionKey'] ?? '',
      username: json['username'] ?? 'Unknown',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String(),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_key': sessionKey,
      'username': username,
      'phone_number': phoneNumber,
      'user_id': userId,
      'created_at': createdAt,
      'is_active': isActive,
    };
  }
}

class ReportRequest {
  final String targetUsername;
  final String reason;
  final int loops;
  final String? customMessage;

  ReportRequest({
    required this.targetUsername,
    required this.reason,
    required this.loops,
    this.customMessage,
  });

  Map<String, dynamic> toJson() => {
        'target_username': targetUsername,
        'reason': reason,
        'loops': loops,
        if (customMessage != null) 'custom_message': customMessage,
      };
}

// ==============================
// API SERVICE
// ==============================

class TelegramAPIService {
  

  static Future<Map<String, dynamic>> requestOTP({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/api/telegram/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to request OTP'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> verify2FA({
    required String phoneNumber,
    required String password2FA,
    required String tempSessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/api/telegram/verify-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'password_2fa': password2FA,
          'temp_session_id': tempSessionId,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': data['message'] ?? '2FA verification failed'
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOTP({
    required String phoneNumber,
    required String otpCode,
    String? tempSessionId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'phone_number': phoneNumber,
        'otp_code': otpCode,
      };
      
      if (tempSessionId != null) {
        body['temp_session_id'] = tempSessionId;
      }

      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/api/telegram/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 400) {
        if (data['message']?.contains('2FA') == true || 
            data['requires_2fa'] == true) {
          return {
            'success': false,
            'requires_2fa': true,
            'message': data['message'] ?? 'Password 2FA required'
          };
        }
        return {
          'success': false,
          'message': data['message'] ?? 'OTP verification failed'
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> submitReport({
    required String sessionKey,
    required ReportRequest report,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:4113/api/telegram/report-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionKey',
        },
        body: jsonEncode(report.toJson()),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Report failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUserSessions(String sessionKey) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:4113/api/telegram/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'sessions': [], 'message': 'Failed to load sessions'};
      }
    } catch (e) {
      return {'success': false, 'sessions': [], 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteSession({
    required String currentSessionKey,
    required String targetSessionKey,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:4113/api/telegram/session/$targetSessionKey'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentSessionKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Delete failed: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkSession(String sessionKey) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:4113/api/telegram/check-session'),
        headers: {
          'Authorization': 'Bearer $sessionKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Session invalid'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getUserReports(String sessionKey) async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:4113/api/telegram/my-reports'),
        headers: {
          'Authorization': 'Bearer $sessionKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'reports': [], 'count': 0};
      }
    } catch (e) {
      return {'success': false, 'reports': [], 'count': 0};
    }
  }

  static Future<Map<String, dynamic>> logout(String sessionKey) async {
    try {
      final response = await http.delete(
        Uri.parse('http://127.0.0.1:4113/api/telegram/logout'),
        headers: {
          'Authorization': 'Bearer $sessionKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Logout failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:4113/api/system/info'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'system': {}};
      }
    } catch (e) {
      return {'success': false, 'system': {}};
    }
  }
}

// ==============================
// SESSION PROVIDER
// ==============================

class SessionProvider extends ChangeNotifier {
  List<UserSession> _sessions = [];
  UserSession? _activeSession;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  bool _initialized = false;

  List<UserSession> get sessions => _sessions;
  UserSession? get activeSession => _activeSession;
  List<Map<String, dynamic>> get reports => _reports;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await loadSessionsFromPrefs();
    
    if (_sessions.isNotEmpty) {
      for (var session in _sessions) {
        final result = await TelegramAPIService.checkSession(session.sessionKey);
        if (result['success'] == true) {
          _activeSession = session;
          break;
        } else {
          _sessions.remove(session);
        }
      }
    }
    
    if (_sessions.isNotEmpty && _activeSession == null) {
      _activeSession = _sessions.first;
    }
    
    _initialized = true;
    notifyListeners();
  }

  void setActiveSession(UserSession session) {
    _activeSession = session;
    notifyListeners();
    _saveSessionsToPrefs();
  }

  Future<void> addSession(UserSession session) async {
    final existingIndex = _sessions.indexWhere((s) => s.phoneNumber == session.phoneNumber);
    if (existingIndex != -1) {
      _sessions[existingIndex] = session;
    } else {
      _sessions.add(session);
    }
    
    _activeSession = session;
    notifyListeners();
    await _saveSessionsToPrefs();
  }

  Future<void> removeSession(UserSession session) async {
    if (_activeSession == null) {
      _sessions.removeWhere((s) => s.sessionKey == session.sessionKey);
      notifyListeners();
      await _saveSessionsToPrefs();
      return;
    }

    final result = await TelegramAPIService.deleteSession(
      currentSessionKey: _activeSession!.sessionKey,
      targetSessionKey: session.sessionKey,
    );
    
    if (result['success'] == true || result['message']?.contains('tidak ditemukan') == true) {
      _sessions.removeWhere((s) => s.sessionKey == session.sessionKey);
      if (_activeSession?.sessionKey == session.sessionKey) {
        _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
      }
      notifyListeners();
      await _saveSessionsToPrefs();
    }
  }

  Future<void> loadSessionsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList('telegram_sessions') ?? [];
    _sessions = sessionsJson
        .map((json) => UserSession.fromJson(jsonDecode(json)))
        .toList();
    
    final activeSessionKey = prefs.getString('active_session_key');
    if (activeSessionKey != null) {
      _activeSession = _sessions.firstWhere(
        (s) => s.sessionKey == activeSessionKey,
        orElse: () => _sessions.isNotEmpty ? _sessions.first : UserSession(
          sessionKey: '',
          username: '',
          phoneNumber: '',
          userId: '',
          createdAt: '',
        ),
      );
    }
  }

  Future<void> _saveSessionsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = _sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('telegram_sessions', sessionsJson);
    if (_activeSession != null) {
      await prefs.setString('active_session_key', _activeSession!.sessionKey);
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void addReport(Map<String, dynamic> report) {
    _reports.insert(0, report);
    notifyListeners();
  }

  Future<void> loadReports() async {
    if (_activeSession == null) return;

    setLoading(true);
    try {
      final result = await TelegramAPIService.getUserReports(
        _activeSession!.sessionKey,
      );

      if (result['success'] == true) {
        final List<dynamic> reportsData = result['reports'] ?? [];
        _reports = reportsData.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading reports: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> submitReport(ReportRequest report) async {
    if (_activeSession == null) {
      return {'success': false, 'message': 'No active session'};
    }

    setLoading(true);
    try {
      final result = await TelegramAPIService.submitReport(
        sessionKey: _activeSession!.sessionKey,
        report: report,
      );

      if (result['success'] == true) {
        addReport(result['data'] ?? {});
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> logoutCurrent() async {
    if (_activeSession == null) {
      return {'success': true, 'message': 'No active session'};
    }

    setLoading(true);
    try {
      final result = await TelegramAPIService.logout(_activeSession!.sessionKey);
      
      _sessions.removeWhere((s) => s.sessionKey == _activeSession!.sessionKey);
      _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
      _reports.clear();
      
      notifyListeners();
      await _saveSessionsToPrefs();
      
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      setLoading(false);
    }
  }
}

// ==============================
// DASHBOARD PAGE (MAIN HOME)
// ==============================

class DashboardPageTelegram extends StatefulWidget {
  const DashboardPageTelegram({super.key});

  @override
  State<DashboardPageTelegram> createState() => _DashboardPageTelegramState();
}

class _DashboardPageTelegramState extends State<DashboardPageTelegram> {
  final Color _primaryRed = const Color(0xFFC62828);
  final Color _accentRed = const Color(0xFFEF5350);
  final Color _darkBg = const Color(0xFF0A0A0A);
  final Color _cardBg = const Color(0xFF1A1A1A);
  final Color _textPrimary = const Color(0xFFF5F5F5);
  final Color _textSecondary = const Color(0xFFA0A0A0);
  final Color _borderColor = const Color(0xFF2A2A2A);
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("DashboardPageTelegram initialized");
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      await provider.initialize();
      _loadReports();
    } catch (e) {
      print("Error initializing app: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadReports() {
    final provider = Provider.of<SessionProvider>(context, listen: false);
    print("Loading reports for session: ${provider.activeSession?.username}");
    
    if (provider.activeSession != null) {
      provider.loadReports();
    }
  }

  void _showSystemInfo(BuildContext context) async {
    final result = await TelegramAPIService.getSystemInfo();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderColor),
        ),
        title: Text(
          'System Information',
          style: TextStyle(color: _textPrimary),
        ),
        content: result['success'] == true
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('System', result['system']['name'] ?? 'N/A'),
                  _buildInfoRow('Version', result['system']['version'] ?? 'N/A'),
                  _buildInfoRow('API Version', result['system']['api_version'] ?? 'N/A'),
                  _buildInfoRow('Status', result['system']['status'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (result['system']['features'] as List<dynamic>?)
                            ?.map((feature) => Chip(
                                  label: Text(
                                    feature.toString(),
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: _primaryRed.withOpacity(0.1),
                                  labelPadding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                ))
                            .toList() ??
                        [],
                  ),
                ],
              )
            : Text(
                'Failed to load system info',
                style: TextStyle(color: Colors.red),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building DashboardPageTelegram...");
    
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text(
          'OTAX TELEGRAM REPORT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: _cardBg,
        elevation: 0,
        foregroundColor: _textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_rounded, size: 22),
            onPressed: () {
              _showSystemInfo(context);
            },
          ),
          Consumer<SessionProvider>(
            builder: (context, provider, child) {
              if (provider.activeSession != null)
                return IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  onPressed: () async {
                    final result = await provider.logoutCurrent();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                );
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: _cardBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: _darkBg,
                border: Border(
                  bottom: BorderSide(color: _borderColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryRed, _accentRed],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryRed.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      FontAwesomeIcons.telegram,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OTAX TELEGRAM',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Multi-Session Report System',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard_rounded, color: _textPrimary),
              title: Text('Dashboard', style: TextStyle(color: _textPrimary)),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem_rounded, color: _textPrimary),
              title: Text('New Report', style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.people_rounded, color: _textPrimary),
              title: Text('Manage Sessions', style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SessionManagerPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.history_rounded, color: _textPrimary),
              title: Text('Report History', style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Report History coming soon!'),
                    backgroundColor: _primaryRed,
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            ListTile(
              leading: Icon(Icons.settings_rounded, color: _textPrimary),
              title: Text('Settings', style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Settings coming soon!'),
                    backgroundColor: _primaryRed,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.help_rounded, color: _textPrimary),
              title: Text('Help & Support', style: TextStyle(color: _textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Help & Support coming soon!'),
                    backgroundColor: _primaryRed,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primaryRed),
            )
          : Consumer<SessionProvider>(
              builder: (context, provider, child) {
                return SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _primaryRed.withOpacity(0.15),
                                  _primaryRed.withOpacity(0.05),
                                ],
                              ),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [_primaryRed, _accentRed],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryRed.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    FontAwesomeIcons.telegram,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.activeSession?.username.toUpperCase() ?? 'WELCOME',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        provider.activeSession?.phoneNumber ?? 'Telegram Report System',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: provider.activeSession != null 
                                                  ? Colors.green 
                                                  : Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            provider.activeSession != null 
                                                ? 'Connected' 
                                                : 'Add session to start',
                                            style: TextStyle(
                                              color: provider.activeSession != null 
                                                  ? Colors.green 
                                                  : Colors.orange,
                                              fontSize: 12,
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

                          // Quick Stats
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                            children: [
                              _buildStatCard(
                                title: 'Active Sessions',
                                value: provider.sessions.length.toString(),
                                icon: Icons.account_circle_rounded,
                                color: _primaryRed,
                              ),
                              _buildStatCard(
                                title: 'Total Reports',
                                value: provider.reports.length.toString(),
                                icon: Icons.report_rounded,
                                color: Colors.blue,
                              ),
                              _buildStatCard(
                                title: 'Completed',
                                value: provider.reports
                                    .where((r) => r['status'] == 'completed')
                                    .length
                                    .toString(),
                                icon: Icons.check_circle_rounded,
                                color: Colors.green,
                              ),
                              _buildStatCard(
                                title: 'Pending',
                                value: provider.reports
                                    .where((r) => r['status'] != 'completed')
                                    .length
                                    .toString(),
                                icon: Icons.pending_rounded,
                                color: Colors.orange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Quick Actions
                          Text(
                            'QUICK ACTIONS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  title: 'Add Session',
                                  icon: Icons.add_rounded,
                                  color: _primaryRed,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginPageTelegram()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  title: 'Manage Sessions',
                                  icon: Icons.people_rounded,
                                  color: Colors.blue,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const SessionManagerPage()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),

                          if (provider.activeSession != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    title: 'New Report',
                                    icon: Icons.report_problem_rounded,
                                    color: _primaryRed,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const ReportPage()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    title: 'Report History',
                                    icon: Icons.history_rounded,
                                    color: Colors.purple,
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Report History coming soon!'),
                                          backgroundColor: _primaryRed,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Recent Reports Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: _cardBg,
                              border: Border.all(color: _borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RECENT REPORTS',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _textPrimary,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    if (provider.activeSession != null && provider.reports.isNotEmpty)
                                      TextButton(
                                        onPressed: () => provider.loadReports(),
                                        child: Text(
                                          'Refresh',
                                          style: TextStyle(
                                            color: _primaryRed,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                if (provider.activeSession == null)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: _darkBg,
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.person_add_rounded,
                                          size: 48,
                                          color: _textSecondary.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No Active Session',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Please add or select a Telegram session to start reporting',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _textSecondary.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const LoginPageTelegram(),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryRed,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Add Session'),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (provider.reports.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: _darkBg,
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.history_rounded,
                                          size: 48,
                                          color: _textSecondary.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No Reports Yet',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Start reporting profiles to see history here',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _textSecondary.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const ReportPage()),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryRed,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Create Report'),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: provider.reports.length > 3 ? 3 : provider.reports.length,
                                    itemBuilder: (context, index) {
                                      final report = provider.reports[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: _darkBg,
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _primaryRed.withOpacity(0.2),
                                              ),
                                              child: Icon(
                                                Icons.person_rounded,
                                                color: _primaryRed,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '@${report['target'] ?? report['target_username'] ?? 'Unknown'}',
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${report['loops'] ?? 0} reports • ${report['reason'] ?? 'spam'}',
                                                    style: TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: report['status'] == 'completed' 
                                                    ? Colors.green.withOpacity(0.1)
                                                    : Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: report['status'] == 'completed' 
                                                      ? Colors.green.withOpacity(0.3)
                                                      : Colors.orange.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                report['status'] == 'completed' ? 'Completed' : 'Pending',
                                                style: TextStyle(
                                                  color: report['status'] == 'completed' 
                                                      ? Colors.green 
                                                      : Colors.orange,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _cardBg,
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// SESSION MANAGER PAGE - VERSI DIPERBAIKI
// ==============================

class SessionManagerPage extends StatefulWidget {
  const SessionManagerPage({super.key});

  @override
  State<SessionManagerPage> createState() => _SessionManagerPageState();
}

class _SessionManagerPageState extends State<SessionManagerPage> {
  final Color _primaryRed = const Color(0xFFC62828);
  final Color _accentRed = const Color(0xFFEF5350);
  final Color _darkBg = const Color(0xFF0A0A0A);
  final Color _cardBg = const Color(0xFF1A1A1A);
  final Color _textPrimary = const Color(0xFFF5F5F5);
  final Color _textSecondary = const Color(0xFFA0A0A0);
  final Color _borderColor = const Color(0xFF2A2A2A);
  
  bool _isLoading = true;
  List<UserSession> _sessions = [];
  UserSession? _activeSession;

  @override
  void initState() {
    super.initState();
    print("=== SessionManagerPage INIT ===");
    
    // Load sessions secara langsung tanpa Provider context
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList('telegram_sessions') ?? [];
      
      _sessions = sessionsJson
          .map((json) => UserSession.fromJson(jsonDecode(json)))
          .toList();
      
      final activeSessionKey = prefs.getString('active_session_key');
      if (activeSessionKey != null) {
        _activeSession = _sessions.firstWhere(
          (s) => s.sessionKey == activeSessionKey,
          orElse: () => _sessions.isNotEmpty ? _sessions.first : UserSession(
            sessionKey: '',
            username: '',
            phoneNumber: '',
            userId: '',
            createdAt: '',
          ),
        );
      } else if (_sessions.isNotEmpty) {
        _activeSession = _sessions.first;
      }

      print("Loaded ${_sessions.length} sessions");
      
    } catch (e) {
      print("Error loading sessions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSession(UserSession session) async {
    try {
      if (_activeSession == null) {
        setState(() {
          _sessions.removeWhere((s) => s.sessionKey == session.sessionKey);
          if (_activeSession?.sessionKey == session.sessionKey) {
            _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
          }
        });
        await _saveSessionsToPrefs();
        return;
      }

      // Hapus dari API
      final result = await TelegramAPIService.deleteSession(
        currentSessionKey: _activeSession!.sessionKey,
        targetSessionKey: session.sessionKey,
      );
      
      if (result['success'] == true || result['message']?.contains('tidak ditemukan') == true) {
        setState(() {
          _sessions.removeWhere((s) => s.sessionKey == session.sessionKey);
          if (_activeSession?.sessionKey == session.sessionKey) {
            _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
          }
        });
        await _saveSessionsToPrefs();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error deleting session: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSessionsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = _sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('telegram_sessions', sessionsJson);
    if (_activeSession != null) {
      await prefs.setString('active_session_key', _activeSession!.sessionKey);
    }
  }

  void _setActiveSession(UserSession session) {
    setState(() {
      _activeSession = session;
    });
    _saveSessionsToPrefs();
    
    // Update provider jika ada
    try {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      provider.setActiveSession(session);
    } catch (e) {
      print("Provider not available: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("=== SessionManagerPage BUILD ===");
    
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: Text(
          'SESSION MANAGER',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_rounded, size: 22),
            onPressed: () {
              _showSystemInfo(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primaryRed),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primaryRed.withOpacity(0.15),
                          _primaryRed.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_primaryRed, _accentRed],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryRed.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            FontAwesomeIcons.telegram,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MULTI-SESSION MANAGER',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Manage your Telegram sessions for reporting',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (_activeSession != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 12),
                          child: Text(
                            'ACTIVE SESSION',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        _buildSessionCard(
                          session: _activeSession!,
                          isActive: true,
                          onSelect: () {
                            Navigator.of(context).pop();
                          },
                          onDelete: () async {
                            await _deleteSession(_activeSession!);
                          },
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ALL SESSIONS',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '${_sessions.length} sessions',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _sessions.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_add_rounded,
                                        size: 72,
                                        color: _textSecondary.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No Telegram Sessions',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Add your first Telegram session to start reporting',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        width: 200,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const LoginPageTelegram(),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryRed,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 24,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_rounded, size: 20),
                                              SizedBox(width: 8),
                                              Text('Add Session'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _sessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _sessions[index];
                                    final isActiveSession = _activeSession?.sessionKey == session.sessionKey;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildSessionCard(
                                        session: session,
                                        isActive: isActiveSession,
                                        onSelect: () {
                                          _setActiveSession(session);
                                          Navigator.of(context).pop();
                                        },
                                        onDelete: () async {
                                          await _deleteSession(session);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPageTelegram(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: _borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: _textPrimary, size: 20),
                              const SizedBox(width: 10),
                              Text('Add New Session', style: TextStyle(color: _textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryRed,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dashboard_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('Dashboard'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionCard({
    required UserSession session,
    required bool isActive,
    required VoidCallback onSelect,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _cardBg,
        border: Border.all(
          color: isActive ? _primaryRed : _borderColor,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isActive ? [_primaryRed, _accentRed] : [_textSecondary, _textSecondary.withOpacity(0.5)],
                    ),
                  ),
                  child: Icon(
                    FontAwesomeIcons.telegram,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            session.username,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _primaryRed.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: _primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.phoneNumber,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${session.userId}',
                        style: TextStyle(
                          color: _textSecondary.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_rounded,
                    color: Colors.red.withOpacity(0.7),
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSystemInfo(BuildContext context) async {
    final result = await TelegramAPIService.getSystemInfo();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderColor),
        ),
        title: Text(
          'System Information',
          style: TextStyle(color: _textPrimary),
        ),
        content: result['success'] == true
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('System', result['system']['name'] ?? 'N/A'),
                  _buildInfoRow('Version', result['system']['version'] ?? 'N/A'),
                  _buildInfoRow('API Version', result['system']['api_version'] ?? 'N/A'),
                  _buildInfoRow('Status', result['system']['status'] ?? 'N/A'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (result['system']['features'] as List<dynamic>?)
                            ?.map((feature) => Chip(
                                  label: Text(
                                    feature.toString(),
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: _primaryRed.withOpacity(0.1),
                                  labelPadding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                ))
                            .toList() ??
                        [],
                  ),
                ],
              )
            : Text(
                'Failed to load system info',
                style: TextStyle(color: Colors.red),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ==============================
// REPORT PAGE - VERSI TAMPILAN DIPERBAIKI
// ==============================

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _loopsController = TextEditingController(text: '1');
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = false;
  bool _isReporting = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String _selectedReason = 'spam';
  List<Map<String, dynamic>> _recentReports = [];
  
  UserSession? _activeSession;

  final List<Map<String, dynamic>> _reasons = [
    {'id': 'spam', 'name': 'Spam', 'icon': Icons.report_rounded, 'description': 'Unsolicited messages or ads'},
    {'id': 'fake', 'name': 'Fake Account', 'icon': Icons.person_off_rounded, 'description': 'Impersonation or fake identity'},
    {'id': 'violence', 'name': 'Violence', 'icon': Icons.warning_rounded, 'description': 'Threats or violent content'},
    {'id': 'pornography', 'name': 'Pornography', 'icon': Icons.no_adult_content_rounded, 'description': 'Adult or explicit content'},
    {'id': 'drugs', 'name': 'Drugs Sales', 'icon': Icons.medical_services_rounded, 'description': 'Illegal substances promotion'},
    {'id': 'scam', 'name': 'Scam', 'icon': Icons.money_off_rounded, 'description': 'Fraudulent activities'},
    {'id': 'harassment', 'name': 'Harassment', 'icon': Icons.block_rounded, 'description': 'Bullying or harassment'},
    {'id': 'other', 'name': 'Other', 'icon': Icons.more_horiz_rounded, 'description': 'Other violations'},
  ];

  final Color _primaryRed = const Color(0xFFC62828);
  final Color _accentRed = const Color(0xFFEF5350);
  final Color _darkBg = const Color(0xFF0A0A0A);
  final Color _cardBg = const Color(0xFF1A1A1A);
  final Color _textPrimary = const Color(0xFFF5F5F5);
  final Color _textSecondary = const Color(0xFFA0A0A0);
  final Color _borderColor = const Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
    _loadRecentReports();
  }

  Future<void> _loadActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList('telegram_sessions') ?? [];
      
      if (sessionsJson.isNotEmpty) {
        final activeSessionKey = prefs.getString('active_session_key');
        
        if (activeSessionKey != null) {
          try {
            final sessionData = sessionsJson
                .map((json) => jsonDecode(json))
                .firstWhere(
                  (data) => data['session_key'] == activeSessionKey,
                );
            
            setState(() {
              _activeSession = UserSession.fromJson(sessionData);
            });
          } catch (e) {
            final firstSession = jsonDecode(sessionsJson.first);
            setState(() {
              _activeSession = UserSession.fromJson(firstSession);
            });
          }
        } else {
          final firstSession = jsonDecode(sessionsJson.first);
          setState(() {
            _activeSession = UserSession.fromJson(firstSession);
          });
        }
      } else {
        setState(() {
          _activeSession = null;
        });
      }
    } catch (e) {
      setState(() {
        _activeSession = null;
      });
    }
  }

  Future<void> _loadRecentReports() async {
    try {
      if (_activeSession == null) return;

      final result = await TelegramAPIService.getUserReports(
        _activeSession!.sessionKey,
      );
      
      if (result['success'] == true && mounted) {
        setState(() {
          _recentReports = List<Map<String, dynamic>>.from(result['reports'] ?? []);
        });
      }
    } catch (e) {
      print("Error loading recent reports: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message, style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: _textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String target) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _borderColor),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_primaryRed, _accentRed],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryRed.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'REPORT SUCCESSFUL',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '@$target',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Report has been successfully submitted\n',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                    TextSpan(
                      text: 'You can track status in Report History',
                      style: TextStyle(color: _textSecondary.withOpacity(0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: _borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Dashboard', style: TextStyle(color: _textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetForm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('New Report'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _targetController.clear();
    _loopsController.text = '1';
    _messageController.clear();
    setState(() {
      _selectedReason = 'spam';
      _statusMessage = '';
      _isReporting = false;
      _progress = 0.0;
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_activeSession == null) {
      _showErrorDialog('No Active Session', 'Please select or add a Telegram session first');
      return;
    }

    setState(() {
      _isLoading = true;
      _isReporting = true;
      _progress = 0.0;
      _statusMessage = 'Initializing report...';
    });

    final report = ReportRequest(
      targetUsername: _targetController.text.trim().replaceAll('@', ''),
      reason: _selectedReason,
      loops: int.tryParse(_loopsController.text) ?? 1,
      customMessage: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
    );

    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _progress = i / 5;
          _statusMessage = _getStatusMessage(i * 20);
        });
      }
    }

    try {
      final result = await TelegramAPIService.submitReport(
        sessionKey: _activeSession!.sessionKey,
        report: report,
      );

      if (mounted) {
        setState(() {
          _isReporting = false;
          _statusMessage = result['message'] ?? 'Report completed';
        });

        if (result['success'] == true) {
          setState(() {
            _recentReports.insert(0, result['data'] ?? {});
          });
          
          await Future.delayed(const Duration(milliseconds: 800));
          _showSuccessDialog(report.targetUsername);
        } else {
          _showErrorDialog('Report Failed', result['message'] ?? 'Unknown error occurred');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: ${e.toString()}';
          _isReporting = false;
        });
        _showErrorDialog('Report Failed', 'Connection error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getStatusMessage(int progress) {
    switch (progress) {
      case 20: return 'Connecting to Telegram API...';
      case 40: return 'Preparing report data...';
      case 60: return 'Sending report requests...';
      case 80: return 'Verifying submission...';
      case 100: return 'Finalizing report...';
      default: return 'Processing...';
    }
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _darkBg,
            border: Border.all(color: _borderColor),
          ),
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: _textPrimary, fontSize: 14),
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: _textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines == 1 ? 16 : 12,
              ),
              prefixIcon: FaIcon(icon, color: _textSecondary, size: 20),
              prefixText: prefixText,
              prefixStyle: TextStyle(color: _textPrimary),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _primaryRed.withOpacity(0.1),
            border: Border.all(color: _primaryRed.withOpacity(0.2)),
          ),
          child: FaIcon(icon, color: _primaryRed, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryRed.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(
                  color: _primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecentReports() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT REPORTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _textSecondary, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _recentReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 60, color: _textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No recent reports',
                            style: TextStyle(color: _textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _recentReports.length,
                      itemBuilder: (context, index) {
                        final report = _recentReports[index];
                        final reason = _reasons.firstWhere(
                          (r) => r['id'] == report['reason'],
                          orElse: () => _reasons.last,
                        );
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _darkBg,
                            border: Border.all(color: _borderColor),
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
                                      color: _primaryRed.withOpacity(0.1),
                                    ),
                                    child: Icon(reason['icon'] as IconData, 
                                      color: _primaryRed, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '@${report['target'] ?? report['target_username'] ?? 'Unknown'}',
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${report['loops'] ?? 0} reports • ${report['reason']}',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: report['status'] == 'completed' 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: report['status'] == 'completed' 
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.orange.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      report['status'] == 'completed' ? 'Completed' : 'Pending',
                                      style: TextStyle(
                                        color: report['status'] == 'completed' 
                                            ? Colors.green 
                                            : Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (report['custom_message'] != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: _primaryRed.withOpacity(0.05),
                                    border: Border.all(color: _primaryRed.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.message_rounded, 
                                        size: 14, color: _textSecondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          report['custom_message'] ?? '',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    report['created_at']?.toString().substring(0, 16) ?? 'Just now',
                                    style: TextStyle(
                                      color: _textSecondary.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${report['report_id']?.toString().substring(0, 8) ?? 'N/A'}',
                                    style: TextStyle(
                                      color: _textSecondary.withOpacity(0.7),
                                      fontSize: 11,
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadRecentReports();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Refresh Reports'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text(
          'Report Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: _cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_recentReports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 22),
              onPressed: () => _showRecentReports(),
              tooltip: 'Recent Reports',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borderColor),
                  ),
                  title: Text(
                    'Report Guidelines',
                    style: TextStyle(color: _textPrimary, fontSize: 18),
                  ),
                  content: Text(
                    '• Ensure target username is correct\n'
                    '• Provide accurate reason for reporting\n'
                    '• Use custom message for additional details\n'
                    '• Avoid false reports to prevent account suspension',
                    style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.6),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('OK', style: TextStyle(color: _primaryRed)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Guidelines',
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _activeSession != null 
                ? Colors.green.withOpacity(0.1) 
                : Colors.red.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: _borderColor),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _activeSession != null ? Icons.check_circle : Icons.error_rounded,
                  color: _activeSession != null ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activeSession != null 
                      ? 'Reporting with: ${_activeSession!.username} (${_activeSession!.phoneNumber})'
                      : 'No active session - Please add a session first',
                    style: TextStyle(
                      color: _activeSession != null ? Colors.green : Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_activeSession != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryRed.withOpacity(0.3)),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: _primaryRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _cardBg,
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [_primaryRed, _accentRed],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.report_problem_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PROFILE REPORT',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _textPrimary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Report violations to Telegram moderators',
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Target Username Field
                          _buildFormField(
                            label: 'TARGET USERNAME',
                            hint: 'username (without @)',
                            controller: _targetController,
                            icon: Icons.person_search_rounded,
                            prefixText: '@',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter target username';
                              }
                              final cleaned = value.replaceAll('@', '').trim();
                              if (cleaned.length < 5) {
                                return 'Username must be at least 5 characters';
                              }
                              if (cleaned.contains(' ')) {
                                return 'Remove spaces from username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Report Reason Section
                          Text(
                            'REPORT REASON',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                            children: _reasons.map((reason) {
                              final isSelected = _selectedReason == reason['id'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedReason = reason['id'];
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: isSelected 
                                      ? _primaryRed.withOpacity(0.15)
                                      : _darkBg,
                                    border: Border.all(
                                      color: isSelected ? _primaryRed : _borderColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected 
                                            ? _primaryRed.withOpacity(0.2)
                                            : _textSecondary.withOpacity(0.1),
                                        ),
                                        child: Icon(
                                          reason['icon'] as IconData,
                                          color: isSelected ? _primaryRed : _textSecondary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        reason['name'] as String,
                                        style: TextStyle(
                                          color: isSelected ? _primaryRed : _textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reason['description'] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected 
                                            ? _primaryRed.withOpacity(0.8)
                                            : _textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),

                          // Loops and Custom Message Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildFormField(
                                  label: 'NUMBER OF REPORTS',
                                  hint: '1-100',
                                  controller: _loopsController,
                                  icon: Icons.repeat_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter number';
                                    }
                                    final loops = int.tryParse(value);
                                    if (loops == null) {
                                      return 'Enter valid number';
                                    }
                                    if (loops < 1 || loops > 100) {
                                      return 'Between 1-100';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  label: 'CUSTOM MESSAGE (OPTIONAL)',
                                  hint: 'Additional details for moderator...',
                                  controller: _messageController,
                                  icon: Icons.message_rounded,
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Progress Indicator (when reporting)
                          if (_isReporting)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: _darkBg,
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'REPORT IN PROGRESS',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${(_progress * 100).round()}%',
                                        style: TextStyle(
                                          color: _primaryRed,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: _progress,
                                      backgroundColor: _darkBg,
                                      color: _primaryRed,
                                      minHeight: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.info_rounded,
                                        color: _primaryRed,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _statusMessage,
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_isReporting) const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _resetForm,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: BorderSide(color: _borderColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh_rounded, 
                                        color: _textPrimary, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Reset Form', 
                                        style: TextStyle(color: _textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _activeSession == null || _isLoading 
                                    ? null : _submitReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _activeSession == null 
                                      ? _textSecondary : _primaryRed,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isReporting ? FontAwesomeIcons.telegram : Icons.report_rounded,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _activeSession == null ? 'NO SESSION' : 'SUBMIT REPORT',
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Information Sections
                  Column(
                    children: [
                      // Security Notice
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _primaryRed.withOpacity(0.1),
                              _primaryRed.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.security_rounded, color: _primaryRed, size: 22),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Security Notice',
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Reports are sent through your active Telegram session. '
                                    'Use responsibly and avoid false reporting.',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: _cardBg,
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.report_rounded, 'Recent', _recentReports.length.toString()),
                            _buildStatItem(Icons.history_rounded, 'Total', _recentReports.length.toString()),
                            _buildStatItem(Icons.timer_rounded, 'Active', _activeSession != null ? '1' : '0'),
                            _buildStatItem(Icons.check_circle_rounded, 'Success', 
                              _recentReports.where((r) => r['status'] == 'completed').length.toString()),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Tips
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _cardBg,
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUICK TIPS',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTipItem('✓', 'Use accurate usernames without @ symbol'),
                        _buildTipItem('✓', 'Select appropriate reason for better moderation'),
                        _buildTipItem('✓', 'Add details in custom message if needed'),
                        _buildTipItem('✓', 'Check report history for status updates'),
                        _buildTipItem('✗', 'Avoid excessive reports on same target'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    _loopsController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

// ==============================
// LOGIN PAGE - VERSI DIPERBAIKI & DIRAPIKAN
// ==============================

class LoginPageTelegram extends StatefulWidget {
  const LoginPageTelegram({super.key});

  @override
  State<LoginPageTelegram> createState() => _LoginPageTelegramState();
}

class _LoginPageTelegramState extends State<LoginPageTelegram> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _password2FAController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showOtpField = false;
  bool _requires2FA = false;
  String? _debugOtp;
  String _tempSessionId = '';

  final Color _primaryRed = const Color(0xFFC62828);
  final Color _accentRed = const Color(0xFFEF5350);
  final Color _darkBg = const Color(0xFF0A0A0A);
  final Color _cardBg = const Color(0xFF1A1A1A);
  final Color _textPrimary = const Color(0xFFF5F5F5);
  final Color _textSecondary = const Color(0xFFA0A0A0);
  final Color _borderColor = const Color(0xFF2A2A2A);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _password2FAController.dispose();
    super.dispose();
  }

  Future<void> _saveSessionToPrefs(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList('telegram_sessions') ?? [];
      
      int existingIndex = -1;
      List<Map<String, dynamic>> sessions = [];
      
      for (int i = 0; i < sessionsJson.length; i++) {
        final sessionMap = jsonDecode(sessionsJson[i]) as Map<String, dynamic>;
        sessions.add(sessionMap);
        if (sessionMap['phone_number'] == session.phoneNumber) {
          existingIndex = i;
        }
      }
      
      final newSessionJson = jsonEncode(session.toJson());
      
      if (existingIndex != -1) {
        sessionsJson[existingIndex] = newSessionJson;
      } else {
        sessionsJson.add(newSessionJson);
      }
      
      await prefs.setStringList('telegram_sessions', sessionsJson);
      await prefs.setString('active_session_key', session.sessionKey);
      
      print('Session saved: ${session.username}');
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  Future<void> _handleRequestOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showOtpField = false;
      _requires2FA = false;
      _tempSessionId = '';
      _otpController.clear();
      _password2FAController.clear();
    });

    try {
      final response = await TelegramAPIService.requestOTP(
        phoneNumber: _phoneController.text.trim(),
      );

      if (response['success'] == true) {
        setState(() {
          _showOtpField = true;
          _debugOtp = response['debug_otp'];
          _tempSessionId = response['temp_session_id'] ?? '';
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOTP() async {
    final cleanOtp = _otpController.text.trim().replaceAll(' ', '');
    
    if (cleanOtp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter OTP code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await TelegramAPIService.verifyOTP(
        phoneNumber: _phoneController.text.trim(),
        otpCode: cleanOtp,
        tempSessionId: _tempSessionId.isNotEmpty ? _tempSessionId : null,
      );

      if (response['requires_2fa'] == true) {
        setState(() {
          _requires2FA = true;
          _showOtpField = false;
          _tempSessionId = response['temp_session_id'] ?? '';
          _errorMessage = response['message'] ?? 'Password 2FA diperlukan';
        });
        return;
      }

if (response['success'] == true) {
      final session = UserSession(
        sessionKey: response['session_key'] ?? '',
        username: response['user']['username'] ?? 'User',
        phoneNumber: _phoneController.text.trim(),
        userId: response['user']['user_id']?.toString() ?? '',
        createdAt: DateTime.now().toIso8601String(),
      );

      // 1. Simpan ke SharedPreferences
      await _saveSessionToPrefs(session);
      
      // 2. Update SessionProvider yang ada (jika ada)
      try {
        final provider = Provider.of<SessionProvider>(context, listen: false);
        await provider.addSession(session);
      } catch (e) {
        print("Provider not available in this context: $e");
        // Lanjutkan tanpa provider, akan diinisialisasi di DashboardPageTelegram
      }

      if (mounted) {
        print("Login successful, navigating to DashboardPageTelegram with MultiProvider...");
        
        // 3. Navigasi dengan cara yang SAMA seperti dari menu utama
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) {
              print("Building DashboardPageTelegram from login...");
              return MultiProvider(
                providers: [
                  ChangeNotifierProvider<SessionProvider>(
                    create: (_) {
                      print("Creating fresh SessionProvider for dashboard...");
                      final provider = SessionProvider();
                      // Initialize provider (akan load session dari SharedPreferences)
                      provider.initialize();
                      return provider;
                    },
                  ),
                ],
                child: const DashboardPageTelegram(),
              );
            },
          ),
          (route) => false,
        ).then((_) {
          print("Returned from DashboardPageTelegram");
        }).catchError((e) {
          print("Navigation error from login: $e");
        });
      }
    }  else {
        setState(() {
          _errorMessage = response['message'] ?? 'Login failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

Future<void> _handleVerify2FA() async {
  final password2FA = _password2FAController.text.trim();
  
  if (password2FA.isEmpty) {
    setState(() {
      _errorMessage = 'Please enter 2FA password';
    });
    return;
  }

  if (_tempSessionId.isEmpty) {
    setState(() {
      _errorMessage = 'Session expired, please restart login process';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final response = await TelegramAPIService.verify2FA(
      phoneNumber: _phoneController.text.trim(),
      password2FA: password2FA,
      tempSessionId: _tempSessionId,
    );

    if (response['success'] == true) {
      final session = UserSession(
        sessionKey: response['session_key'] ?? '',
        username: response['user']['username'] ?? 'User',
        phoneNumber: _phoneController.text.trim(),
        userId: response['user']['user_id']?.toString() ?? '',
        createdAt: DateTime.now().toIso8601String(),
      );

      // 1. Simpan ke SharedPreferences
      await _saveSessionToPrefs(session);
      
      // 2. Update SessionProvider yang ada (jika ada)
      try {
        final provider = Provider.of<SessionProvider>(context, listen: false);
        await provider.addSession(session);
      } catch (e) {
        print("Provider not available in this context: $e");
        // Lanjutkan tanpa provider, akan diinisialisasi di DashboardPageTelegram
      }

      if (mounted) {
        print("Login successful, navigating to DashboardPageTelegram with MultiProvider...");
        
        // 3. Navigasi dengan cara yang SAMA seperti dari menu utama
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) {
              print("Building DashboardPageTelegram from login...");
              return MultiProvider(
                providers: [
                  ChangeNotifierProvider<SessionProvider>(
                    create: (_) {
                      print("Creating fresh SessionProvider for dashboard...");
                      final provider = SessionProvider();
                      // Initialize provider (akan load session dari SharedPreferences)
                      provider.initialize();
                      return provider;
                    },
                  ),
                ],
                child: const DashboardPageTelegram(),
              );
            },
          ),
          (route) => false,
        ).then((_) {
          print("Returned from DashboardPageTelegram");
        }).catchError((e) {
          print("Navigation error from login: $e");
        });
      }
    } else {
      setState(() {
        _errorMessage = response['message'] ?? '2FA verification failed';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = '2FA verification failed: ${e.toString()}';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? hintText,
    String? Function(String?)? validator,
    bool isOTPField = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _darkBg,
            border: Border.all(color: _borderColor),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: _textPrimary, fontSize: 14),
            inputFormatters: isOTPField 
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text.replaceAll(' ', '');
                      if (text.length > 6) return oldValue;
                      if (text.isEmpty) return newValue;
                      
                      final formatted = text.length > 3 
                          ? '${text.substring(0, 3)} ${text.substring(3)}'
                          : text;
                      
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ]
                : null,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: _textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
              prefixIcon: Icon(prefixIcon, color: _textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  void _resetForm() {
    setState(() {
      _showOtpField = false;
      _requires2FA = false;
      _errorMessage = '';
      _debugOtp = null;
      _tempSessionId = '';
      _otpController.clear();
      _password2FAController.clear();
    });
  }

  void _goBackToDashboard() {
  if (!mounted) return;

  print("Back to Dashboard with MultiProvider...");

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) {
        print("Building DashboardPageTelegram from back navigation...");
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionProvider>(
              create: (_) {
                print("Creating fresh SessionProvider for dashboard (back)...");
                final provider = SessionProvider();
                provider.initialize(); // load dari SharedPreferences
                return provider;
              },
            ),
          ],
          child: const DashboardPageTelegram(),
        );
      },
    ),
    (route) => false,
  ).then((_) {
    print("Returned from DashboardPageTelegram (back)");
  }).catchError((e) {
    print("Navigation error (back): $e");
  });
}

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepItem(1, 'Phone', !_showOtpField && !_requires2FA),
          Container(
            height: 1,
            width: 40,
            color: _borderColor,
          ),
          _buildStepItem(2, 'OTP', _showOtpField && !_requires2FA),
          Container(
            height: 1,
            width: 40,
            color: _borderColor,
          ),
          _buildStepItem(3, '2FA', _requires2FA),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _primaryRed : _textSecondary.withOpacity(0.1),
            border: Border.all(
              color: isActive ? _primaryRed : _borderColor,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? _primaryRed : _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed, {bool isPrimary = true}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary 
            ? _primaryRed 
            : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : _textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isPrimary 
              ? BorderSide.none 
              : BorderSide(color: _borderColor),
          ),
          elevation: isPrimary ? 5 : 0,
        ),
        child: _isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isPrimary ? Colors.white : _primaryRed,
              ),
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text(
          'Add Telegram Session',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBackToDashboard,
        ),
        backgroundColor: _cardBg,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_primaryRed.withOpacity(0.3), _accentRed.withOpacity(0.1)],
                        ),
                        border: Border.all(
                          color: _primaryRed.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        FontAwesomeIcons.telegram,
                        size: 48,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ADD TELEGRAM SESSION',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login with your Telegram account',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Step Indicator
              _buildStepIndicator(),

              const SizedBox(height: 32),

              // Main Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _cardBg,
                  border: Border.all(color: _borderColor),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telegram Login',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _requires2FA 
                            ? 'Enter your 2FA password to continue'
                            : _showOtpField
                                ? 'Enter the OTP sent to your phone'
                                : 'Enter your phone number to add session',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Phone Number Field
                      if (!_showOtpField && !_requires2FA)
                        Column(
                          children: [
                            _buildTextField(
                              label: 'Phone Number',
                              controller: _phoneController,
                              prefixIcon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              hintText: '+6281234567890',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter phone number';
                                }
                                if (!value.contains('+')) {
                                  return 'Include country code (+62...)';
                                }
                                if (value.length < 10) {
                                  return 'Enter valid phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),

                      // OTP Field
                      if (_showOtpField && !_requires2FA)
                        Column(
                          children: [
                            _buildTextField(
                              label: 'OTP Code',
                              controller: _otpController,
                              prefixIcon: Icons.sms_rounded,
                              keyboardType: TextInputType.number,
                              hintText: '123 456',
                              isOTPField: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter OTP code';
                                }
                                final clean = value.replaceAll(' ', '');
                                if (clean.length < 6) {
                                  return 'OTP must be 6 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_debugOtp != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _primaryRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _primaryRed.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.code_rounded, color: _primaryRed, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Debug OTP: $_debugOtp',
                                      style: TextStyle(color: _primaryRed, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'OTP sent to ${_phoneController.text}',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // 2FA Field
                      if (_requires2FA)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.security_rounded, color: Colors.orange, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '2FA Verification Required',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              label: '2FA Password',
                              controller: _password2FAController,
                              prefixIcon: Icons.lock_rounded,
                              obscureText: true,
                              hintText: 'Enter your 2FA password',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter 2FA password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter the password you set for Two-Factor Authentication',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      // Error Message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: _errorMessage.contains('2FA') 
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _errorMessage.contains('2FA')
                                  ? Colors.orange.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _errorMessage.contains('2FA') 
                                    ? Icons.warning_rounded
                                    : Icons.error_rounded,
                                color: _errorMessage.contains('2FA') 
                                    ? Colors.orange 
                                    : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: _errorMessage.contains('2FA') 
                                        ? Colors.orange 
                                        : Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 32),

                      // Main Action Button
                      _buildActionButton(
                        _requires2FA
                            ? 'VERIFY 2FA'
                            : _showOtpField
                                ? 'VERIFY OTP'
                                : 'GET OTP',
                        _requires2FA
                            ? _handleVerify2FA
                            : _showOtpField
                                ? _handleVerifyOTP
                                : _handleRequestOTP,
                        isPrimary: true,
                      ),

                      // Additional Options
                      const SizedBox(height: 16),

                      if (_showOtpField || _requires2FA)
                        Column(
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : _resetForm,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_rounded, 
                                    color: _textSecondary, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Use different phone number',
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),

                      if (_requires2FA)
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            setState(() {
                              _requires2FA = false;
                              _showOtpField = true;
                              _password2FAController.clear();
                              _errorMessage = '';
                            });
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back_rounded, 
                                color: _textSecondary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Back to OTP verification',
                                style: TextStyle(color: _textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Back Button
              _buildActionButton(
                'Back to Dashboard',
                _goBackToDashboard,
                isPrimary: false,
              ),

              const SizedBox(height: 20),

              // Info Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _primaryRed.withOpacity(0.05),
                  border: Border.all(color: _primaryRed.withOpacity(0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: _primaryRed, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Information',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your session data is stored locally and encrypted. '
                            'We never share your Telegram credentials with third parties.',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
}