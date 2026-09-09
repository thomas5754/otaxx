import 'dart:convert';
import 'dart:ui';
import 'package:provider/provider.dart'; 
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
import 'change_password.dart';
import 'bug_sender.dart';
import 'nik_check.dart';
import 'admin_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'pasar_online_page.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_group_page.dart'; 
import 'notification_page.dart';
import 'chat_room_page.dart';
import 'telegram_report_system.dart';
import 'spotify_music_player.dart';
import 'custom_payload.dart';
import 'update_module_page.dart';
import 'thanks_to_page.dart';
import 'spam_pair.dart';
import 'alquran.dart';
import 'send_notification_page.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'tes_func_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:io';
import 'main.dart';
class SholatService {
 String _getTimeZone(double longitude) {

  
  if (longitude >= 105 && longitude < 120) {
    return "WIB";
  } else if (longitude >= 120 && longitude < 135) {
    return "WITA";
  } else if (longitude >= 135 && longitude <= 150) {
    return "WIT";
  } else {
    return "WIB"; 
  }
}

  Future<Map<String, dynamic>> getJadwalSholat(String cityId) async {
    try {
      final now = DateTime.now();
     
      final date = "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
      
   
      final response = await http.get(
        Uri.parse('https://api.myquran.com/v1/sholat/jadwal/$cityId/$date'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
    } catch (e) {
      print('Error fetching sholat schedule: $e');
    }
    return {};
  }

  // Method untuk mencari kota berdasarkan nama (mirip dengan Python)
  Future<List<dynamic>> searchKota(String query) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.myquran.com/v1/sholat/kota/cari/$query'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      print('Error searching cities: $e');
    }
    return [];
  }
  
  // Method untuk mengambil semua kota (untuk dropdown)
  Future<List<dynamic>> getKotaList() async {
    try {
    
      final response = await http.get(
        Uri.parse('https://api.myquran.com/v1/sholat/kota/cari/'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      print('Error fetching cities: $e');
    }
    return [];
  }

Future<Map<String, dynamic>?> getCurrentLocationCity() async {
  try {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) return null;

    if (!await Geolocator.isLocationServiceEnabled()) {
      print('📍 Location service tidak aktif');
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    final timeZone = _getTimeZone(position.longitude);

    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (places.isEmpty) return null;

    final place = places.first;
    String? cityName = 
        place.locality ?? 
        place.subLocality ?? 
        place.subAdministrativeArea ?? 
        place.administrativeArea;
    
    if (cityName == null) return null;

    print('📍 Location found: $cityName');
    String cleanName = cityName.toLowerCase();
    cleanName = cleanName
        .replaceAll('kabupaten', '')
        .replaceAll('kab.', '')
        .replaceAll('kota', '')
        .replaceAll('kab', '')
        .replaceAll('kot', '')
        .replaceAll('administrative', '')
        .replaceAll('area', '')
        .trim();
    List<dynamic> searchResults = [];
    searchResults = await searchKota(cleanName);
    if (searchResults.isEmpty && cleanName.contains(' ')) {
      final parts = cleanName.split(' ');
      for (var part in parts) {
        if (part.length > 3) {
          searchResults = await searchKota(part);
          if (searchResults.isNotEmpty) break;
        }
      }
    }
    if (searchResults.isEmpty && cleanName.contains(' ')) {
      final firstWord = cleanName.split(' ')[0];
      if (firstWord.length > 2) {
        searchResults = await searchKota(firstWord);
      }
    }
    if (searchResults.isEmpty) {
      final allCities = await getKotaList();
      Map<String, dynamic>? nearestCity;
      double minDistance = double.infinity;
      
      for (var city in allCities) {
        final cityLat = double.tryParse(city['lintang']?.toString() ?? '0') ?? 0;
        final cityLong = double.tryParse(city['bujur']?.toString() ?? '0') ?? 0;
        
        if (cityLat != 0 && cityLong != 0) {
          final distance = calculateDistance(
            position.latitude, 
            position.longitude, 
            cityLat, 
            cityLong
          );
          
          if (distance < minDistance) {
            minDistance = distance;
            nearestCity = city;
          }
        }
      }
      
      if (nearestCity != null) {
        print('📍 Using nearest city: ${nearestCity['lokasi']}');
        return {
          'cityId': nearestCity['id'].toString(),
          'cityName': nearestCity['lokasi']?.toString() ?? cityName,
          'timeZone': timeZone,
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }
    }
    
    if (searchResults.isNotEmpty) {
      final cityData = searchResults[0];
      print('✅ City matched: ${cityData['lokasi']}');
      
      return {
        'cityId': cityData['id'].toString(),
        'cityName': cityData['lokasi']?.toString() ?? cityName,
        'timeZone': timeZone,
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } else {
      print('⚠️ No matching city found in database');
      return null;
    }
  } catch (e) {
    print('❌ Error getting location: $e');
    return null;
  }
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Radius bumi dalam km
  
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
  
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRadians(double degree) {
  return degree * pi / 180;
}
}
class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}
// Animated Background
class AnimatedBackground extends StatefulWidget {
  @override
  _AnimatedBackgroundState createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -100, end: 100).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(_animation.value / 100, -0.5),
              radius: 1.5,
              colors: [
                Color(0xFF8B0000).withOpacity(0.1),
                Color(0xFF1F2937).withOpacity(0.1),
                Colors.transparent,
              ],
              stops: [0.1, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _jadwalSholat;
  List<dynamic> _cityList = [];
  String _selectedCityId = "1227"; // Default: Jakarta
  String _selectedCityName = "Jakarta";
  bool _isLoadingSholat = false;
  Timer? _sholatTimer;
  final SholatService _sholatService = SholatService();
  String? _currentLocation;
  bool _useCurrentLocation = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late WebSocketChannel channel;
  late DateTime _lastStatsUpdate;
  late Timer _healthCheckTimer;
late Timer _timeTimer;
late Timer _fetchTimer;
DateTime _wibTime = DateTime.now();
DateTime _witaTime = DateTime.now().add(const Duration(hours: 1));
DateTime _witTime = DateTime.now().add(const Duration(hours: 2));
String _dayPeriod = "Morning";
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
late PackageInfo _packageInfo;
bool _isChecking = false;
String? _updateError;
Map<String, dynamic>? _updateInfo;
List<String> _changelog = [];
bool _showUpdateBanner = false;
  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  List<dynamic> notifications = [];
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;
late Timer _realTimeClockTimer;
String _currentTime = "00:00:00";
String _currentTimeZoneDisplay = "WIB";
  String androidId = "unknown";

  int _bottomNavIndex = 0;
  Widget _selectedPage = const Placeholder();

  bool isLoading = false;
  bool hasUnreadNotif = false;
bool isNotifLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  List<dynamic> senderList = [];
List<dynamic> _hadithList = [];
  Map<String, dynamic>? _currentHadith;
  Timer? _hadithTimer;
  bool _isLoadingHadith = false;
  int _currentPage = 1;
  int _totalPages = 493;
  int onlineUsers = 0;
  int activeConnections = 0;
  int _carouselCurrentIndex = 0;
  int _quickActionIndex = 0;
  bool _envelopeOpened = false;
  
@override
void initState() {
  super.initState();
  
  print("📱 DashboardPage initialized for user: ${widget.username}");
  sessionKey = widget.sessionKey;
  username = widget.username;
  password = widget.password;
  role = widget.role;
  expiredDate = widget.expiredDate;
  listBug = widget.listBug ?? [];
  listDoos = widget.listDoos ?? [];
  newsList = widget.news ?? [];
  _initPackageInfo();
  _jadwalSholat = {
    'lokasi': 'Jakarta',
    'daerah': 'DKI Jakarta',
    'jadwal': {
      'imsak': '04:22',
      'subuh': '04:32',
      'terbit': '05:46',
      'dzuhur': '12:08',
      'ashar': '15:30',
      'maghrib': '18:20',
      'isya': '19:33',
    }
  };
  _selectedPage = _buildEnhancedNewsPage();
  _initAnimations();
  _initializeVideo();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _initRealTimeSystems();
    }
  });
  _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (mounted) {
      _updateTimes();
    } else {
      timer.cancel();
    }
  });
  _setFallbackHadith();
  Future.delayed(Duration(seconds: 2), () {
    if (mounted) {
      _fetchHadith();
    }
  });
  Future.delayed(Duration(seconds: 3), () {
    if (mounted) {
      _initSholatData();
    }
  });
  
  _realTimeClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (mounted) {
      _updateRealTimeClock();
    } else {
      timer.cancel();
    }
  });
}

String _getTimeZone(double longitude) {

  
  if (longitude >= 105 && longitude < 120) {
    return "WIB";
  } else if (longitude >= 120 && longitude < 135) {
    return "WITA";
  } else if (longitude >= 135 && longitude <= 150) {
    return "WIT";
  } else {
    return "WIB"; 
  }
}

String _currentTimeZone = "WIB";
String _timeZoneAbbreviation = "WIB";
void _initRealTimeSystems() async {
  print("🔄 Initializing real-time systems...");
  
  try {
    await _initAndroidIdAndConnect();
    await Future.delayed(const Duration(seconds: 2));
    await Future.wait([
      _fetchAdvancedStats(),
      _fetchSenders(),
      _fetchNotifications(),
    ]);
    
    print("✅ Real-time systems initialized");
  } catch (e) {
    print("❌ Error initializing real-time systems: $e");
    _startPollingFallback();
  }
}
Future<void> _initPackageInfo() async {
  try {
    _packageInfo = await PackageInfo.fromPlatform();
    print("📦 Package Info: ${_packageInfo.version} (${_packageInfo.buildNumber})");
    _checkForUpdates();
  } catch (e) {
    print("❌ Error getting package info: $e");
  }
}
Future<void> _checkForUpdates() async {
  if (_isChecking) return;
  
  setState(() {
    _isChecking = true;
    _updateError = null;
  });

  try {
    final response = await Dio().get(
      'http://127.0.0.1:4113/api/check-update',
      queryParameters: {
        'version': _packageInfo.version,
        'build': _packageInfo.buildNumber,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${widget.sessionKey}',
        },
      ),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = response.data;
      
      if (data['error'] != null) {
        setState(() {
          _updateError = data['error'].toString();
          _updateInfo = null;
          _changelog = [];
          _showUpdateBanner = false;
        });
      } else if (data['has_update'] == true && data['update_info'] != null) {
        setState(() {
          _updateInfo = data['update_info'];
          _changelog = List<String>.from(data['update_info']['changelog'] ?? []);
          _showUpdateBanner = true;
        });
        _showUpdateNotification(data['update_info']);
      } else {
        setState(() {
          _updateInfo = null;
          _changelog = [];
          _showUpdateBanner = false;
        });
      }
    } else {
      setState(() {
        _updateError = 'Server merespon dengan kode ${response.statusCode}';
        _showUpdateBanner = false;
      });
    }
  } catch (e) {
    setState(() {
      _updateError = 'Gagal mengecek update: ${e.toString()}';
      _showUpdateBanner = false;
    });
  } finally {
    setState(() {
      _isChecking = false;
    });
  }
}
void _showUpdateNotification(Map<String, dynamic> updateInfo) {
  final version = updateInfo['version'] ?? 'terbaru';
  final isCritical = updateInfo['critical'] == true;
  ScaffoldMessenger.of(context).showMaterialBanner(
    MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCritical ? '🚨 UPDATE KRITIS TERSEDIA' : '🔄 UPDATE TERSEDIA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Versi $version telah tersedia. Update sekarang untuk mendapatkan fitur terbaru!',
            style: TextStyle(color: Colors.white70),
          ),
          if (_changelog.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Perubahan:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            ..._changelog.take(3).map((change) => Text(
              '• $change',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            )),
          ],
        ],
      ),
      backgroundColor: isCritical ? Colors.red[800]! : Colors.blue[800]!,
      actions: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UpdateModulePage(
                  sessionKey: sessionKey,
                  username: username,
                  role: role,
                ),
              ),
            );
          },
          child: Text('UPDATE', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text('NANTI', style: TextStyle(color: Colors.white70)),
        ),
      ],
      padding: EdgeInsets.all(16),
    ),
  );
  if (!isCritical) {
    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }
}
void _initAnimations() {
  _controller = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  );
  _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  _slideAnimation = Tween<Offset>(
    begin: const Offset(0, 0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  _controller.forward();
}

void _startWebSocketHealthCheck() {
  Timer.periodic(Duration(seconds: 30), (timer) {
    if (channel?.closeCode != null) {
      print("⚠️ WebSocket disconnected, reconnecting...");
      _reconnectWebSocket();
    }
  });
}

void _updateRealTimeClock() {
  final now = DateTime.now();
  final timeString = '${now.hour.toString().padLeft(2, '0')}:'
                    '${now.minute.toString().padLeft(2, '0')}:'
                    '${now.second.toString().padLeft(2, '0')}';
  String timeZone;
  final hour = now.hour;
  
  if (hour >= 5 && hour < 18) {
    timeZone = _timeZoneAbbreviation;
  } else {
    timeZone = _timeZoneAbbreviation; // tetap sama
  }
  
  if (mounted) {
    setState(() {
      _currentTime = timeString;
      _currentTimeZoneDisplay = timeZone;
    });
  }
}
Future<void> _initSholatData() async {
  if (_isLoadingSholat || !mounted) return;

  setState(() {
    _isLoadingSholat = true;
  });

  try {
    final locationData = await _sholatService.getCurrentLocationCity();

    if (locationData != null && mounted) {
      final cityId = locationData['cityId'];
      final cityName = locationData['cityName'];
      final timeZone = locationData['timeZone'];

      print('📍 Using current location: $cityName (ID: $cityId)');

      setState(() {
        _selectedCityId = cityId;
        _selectedCityName = cityName;
        _useCurrentLocation = true;
        _currentTimeZone = timeZone;
        _timeZoneAbbreviation = timeZone;
      });

      await _fetchSholatSchedule(cityId);
      _saveLocationPreference(cityId, cityName);
    } else {
      await _loadSavedLocation();
    }
  } catch (e) {
    print('❌ Error initializing sholat data: $e');
    _setDefaultSholatSchedule();
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingSholat = false;
      });
    }
  }
}

Future<void> _saveLocationPreference(String cityId, String cityName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_city_id', cityId);
    await prefs.setString('last_city_name', cityName);
    await prefs.setBool('use_current_location', true);
    print('💾 Location preference saved: $cityName ($cityId)');
  } catch (e) {
    print('Error saving location preference: $e');
  }
}

Future<void> _loadSavedLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedCityId = prefs.getString('last_city_id');
    final savedCityName = prefs.getString('last_city_name');
    final useCurrentLocation = prefs.getBool('use_current_location') ?? false;
    
    if (savedCityId != null && savedCityName != null) {
      print('📂 Loading saved location: $savedCityName ($savedCityId)');
      
      setState(() {
        _selectedCityId = savedCityId;
        _selectedCityName = savedCityName;
        _useCurrentLocation = useCurrentLocation;
      });
      
      await _fetchSholatSchedule(savedCityId);
    } else {
      _setDefaultSholatSchedule();
      print('📍 Using default location: Jakarta');
    }
  } catch (e) {
    print('Error loading saved location: $e');
    _setDefaultSholatSchedule();
  }
}
// Fungsi helper untuk membersihkan nama kota
String _cleanCityName(String cityName) {
  if (cityName.isEmpty) return '';
  
  String cleaned = cityName.toLowerCase();
  List<String> prefixes = [
    'kecamatan', 'kelurahan', 'kota', 'kab.', 'kabupaten',
    'kab', 'kec', 'kel', 'desa', 'kabkota'
  ];
  
  for (var prefix in prefixes) {
    cleaned = cleaned.replaceAll(prefix, '').trim();
  }
  List<String> directions = ['selatan', 'utara', 'timur', 'barat'];
  for (var dir in directions) {
    cleaned = cleaned.replaceAll(' $dir', '').replaceAll('$dir ', '');
  }
  
  return cleaned.trim();
}

bool _isCityMatch(String apiCityName, String geocodingCityName) {
  if (apiCityName.isEmpty || geocodingCityName.isEmpty) return false;
  String cleanApi = apiCityName.replaceAll(RegExp(r'[^a-z]'), '');
  String cleanGeo = geocodingCityName.replaceAll(RegExp(r'[^a-z]'), '');
  return cleanApi.contains(cleanGeo) || cleanGeo.contains(cleanApi) ||
         cleanApi == cleanGeo;
}

Future<void> _fetchSholatSchedule(String cityId) async {
  if (!mounted) return;
  
  try {
    _safeSetState(() {
      _isLoadingSholat = true;
    });
    
    final data = await _sholatService.getJadwalSholat(cityId)
      .timeout(Duration(seconds: 10), onTimeout: () {
        return {};
      });
    
    if (mounted && data.isNotEmpty && data['status'] == true) {
      _safeSetState(() {
        _jadwalSholat = data['data']; // Perhatikan struktur response v1
      });
    } else {
      _setDefaultSholatSchedule();
    }
  } catch (e) {
    print('Error fetching sholat schedule: $e');
    _setDefaultSholatSchedule();
  } finally {
    if (mounted) {
      _safeSetState(() {
        _isLoadingSholat = false;
      });
    }
  }
}
void _setDefaultSholatSchedule() {
  if (mounted) {
    _safeSetState(() {
      _jadwalSholat = {
        'lokasi': 'Jakarta',
        'daerah': 'DKI Jakarta',
        'jadwal': {
          'imsak': '04:22',
          'subuh': '04:32',
          'terbit': '05:46',
          'dzuhur': '12:08',
          'ashar': '15:30',
          'maghrib': '18:20',
          'isya': '19:33',
        }
      };
      _isLoadingSholat = false;
    });
  }
}

String _getNextSholatTime() {
  if (_jadwalSholat == null || _jadwalSholat!['jadwal'] == null) {
    return "Mengambil jadwal...";
  }
  
  final jadwal = _jadwalSholat!['jadwal'];
  final now = DateTime.now();
  final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  
  final sholatTimes = [
    {'name': 'Subuh', 'time': jadwal['subuh']?.toString() ?? '04:32'},
    {'name': 'Dzuhur', 'time': jadwal['dzuhur']?.toString() ?? '12:08'},
    {'name': 'Ashar', 'time': jadwal['ashar']?.toString() ?? '15:30'},
    {'name': 'Maghrib', 'time': jadwal['maghrib']?.toString() ?? '18:20'},
    {'name': 'Isya', 'time': jadwal['isya']?.toString() ?? '19:33'},
  ];
  
  for (var sholat in sholatTimes) {
    if (_isTimeLater(sholat['time']!, currentTime)) {
      return "Menuju ${sholat['name']} : ${sholat['time']}";
    }
  }
  
  final imsakTime = jadwal['imsak']?.toString() ?? '04:22';
  return "Menuju Imsak : $imsakTime";
}

bool _isTimeLater(String time1, String time2) {
  try {
    final t1 = time1.split(':');
    final t2 = time2.split(':');
    
    final hour1 = int.tryParse(t1[0]) ?? 0;
    final minute1 = int.tryParse(t1[1]) ?? 0;
    final hour2 = int.tryParse(t2[0]) ?? 0;
    final minute2 = int.tryParse(t2[1]) ?? 0;
    
    return hour1 > hour2 || (hour1 == hour2 && minute1 > minute2);
  } catch (e) {
    return false;
  }
}
void _showCitySelector() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Color(0xFF00B4D8)),
                              SizedBox(width: 12),
                              Text(
                                'Pilih Lokasi Sholat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            if (mounted) {
                              setState(() {
                                _isLoadingSholat = true;
                              });
                            }
                            await _initSholatData();
                          },
                          icon: Icon(Icons.gps_fixed),
                          label: Text('Gunakan Lokasi Saat Ini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00B4D8),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari kota/kabupaten...',
                          hintStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.white70),
                        ),
                        style: TextStyle(color: Colors.white),
                        onChanged: (value) async {
                          if (value.length > 2) {
                            final results = await _sholatService.searchKota(value);
                            setState(() {
                              _cityList = results;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                Expanded(
                  child: _cityList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, color: Colors.white30, size: 50),
                              SizedBox(height: 16),
                              Text(
                                'Cari kota atau kabupaten',
                                style: TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Minimal 3 karakter',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _cityList.length,
                          itemBuilder: (context, index) {
                            final city = _cityList[index];
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_city,
                                  color: Color(0xFF00B4D8).withOpacity(0.7),
                                ),
                                title: Text(
                                  city['lokasi']?.toString() ?? 'Unknown',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: city['daerah'] != null
                                    ? Text(
                                        city['daerah'].toString(),
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      )
                                    : null,
                                trailing: _selectedCityId == city['id'].toString()
                                    ? Icon(Icons.check, color: Color(0xFF00B4D8))
                                    : null,
                                onTap: () async {
                                  if (mounted) {
                                    setState(() {
                                      _selectedCityId = city['id'].toString();
                                      _selectedCityName = city['lokasi']?.toString() ?? 'Jakarta';
                                      _useCurrentLocation = false;
                                      _isLoadingSholat = true;
                                    });
                                  }
                                  await _fetchSholatSchedule(city['id'].toString());
                                  if (mounted) {
                                    setState(() {
                                      _isLoadingSholat = false;
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pilih kota untuk mendapatkan jadwal sholat yang akurat',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
Widget _buildSholatTimeItem(String name, String time, bool isActive) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: isActive ? Color(0xFF00B4D8).withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isActive ? Color(0xFF00B4D8).withOpacity(0.5) : Colors.white.withOpacity(0.1),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: TextStyle(
            color: isActive ? Color(0xFF00B4D8) : Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: isActive ? Color(0xFF00B4D8) : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'ShareTechMono',
          ),
        ),
      ],
    ),
  );
}
// Helper function untuk safe setState
void _safeSetState(VoidCallback fn) {
  if (mounted) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(fn);
        }
      });
    } catch (e) {
      print("⚠️ Error in setState: $e");
    }
  }
}

// Helper untuk mendapatkan waktu sholat dengan null safety
String _getSholatTime(String key) {
  if (_jadwalSholat == null || 
      _jadwalSholat!['jadwal'] == null || 
      _jadwalSholat!['jadwal'][key] == null) {
    return '--:--';
  }
  return _jadwalSholat!['jadwal'][key]?.toString() ?? '--:--';
}
Future<void> _fetchHadith() async {
  if (_isLoadingHadith) return;
  
  setState(() {
    _isLoadingHadith = true;
  });
  
  try {
    print("📖 Fetching hadith from API...");
    
    final randomPage = Random().nextInt(10) + 1;
    
    final res = await http.get(
      Uri.parse("http://nodemyayun.otax.store:2112/hadith/muslim?page=$randomPage&limit=10"),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      
      if (data['items'] is List && data['items'].isNotEmpty) {
        final items = data['items'] as List;
        final validItems = items.where((item) {
          final arabic = item['arab']?.toString() ?? '';
          final translation = item['id']?.toString() ?? '';
          return arabic.isNotEmpty && translation.isNotEmpty;
        }).toList();
        
        if (validItems.isEmpty) {
          print("⚠️ No valid hadith items after filtering");
          _setFallbackHadith();
          return;
        }
        final item = validItems[0];
        String arabic = item['arab']?.toString() ?? '';
        String translation = item['id']?.toString() ?? '';
        final number = item['number']?.toString() ?? '';
        arabic = _cleanArabicText(arabic);
        translation = _cleanTranslationText(translation);
        if (translation.isEmpty) {
          print("🔄 Translation empty after cleaning, trying alternative extraction");
          translation = _extractHadithFromText(item['id']?.toString() ?? '');
        }
        
        setState(() {
          _currentHadith = {
            'number': number,
            'arab': arabic,
            'id': translation,
          };
        });
        
        print("✅ Hadith #$number loaded successfully");
        print("✅ Arabic: ${arabic.length} chars");
        print("✅ Translation: ${translation.length} chars");
        
      } else {
        print("⚠️ No hadith items in response");
        _setFallbackHadith();
      }
    } else {
      print("⚠️ API returned ${res.statusCode}");
      _setFallbackHadith();
    }
  } catch (e) {
    print("❌ Error fetching hadith: $e");
    _setFallbackHadith();
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingHadith = false;
      });
    }
  }
}

String _extractHadithFromText(String text) {
  if (text.isEmpty) return '';
  final quoteMatches = RegExp(r'"([^"]*)"').allMatches(text);
  if (quoteMatches.isNotEmpty) {
    final lastMatch = quoteMatches.last;
    return lastMatch.group(1) ?? text;
  }
  final index = text.lastIndexOf('bersabda:');
  if (index != -1) {
    return text.substring(index + 9).trim();
  }
  return text;
}

String _cleanArabicText(String arabic) {
  if (arabic.isEmpty) return '';

  arabic = arabic
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  arabic = arabic.replaceAll(RegExp(r'<[^>]*>'), '');
  arabic = arabic.replaceAll(RegExp(r'\[.*?\]'), '');
  arabic = arabic.replaceAll(RegExp(r'\s+'), ' ').trim();

  return arabic;
}

String _cleanTranslationText(String translation) {
  if (translation.isEmpty) return '';

  translation = translation
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  translation = translation.replaceAll(RegExp(r'<[^>]*>'), '');
  translation = translation.replaceAll(RegExp(r'\[.*?\]'), '');
  translation = translation.replaceAll(RegExp(r'\s+'), ' ').trim();

  return translation;
}

void _pickRandomHadith() {
  if (_hadithList.isEmpty) {
    _setFallbackHadith();
    return;
  }

  final random = Random();
  final randomIndex = random.nextInt(_hadithList.length);
  final hadith = _hadithList[randomIndex];

  setState(() {
    _currentHadith = hadith is Map<String, dynamic>
        ? hadith
        : Map<String, dynamic>.from(hadith);
  });
}

void _setFallbackHadith() {
  final fallbackHadithList = [
    {
      'number': '1',
      'arab': 'مَنْ صَلَّى عَلَيَّ وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ عَشْرًا',
      'id': 'Rasulullah ﷺ bersabda: "Barangsiapa yang bershalawat kepadaku sekali, niscaya Allah bershalawat kepadanya sepuluh kali."',
    },
    {
      'number': '2', 
      'arab': 'الدُّنْيَا سَجْنُ الْمُؤْمِنِ وَجَنَّةُ الْكَافِرِ',
      'id': 'Rasulullah ﷺ bersabda: "Dunia adalah penjara bagi orang mukmin dan surga bagi orang kafir."',
    },
    {
      'number': '3',
      'arab': 'لَا تَكْذِبُوا عَلَيَّ فَإِنَّهُ مَنْ يَكْذِبْ عَلَيَّ يَلِجْ النَّارَ',
      'id': 'Rasulullah ﷺ bersabda: "Janganlah kalian berdusta atas namaku, karena siapa yang berdusta atas namaku niscaya dia masuk neraka."',
    },
    {
      'number': '4',
      'arab': 'كَفَى بِالْمَرْءِ كَذِبًا أَنْ يُحَدِّثَ بِكُلِّ مَا سَمِعَ',
      'id': 'Rasulullah ﷺ bersabda: "Cukuplah seseorang (dianggap) berbohong apabila dia menceritakan semua yang dia dengarkan."',
    },
    {
      'number': '5',
      'arab': 'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
      'id': 'Rasulullah ﷺ bersabda: "Seorang muslim adalah orang yang kaum muslimin selamat dari lisan dan tangannya."',
    },
  ];
  
  final random = Random();
  final randomIndex = random.nextInt(fallbackHadithList.length);
  
  setState(() {
    _currentHadith = fallbackHadithList[randomIndex];
  });
  
  print("✅ Using fallback hadith #${_currentHadith!['number']}");
}

Future<void> _fetchAdvancedStats({int retryCount = 3}) async {
  if (retryCount <= 0 || !mounted) return;

  try {
    final uri = Uri.parse(
      "http://127.0.0.1:4113/api/stats/real-time?key=$sessionKey",
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $sessionKey',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() {
        onlineUsers =
            data['online_users'] ??
            data['global_stats']?['online_users'] ??
            onlineUsers;

        activeConnections =
            data['connections_count'] ??
            data['personal_stats']?['active_connections'] ??
            activeConnections;

        _lastStatsUpdate = DateTime.now();
      });
      return;
    }

    if (response.statusCode == 401) {
      _handleInvalidSession("Session expired");
      return;
    }
  } catch (_) {}

  await Future.delayed(const Duration(seconds: 2));
  await _fetchAdvancedStats(retryCount: retryCount - 1);
}
Future<void> _fetchNotifications() async {
  if (isNotifLoading) return;

  setState(() {
    isNotifLoading = true;
  });

  try {
    print("📢 Fetching notifications...");
    
    final uri = Uri.parse("http://127.0.0.1:4113/notify/list")
        .replace(queryParameters: {
          'key': sessionKey,
          'username': username,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        });

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionKey',
      },
    ).timeout(const Duration(seconds: 10));

    print("📢 Notifications status: ${res.statusCode}");
    
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        setState(() {
          notifications = data;
          hasUnreadNotif = data.isNotEmpty;
        });
        print("✅ ${notifications.length} notifications loaded");
      } else if (data is Map) {
        final notifList = data['notifications'] ?? data['data'] ?? [];
        if (notifList is List) {
          setState(() {
            notifications = notifList;
            hasUnreadNotif = notifList.isNotEmpty;
          });
          print("✅ ${notifications.length} notifications loaded from map");
        }
      }
    } else {
      print("⚠️ Failed to fetch notifications: ${res.statusCode}");
    }
  } catch (e) {
    print("❌ Error fetching notifications: $e");
  } finally {
    if (mounted) {
      setState(() {
        isNotifLoading = false;
      });
    }
  }
}

void _openNotifications() {
  print("📢 [UI] Opening notifications panel");
  print("📢 [UI] Notifications count: ${notifications.length}");

  setState(() {
    hasUnreadNotif = false;
  });

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Color(0xFF0F1419),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Color(0xFF2A2F35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF1A1F25),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF2A2F35),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bloodRed.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        color: bloodRed,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notifikasi",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${notifications.length} pesan baru",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: notifications.isEmpty
                  ? _buildEmptyNotifications()
                  : _buildNotificationsList(),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1A1F25),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF2A2F35),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF3A3F45),
                          width: 1,
                        ),
                        color: Colors.white.withOpacity(0.03),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          // Mark all as read logic
                        },
                        icon: Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        label: Text(
                          "Tandai Semua Dibaca",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: bloodRed.withOpacity(0.1),
                      border: Border.all(
                        color: bloodRed.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.refresh,
                        size: 20,
                        color: bloodRed,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _fetchNotifications();
                        _openNotifications();
                      },
                      tooltip: "Refresh",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildEmptyNotifications() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: 36,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Tidak Ada Notifikasi",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tidak ada notifikasi untuk ditampilkan saat ini",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 180,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Color(0xFF3A3F45),
                width: 1,
              ),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _fetchNotifications();
                _openNotifications();
              },
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Refresh",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildNotificationsList() {
  return RefreshIndicator(
    onRefresh: () async {
      print("🔄 [UI] Pull to refresh notifications");
      await _fetchNotifications();
    },
    color: bloodRed,
    backgroundColor: Color(0xFF0F1419),
    child: ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final title = notification["title"]?.toString() ?? "Notifikasi";
        final message = notification["message"]?.toString() ?? "-";
        final createdAt = notification["createdAt"]?.toString() ?? "";
        final isNew = index == 0;

        // Format waktu
        String formattedTime;
        try {
          final date = DateTime.parse(createdAt);
          final now = DateTime.now();
          final difference = now.difference(date);

          if (difference.inMinutes < 1) {
            formattedTime = "Baru saja";
          } else if (difference.inMinutes < 60) {
            formattedTime = "${difference.inMinutes}m yang lalu";
          } else if (difference.inHours < 24) {
            formattedTime = "${difference.inHours}j yang lalu";
          } else {
            formattedTime = "${difference.inDays}h yang lalu";
          }
        } catch (e) {
          formattedTime = "Waktu tidak diketahui";
        }

        return _buildNotificationItem(
          title: title,
          message: message,
          time: formattedTime,
          isNew: isNew,
          index: index,
        );
      },
    ),
  );
}

Widget _buildNotificationItem({
  required String title,
  required String message,
  required String time,
  required bool isNew,
  required int index,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // Handle notification tap
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: bloodRed.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.02),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isNew
                ? bloodRed.withOpacity(0.05)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNew
                  ? bloodRed.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isNew)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bloodRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "BARU",
                        style: TextStyle(
                          color: bloodRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Message
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Time and actions
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      onPressed: () {
                        _showNotificationActions(context, index);
                      },
                      padding: EdgeInsets.zero,
                      splashRadius: 14,
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

void _showNotificationActions(BuildContext context, int index) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF1A1F25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFF2A2F35),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 22,
                    ),
                    title: Text(
                      "Tandai Dibaca",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Implement mark as read
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Color(0xFF2A2F35),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Colors.red.withOpacity(0.8),
                      size: 22,
                    ),
                    title: Text(
                      "Hapus Notifikasi",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Implement delete
                    },
                  ),
                  Divider(
                    height: 1,
                    color: Color(0xFF2A2F35),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.content_copy_outlined,
                      color: Colors.white.withOpacity(0.8),
                      size: 22,
                    ),
                    title: Text(
                      "Salin Pesan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Implement copy
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFF1A1F25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFF2A2F35),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.cancel_outlined,
                  color: Colors.white.withOpacity(0.8),
                  size: 22,
                ),
                title: Text(
                  "Tutup",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
  void _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/videos/bg.mp4')
      ..initialize().then((_) {
        _videoController.setVolume(0.0);
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {
          _isVideoInitialized = true;
        });
      });
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }
void _connectToWebSocket() {
  try {
    print("🌐 Connecting to WebSocket...");
    
    // Close existing connection if any
    if (channel != null && channel.closeCode == null) {
      try {
        channel.sink.close(status.goingAway);
      } catch (e) {
        print("⚠️ Error closing old connection: $e");
      }
    }
    
    // Connect to WebSocket
    channel = WebSocketChannel.connect(
      Uri.parse('ws://nodemyayun.otax.store:3000/ws'),
      protocols: ['otax-protocol'],
    );
    
    print("✅ WebSocket connection established");
    
    // Setup message handler
    channel.stream.listen(
      (dynamic message) {
        print("📨 WebSocket message received: ${message.toString().substring(0, min(100, message.toString().length))}");
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        print("❌ WebSocket error: $error");
        _reconnectWebSocket();
      },
      onDone: () {
        print("🔌 WebSocket connection closed");
        if (channel.closeCode != 1000) {
          _reconnectWebSocket();
        }
      },
      cancelOnError: true,
    );
    
    // Send authentication after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (channel != null && channel.closeCode == null) {
        _sendWebSocketAuth();
      }
    });
    
  } catch (e) {
    print("❌ Failed to connect WebSocket: $e");
    _reconnectWebSocket();
  }
}

void _sendWebSocketAuth() {
  try {
    print("🔐 Sending WebSocket authentication...");
    
    final authMessage = jsonEncode({
      "type": "auth",
      "token": sessionKey,
      "username": username,
      "role": role,
      "androidId": androidId,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
    
    channel.sink.add(authMessage);
    print("✅ Authentication sent");
  } catch (e) {
    print("❌ Error sending auth: $e");
  }
}

void _handleWebSocketMessage(dynamic event) {
  try {
    print("📨 Raw WebSocket message: $event");
    
    final data = jsonDecode(event.toString());
    final type = data['type']?.toString().toLowerCase();
    
    print("📨 Processing message type: $type");
    
    switch (type) {
      case 'stats_update':
      case 'stats':
        _handleStatsUpdate(data);
        break;
        
      case 'notification':
      case 'notify':
        _handleNewNotification(data);
        break;
        
      case 'connections_update':
      case 'senders':
        _handleConnectionsUpdate(data);
        break;
        
      case 'user_online':
      case 'online':
        _handleUserOnlineUpdate(data);
        break;
        
      case 'ping':
        // Respond to ping
        channel.sink.add(jsonEncode({'type': 'pong', 'timestamp': DateTime.now().millisecondsSinceEpoch}));
        break;
        
      case 'auth_success':
        print("✅ WebSocket authentication successful");
        // Request initial data after auth
        channel.sink.add(jsonEncode({
          'type': 'get_initial_data',
          'token': sessionKey,
        }));
        break;
        
      default:
        print("📨 Unknown message type: $type, data: ${data.toString().substring(0, min(100, data.toString().length))}");
    }
  } catch (e) {
    print("❌ Error parsing WebSocket message: $e");
  }
}

void _handleStatsUpdate(Map<String, dynamic> data) {
  if (mounted) {
    setState(() {
      // Update online users dari server
      onlineUsers = data['total_online_users'] ?? 
                   data['onlineUsers'] ?? 
                   data['online_count'] ?? 
                   onlineUsers;
      
      // Update active connections untuk user ini
      activeConnections = data['your_active_connections'] ?? 
                         data['myConnections'] ?? 
                         data['connections_count'] ?? 
                         activeConnections;
      
      print("📊 Stats Updated: Online=$onlineUsers, Connections=$activeConnections");
    });
  }
}
void _showInAppNotification(Map<String, dynamic> notification) {
  // Tampilkan banner notifikasi
  ScaffoldMessenger.of(context).showMaterialBanner(
    MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification['title'],
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            notification['message'],
            style: TextStyle(color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      backgroundColor: _getNotificationColor(notification['type']),
      actions: [
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            _openNotifications();
          },
          child: Text('BUKA', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: Text('TUTUP', style: TextStyle(color: Colors.white70)),
        ),
      ],
      padding: EdgeInsets.all(16),
    ),
  );
  
  // Auto-hide setelah 5 detik
  Future.delayed(Duration(seconds: 5), () {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  });
}

Color _getNotificationColor(String type) {
  switch (type) {
    case 'warning':
      return Colors.orange[800]!;
    case 'error':
      return Colors.red[800]!;
    case 'success':
      return Colors.green[800]!;
    case 'info':
    default:
      return Colors.blue[800]!;
  }
}
Color _getTimeZoneColor(String timeZone) {
  switch (timeZone) {
    case "WIB":
      return Color(0xFF2196F3); // Biru
    case "WITA":
      return Color(0xFF4CAF50); // Hijau
    case "WIT":
      return Color(0xFFFF9800); // Oranye
    default:
      return Color(0xFF00B4D8);
  }
}

bool _isCurrentSholat(String sholatName, String? sholatTime) {
  if (sholatTime == null) return false;
  
  try {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Ambil hanya jam dan menit dari waktu sholat (hapus detik jika ada)
    final sholatTimeFormatted = sholatTime.length >= 5 ? sholatTime.substring(0, 5) : sholatTime;
    
    return sholatTimeFormatted == currentTime;
  } catch (e) {
    return false;
  }
}
void _handleNewNotification(Map<String, dynamic> data) {
  final notification = {
    'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
    'title': data['title'] ?? 'Notification',
    'message': data['message'] ?? '',
    'createdAt': data['timestamp'] ?? DateTime.now().toIso8601String(),
    'type': data['notification_type'] ?? 'info',
    'read': false,
  };
  
  if (mounted) {
    setState(() {
      // Tambahkan notifikasi baru di urutan teratas
      notifications.insert(0, notification);
      hasUnreadNotif = true;
      
      // Batasi jumlah notifikasi (misal 50 terbaru)
      if (notifications.length > 50) {
        notifications = notifications.sublist(0, 50);
      }
    });
    
    // Tampilkan snackbar atau banner notifikasi
    _showInAppNotification(notification);
  }
}

void _handleConnectionsUpdate(Map<String, dynamic> data) {
  final List<dynamic> connections = data['connections'] ?? [];
  if (mounted) {
    setState(() {
      senderList = connections.cast<Map<String, dynamic>>();
      activeConnections = connections.length;
    });
  }
}

void _handleUserOnlineUpdate(Map<String, dynamic> data) {
  final String action = data['action'] ?? 'update';
  final int count = data['count'] ?? onlineUsers;
  
  if (mounted) {
    setState(() {
      if (action == 'increment') {
        onlineUsers += 1;
      } else if (action == 'decrement') {
        onlineUsers -= 1;
        if (onlineUsers < 0) onlineUsers = 0;
      } else {
        onlineUsers = count;
      }
    });
  }
}

int _reconnectAttempts = 0;
bool _isReconnecting = false;

void _reconnectWebSocket() {
  if (_isReconnecting) return;
  
  _isReconnecting = true;
  _reconnectAttempts++;
  
  // Exponential backoff: 3, 6, 12, 24, 30 seconds
  final delaySeconds = _reconnectAttempts <= 5 
    ? pow(2, _reconnectAttempts).toInt() 
    : 30;
  
  print("🔄 Reconnecting WebSocket in $delaySeconds seconds (attempt $_reconnectAttempts)...");
  
  Future.delayed(Duration(seconds: delaySeconds), () {
    if (mounted) {
      _isReconnecting = false;
      _connectToWebSocket();
    }
  });
}
// Di dalam _buildEnhancedNewsPage(), tambahkan widget ini:
Widget _buildConnectionStatusIndicator() {
  final isConnected = channel?.closeCode == null;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isConnected ? Colors.green : Colors.orange,
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green : Colors.orange,
            boxShadow: [
              BoxShadow(
                color: isConnected ? Colors.green.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? "REAL-TIME CONNECTED" : "CONNECTING...",
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isConnected 
                  ? "WebSocket connection active"
                  : "Attempting to reconnect...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (!isConnected)
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: Colors.orange,
            onPressed: _reconnectWebSocket,
          ),
      ],
    ),
  );
}
void _startPollingFallback() {
  print("🔄 Starting polling fallback...");
  
  // Poll setiap 15 detik jika WebSocket tidak tersedia
  Timer.periodic(Duration(seconds: 15), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    // Hanya poll jika WebSocket tidak terhubung
    if (channel?.closeCode != null) {
      print("🔄 Polling data (WebSocket disconnected)...");
      Future.wait([
        _fetchAdvancedStats(),
        _fetchSenders(),
        _fetchNotifications(),
      ]);
    }
  });
}
  void _handleInvalidSession(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: glassBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: bloodRed.withOpacity(0.5), width: 1),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: bloodRed, size: 28),
              const SizedBox(width: 10),
              Text("Session Expired",
                  style: TextStyle(color: bloodRed, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            Container(
              decoration: BoxDecoration(
                color: bloodRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                  );
                },
                child: Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
  setState(() {
    _bottomNavIndex = index;
    if (index == 0) {
      _selectedPage = _buildEnhancedNewsPage();
    } else if (index == 1) {
      // WhatsApp - Tampilkan menu pilihan dengan animasi
      _selectedPage = _buildWhatsAppMenuPage();
    } else if (index == 2) {
      try {
        _selectedPage = BugGroupPage(
          sessionKey: sessionKey,
          role: role,
        );
      } catch (e) {
        print('Error creating BugGroupPage: $e');
        _selectedPage = Center(
          child: Text('Error: $e', style: TextStyle(color: Colors.red)),
        );
      }
    } else if (index == 3) {
  _selectedPage = ToolsPage(
    sessionKey: sessionKey,
    userRole: role,
    listDoos: listDoos,
    username: username, 
  );
}
  });
}
Widget _buildWhatsAppMenuPage() {
  final List<Map<String, dynamic>> menuOptions = [
    {
      'title': 'OTAX BUG',
      'subtitle': 'Bug tanpa custom',
      'description': 'Gunakan langsung tanpa custom delay dan loops',
      'icon': Icons.bug_report,
      'iconColor': Color(0xFF25D366),
      'gradientColors': [Color(0xFF075E54), Color(0xFF128C7E), Color(0xFF25D366)],
      'badgeText': 'RECOMMENDED',
      'badgeColor': Color(0xFFFF6B35),
      'features': ['Mudah digunakan', 'Function terbaru', 'All work gacor', 'OTAX BUG'],
      'onTap': () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            username: username,
            password: password,
            listBug: listBug,
            role: role,
            expiredDate: expiredDate,
            sessionKey: sessionKey,
          ),
        ),
      ),
    },
    {
      'title': 'CUSTOM BUG',
      'subtitle': 'Menu custom bug',
      'description': 'Buat menu bug, delay pengiriman dan loops',
      'icon': Icons.settings_applications,
      'iconColor': Color(0xFF9C27B0),
      'gradientColors': [Color(0xFF6A11CB), Color(0xFF2575FC), Color(0xFF9C27B0)],
      'badgeText': 'CUSTOM',
      'badgeColor': Color(0xFF9C27B0),
      'features': ['Pengaturan Mudah', 'Support Multi Bug', 'Bebas Spam', 'Gacor The Best'],
      'onTap': () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomPayloadPage(
            sessionKey: sessionKey,
            username: username,
            role: role,
            listBug: listBug,
          ),
        ),
      ),
    },
    {
      'title': 'SPAM PAIR',
      'subtitle': 'Menu Spam Pairing',
      'description': 'Pairing Whatsapp dan OTP Telegram',
      'icon': Icons.mail,
      'iconColor': Color(0xFFFF9800),
      'gradientColors': [Color(0xFFFF512F), Color(0xFFF09819), Color(0xFFFF9800)],
      'badgeText': 'SPAM',
      'badgeColor': Color(0xFFFF9800),
      'features': ['Mudah Digunakan', 'Anti Gimmick', 'Tanpa Sender', 'Pengecekan Backend'],
      'onTap': () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpamPairPage(
            sessionKey: sessionKey,
            username: username,
            role: role,
          ),
        ),
      ),
    },
  ];

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071A19), Color(0xFF0A2220), Color(0xFF0D2E2C), Color(0xFF0A1D1C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: AnimatedBackground()),
          // Subtle top glow
          Positioned(
            top: -60,
            left: -60,
            right: -60,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [Color(0xFF25D366).withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _buildWhatsAppHeader(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: CarouselSlider.builder(
                          options: CarouselOptions(
                            height: double.infinity,
                            viewportFraction: 0.82,
                            initialPage: 0,
                            enableInfiniteScroll: true,
                            autoPlay: true,
                            autoPlayInterval: Duration(seconds: 4),
                            autoPlayAnimationDuration: Duration(milliseconds: 700),
                            autoPlayCurve: Curves.easeInOutCubic,
                            enlargeCenterPage: true,
                            enlargeFactor: 0.18,
                            scrollDirection: Axis.horizontal,
                            onPageChanged: (index, reason) {
                              setState(() { _carouselCurrentIndex = index; });
                            },
                          ),
                          itemCount: menuOptions.length,
                          itemBuilder: (context, index, realIndex) {
                            return _buildCarouselCard(menuOptions[index], index);
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(menuOptions.length, (i) {
                          final bool active = i == _carouselCurrentIndex;
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? Color(0xFF25D366)
                                  : Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: active
                                  ? [BoxShadow(color: Color(0xFF25D366).withOpacity(0.6), blurRadius: 6)]
                                  : [],
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 16),
                      _buildInfoPanel(),
                      SizedBox(height: 16),
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

Widget _buildWhatsAppHeader() {
  return Container(
    height: 175,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF075E54),
          Color(0xFF0A7A6E),
          Color(0xFF071A19).withOpacity(0.0),
        ],
        stops: [0.0, 0.6, 1.0],
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.04,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/logo.jpg'),
                  repeat: ImageRepeat.repeat,
                  scale: 2.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF071A19)],
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with glow ring
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF25D366).withOpacity(0.45),
                      blurRadius: 22,
                      spreadRadius: 4,
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
                ),
                child: Center(
                  child: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 36),
                ),
              ),
              SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFFB2DFDB)],
                ).createShader(bounds),
                child: Text(
                  "OTAX MENU",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Pilih menu yang tersedia bosque!",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10),
              Container(
                width: 100,
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFF25D366), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildCarouselCard(Map<String, dynamic> option, int index) {
  final gradientColors = option['gradientColors'] as List<Color>;
  final badgeColor = option['badgeColor'] as Color;
  final features = option['features'] as List<String>;

  return Animate(
    effects: [
      FadeEffect(duration: 350.ms, delay: (80 * index).ms),
      SlideEffect(
        begin: Offset(0, 0.04),
        end: Offset.zero,
        duration: 350.ms,
        delay: (80 * index).ms,
        curve: Curves.easeOut,
      ),
    ],
    child: GestureDetector(
      onTap: option['onTap'] as VoidCallback,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 0,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Watermark OTAX text
              Positioned(
                bottom: -10,
                right: -10,
                child: Opacity(
                  opacity: 0.07,
                  child: Text(
                    "OTAX",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              // Top-left decorative circle
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              // Bottom-right small circle
              Positioned(
                bottom: 60,
                right: -15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Glossy top shine
              Positioned(
                top: 0, left: 0, right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: icon + badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              option['icon'] as IconData,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: badgeColor.withOpacity(0.55),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            option['badgeText'] as String,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    // Title
                    Text(
                      option['title'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      option['subtitle'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 10),
                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    // Description
                    Text(
                      option['description'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 12.5,
                        height: 1.55,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    // Features chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: features.take(3).map((f) => Container(
                        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white.withOpacity(0.8), size: 11),
                            SizedBox(width: 4),
                            Text(
                              f,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                    Spacer(),
                    // START MODULE button
                    Container(
                      margin: EdgeInsets.only(bottom: 18),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: option['onTap'] as VoidCallback,
                          splashColor: Colors.white.withOpacity(0.15),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "START MODULE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildInfoPanel() {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20),
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFF25D366).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.info_outline_rounded, color: Color(0xFF25D366), size: 16),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Semua menu telah diuji coba dan tanpa gimmick real work 100%",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF25D366),
                      boxShadow: [BoxShadow(color: Color(0xFF25D366).withOpacity(0.7), blurRadius: 5)],
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    "OTAX TEAM",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
// Helper untuk feature item
Widget _buildFeatureItem(String text, IconData icon) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
  void _navigateToAdminPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminPage(sessionKey: sessionKey)),
    );
  }

  void _navigateToSellerPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerPage(keyToken: sessionKey)),
    );
  }

  Future<void> _fetchSenders({bool refresh = false}) async {
  if (isLoading && !refresh) return;

  if (!refresh && mounted) {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
  }

  try {
    final uri = Uri.parse(
      "http://127.0.0.1:4113/mySender?key=$sessionKey",
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is Map && data['valid'] == true) {
        final List connections = data['connections'] ?? [];

        if (!mounted) return;
        setState(() {
          senderList =
              List<Map<String, dynamic>>.from(connections);
          activeConnections = senderList.length;
        });
      } else {
        if (!mounted) return;
        setState(() {
          senderList.clear();
          activeConnections = 0;
          errorMessage = "Data sender tidak valid";
        });
      }
      return;
    }

    if (response.statusCode == 401) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        senderList.clear();
        activeConnections = 0;
        errorMessage = data['error'] ?? "Session expired";
      });
      return;
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      errorMessage = "Gagal mengambil data sender";
    });
  } finally {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      isRefreshing = false;
    });
  }
}
  final Color bloodRed = const Color(0xFFD32F2F);
final Color darkRed = const Color(0xFF8E0000);
final Color lightRed = const Color(0xFFFFEAEA);

final Color deepBlack = const Color(0xFF0D0D0D);
final Color glassBlack = Colors.black.withOpacity(0.6);

final Color primaryDark = const Color(0xFF111111);

final Color primaryPurple = const Color(0xFFD32F2F);
final Color accentPurple = const Color(0xFFFF1744);
final Color lightPurple = const Color(0xFFFFF5F5);

final Color primaryWhite = const Color(0xFFFFFFFF);
final Color accentGrey = const Color(0xFFCCCCCC);

final Color cardDark = const Color(0xFF1C1C1C);

final Color purpleGradientStart = const Color(0xFF8E0000);
final Color purpleGradientEnd = const Color(0xFFFF1744);

  Widget _buildCompactInfoItem({
    required FaIconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    // PERUBAHAN: Bungkus seluruh item dalam Container untuk border penuh
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Beri jarak antar item
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryPurple.withOpacity(0.3)), // Border penuh
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: lightPurple, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accentGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'ShareTechMono',
                    shadows: valueColor == primaryWhite ? [
                      Shadow(
                        color: primaryPurple.withOpacity(0.5),
                        blurRadius: 5,
                      ),
                    ] : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
void _showRealTimeNotification(Map<String, dynamic> data) {
  
  if (!mounted) return;
  
  final message = data['message']?.toString() ?? 'New notification';
  final title = data['title']?.toString() ?? 'Notification';
  
  
  setState(() {
    notifications.insert(0, {
      'title': title,
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
    });
    hasUnreadNotif = true;
  });
  

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: bloodRed,
      duration: const Duration(seconds: 3),
    ),
  );
}

void _fetchConnectionsFromBackend() async {

  try {
  
    channel.sink.add(jsonEncode({
      "type": "get_connections",
      "token": sessionKey,
    }));
    
  
    await _fetchSenders();
  } catch (e) {
    print("Error fetching connections: $e");
  }
}
void _updateTimes() {
  if (!mounted) return;
  
  final now = DateTime.now();
  final hour = now.hour;
  if (hour >= 5 && hour < 10) {
    _dayPeriod = "Pagi 🌅";
  } else if (hour >= 10 && hour < 15) {
    _dayPeriod = "Siang ☀️";
  } else if (hour >= 15 && hour < 18) {
    _dayPeriod = "Sore 🌇";
  } else {
    _dayPeriod = "Malam 🌙";
  }
  _wibTime = now;
  _witaTime = now.add(const Duration(hours: 1));
  _witTime = now.add(const Duration(hours: 2));
  
  if (mounted) {
    setState(() {});
  }
}

// Helper untuk format waktu dengan efek gradient
String _formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}

Color _getTimeBackgroundColor(String period) {
  if (period.contains("Pagi")) {
    return const Color(0xFF0F2027); // Dark blue gradient for morning
  } else if (period.contains("Siang")) {
    return const Color(0xFF1A1A2E); // Deep navy for afternoon
  } else if (period.contains("Sore")) {
    return const Color(0xFF16213E); // Purple-blue for evening
  } else {
    return const Color(0xFF0D1117); // Darkest for night
  }
}

Color _getTimeAccentColor(String period) {
  if (period.contains("Pagi")) {
    return const Color(0xFF00B4D8); // Morning blue
  } else if (period.contains("Siang")) {
    return const Color(0xFFF9C74F); // Afternoon gold
  } else if (period.contains("Sore")) {
    return const Color(0xFFE76F51); // Evening orange
  } else {
    return const Color(0xFF7209B7); // Night purple
  }
}

// Ganti widget jam menjadi lebih compact dan jelas
Widget _buildCompactTimeZone({
  required String timeZone,
  required DateTime time,
  required Color primaryColor,
  required Color accentColor,
}) {
  String periodText = '';
  IconData periodIcon = Icons.wb_sunny;
  
  final hour = time.hour;
  if (hour >= 5 && hour < 10) {
    periodText = '🌅';
    periodIcon = Icons.wb_twilight;
  } else if (hour >= 10 && hour < 15) {
    periodText = '☀️';
    periodIcon = Icons.wb_sunny;
  } else if (hour >= 15 && hour < 18) {
    periodText = '🌇';
    periodIcon = Icons.nights_stay;
  } else {
    periodText = '🌙';
    periodIcon = Icons.nightlight_round;
  }
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withOpacity(0.8),
          primaryColor.withOpacity(0.4),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: accentColor.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.3),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeZone,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentColor.withOpacity(0.2),
            ),
          ),
          child: Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'ShareTechMono',
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              periodIcon,
              color: accentColor,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              periodText,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          '${time.second.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontFamily: 'ShareTechMono',
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuickStat({
    required FaIconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case "OWNER":
        return Colors.red;
      case "TK":
        return primaryPurple;
      case "PT":
        return Colors.green;
      case "RESELLER":
        return Colors.orange;
      default:
        return lightPurple;
    }
  }

  // Widget untuk membangun video background
  Widget _buildVideoBackground() {
    if (_isVideoInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController.value.size.width,
            height: _videoController.value.size.height,
            child: VideoPlayer(_videoController),
          ),
        ),
      );
    } else {
      // Tampilkan layar hitam jika video belum dimuat
      return Container(color: deepBlack);
    }
  }
// Widget stat dengan indikator live
Widget _buildRealTimeStatChip({
  required FaIconData icon,
  required String value,
  required String label,
  required Color color,
  bool isLive = false,
}) {
  return Column(
    children: [
      Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
          if (isLive)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      if (isLive)
        Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withOpacity(0.4),
            ),
          ),
          child: Text(
            "LIVE",
            style: TextStyle(
              color: Colors.green,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
    ],
  );
}

Widget _buildDebugPanel() {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DEBUG INFO",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "WebSocket: ${channel?.closeCode == null ? 'CONNECTED ✅' : 'DISCONNECTED ❌'}",
          style: TextStyle(color: Colors.white),
        ),
        Text(
          "Online Users: $onlineUsers",
          style: TextStyle(color: Colors.white),
        ),
        Text(
          "Active Connections: $activeConnections",
          style: TextStyle(color: Colors.white),
        ),
        Text(
          "Notifications: ${notifications.length}",
          style: TextStyle(color: Colors.white),
        ),
        Text(
          "Has Unread: $hasUnreadNotif",
          style: TextStyle(color: Colors.white),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                _fetchAdvancedStats();
                _fetchSenders();
                _fetchNotifications();
              },
              child: Text("Refresh Data"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: _reconnectWebSocket,
              child: Text("Reconnect WS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
Widget _buildEnhancedNewsPage() {
  return RefreshIndicator(
    onRefresh: () async {
      setState(() {
        isRefreshing = true;
      });
      await _fetchSenders();
      await _fetchNotifications();
      setState(() {
        isRefreshing = false;
      });
    },
    color: bloodRed,
    backgroundColor: deepBlack,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E14),
            Color(0xFF111827),
            Color(0xFF1F2937),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBackground(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
          CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
  expandedHeight: 200,
  backgroundColor: Colors.transparent,
  automaticallyImplyLeading: false,
  flexibleSpace: FlexibleSpaceBar(
    collapseMode: CollapseMode.parallax,
    background: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A3D1F).withOpacity(0.95), // Deep green
            Color(0xFF1B6B3A).withOpacity(0.88), // Forest green
            Color(0xFF0D4A26).withOpacity(0.95), // Dark green
          ],
        ),
      ),
      child: Stack(
        children: [
          // ── Background shimmer gold overlay ──
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0xFFFFD700),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Bedug besar kiri bawah ──
          Positioned(
            bottom: -18,
            left: -12,
            child: Opacity(
              opacity: 0.82,
              child: Image.asset(
                'assets/images/bedug_deco.png',
                width: 155,
                height: 155,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // ── Bedug kecil kiri atas ──
          Positioned(
            top: 6,
            left: 10,
            child: Opacity(
              opacity: 0.30,
              child: Transform.rotate(
                angle: -0.18,
                child: Image.asset(
                  'assets/images/bedug_deco.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // ── Ketupat besar kanan bawah ──
          Positioned(
            bottom: -14,
            right: -8,
            child: Opacity(
              opacity: 0.85,
              child: Image.asset(
                'assets/images/ketupat_deco.png',
                width: 148,
                height: 148,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // ── Ketupat kecil kanan atas ──
          Positioned(
            top: 8,
            right: 12,
            child: Opacity(
              opacity: 0.32,
              child: Transform.rotate(
                angle: 0.18,
                child: Image.asset(
                  'assets/images/ketupat_deco.png',
                  width: 58,
                  height: 58,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // ── Garis emas horisontal dekorasi ──
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.18,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFFFFD700),
                        Color(0xFFFFD700),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.white,
                        Color(0xFFFFD700), // Gold
                        Colors.white,
                      ],
                      stops: [0.1, 0.5, 0.9],
                    ).createShader(bounds);
                  },
                  child: Text(
                    "otax dashboard",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontFamily: 'Aktura',
                    ),
                  ),
                ),
                SizedBox(height: 6),

                // ✅ TAMBAHAN: Label Ramadan Mubarak
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFFFFD700).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "✨ Minal Aidin Wal Faizin ✨",
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                SizedBox(height: 8),
                Text(
                  "Mohon Maaf Lahir & Batin 🙏",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                    // 🎉 Idul Fitri Envelope
                    _buildIdulFitriEnvelope(),
                    if (_showUpdateBanner && _updateInfo != null)
          _buildUpdateBanner(),
                      // Welcome Card dengan Neumorphic Design
                      Container(
  padding: EdgeInsets.all(24),
  margin: EdgeInsets.only(bottom: 20),
  decoration: BoxDecoration(
    color: Color(0xFF1A1F2E),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.4),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.05),
        blurRadius: 30,
        offset: Offset(0, -10),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned(
          bottom: -10,
          right: -10,
          child: Opacity(
            opacity: 0.20,
            child: Image.asset(
              'assets/images/ketupat_deco.png',
              width: 200,
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          bottom: -10,
          left: -10,
          child: Opacity(
            opacity: 0.13,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scale(-1.0, 1.0),
              child: Image.asset(
                'assets/images/bedug_deco.png',
                width: 130,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
        Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFC2185B),
                        Color(0xFFE91E63),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFE91E63).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_user,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back,",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        username,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getRoleColor(role).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF252A3A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.timer,
                    color: Color(0xFF64FFDA),
                    size: 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFFFFD700).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(0xFFFFD700).withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Text(
                "✨  Selamat Idul Fitri 1447H  🕌",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFD700).withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            SizedBox(height: 20),
            Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRealTimeStatChip(
                  icon: Icons.people,
                  value: '$onlineUsers',
                  label: "Online Users",
                  color: Color(0xFF4CAF50),
                  isLive: onlineUsers > 0,
                ),
                _buildRealTimeStatChip(
                  icon: Icons.link,
                  value: '$activeConnections',
                  label: "Active Connections",
                  color: Color(0xFF2196F3),
                  isLive: activeConnections > 0,
                ),
                _buildStatChip(
                  icon: Icons.calendar_today,
                  value: expiredDate,
                  label: "Expiration",
                  color: Color(0xFFFF9800),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
),

                      // Latest News Section dengan Glassmorphism
                      if (newsList.isNotEmpty) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.newspaper,
                                    color: Color(0xFFFF5722),
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "LATEST UPDATES",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFFF5722).withOpacity(0.2),
                                          Color(0xFFFF5722).withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFFF5722).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      "${newsList.length} Updates",
                                      style: TextStyle(
                                        color: Color(0xFFFF5722),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              height: 260,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: newsList.length,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, i) {
                                  final item = newsList[i];
                                  return _buildNewsCard(item, i);
                                },
                              ),
                            ),
                            SizedBox(height: 30),
                          ],
                        ),
                      ],
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1F2E).withOpacity(0.8),
            Color(0xFF0F172A).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF2D3748).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD700).withOpacity(0.8),
                  Color(0xFFFFF176).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 24,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "QUICK ACTIONS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontFamily: 'Orbitron',
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Beberapa Menu Tambahan",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD700).withOpacity(0.15),
                  Color(0xFFFFD700).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 1000),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFF176)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFFD700).withOpacity(0.8),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "OTAX",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
    
    const SizedBox(height: 24),
    CarouselSlider.builder(
      options: CarouselOptions(
        height: 190,
        aspectRatio: 16 / 9,
        viewportFraction: 0.78,
        initialPage: 0,
        enableInfiniteScroll: true,
        reverse: false,
        autoPlay: true,
        autoPlayInterval: Duration(seconds: 5),
        autoPlayAnimationDuration: Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        enlargeCenterPage: true,
        enlargeFactor: 0.22,
        scrollDirection: Axis.horizontal,
        onPageChanged: (index, reason) {
          setState(() {
            _quickActionIndex = index;
          });
        },
      ),
      itemCount: 6,
      itemBuilder: (context, index, realIndex) {
        final actions = [
          _ModernActionCard(
            title: "Manage Bug Sender",
            subtitle: "Pairing & Configuration",
            icon: Icons.bug_report_rounded,
            iconColor: Colors.white,
            gradient: LinearGradient(
              colors: [
                Color(0xFF8E24AA),
                Color(0xFFE91E63),
                Color(0xFFFF5252),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => BugSenderPage(
                    sessionKey: sessionKey,
                    username: username,
                    role: role,
                  ),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                      child: child,
                    );
                  },
                  transitionDuration: Duration(milliseconds: 400),
                ),
              );
            },
            index: index,
          ),
          _ModernActionCard(
            title: "Chat Room",
            subtitle: "Global Communication",
            icon: Icons.chat_bubble_rounded,
            iconColor: Colors.white,
            gradient: LinearGradient(
              colors: [
                Color(0xFF1565C0),
                Color(0xFF2196F3),
                Color(0xFF03A9F4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => ChatRoomPage(username: username),
                  transitionsBuilder: (_, animation, __, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    );
                  },
                  transitionDuration: Duration(milliseconds: 500),
                ),
              );
            },
            index: index,
          ),
          _ModernActionCard(
            title: "Telegram Report",
            subtitle: "OTAX Report System",
            icon: FontAwesomeIcons.telegram,
            iconColor: Colors.white,
            gradient: LinearGradient(
              colors: [
                Color(0xFF0088cc),
                Color(0xFF00A8E8),
                Color(0xFF4FC3F7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => MultiProvider(
                    providers: [
                      ChangeNotifierProvider<SessionProvider>(
                        create: (_) {
                          final provider = SessionProvider();
                          provider.initialize();
                          return provider;
                        },
                      ),
                    ],
                    child: const DashboardPageTelegram(),
                  ),
                  transitionsBuilder: (_, animation, __, child) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return FadeTransition(
                      opacity: curvedAnimation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0)
                            .animate(curvedAnimation),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: Duration(milliseconds: 400),
                ),
              );
            },
            index: index,
          ),
          _ModernActionCard(
            title: "TES FUNC",
            subtitle: "Test Function & Message",
            icon: Icons.code_rounded,
            iconColor: Colors.white,
            gradient: LinearGradient(
              colors: [
                Color(0xFF0097A7),
                Color(0xFF00BCD4),
                Color(0xFF4DD0E1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TesFuncPage(
                    sessionKey: sessionKey,
                    username: username,
                    role: role,
                  ),
                ),
              );
            },
            index: index,
          ),
          _ModernActionCard(
  title: "Al-QURAN",
  subtitle: "Alquran Lengkap Beserta Terjemahan",
  icon: Icons.menu_book_rounded,
  iconColor: Colors.white,
  gradient: LinearGradient(
    colors: [
      Color(0xFF43A047),
      Color(0xFF66BB6A),
      Color(0xFF81C784),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlQuranPage(),
      ),
    );
  },
  index: index,
),
          _ModernActionCard(
  title: "Pasar Online",
  subtitle: "JasaPost Marketplace",
  icon: Icons.storefront_rounded,
  iconColor: Colors.white,
  gradient: LinearGradient(
    colors: [
      Color(0xFFD32F2F),
      Color(0xFF8E0000),
      Color(0xFFFF5252),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  onTap: () {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PasarOnlinePage(
          sessionKey: sessionKey,
          username: username,
          role: role,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  },
  index: index,
),
        ];
        return actions[index];
      },
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.1),
    
    const SizedBox(height: 20),
    Center(
      child: Wrap(
        spacing: 6,
        children: List.generate(6, (i) {
          final bool isActive = i == _quickActionIndex;
          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? Color(0xFFFFD700)
                  : Colors.white.withOpacity(0.2),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Color(0xFFFFD700).withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    ),
  ],
),
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Header with City Selection
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1E2D).withOpacity(0.9),
            Color(0xFF0F2A3D).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF1E3A5F).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0066CC).withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF00B4D8),
                          Color(0xFF0077B6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00B4D8).withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mosque_rounded,
                        color: Colors.white,
                        size: 22,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "JADWAL SHOLAT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          fontFamily: 'Inter',
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _jadwalSholat?['lokasi'] ?? _selectedCityName,
                        style: TextStyle(
                          color: Color(0xFF89C2D9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // City Selector Button
              GestureDetector(
                onTap: _showCitySelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.15),
                        Colors.teal.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useCurrentLocation
                            ? Icons.gps_fixed
                            : Icons.edit_location_alt_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _useCurrentLocation ? "GPS" : "GANTI",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Next Prayer Time Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF00B4D8).withOpacity(0.2),
                  Color(0xFF0077B6).withOpacity(0.15),
                  Color(0xFF00509E).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(0xFF00B4D8).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF00B4D8).withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                // Live Indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFF6B35),
                        Color(0xFFFF8E53),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF6B35).withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Prayer Time Info
                Expanded(
                  child: _isLoadingSholat
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00B4D8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Mengambil jadwal...",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _getNextSholatTime(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                ),
                
                // OTAX Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00B4D8).withOpacity(0.15),
                        Color(0xFF0077B6).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(0xFF00B4D8).withOpacity(0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    "OTAX",
                    style: TextStyle(
                      color: Color(0xFF00B4D8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Prayer Times Carousel
          _isLoadingSholat
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF00B4D8),
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoadingSholat = false;
                              _setDefaultSholatSchedule();
                            });
                          },
                          child: Text(
                            "Gunakan Jadwal Default",
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            minimumSize: Size(0, 36),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 10),
                    children: [
                      SizedBox(width: 8),
                      
                      // Subuh
                      _buildPrayerTimeCard(
                        prayerName: "Subuh",
                        time: _jadwalSholat?['jadwal']?['subuh'] ?? '--:--',
                        icon: Icons.nights_stay_rounded,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF4A6FA5),
                            Color(0xFF3A5A95),
                            Color(0xFF2A4A85),
                          ],
                        ),
                        isNext: _isCurrentSholat(
                          "Subuh",
                          _jadwalSholat?['jadwal']?['subuh'],
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Dzuhur
                      _buildPrayerTimeCard(
                        prayerName: "Dzuhur",
                        time: _jadwalSholat?['jadwal']?['dzuhur'] ?? '--:--',
                        icon: Icons.wb_sunny_rounded,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFF9A825),
                            Color(0xFFF57F17),
                            Color(0xFFE65100),
                          ],
                        ),
                        isNext: _isCurrentSholat(
                          "Dzuhur",
                          _jadwalSholat?['jadwal']?['dzuhur'],
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Ashar
                      _buildPrayerTimeCard(
                        prayerName: "Ashar",
                        time: _jadwalSholat?['jadwal']?['ashar'] ?? '--:--',
                        icon: Icons.wb_cloudy_rounded,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFE65100),
                            Color(0xFFBF360C),
                            Color(0xFF8E1600),
                          ],
                        ),
                        isNext: _isCurrentSholat(
                          "Ashar",
                          _jadwalSholat?['jadwal']?['ashar'],
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Maghrib
                      _buildPrayerTimeCard(
                        prayerName: "Maghrib",
                        time: _jadwalSholat?['jadwal']?['maghrib'] ?? '--:--',
                        icon: Icons.nightlight_round,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF8E24AA),
                            Color(0xFF6A1B9A),
                            Color(0xFF4A148C),
                          ],
                        ),
                        isNext: _isCurrentSholat(
                          "Maghrib",
                          _jadwalSholat?['jadwal']?['maghrib'],
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Isya
                      _buildPrayerTimeCard(
                        prayerName: "Isya",
                        time: _jadwalSholat?['jadwal']?['isya'] ?? '--:--',
                        icon: Icons.bedtime_rounded,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1565C0),
                            Color(0xFF0D47A1),
                            Color(0xFF002171),
                          ],
                        ),
                        isNext: _isCurrentSholat(
                          "Isya",
                          _jadwalSholat?['jadwal']?['isya'],
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Info Card
                      Container(
                        width: 120,
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A237E).withOpacity(0.8),
                              Color(0xFF283593).withOpacity(0.7),
                              Color(0xFF303F9F).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFF3949AB).withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1A237E).withOpacity(0.3),
                              blurRadius: 15,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF00B4D8),
                                size: 22,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Update:",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${DateTime.now().day}/${DateTime.now().month}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Kemenag RI",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 8),
                    ],
                  ),
                ),
        ],
      ),
    ),
    
    // Spacing to next section
    const SizedBox(height: 20),
    
    // Hadith Quote Card
    _buildHadithQuoteCard(),
    
    const SizedBox(height: 20),
  ],
),
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1F2E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.connect_without_contact,
                                  color: Color(0xFFE91E63),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "CONNECT WITH OTAX TEAM",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildSocialButton(
                                  icon: FontAwesomeIcons.telegram,
                                  color: Color(0xFF0088CC),
                                  label: "Telegram",
                                  url: 'https://t.me/Otapengenkawin',
                                ),
                                _buildSocialButton(
                                  icon: FontAwesomeIcons.youtube,
                                  color: Color(0xFFFF0000),
                                  label: "YouTube",
                                  url: 'https://youtube.com',
                                ),
                                _buildSocialButton(
                                  icon: FontAwesomeIcons.tiktok,
                                  color: Color(0xFF000000),
                                  label: "TikTok",
                                  url: 'https://www.tiktok.com/@otaxpengenkawin',
                                ),
                                
_buildSocialButton(
  icon: Icons.favorite,
  color: Color(0xFFE91E63),
  label: "Thanks To",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ThanksToPage()),
    );
  },
),
                              ],
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Selalu nantikan project terbaru dari TEAM OTAX",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom Padding
                      SizedBox(height: 60),
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
                              
String _getTimeQuote(String period) {
  if (period.contains("Pagi")) {
    return "“مَنْ أَصْبَحَ مِنْكُمْ آمِنًا فِي سِرْبِهِ، مُعَافًى فِي جَسَدِهِ، عِنْدَهُ قُوتُ يَوْمِهِ، فَكَأَنَّمَا حِيزَتْ لَهُ الدُّنْيَا.” (رواه الترمذي)\n— Barang siapa yang bangun pagi dalam keadaan aman, sehat, dan cukup makan, maka seakan-akan dunia telah diberikan kepadanya.";
  } else if (period.contains("Siang")) {
    return "“اغْتَنِمْ خَمْسًا قَبْلَ خَمْسٍ...” (رواه الحاكم)\n— Manfaatkanlah lima perkara sebelum lima perkara: termasuk waktu luang sebelum sibuk.";
  } else if (period.contains("Sore")) {
    return "“نِعْمَتَانِ مَغْبُونٌ فِيهِمَا كَثِيرٌ مِنَ النَّاسِ: الصِّحَّةُ وَالْفَرَاغُ.” (رواه البخاري)\n— Dua kenikmatan yang sering dilalaikan manusia: kesehatan dan waktu luang.";
  } else {
    return "“بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا.” (رواه البخاري)\n— Dengan nama-Mu ya Allah aku hidup dan aku mati.";
  }
}
Widget _buildPrayerTimeCard({
  required String prayerName,
  required String time,
  required FaIconData icon,
  required Gradient gradient,
  required bool isNext,
}) {
  return Container(
    width: 110,
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: gradient.colors.first.withOpacity(0.4),
          blurRadius: 15,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Icon and Indicator
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (isNext)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Prayer Name
              Text(
                prayerName.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'ShareTechMono',
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Status Indicator
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 2,
                    decoration: BoxDecoration(
                      color: isNext ? Colors.green : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isNext ? "NEXT" : "SHOLAT",
                    style: TextStyle(
                      color: isNext ? Colors.green : Colors.white.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Fungsi untuk membuat card sholat dalam carousel
Widget _buildSholatCarouselCard({
  required String name,
  required String time,
  required FaIconData icon,
  required Gradient gradient,
  required bool isNext,
}) {
  return Container(
    width: 110, // Lebar tetap untuk konsistensi
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: gradient.colors.first.withOpacity(0.3),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Stack(
      children: [
        // Background Pattern Effect
        Positioned(
          top: -10,
          right: -10,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & Name Row
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (isNext)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.8),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Sholat Name
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              
              SizedBox(height: 4),
              
              // Time
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'ShareTechMono',
                  letterSpacing: 1,
                ),
              ),
              
              SizedBox(height: 4),
              
              // Status Indicator
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 2,
                    decoration: BoxDecoration(
                      color: isNext ? Colors.green : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    isNext ? "SELANJUTNYA" : "SHOLAT",
                    style: TextStyle(
                      color: isNext ? Colors.green : Colors.white.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════
// 🎉 IDUL FITRI ENVELOPE & GREETING CARD
// ════════════════════════════════════════════════

Widget _buildIdulFitriEnvelope() {
  return GestureDetector(
    onTap: () => _showIdulFitriCard(context),
    child: AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A6B3C).withOpacity(0.9),
            Color(0xFF2D9E5F).withOpacity(0.8),
            Color(0xFF1A6B3C).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2D9E5F).withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Color(0xFFFFD700).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Ikon amplop animasi
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  _envelopeOpened ? Icons.drafts : Icons.mail,
                  color: Color(0xFFFFD700),
                  size: 28,
                ),
                if (!_envelopeOpened)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 2000.ms, color: Color(0xFFFFD700).withOpacity(0.3)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _envelopeOpened ? "Kartu Ucapan Dibuka ✅" : "📬 Ada Kartu Ucapan Untukmu",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _envelopeOpened
                      ? "Ketuk untuk membuka kembali"
                      : "🎉 Selamat Idul Fitri 1447H — Ketuk untuk buka surat",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFFFD700).withOpacity(0.8),
            size: 28,
          ),
        ],
      ),
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
}

void _showIdulFitriCard(BuildContext context) {
  setState(() => _envelopeOpened = true);
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Tutup",
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: Duration(milliseconds: 500),
    transitionBuilder: (ctx, anim, secAnim, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, anim, secAnim) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D4A2A),
                  Color(0xFF1A6B3C),
                  Color(0xFF0D4A2A),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2D9E5F).withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dekorasi bintang latar
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: CustomPaint(
                      painter: _StarPatternPainter(),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ornamen atas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _goldDividerLine(),
                          SizedBox(width: 12),
                          Text("✦", style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
                          SizedBox(width: 8),
                          Text("☪", style: TextStyle(color: Color(0xFFFFD700), fontSize: 22)),
                          SizedBox(width: 8),
                          Text("✦", style: TextStyle(color: Color(0xFFFFD700), fontSize: 20)),
                          SizedBox(width: 12),
                          _goldDividerLine(),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Bismillah
                      Text(
                        "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700).withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Dengan Menyebut Nama Allah Yang Maha Pengasih, Maha Penyayang",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Judul kartu
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFFFFD700), Colors.white, Color(0xFFFFD700)],
                        ).createShader(bounds),
                        child: Text(
                          "Selamat Hari Raya\nIdul Fitri 1447 H",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Minal Aidin Wal Faizin",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700).withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Garis pembatas
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFFFD700).withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Pesan permintaan maaf
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFFFFD700).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "🙏 Mohon Maaf Lahir & Batin 🙏",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              "Di hari yang fitri ini, kami dengan segala kerendahan hati memohon maaf atas segala kesalahan, kekurangan, dan kekhilafan yang pernah kami perbuat, baik yang disengaja maupun tidak disengaja.\n\nSemoga Allah SWT menerima amal ibadah kita, mempertemukan kita kembali di Ramadhan yang akan datang, dan menjadikan kita termasuk orang-orang yang kembali fitri. 🌿",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12.5,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Tanda tangan
                      Text(
                        "— Tim otax dashboard —",
                        style: TextStyle(
                          color: Color(0xFFFFD700).withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Taqabbalallahu Minna Wa Minkum 🤲",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                      SizedBox(height: 24),

                      // Tombol tutup
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFFD700).withOpacity(0.3),
                                Color(0xFFFFD700).withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Color(0xFFFFD700).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            "Tutup 🌙",
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
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
    },
  );
}

Widget _goldDividerLine() {
  return Expanded(
    child: Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Color(0xFFFFD700).withOpacity(0.7),
          ],
        ),
      ),
    ),
  );
}

Widget _buildUpdateBanner() {
  final isCritical = _updateInfo?['critical'] == true;
  final version = _updateInfo?['version'] ?? 'terbaru';
  
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UpdateModulePage(
            sessionKey: sessionKey,
            username: username,
            role: role,
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCritical
              ? [Color(0xFFD32F2F), Color(0xFFB71C1C)]
              : [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? Colors.red[300]! : Colors.blue[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCritical 
                ? Colors.red.withOpacity(0.3)
                : Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Icon(
                isCritical ? Icons.warning : Icons.system_update,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isCritical ? 'UPDATE KRITIS' : 'UPDATE TERSEDIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v$version',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Versi terbaru telah tersedia. Ketuk untuk mengupdate aplikasi.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                if (_changelog.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    'Fitur baru:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ..._changelog.take(2).map((change) => Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Colors.white),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            change,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 18,
          ),
        ],
      ),
    ),
  );
}
Widget _buildHadithQuoteCard() {
  final hadith = _currentHadith;
  final arabic = hadith?['arab'] ?? '';
  final translation = hadith?['id'] ?? '';
  final number = hadith?['number'] ?? '';
  
  // Ambil teks hadis saja (tanpa sanad panjang)
  String getShortHadith(String arabicText) {
    // Cari kata 'قَالَ' yang menandakan awal hadis
    final parts = arabicText.split('قَالَ');
    if (parts.length > 1) {
      for (var part in parts) {
        if (part.contains('رَسُولُ اللَّهِ') || part.contains('النَّبِيُّ')) {
          final hadithText = 'قَالَ$part'.trim();
          // Ambil maksimal 100 karakter
          return hadithText.length > 100 
              ? '${hadithText.substring(0, 100)}...'
              : hadithText;
        }
      }
      // Ambil bagian terakhir jika tidak menemukan pola
      final lastPart = parts.last;
      return lastPart.length > 100 
          ? '${lastPart.substring(0, 100)}...'
          : lastPart;
    }
    // Jika tidak ditemukan, ambil 100 karakter pertama
    return arabicText.length > 100 
        ? '${arabicText.substring(0, 100)}...'
        : arabicText;
  }
  
  String getShortTranslation(String translationText) {
    // Cari terjemah yang sebenarnya (biasanya setelah 'Rasulullah ﷺ bersabda:')
    if (translationText.contains('Rasulullah ﷺ bersabda:')) {
      final index = translationText.indexOf('Rasulullah ﷺ bersabda:');
      return translationText.substring(index);
    }
    
    // Cari baris yang berisi terjemah (biasanya diawali dengan tanda —)
    final lines = translationText.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('—') || line.contains('bersabda') || line.contains('Rasulullah')) {
        return line.length > 120 
            ? '${line.substring(0, 120)}...'
            : line;
      }
    }
    
    // Jika tidak ditemukan, ambil 120 karakter pertama
    return translationText.length > 120 
        ? '${translationText.substring(0, 120)}...'
        : translationText;
  }
  
  final shortArabic = getShortHadith(arabic);
  final shortTranslation = getShortTranslation(translation);
  
  // Loading state dengan pesan motivasi
  if (_isLoadingHadith || shortArabic.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A).withOpacity(0.9),
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF475569).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF475569).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0EA5E9).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.book,
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
                      "HADITH OF THE DAY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Sahih Muslim • Loading...",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Motivasi Message dengan animasi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF0EA5E9).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFF59E0B),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  "Sempatkan Waktumu",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Untuk Membaca 1 Hadist",
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.black.withOpacity(0.3),
                    color: Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Hadis sudah loaded, tampilkan hadis
  return GestureDetector(
    onTap: () {
      _showFullHadithPage();
    },
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A).withOpacity(0.9),
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF475569).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF475569).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan judul hadis
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0EA5E9).withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.book,
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
                      "HADITH OF THE DAY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Sahih Muslim • Tap to read full",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Arabic Hadith Text (pendek)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shortArabic,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Uthmanic',
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Short Translation
          if (shortTranslation.isNotEmpty && shortTranslation != shortArabic)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                shortTranslation,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          const SizedBox(height: 12),
          
          // Footer dengan info hadis
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(0xFF0EA5E9).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.library_books,
                      size: 12,
                      color: Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Muslim #${number}",
                      style: TextStyle(
                        color: Color(0xFF0EA5E9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Indicator bahwa ini bisa di-tap
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Tap for full",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
void _showFullHadithPage() {
  final currentHadith = _currentHadith;
  
  if (currentHadith == null) return;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.9),
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header dengan close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book_outlined,
                    color: Color(0xFF0EA5E9),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "HADITH FULL TEXT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "Sahih Muslim • Hadith #${currentHadith['number']}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Arabic Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.text_snippet,
                                color: Color(0xFF0EA5E9),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "ARABIC TEXT",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentHadith['arab'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontFamily: 'Uthmanic',
                              height: 1.7,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Section: Translation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.translate,
                                color: Color(0xFF0EA5E9),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "TRANSLATION",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentHadith['id'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Kitab Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF0EA5E9).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Color(0xFF0EA5E9).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF0EA5E9),
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Hadith ini berasal dari Sahih Muslim, salah satu kitab hadis paling shahih setelah Sahih Bukhari.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Footer Actions - tampilkan refresh di sini saja
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Refresh Button - lebih besar di halaman full
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _fetchHadith();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mengambil hadis baru...'),
                            backgroundColor: Color(0xFF0EA5E9),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text("AMBIL HADIS BARU"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 3,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "TUTUP",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
Widget _buildStatChip({
  required FaIconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Column(
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

// News Card with Hover Effect
Widget _buildNewsCard(Map<String, dynamic> item, int index) {
  return Container(
    width: 280,
    margin: EdgeInsets.only(right: 16),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Handle news tap
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF252A3A),
                Color(0xFF1A1F2E),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Stack(
                    children: [
                      if (item['image'] != null)
                        Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(item['image']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.new_releases,
                                color: Color(0xFFFF5722),
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "NEW",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['title'] ?? 'No Title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withOpacity(0.5),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Just now",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.arrow_forward,
                            color: Color(0xFFFF5722),
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Action Tile for Quick Actions
Widget _buildActionTile({
  required String title,
  required String subtitle,
  required FaIconData icon,
  required Color iconColor,
  required List<Color> gradient,
  required VoidCallback onTap,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 12,
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
String _formatLastUpdate(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);
  
  if (difference.inSeconds < 60) {
    return '${difference.inSeconds}s ago';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else {
    return '${difference.inDays}d ago';
  }
}
// Status Indicator
Widget _buildStatusIndicator({
  required String title,
  required String status,
  required Color color,
  required int value,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      Container(
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(
              flex: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              flex: 100 - value,
              child: SizedBox(),
            ),
          ],
        ),
      ),
      SizedBox(height: 4),
      Text(
        "$value%",
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      ),
    ],
  );
}

// Social Button
Widget _buildSocialButton({
  required FaIconData icon,
  required Color color,
  required String label,
  String? url,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap ?? () async {
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await launchUrl(uri);
        }
      }
    },
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// Widget untuk membuat Premium Card yang elegant
Widget _buildPremiumCard({
  required String title,
  required String subtitle,
  required FaIconData icon,
  required Color iconColor,
  required List<Color> gradientColors,
  required VoidCallback onTap,
  required List<String> features,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo.jpg'),
                      repeat: ImageRepeat.repeat,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Icon
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: 32,
                          ),
                        ),
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
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Features List
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              feature,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Tap Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "TAP TO OPEN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Glow Effect
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
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

// Widget untuk Mini Action Button
Widget _buildMiniActionButton({
  required FaIconData icon,
  required String label,
  required Color color,
}) {
  return Column(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
    // Fungsi untuk membangun tombol kontak
  List<Widget> _buildContactActions() {
    return [
      _contactActionButton(
        icon: FontAwesomeIcons.telegram,
        label: "Telegram",
        url: 'https://t.me/Otapengenkawin',
        color: lightRed,
      ),
      _contactActionButton(
        icon: FontAwesomeIcons.telegram,
        label: "Channel",
        url: 'https://t.me/',
        color: lightRed,
      ),
      _contactActionButton(
        icon: FontAwesomeIcons.tiktok,
        label: "TikTok",
        url: 'https://www.tiktok.com/Otax',
        color: lightRed,
      ),
    ];
  }

  Widget _contactActionButton({
    required FaIconData icon,
    required String label,
    required String url,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          await launchUrl(uri);
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhancedGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: glassBlack,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: bloodRed.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bloodRed.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _enhancedInfoRow(IconData icon, String label, String value,
      {Color valueColor = Colors.white}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bloodRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bloodRed.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: bloodRed, size: 20),
          ),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.bold,
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
  return Scaffold(
    drawer: _buildDrawer(),
    backgroundColor: deepBlack,
    extendBody: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: Opacity(
        opacity: 0.10,
        child: Image.asset(
          'assets/images/ketupat_deco.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),

      title: Container(
        height: 50,
        child: Image.asset(
          'assets/images/otaxlogo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.white],
              ).createShader(bounds),
              child: const Text(
                "OTAX",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.music_note, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: deepBlack,
                  body: SpotifyMusicPlayer(
                    sessionKey: sessionKey,
                    username: username,
                  ),
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications),
              if (hasUnreadNotif)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _openNotifications,
        ),
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: cardDark,
                title: Text("Keluar", style: TextStyle(color: Colors.white)),
                content: Text(
                  "Apakah Anda yakin ingin keluar?",
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Batal", style: TextStyle(color: bloodRed)),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                    child: Text("Keluar", style: TextStyle(color: bloodRed)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),

    // ✅ BODY DIBUNGKUS STACK - masjid di pojok bawah
    body: Stack(
      children: [
        // Konten halaman utama (existing)
        FadeTransition(opacity: _animation, child: _selectedPage),

        // ✅ HIASAN IDUL FITRI - Bedug kiri bawah
        Positioned(
          bottom: 62,
          left: -10,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.13,
              child: Image.asset(
                'assets/images/bedug_deco.png',
                width: 110,
                height: 110,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // ✅ HIASAN IDUL FITRI - Ketupat kanan bawah
        Positioned(
          bottom: 62,
          right: -8,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.13,
              child: Image.asset(
                'assets/images/ketupat_deco.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 75,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFFFFD700).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "✨ Minal Aidin Wal Faizin 1447H ✨",
                  style: TextStyle(
                    color: Color(0xFFFFD700).withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),

    bottomNavigationBar: _buildGlassBottomNavBar(),
  );
}

// PERUBAHAN: Widget Drawer yang lebih elegan
Widget _buildDrawer() {
  // Tambahkan definisi warna di sini
  final Color darkRed = const Color(0xFFB71C1C);
  final Color accentRed = const Color(0xFFFF5252);
  final Color primaryWhite = Colors.white;

  return Drawer(
    width: MediaQuery.of(context).size.width * 0.85,
    backgroundColor: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.98),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: darkRed.withOpacity(0.5),
            blurRadius: 50,
            spreadRadius: 5,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background efek partikel
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      darkRed.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              // Header dengan efek khusus
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      darkRed.withOpacity(0.8),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: darkRed.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Efek cahaya belakang
                    Positioned(
                      top: -50,
                      left: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentRed.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo dengan efek khusus
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                accentRed,
                                darkRed,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentRed.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                            child: const CircleAvatar(
                              radius: 40,
                              backgroundImage: AssetImage('assets/images/logo.jpg'),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Nama aplikasi dengan efek gradient
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              accentRed,
                              Colors.white,
                              accentRed,
                            ],
                            stops: const [0.1, 0.5, 0.9],
                          ).createShader(bounds),
                          child: const Text(
                            'OTAX',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        Container(
                          width: 100,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                accentRed.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // User info di bagian bawah header
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            widget.username,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  darkRed.withOpacity(0.5),
                                  accentRed.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: accentRed.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentRed,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentRed.withOpacity(0.8),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.role.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentRed,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentRed.withOpacity(0.8),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Exp: ${widget.expiredDate}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
  child: ListView(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
    children: [
     if (widget.role == "KINGZ" || widget.role == "OWNER")
  _buildMenuItem(
    icon: Icons.admin_panel_settings,
    title: 'Admin Page',
    accentRed: accentRed,
    darkRed: darkRed,
    onTap: () {
      Navigator.pop(context);
      _navigateToAdminPage();
    },
  ),
      
      if (widget.role == "KINGZ")
        _buildMenuItem(
          icon: Icons.notifications_active,
          title: 'Kirim Notifikasi',
          accentRed: accentRed,
          darkRed: darkRed,
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SendNotificationPage(
                  sessionKey: widget.sessionKey,
                  username: widget.username,
                ),
              ),
            );
          },
        ),
      
      _buildMenuItem(
        icon: Icons.storefront,
        title: 'Pasar Online',
        accentRed: accentRed,
        darkRed: darkRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PasarOnlinePage(
                sessionKey: widget.sessionKey,
                username: widget.username,
                role: widget.role,
              ),
            ),
          );
        },
      ),
      _buildMenuItem(
        icon: Icons.lock_reset,
        title: 'Change Password',
        accentRed: accentRed,
        darkRed: darkRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangePasswordPage(
                username: widget.username,
                sessionKey: widget.sessionKey,
              ),
            ),
          );
        },
      ),
      
      _buildMenuItem(
        icon: Icons.fingerprint,
        title: 'NIK Check',
        accentRed: accentRed,
        darkRed: darkRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NikCheckerPage(),
            ),
          );
        },
      ),
      _buildMenuItem(
        icon: Icons.system_update_alt,
        title: 'Update App',
        accentRed: accentRed,
        darkRed: darkRed,
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UpdateModulePage(
                sessionKey: widget.sessionKey,
                username: widget.username,
                role: widget.role,
              ),
            ),
          );
        },
      ),
    ],
  ),
),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'OTAX © 2026',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    letterSpacing: 1,
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

// Helper untuk membuat menu item yang elegan
Widget _buildMenuItem({
  required FaIconData icon,
  required String title,
  required Color accentRed,
  required Color darkRed,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accentRed.withOpacity(0.2),
        highlightColor: darkRed.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      darkRed.withOpacity(0.5),
                      accentRed.withOpacity(0.3),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: darkRed.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: accentRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: accentRed.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
Widget _buildGlassBottomNavBar() {
  final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
  
  return Container(
    height: 70 + bottomPadding, // Tambahkan padding bottom dari viewport
    padding: EdgeInsets.only(bottom: bottomPadding), // Beri padding untuk notch/safe area
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.8),
          Colors.black.withOpacity(0.9),
        ],
      ),
    ),
    child: Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: bloodRed.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated Background Effect
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: (_bottomNavIndex * (MediaQuery.of(context).size.width - 40) / 4),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 40) / 4,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bloodRed.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
                
                // Navigation Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_rounded,
                      label: "Home",
                      activeIcon: Icons.home_filled,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: FontAwesomeIcons.whatsapp,
                      label: "WhatsApp",
                      activeIcon: FontAwesomeIcons.whatsappSquare,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.group,
                      label: "Bug Group",
                      activeIcon: Icons.group_work,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.build_circle_outlined,
                      label: "Tools",
                      activeIcon: Icons.build_circle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
Widget _buildNavItem({
  required int index,
  required FaIconData icon,
  required String label,
  required IconData activeIcon,
}) {
  bool isActive = _bottomNavIndex == index;
  
  return GestureDetector(
    onTap: () => _onBottomNavTapped(index),
    child: Container(
      width: (MediaQuery.of(context).size.width - 40) / 4,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with Animation
          Stack(
            alignment: Alignment.center,
            children: [
              // Background Glow for Active Item
              if (isActive)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        bloodRed.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      radius: 0.7,
                    ),
                  ),
                ),
              
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive 
                    ? bloodRed.withOpacity(0.2)
                    : Colors.transparent,
                  border: Border.all(
                    color: isActive 
                      ? bloodRed.withOpacity(0.5)
                      : Colors.transparent,
                    width: isActive ? 1.5 : 0,
                  ),
                  boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: bloodRed.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey<bool>(isActive),
                      color: isActive ? bloodRed : Colors.white.withOpacity(0.7),
                      size: isActive ? 22 : 20,
                    ),
                  ),
                ),
              ),
              
              // Pulsing Dot for Active Item
              if (isActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bloodRed,
                      boxShadow: [
                        BoxShadow(
                          color: bloodRed.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 6),
          
          // Label with Animation
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive 
                ? bloodRed.withOpacity(0.15)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isActive 
                  ? bloodRed 
                  : Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: isActive ? 0.5 : 0.3,
                shadows: isActive
                  ? [
                      Shadow(
                        color: bloodRed.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
              ),
            ),
          ),
          
          // Animated Underline for Active Item
          if (isActive)
            Container(
              margin: EdgeInsets.only(top: 4),
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bloodRed, bloodRed.withOpacity(0.5)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: bloodRed.withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: glassBlack,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: bloodRed.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: bloodRed.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bloodRed.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [bloodRed, lightRed],
                  ).createShader(bounds),
                  child: const Text(
                    "Account Info",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                _enhancedInfoRow(Icons.person, "Username", username),
                _enhancedInfoRow(Icons.shield, "Role", role),
                _enhancedInfoRow(Icons.calendar_today, "Expired", expiredDate),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [bloodRed, darkRed],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                            (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

@override
void dispose() {
  // Cancel semua timer dengan aman
  try {
    _timeTimer?.cancel();
    _hadithTimer?.cancel();
    _fetchTimer?.cancel();
    _healthCheckTimer?.cancel();
    _sholatTimer?.cancel(); 
    _realTimeClockTimer?.cancel();
  } catch (e) {
    print("⚠️ Error cancelling timers: $e");
  }
  try {
    if (channel != null) {
      channel.sink.close(1000, 'App disposed');
    }
  } catch (e) {
    print("⚠️ Error closing WebSocket: $e");
  }
  _videoController?.dispose();
  _controller?.dispose();
  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
  super.dispose();
}
}
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _controller?.setLooping(true);
          _controller?.setVolume(0.0);
          _controller?.play();
        });
    }
  }

  bool _isVideo(String url) =>
      url.endsWith(".mp4") ||
          url.endsWith(".webm") ||
          url.endsWith(".mov") ||
          url.endsWith(".mkv");

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_controller != null && _controller!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        );
      } else {
        return Center(child: CircularProgressIndicator(color: Colors.red));
      }
    } else {
      return Image.network(widget.url, fit: BoxFit.cover);
    }
  }
}
class _ModernActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Gradient gradient;
  final VoidCallback onTap;
  final int index;

  const _ModernActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        ScaleEffect(
          duration: 400.ms,
          curve: Curves.easeOutBack,
          delay: (100 * index).ms,
        ),
        FadeEffect(duration: 400.ms),
      ],
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            "Tap →",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.transparent,
                        Colors.black.withOpacity(0.05),
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
}
// ════════════════════════════════════════════════
// ⭐ STAR PATTERN PAINTER FOR IDUL FITRI CARD
// ════════════════════════════════════════════════
class _StarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFFFD700).withOpacity(0.07)
      ..style = PaintingStyle.fill;

    final random = Random(42);
    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    final crescentPaint = Paint()
      ..color = Color(0xFFFFD700).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), 24, crescentPaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.85), 18, crescentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const gridSize = 30.0;

    
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

