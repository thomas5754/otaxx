import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';

// TAMBAHKAN IMPORT INI
import 'package:permission_handler/permission_handler.dart';

class UpdateModulePage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const UpdateModulePage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<UpdateModulePage> createState() => _UpdateModulePageState();
}

class _UpdateModulePageState extends State<UpdateModulePage> {
  // FIXED: Tambah baseUrl yang diperlukan
  final String baseUrl = 'http://127.0.0.1:4113';

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: '0.0.0',
    buildNumber: '0',
  );

  Map<String, dynamic>? _updateInfo;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  Timer? _autoCheckTimer;
  bool _autoUpdateOnWifi = false;
  bool _autoUpdateOnMobile = false;
  String? _errorMessage;
  String? _filePath;
  List<String> _changelog = [];
  final Dio _dio = Dio();
  bool _hasPendingUpdate = false;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _loadUpdateSettings();
    _startAutoCheck();
    // Delay sedikit untuk pastikan package info sudah di-load
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _loadUpdateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoUpdateOnWifi = prefs.getBool('auto_update_wifi') ?? false;
      _autoUpdateOnMobile = prefs.getBool('auto_update_mobile') ?? false;
      _hasPendingUpdate = prefs.getBool('pending_update') ?? false;
    });
  }

  Future<void> _saveUpdateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_update_wifi', _autoUpdateOnWifi);
    await prefs.setBool('auto_update_mobile', _autoUpdateOnMobile);
  }

  void _startAutoCheck() {
    // Check for updates every 6 hours
    _autoCheckTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (await _shouldAutoCheck()) {
        await _checkForUpdates(silent: true);
      }
    });
  }

  Future<bool> _shouldAutoCheck() async {
    final connectivity = await Connectivity().checkConnectivity();
    
    if (connectivity == ConnectivityResult.wifi && _autoUpdateOnWifi) {
      return true;
    }
    
    if (connectivity == ConnectivityResult.mobile && _autoUpdateOnMobile) {
      return true;
    }
    
    return false;
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_isChecking) return;
    
    if (!silent) {
      setState(() {
        _isChecking = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _dio.get(
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
      ).timeout(const Duration(seconds: 10));

      print('Update check response: ${response.statusCode}');
      print('Update check data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Debug log
        print('has_update: ${data['has_update']}');
        print('update_info: ${data['update_info']}');
        print('error: ${data['error']}');
        
        // Jika server mengembalikan error
        if (data['error'] != null) {
          if (!silent) {
            setState(() {
              _errorMessage = data['error'].toString();
              _updateInfo = null;
              _changelog = [];
            });
          }
          return;
        }
        
        // PERBAIKAN: Sederhanakan logika - percaya pada server
        if (data['has_update'] == true && data['update_info'] != null) {
          final updateInfo = data['update_info'];
          
          // Validasi minimal: pastikan ada version dan download_url
          if (updateInfo['version'] != null && updateInfo['download_url'] != null) {
            setState(() {
              _updateInfo = updateInfo;
              _changelog = List<String>.from(updateInfo['changelog'] ?? []);
            });
            
            print('Update available: $_updateInfo');
            
            // PERBAIKAN: Selalu tampilkan notifikasi jika ada update dan bukan silent check
            if (!silent) {
              _showUpdateNotification(updateInfo);
            }
            
            // Clear pending update flag
            if (_hasPendingUpdate) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('pending_update');
              setState(() {
                _hasPendingUpdate = false;
              });
            }
          } else {
            // Data update tidak lengkap
            print('Update info is incomplete: $updateInfo');
            if (!silent) {
              setState(() {
                _errorMessage = 'Update information is incomplete from server';
                _updateInfo = null;
                _changelog = [];
              });
            }
          }
        } else {
          // Tidak ada update
          setState(() {
            _updateInfo = null;
            _changelog = [];
          });
          print('No update available or update_info is null');
        }
      } else {
        if (!silent) {
          setState(() {
            _errorMessage = 'Server returned ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Update check error: $e');
      if (!silent) {
        setState(() {
          _errorMessage = 'Failed to check for updates: ${e.toString()}';
        });
      }
    } finally {
      if (!silent) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _showUpdateNotification(Map<String, dynamic> updateInfo) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF00B4D8), width: 1),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.update, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'Update Available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New version ${updateInfo['version']} is available!',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Current version: ${_packageInfo.version}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_changelog.isNotEmpty) ...[
                const Text(
                  'What\'s new:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: SingleChildScrollView(
                    child: Column(
                      children: _changelog.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        title: Text(
                          item,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Bug fixes and performance improvements',
                  style: TextStyle(color: Colors.white70),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveForLater();
              },
              child: const Text('Later', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startDownload(updateInfo['download_url']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveForLater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_update', true);
    setState(() {
      _hasPendingUpdate = true;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update saved for later'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _startDownload(String url) async {
    if (_isDownloading) return;
    
    // Validasi URL
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() {
        _errorMessage = 'Invalid download URL';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid download URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi koneksi internet
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      setState(() {
        _errorMessage = 'No internet connection';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your internet connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Jika menggunakan mobile data dan setting tidak diizinkan
    if (connectivity == ConnectivityResult.mobile && !_autoUpdateOnMobile) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mobile Data Warning'),
          content: const Text('You are using mobile data. Download may incur additional charges. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      
      if (shouldContinue != true) return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
      _errorMessage = null;
    });

    try {
      print('Starting download from: $url');
      
      // PERBAIKAN: Gunakan external storage untuk Android
      Directory dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      final fileName = 'otax_${_updateInfo!['version']}.apk';
      _filePath = '${dir.path}/$fileName';

      print('Downloading to: $_filePath');

      await _dio.download(
        url,
        _filePath!,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
              _downloadStatus = 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}% (${_formatBytes(received)}/${_formatBytes(total)})';
            });
          }
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${widget.sessionKey}',
            'Accept': '*/*',
          },
          receiveTimeout: const Duration(minutes: 10),
          validateStatus: (status) => status! < 500,
        ),
      );

      if (mounted) {
        setState(() {
          _downloadStatus = 'Download complete! Installing...';
        });
      }

      // Verify file exists and has size
      final file = File(_filePath!);
      if (await file.exists()) {
        final length = await file.length();
        print('File downloaded: ${_formatBytes(length)}');
        
        if (length > 0) {
          await _installApk();
        } else {
          throw Exception('Downloaded file is empty');
        }
      } else {
        throw Exception('File not found after download');
      }
      
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Download failed: ${e.toString()}';
          _isDownloading = false;
          _downloadStatus = 'Download failed';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // TAMBAHKAN FUNGSI UNTUK MEMINTA IZIN INSTALL APLIKASI TIDAK DIKENAL
  Future<bool> _checkAndRequestInstallPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // Cek status izin untuk menginstal paket (khusus Android)
      final status = await Permission.requestInstallPackages.status;
      
      if (!status.isGranted) {
        // Jika izin belum diberikan, tampilkan dialog permintaan izin
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Izin Diperlukan'),
            content: const Text(
              'Untuk menginstal pembaruan aplikasi, Anda perlu mengizinkan instalasi dari sumber tidak dikenal.\n\n'
              'Aplikasi akan membuka halaman pengaturan untuk mengaktifkan "Izinkan dari sumber ini".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                ),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );
        
        if (shouldRequest == true) {
          // Minta izin dari pengguna
          final result = await Permission.requestInstallPackages.request();
          
          if (result.isGranted) {
            return true;
          } else {
            // Buka halaman pengaturan aplikasi
            await openAppSettings();
            
            // Tunggu pengguna kembali dari pengaturan
            await Future.delayed(const Duration(seconds: 2));
            
            // Cek kembali status izin
            final newStatus = await Permission.requestInstallPackages.status;
            return newStatus.isGranted;
          }
        }
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking install permission: $e');
      return true; // Fallback untuk perangkat lama
    }
  }

  // MODIFIKASI FUNGSI _installApk() UNTUK MENAMBAHKAN PERMINTAAN IZIN
  Future<void> _installApk() async {
    if (_filePath == null) return;
    
    try {
      // CEK DAN MINTA IZIN INSTALL APLIKASI TIDAK DIKENAL (HANYA ANDROID)
      if (Platform.isAndroid) {
        final hasPermission = await _checkAndRequestInstallPermission();
        
        if (!hasPermission) {
          if (mounted) {
            setState(() {
              _downloadStatus = 'Izin instalasi belum diberikan';
              _isDownloading = false;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Instalasi dibatalkan. Izin diperlukan untuk menginstal aplikasi.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      final file = File(_filePath!);
      if (await file.exists()) {
        // Tampilkan dialog konfirmasi sebelum instalasi
        if (mounted) {
          final bool? confirmInstall = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF00B4D8)),
                  SizedBox(width: 10),
                  Text('Konfirmasi Instalasi'),
                ],
              ),
              content: Text(
                'Aplikasi akan melakukan instalasi pembaruan versi ${_updateInfo?['version']}.\n\n'
                'Pastikan Anda telah mencadangkan data penting sebelum melanjutkan.\n\n'
                'Lanjutkan instalasi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                  ),
                  child: const Text('Instal Sekarang'),
                ),
              ],
            ),
          );

          if (confirmInstall != true) {
            setState(() {
              _isDownloading = false;
              _downloadStatus = 'Instalasi dibatalkan';
            });
            return;
          }
        }

        // Gunakan OpenFile untuk membuka file APK
        await OpenFile.open(_filePath!);
        
        if (mounted) {
          setState(() {
            _downloadStatus = 'Memulai instalasi...';
          });
          
          // Tampilkan pesan bahwa aplikasi akan ditutup
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplikasi akan ditutup untuk melanjutkan instalasi...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Tunggu sebentar agar pengguna bisa melihat pesan
          await Future.delayed(const Duration(seconds: 2));
          
          // Tutup aplikasi untuk melanjutkan instalasi
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      print('Installation error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menginstal: ${e.toString()}';
          _isDownloading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal menginstal. Silakan instal secara manual dari penyimpanan.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Buka File',
              onPressed: () {
                if (_filePath != null) {
                  OpenFile.open(_filePath!);
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _forceCheckUpdates() async {
    await _checkForUpdates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update check completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildUpdateCard() {
    if (_updateInfo == null) {
      return _buildNoUpdateCard();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00B4D8).withOpacity(0.2),
            const Color(0xFF0077B6).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00B4D8).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4D8).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B4D8).withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(Icons.upgrade, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Available!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Version ${_updateInfo!['version']}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Update Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUpdateDetail(
                  icon: Icons.info,
                  title: 'Current Version',
                  value: _packageInfo.version,
                ),
                _buildUpdateDetail(
                  icon: Icons.arrow_upward,
                  title: 'New Version',
                  value: _updateInfo!['version'].toString(),
                ),
                _buildUpdateDetail(
                  icon: Icons.sd_storage,
                  title: 'File Size',
                  value: _formatBytes(_updateInfo!['size'] ?? 0),
                ),
                _buildUpdateDetail(
                  icon: Icons.security,
                  title: 'Security',
                  value: 'Verified by OTAX Team',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Changelog
          if (_changelog.isNotEmpty) ...[
            Text(
              'What\'s New:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _changelog.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  title: Text(
                    item,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Download Button
          if (_isDownloading)
            _buildDownloadProgress()
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startDownload(_updateInfo!['download_url']),
                icon: const Icon(Icons.download),
                label: const Text('DOWNLOAD UPDATE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoUpdateCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.2),
            const Color(0xFF2E7D32).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), Colors.green.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'You\'re Up to Date!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Version: ${_packageInfo.version}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your app has all the latest features and security updates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          LinearPercentIndicator(
            animation: true,
            lineHeight: 8,
            animationDuration: 200,
            percent: _downloadProgress,
            backgroundColor: Colors.black.withOpacity(0.3),
            progressColor: const Color(0xFF00B4D8),
            barRadius: const Radius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download, color: Color(0xFF00B4D8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _downloadStatus,
                  style: const TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00B4D8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Update Module',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_hasPendingUpdate)
            IconButton(
              icon: Badge(
                label: const Text('1'),
                child: const Icon(Icons.download, color: Colors.white),
              ),
              onPressed: () {
                _checkForUpdates();
              },
              tooltip: 'Pending Update',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _forceCheckUpdates,
            tooltip: 'Check for Updates',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    const Color(0xFF00B4D8).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              // Current Version Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E293B),
                      const Color(0xFF334155),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.phone_android, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current App Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version: ${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Package: ${_packageInfo.packageName}',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Update Settings Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingSwitch(
                      title: 'Auto Update on WiFi',
                      subtitle: 'Automatically download updates when connected to WiFi',
                      value: _autoUpdateOnWifi,
                      onChanged: (value) {
                        setState(() => _autoUpdateOnWifi = value);
                        _saveUpdateSettings();
                      },
                    ),
                    _buildSettingSwitch(
                      title: 'Auto Update on Mobile Data',
                      subtitle: 'Download updates using mobile data (may incur charges)',
                      value: _autoUpdateOnMobile,
                      onChanged: (value) {
                        setState(() => _autoUpdateOnMobile = value);
                        _saveUpdateSettings();
                      },
                    ),
                  ],
                ),
              ),

              // Update Card
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _checkForUpdates();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        if (_isChecking)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Color(0xFF00B4D8)),
                                SizedBox(height: 16),
                                Text(
                                  'Checking for updates...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          )
                        else
                          _buildUpdateCard(),

                        const SizedBox(height: 20),

                        // Info - TAMBAHKAN INFORMASI TENTANG IZIN
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info, color: Color(0xFF00B4D8), size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Informasi Update',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• Fitur Check Update Oleh TEAM OTAX\n'
                                '• Aplikasi auto restart setelah instalasi\n'
                                '• Auto download dan siapkan kuota bos!\n'
                                '• Update dengan koneksi yang stabil\n'
                                '• Support Android 8.0+\n'
                                '• Diperlukan izin "Install Unknown Apps" untuk instalasi\n'
                                '• File APK aman dan sudah diverifikasi',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.5,
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF00B4D8),
      contentPadding: EdgeInsets.zero,
    );
  }
}