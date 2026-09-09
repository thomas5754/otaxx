import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTAX Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 64,
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: const Color(0xFF1DB954),
          inactiveTrackColor: const Color(0xFF2A2A2A),
          thumbColor: Colors.white,
          overlayColor: Colors.white.withOpacity(0.1),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Color(0xFF1DB954),
          unselectedLabelColor: Color(0xFF6B6B6B),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: SpotifyMusicPlayer(
        sessionKey: "spotify_session",
        username: "User",
      ),
    );
  }
}

class SpotifyMusicPlayer extends StatefulWidget {
  final String sessionKey;
  final String username;
  
  const SpotifyMusicPlayer({
    super.key,
    required this.sessionKey,
    required this.username,
  });

  @override
  State<SpotifyMusicPlayer> createState() => _SpotifyMusicPlayerState();
}

class _SpotifyMusicPlayerState extends State<SpotifyMusicPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _isFavorite = false;
  bool _showPlayerControls = false;
  bool _isResuming = false;
  
  double _volume = 0.5;
  double _playbackSpeed = 1.0;
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _playlist = [];
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _downloads = [];
  
  // Download progress tracking: trackId -> progress (0.0-1.0), or -1 if failed
  final Map<String, double> _downloadProgress = {};
  
  Map<String, dynamic>? _currentTrack;
  String _currentAudioUrl = '';
  String? _resumeTrackId;
  
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  int _currentIndex = -1;
  
  final Color _primaryColor = const Color(0xFF1DB954);
  final Color _backgroundColor = const Color(0xFF0A0A0A);
  final Color _surfaceColor = const Color(0xFF141414);
  final Color _cardColor = const Color(0xFF1C1C1C);
  final Color _textColor = Colors.white;
  final Color _subtitleColor = const Color(0xFF808080);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _initAudioPlayer();
    _initAnimation();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveAppState();
    } else if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAppState();
      });
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
      
      if (state == PlayerState.playing) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    });
    
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    
    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
      _savePlaybackState();
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      _handleTrackCompletion();
    });
  }

  void _initAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
  }

  Future<void> _saveAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanedPlaylist = _playlist.map((track) {
        final cleanTrack = Map<String, dynamic>.from(track);
        cleanTrack.removeWhere((key, value) => 
          value == null || value.toString().isEmpty);
        return cleanTrack;
      }).toList();
      
      final cleanedFavorites = _favorites.map((track) {
        final cleanTrack = Map<String, dynamic>.from(track);
        cleanTrack.removeWhere((key, value) => 
          value == null || value.toString().isEmpty);
        return cleanTrack;
      }).toList();
      
      final cleanedHistory = _history.map((item) {
        final cleanItem = Map<String, dynamic>.from(item);
        if (item['type'] == 'play') {
          final cleanTrack = Map<String, dynamic>.from(item['track']);
          cleanTrack.removeWhere((key, value) => 
            value == null || value.toString().isEmpty);
          cleanItem['track'] = cleanTrack;
        }
        return cleanItem;
      }).toList();
      
      await prefs.setString('playlist', jsonEncode(cleanedPlaylist));
      await prefs.setString('favorites', jsonEncode(cleanedFavorites));
      await prefs.setString('history', jsonEncode(cleanedHistory));
      
      // Save downloads
      final cleanedDownloads = _downloads.map((d) {
        final c = Map<String, dynamic>.from(d);
        c.removeWhere((k, v) => v == null || v.toString().isEmpty);
        return c;
      }).toList();
      await prefs.setString('downloads', jsonEncode(cleanedDownloads));
      
      if (_currentTrack != null) {
        final cleanCurrentTrack = Map<String, dynamic>.from(_currentTrack!);
        cleanCurrentTrack.removeWhere((key, value) => 
          value == null || value.toString().isEmpty);
        await prefs.setString('current_track', jsonEncode(cleanCurrentTrack));
      } else {
        await prefs.remove('current_track');
      }
      
      await prefs.setInt('current_index', _currentIndex);
      await prefs.setBool('is_shuffle', _isShuffle);
      await prefs.setBool('is_repeat', _isRepeat);
      await prefs.setDouble('volume', _volume);
      await prefs.setDouble('playback_speed', _playbackSpeed);
      await prefs.setString('audio_url', _currentAudioUrl);
      await prefs.setInt('position', _position.inSeconds);
      await prefs.setBool('is_playing', _isPlaying);
      await prefs.setBool('show_player', _showPlayerControls);
      
      if (_currentTrack != null) {
        await prefs.setString('resume_track_id', _currentTrack!["id"]?.toString() ?? '');
      } else {
        await prefs.remove('resume_track_id');
      }
    } catch (e) {
      debugPrint('Error saving app state: $e');
    }
  }

  Future<void> _loadAppState() async {
    if (_isResuming) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final playlistJson = prefs.getString('playlist');
      final favoritesJson = prefs.getString('favorites');
      final historyJson = prefs.getString('history');
      final downloadsJson = prefs.getString('downloads');
      final currentTrackJson = prefs.getString('current_track');
      final audioUrl = prefs.getString('audio_url') ?? '';
      final position = prefs.getInt('position') ?? 0;
      final wasPlaying = prefs.getBool('is_playing') ?? false;
      final showPlayer = prefs.getBool('show_player') ?? false;
      final resumeTrackId = prefs.getString('resume_track_id');
      
      List<Map<String, dynamic>> loadedPlaylist = [];
      List<Map<String, dynamic>> loadedFavorites = [];
      List<Map<String, dynamic>> loadedHistory = [];
      List<Map<String, dynamic>> loadedDownloads = [];
      
      if (playlistJson != null && playlistJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(playlistJson);
          if (parsed is List) {
            loadedPlaylist = List<Map<String, dynamic>>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing playlist: $e');
        }
      }
      
      if (favoritesJson != null && favoritesJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(favoritesJson);
          if (parsed is List) {
            loadedFavorites = List<Map<String, dynamic>>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing favorites: $e');
        }
      }
      
      if (historyJson != null && historyJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(historyJson);
          if (parsed is List) {
            loadedHistory = List<Map<String, dynamic>>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing history: $e');
        }
      }
      
      if (downloadsJson != null && downloadsJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(downloadsJson);
          if (parsed is List) {
            loadedDownloads = List<Map<String, dynamic>>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing downloads: $e');
        }
      }
      
      Map<String, dynamic>? loadedCurrentTrack;
      if (currentTrackJson != null && currentTrackJson.isNotEmpty) {
        try {
          loadedCurrentTrack = jsonDecode(currentTrackJson);
        } catch (e) {
          debugPrint('Error parsing current track: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _playlist = loadedPlaylist;
          _favorites = loadedFavorites;
          _history = loadedHistory;
          _downloads = loadedDownloads;
          
          _currentIndex = prefs.getInt('current_index') ?? -1;
          _isShuffle = prefs.getBool('is_shuffle') ?? false;
          _isRepeat = prefs.getBool('is_repeat') ?? false;
          _volume = prefs.getDouble('volume') ?? 0.5;
          _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
          _currentAudioUrl = audioUrl;
          _position = Duration(seconds: position);
          _showPlayerControls = showPlayer;
          _resumeTrackId = resumeTrackId;
        });
        if (loadedCurrentTrack != null && loadedCurrentTrack.containsKey('id')) {
          final trackInPlaylist = _playlist.firstWhere(
            (track) => track['id'] == loadedCurrentTrack!['id'],
            orElse: () => {},
          );
          
          if (trackInPlaylist.isNotEmpty) {
            setState(() {
              _currentTrack = trackInPlaylist;
              _isFavorite = _favorites.any((fav) => fav["id"] == trackInPlaylist["id"]);
            });
          } else if (loadedCurrentTrack['track_url'] != null) {
            setState(() {
              _currentTrack = loadedCurrentTrack;
              _isFavorite = _favorites.any((fav) => fav["id"] == loadedCurrentTrack!["id"]);
            });
          }
        }
        if (_currentTrack != null && 
            _currentAudioUrl.isNotEmpty && 
            wasPlaying && 
            resumeTrackId == _currentTrack!['id']) {
          await _resumePlayback();
        }
      }
    } catch (e) {
      debugPrint('Error loading app state: $e');
    } finally {
      _isResuming = false;
    }
  }

  Future<void> _resumePlayback() async {
    if (_currentAudioUrl.isEmpty || _currentTrack == null) return;
    
    try {
      _isResuming = true;
      
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.setVolume(_volume);
      
      final source = UrlSource(_currentAudioUrl);
      await _audioPlayer.play(source);
      
      if (_position.inSeconds > 0) {
        await Future.delayed(const Duration(milliseconds: 500), () async {
          await _audioPlayer.seek(_position);
        });
      }
      
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _showPlayerControls = true;
        });
        _animationController.repeat();
      }
    } catch (e) {
      debugPrint('Error resuming playback: $e');
      await _refreshCurrentAudioUrl();
    } finally {
      _isResuming = false;
    }
  }

  Future<void> _refreshCurrentAudioUrl() async {
    if (_currentTrack == null || _currentTrack!['track_url'] == null) return;
    
    try {
      final newAudioUrl = await _getAudioUrl(_currentTrack!['track_url']);
      if (newAudioUrl != null && mounted) {
        setState(() {
          _currentAudioUrl = newAudioUrl;
        });
        await _saveAppState();
        await _resumePlayback();
      }
    } catch (e) {
      debugPrint('Error refreshing audio URL: $e');
    }
  }

  Future<void> _savePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('position', _position.inSeconds);
      await prefs.setBool('is_playing', _isPlaying);
    } catch (e) {
      debugPrint('Error saving playback state: $e');
    }
  }

  Future<String?> _getAudioUrl(String trackUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(trackUrl);
      final response = await http.get(
        Uri.parse("https://rynekoo-api.hf.space/downloader/youtube/v2?url=$encodedUrl"),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      debugPrint("Audio API status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json["success"] == true && json["result"] != null) {
          final medias = json["result"]["medias"] as List?;
          if (medias != null && medias.isNotEmpty) {
            // Prefer media with is_audio: true (mp4 with audio, usually 360p)
            final audioMedia = medias.firstWhere(
              (m) => m["is_audio"] == true,
              orElse: () => null,
            );
            if (audioMedia != null) {
              final url = audioMedia["url"]?.toString() ?? "";
              if (url.isNotEmpty) return url;
            }
            // Fallback: first media that has a URL
            for (final m in medias) {
              final url = m["url"]?.toString() ?? "";
              if (url.isNotEmpty) return url;
            }
          }
        }
        debugPrint("Audio API returned no usable URL. Response: ${response.body.substring(0, 200)}");
      }
    } catch (e) {
      debugPrint("Error fetching audio: $e");
    }
    return null;
  }

  /// Returns all available media formats for a YouTube URL
  Future<List<Map<String, dynamic>>?> _getMediaFormats(String trackUrl) async {
    try {
      final encodedUrl = Uri.encodeComponent(trackUrl);
      final response = await http.get(
        Uri.parse("https://rynekoo-api.hf.space/downloader/youtube/v2?url=$encodedUrl"),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json["success"] == true && json["result"] != null) {
          final medias = json["result"]["medias"] as List?;
          if (medias != null) {
            return List<Map<String, dynamic>>.from(medias);
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting media formats: $e");
    }
    return null;
  }

  Future<void> _play(Map<String, dynamic> track) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _currentTrack = track;
      _showPlayerControls = true;
      _isFavorite = _favorites.any((fav) => fav["id"] == track["id"]);
    });

    try {
      final audioUrl = await _getAudioUrl(track['track_url']);
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.setVolume(_volume);
        
        final source = UrlSource(audioUrl);
        await _audioPlayer.play(source);
        
        if (mounted) {
          setState(() {
            _currentAudioUrl = audioUrl;
            _position = Duration.zero;
          });
        }
        final existingIndex = _playlist.indexWhere((item) => item["id"] == track["id"]);
        if (existingIndex == -1) {
          if (mounted) {
            setState(() {
              _playlist.add(track);
              _currentIndex = _playlist.length - 1;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentIndex = existingIndex;
            });
          }
        }

        _addToPlayHistory(track);
        await _saveAppState();
      } else {
        _showSnackBar("Audio not available");
      }
    } catch (e) {
      _showSnackBar("Error playing track");
      debugPrint("Play error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleTrackCompletion() {
    if (_isRepeat && _currentTrack != null) {
      _play(_currentTrack!);
    } else if (_playlist.isNotEmpty) {
      _playNext();
    } else {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
      _savePlaybackState();
    }
  }

  Future<void> _playNext() async {
    if (_playlist.isEmpty || _currentIndex == -1) return;
    
    int nextIndex;
    if (_isShuffle) {
      do {
        nextIndex = _getRandomIndex();
      } while (nextIndex == _currentIndex && _playlist.length > 1);
    } else {
      nextIndex = (_currentIndex + 1) % _playlist.length;
    }
    
    if (nextIndex < _playlist.length) {
      if (mounted) {
        setState(() => _currentIndex = nextIndex);
      }
      await _play(_playlist[nextIndex]);
    }
  }

  Future<void> _playPrevious() async {
    if (_playlist.isEmpty || _currentIndex <= 0) return;
    
    final prevIndex = _currentIndex - 1;
    if (mounted) {
      setState(() => _currentIndex = prevIndex);
    }
    await _play(_playlist[prevIndex]);
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
    await _savePlaybackState();
  }

  Future<void> _resume() async {
    if (_currentAudioUrl.isEmpty && _currentTrack != null) {
      await _play(_currentTrack!);
    } else {
      await _audioPlayer.resume();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    }
    await _savePlaybackState();
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _animationController.reset();
      });
    }
    await _saveAppState();
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
    await _savePlaybackState();
  }

  Future<void> _setVolume(double volume) async {
    if (mounted) {
      setState(() => _volume = volume);
    }
    await _audioPlayer.setVolume(volume);
    await _saveAppState();
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    if (mounted) {
      setState(() => _playbackSpeed = speed);
    }
    await _audioPlayer.setPlaybackRate(speed);
    await _saveAppState();
  }

  void _toggleShuffle() {
    if (mounted) {
      setState(() => _isShuffle = !_isShuffle);
    }
    _saveAppState();
  }

  void _toggleRepeat() {
    if (mounted) {
      setState(() => _isRepeat = !_isRepeat);
    }
    _saveAppState();
  }

  void _toggleFavorite() {
    if (_currentTrack == null) return;
    
    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          if (!_favorites.any((fav) => fav["id"] == _currentTrack!["id"])) {
            _favorites.add(_currentTrack!);
          }
        } else {
          _favorites.removeWhere((fav) => fav["id"] == _currentTrack!["id"]);
        }
      });
    }
    
    _saveAppState();
  }

  void _addToPlaylist(Map<String, dynamic> track) {
    if (!_playlist.any((item) => item["id"] == track["id"])) {
      if (mounted) {
        setState(() => _playlist.add(track));
      }
      _showSnackBar("Added to playlist");
      _saveAppState();
    }
  }

  void _removeFromPlaylist(int index) {
    if (index < 0 || index >= _playlist.length) return;
    
    if (mounted) {
      setState(() {
        final removedId = _playlist[index]["id"];
        
        if (_currentIndex == index) {
          _currentIndex = -1;
          _currentTrack = null;
          _currentAudioUrl = '';
          _isPlaying = false;
          _position = Duration.zero;
          _audioPlayer.stop();
        } else if (_currentIndex > index) {
          _currentIndex--;
        }
        
        _playlist.removeAt(index);
        if (!_playlist.any((item) => item["id"] == removedId)) {
          _favorites.removeWhere((fav) => fav["id"] == removedId);
          if (_currentTrack?["id"] == removedId) {
            _isFavorite = false;
          }
        }
      });
    }
     _saveAppState();
  }

  void _clearPlaylist() async {
    await _audioPlayer.stop();
    
    if (mounted) {
      setState(() {
        _playlist.clear();
        _currentIndex = -1;
        _currentTrack = null;
        _currentAudioUrl = '';
        _isPlaying = false;
        _position = Duration.zero;
        _isFavorite = false;
      });
    }
     _saveAppState();
  }

  void _addToHistory(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    
    final existingIndex = _history.indexWhere(
      (item) => item["type"] == "search" && item["query"] == trimmedQuery
    );
    
    if (existingIndex != -1) {
      _history.removeAt(existingIndex);
    }
    
    if (mounted) {
      setState(() => _history.insert(0, {
        "query": trimmedQuery,
        "time": DateTime.now().toIso8601String(),
        "type": "search"
      }));
    }
    
    if (_history.length > 20) {
      _history.removeLast();
    }
    
    _saveAppState();
  }

  void _addToPlayHistory(Map<String, dynamic> track) {
    final existingIndex = _history.indexWhere(
      (item) => item["type"] == "play" && item["track"]["id"] == track["id"]
    );
    
    if (existingIndex != -1) {
      _history.removeAt(existingIndex);
    }
    
    final cleanTrack = Map<String, dynamic>.from(track);
    cleanTrack.removeWhere((key, value) => 
      value == null || value.toString().isEmpty);
    
    if (mounted) {
      setState(() => _history.insert(0, {
        "track": cleanTrack,
        "time": DateTime.now().toIso8601String(),
        "type": "play"
      }));
    }
    
    if (_history.length > 50) {
      _history.removeLast();
    }
    
    _saveAppState();
  }

  int _getRandomIndex() => _playlist.isEmpty ? 0 : DateTime.now().microsecondsSinceEpoch % _playlist.length;

  bool _isDownloaded(String trackId) =>
      _downloads.any((d) => d["id"] == trackId);

  bool _isDownloading(String trackId) =>
      _downloadProgress.containsKey(trackId) &&
      _downloadProgress[trackId]! >= 0 &&
      _downloadProgress[trackId]! < 1.0;

  Future<void> _downloadTrack(Map<String, dynamic> track) async {
    final trackId = track["id"]?.toString() ?? "";
    if (trackId.isEmpty) return;

    if (_isDownloaded(trackId)) {
      _showSnackBar("Already downloaded");
      return;
    }
    if (_isDownloading(trackId)) {
      _showSnackBar("Download already in progress");
      return;
    }

    if (mounted) {
      setState(() => _downloadProgress[trackId] = 0.01);
    }
    _showSnackBar("Downloading: ${track["title"] ?? "track"}");

    try {
      final trackUrl = track["track_url"]?.toString() ?? "";
      if (trackUrl.isEmpty) throw Exception("No track URL");

      // Step 1: Get media URL
      final audioUrl = await _getAudioUrl(trackUrl);
      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception("Could not get audio URL");
      }

      if (mounted) setState(() => _downloadProgress[trackId] = 0.1);

      // Step 2: Download the audio bytes
      final audioResponse = await http.get(Uri.parse(audioUrl)).timeout(
        const Duration(minutes: 5),
      );

      if (audioResponse.statusCode != 200) {
        throw Exception("Download failed: ${audioResponse.statusCode}");
      }

      if (mounted) setState(() => _downloadProgress[trackId] = 0.85);

      // Step 3: Save to app documents directory
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory("${dir.path}/otax_downloads");
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Sanitize filename
      final safeTitle = (track["title"] ?? "track")
          .toString()
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .substring(0, (track["title"]?.toString().length ?? 0).clamp(0, 80));
      final fileName = "${trackId}_$safeTitle.mp4";
      final filePath = "${downloadsDir.path}/$fileName";

      final file = File(filePath);
      await file.writeAsBytes(audioResponse.bodyBytes);

      if (mounted) setState(() => _downloadProgress[trackId] = 1.0);

      // Step 4: Record in downloads list
      final downloadRecord = Map<String, dynamic>.from(track);
      downloadRecord["filePath"] = filePath;
      downloadRecord["downloadedAt"] = DateTime.now().toIso8601String();
      downloadRecord["fileSize"] = audioResponse.bodyBytes.length;

      if (mounted) {
        setState(() {
          _downloads.removeWhere((d) => d["id"] == trackId);
          _downloads.insert(0, downloadRecord);
        });
      }

      await _saveAppState();
      _showSnackBar("✓ Downloaded: ${track["title"] ?? "track"}");
    } catch (e) {
      debugPrint("Download error: $e");
      if (mounted) {
        setState(() => _downloadProgress[trackId] = -1.0); // mark failed
      }
      _showSnackBar("Download failed. Try again.");
      // Clean up failed state after a moment
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _downloadProgress.remove(trackId));
      });
    }
  }

  Future<void> _playDownloadedTrack(Map<String, dynamic> track) async {
    final filePath = track["filePath"]?.toString() ?? "";
    if (filePath.isEmpty) {
      _showSnackBar("File path not found");
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      // File was deleted externally – remove from list
      if (mounted) {
        setState(() => _downloads.removeWhere((d) => d["id"] == track["id"]));
      }
      await _saveAppState();
      _showSnackBar("File not found, removed from downloads");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentTrack = track;
      _showPlayerControls = true;
      _isFavorite = _favorites.any((fav) => fav["id"] == track["id"]);
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play(DeviceFileSource(filePath));

      if (mounted) {
        setState(() {
          _currentAudioUrl = filePath;
          _position = Duration.zero;
        });
      }

      final existingIndex = _playlist.indexWhere((item) => item["id"] == track["id"]);
      if (existingIndex == -1) {
        if (mounted) {
          setState(() {
            _playlist.add(track);
            _currentIndex = _playlist.length - 1;
          });
        }
      } else {
        if (mounted) setState(() => _currentIndex = existingIndex);
      }

      _addToPlayHistory(track);
      await _saveAppState();
    } catch (e) {
      _showSnackBar("Error playing downloaded track");
      debugPrint("Play downloaded error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteDownload(Map<String, dynamic> track) async {
    final filePath = track["filePath"]?.toString() ?? "";
    if (filePath.isNotEmpty) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint("Error deleting file: $e");
      }
    }
    if (mounted) {
      setState(() => _downloads.removeWhere((d) => d["id"] == track["id"]));
    }
    await _saveAppState();
    _showSnackBar("Deleted download");
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "${bytes}B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)}KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB";
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _searchQuery = trimmedQuery;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          "https://api.siputzx.my.id/api/s/youtube?query=${Uri.encodeComponent(trimmedQuery)}"
        ),
        headers: {'accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json["status"] == true && json["data"] != null) {
          final results = List<Map<String, dynamic>>.from(
            (json["data"] as List).map((e) => ({
              "id": e["videoId"]?.toString() ?? "",
              "title": e["title"]?.toString() ?? "Unknown Title",
              "artist": (e["author"] is Map ? e["author"]["name"] : e["author"])?.toString() ?? "Unknown Artist",
              "album": "YouTube",
              "duration": e["duration"] is Map
                  ? (e["duration"]["timestamp"]?.toString() ?? "0:00")
                  : (e["timestamp"]?.toString() ?? "0:00"),
              "durationSeconds": e["duration"] is Map
                  ? (int.tryParse(e["duration"]["seconds"]?.toString() ?? "0") ?? 0)
                  : (int.tryParse(e["seconds"]?.toString() ?? "0") ?? 0),
              "imageUrl": e["image"]?.toString() ?? e["thumbnail"]?.toString() ?? "",
              "track_url": e["url"]?.toString() ?? "https://youtube.com/watch?v=${e["videoId"]}",
              "release_date": e["ago"]?.toString() ?? "",
              "views": e["views"]?.toString() ?? "",
            }))
          ).where((track) =>
            track["id"].toString().isNotEmpty &&
            track["track_url"].toString().isNotEmpty
          ).toList();

          if (mounted) {
            setState(() {
              _results = results;
            });
          }

          _addToHistory(trimmedQuery);
        } else {
          _showSnackBar("No results found");
        }
      } else {
        _showSnackBar("Search failed (${response.statusCode})");
      }
    } catch (e) {
      _showSnackBar("Search error: check connection");
      debugPrint("Search error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (value.length >= 2) {
        _search(value);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                "OTAX Music",
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            _buildAppBarIcon(
              icon: Icons.history_rounded,
              onTap: () => showModalBottomSheet(
                context: context,
                backgroundColor: _surfaceColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                isScrollControlled: true,
                builder: (context) => _buildHistorySheet(),
              ),
            ),
            _buildAppBarIcon(
              icon: Icons.queue_music_rounded,
              onTap: _playlist.isNotEmpty
                  ? () => showModalBottomSheet(
                        context: context,
                        backgroundColor: _surfaceColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        isScrollControlled: true,
                        builder: (context) => _buildPlaylistSheet(),
                      )
                  : null,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen ? 120 : 136),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "Search songs, artists...",
                        hintStyle: TextStyle(color: _subtitleColor, fontSize: 14),
                        filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: Icon(Icons.search_rounded, color: _subtitleColor, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  if (mounted) setState(() => _results.clear());
                                },
                                child: Icon(Icons.close_rounded, color: _subtitleColor, size: 18),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _search,
                    ),
                  ),
                ),
                SizedBox(
                  height: isSmallScreen ? 48 : 56,
                  child: TabBar(
                    indicatorColor: _primaryColor,
                    indicatorWeight: 2.5,
                    dividerColor: Colors.transparent,
                    labelColor: _primaryColor,
                    unselectedLabelColor: _subtitleColor,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.2),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    tabs: const [
                      Tab(icon: Icon(Icons.search_rounded, size: 20), text: "Search"),
                      Tab(icon: Icon(Icons.queue_music_rounded, size: 20), text: "Playlist"),
                      Tab(icon: Icon(Icons.favorite_rounded, size: 20), text: "Favorites"),
                      Tab(icon: Icon(Icons.download_rounded, size: 20), text: "Downloads"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildSearchTab(),
            _buildPlaylistTab(),
            _buildFavoritesTab(),
            _buildDownloadsTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomPlayer(),
      ),
    );
  }

  Widget _buildAppBarIcon({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Icon(
          icon,
          color: onTap != null ? _textColor : _subtitleColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildBottomPlayer() {
    if (_currentTrack == null && !_showPlayerControls) {
      return const SizedBox.shrink();
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      height: _showPlayerControls ? MediaQuery.of(context).size.height * 0.62 : 76,
      child: _currentTrack != null ? _buildPlayerControls() : const SizedBox.shrink(),
    );
  }

  Widget _buildPlayerControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A1A),
            _backgroundColor,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: _primaryColor.withOpacity(0.04),
            blurRadius: 60,
            spreadRadius: 10,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (mounted) setState(() => _showPlayerControls = !_showPlayerControls);
            },
            onPanUpdate: (details) {
              if (details.delta.dy > 3 && mounted) {
                setState(() => _showPlayerControls = false);
              } else if (details.delta.dy < -3 && mounted) {
                setState(() => _showPlayerControls = true);
              }
            },
            child: Container(
              height: 28,
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            child: _showPlayerControls ? _buildExpandedPlayer() : _buildMiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayer() {
    final sw = MediaQuery.of(context).size.width;
    final artSize = sw * 0.6;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) => Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: artSize,
                    height: artSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.25),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _currentTrack!["imageUrl"] != null &&
                              _currentTrack!["imageUrl"].toString().isNotEmpty
                          ? Image.network(
                              _currentTrack!["imageUrl"].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultAlbumArt(artSize),
                            )
                          : _buildDefaultAlbumArt(artSize),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack!["title"]?.toString() ?? "Unknown Title",
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentTrack!["artist"]?.toString() ?? "Unknown Artist",
                        style: TextStyle(
                          color: _subtitleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _toggleFavorite,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isFavorite ? Colors.red.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.red : _subtitleColor,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressSlider(),
            const SizedBox(height: 20),
            _buildMainControls(sw),
            const SizedBox(height: 20),
            _buildVolumeRow(sw),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSlider() {
    final posSeconds = _position.inSeconds.toDouble();
    final durSeconds = _duration.inSeconds.toDouble().clamp(1.0, double.infinity);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: _primaryColor,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.08),
          ),
          child: Slider(
            value: posSeconds.clamp(0, durSeconds),
            max: durSeconds,
            onChanged: (v) {
              if (mounted) setState(() => _position = Duration(seconds: v.toInt()));
            },
            onChangeEnd: (v) => _seek(Duration(seconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(_position),
                style: TextStyle(color: _subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatTime(_duration),
                style: TextStyle(color: _subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls(double sw) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildControlIcon(
          icon: Icons.shuffle_rounded,
          size: 22,
          color: _isShuffle ? _primaryColor : _subtitleColor,
          onTap: _toggleShuffle,
          active: _isShuffle,
        ),
        _buildControlIcon(
          icon: Icons.skip_previous_rounded,
          size: 32,
          color: _playlist.length > 1 ? _textColor : _subtitleColor.withOpacity(0.4),
          onTap: _playlist.length > 1 ? _playPrevious : null,
        ),
        GestureDetector(
          onTap: _isLoading ? null : (_isPlaying ? _pause : _resume),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
          ),
        ),
        _buildControlIcon(
          icon: Icons.skip_next_rounded,
          size: 32,
          color: _playlist.length > 1 ? _textColor : _subtitleColor.withOpacity(0.4),
          onTap: _playlist.length > 1 ? _playNext : null,
        ),
        _buildControlIcon(
          icon: _isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          size: 22,
          color: _isRepeat ? _primaryColor : _subtitleColor,
          onTap: _toggleRepeat,
          active: _isRepeat,
        ),
      ],
    );
  }

  Widget _buildControlIcon({
    required IconData icon,
    required double size,
    required Color color,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Icon(icon, size: size, color: color),
            if (active)
              Positioned(
                bottom: -6,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeRow(double sw) {
    return Row(
      children: [
        Icon(Icons.volume_down_rounded, color: _subtitleColor, size: 18),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white.withOpacity(0.6),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.08),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: _volume,
              min: 0,
              max: 1,
              onChanged: _setVolume,
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded, color: _subtitleColor, size: 18),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: _surfaceColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => _buildSpeedSelector(),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _playbackSpeed != 1.0 ? _primaryColor.withOpacity(0.15) : _cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _playbackSpeed != 1.0 ? _primaryColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                color: _playbackSpeed != 1.0 ? _primaryColor : _subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAlbumArt(double size) {
    return Container(
      width: size,
      height: size,
      color: _cardColor,
      child: Icon(Icons.music_note_rounded, color: _subtitleColor, size: size * 0.3),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Playback Speed',
            style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: speeds.map((speed) {
              final selected = _playbackSpeed == speed;
              return GestureDetector(
                onTap: () {
                  _setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: selected ? _primaryColor : _cardColor,
                    boxShadow: selected
                        ? [BoxShadow(color: _primaryColor.withOpacity(0.35), blurRadius: 16)]
                        : null,
                  ),
                  child: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: selected ? Colors.black : _textColor,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final progress = _duration.inSeconds > 0
        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(_primaryColor),
            minHeight: 2,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: _currentTrack!["imageUrl"] != null &&
                            _currentTrack!["imageUrl"].toString().isNotEmpty
                        ? Image.network(
                            _currentTrack!["imageUrl"].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildMiniDefaultAlbumArt(),
                          )
                        : _buildMiniDefaultAlbumArt(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack!["title"]?.toString() ?? "Unknown Title",
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentTrack!["artist"]?.toString() ?? "Unknown Artist",
                        style: TextStyle(color: _subtitleColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : (_isPlaying ? _pause : _resume),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 12),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _playlist.length > 1 ? _playNext : null,
                  child: Icon(
                    Icons.skip_next_rounded,
                    color: _playlist.length > 1 ? _textColor : _subtitleColor.withOpacity(0.3),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDefaultAlbumArt() {
    return Container(
      color: _cardColor,
      child: Icon(Icons.music_note_rounded, color: _subtitleColor, size: 22),
    );
  }

  Widget _buildSearchTab() {
    if (_isLoading && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor, strokeWidth: 2),
            const SizedBox(height: 16),
            Text("Searching...", style: TextStyle(color: _subtitleColor, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_results.isEmpty && _searchQuery.isNotEmpty && !_isLoading) {
      return _buildEmptyState(Icons.search_off_rounded, "No results found", "Try different keywords");
    }

    if (_results.isEmpty) {
      return _buildEmptyState(Icons.search_rounded, "Search for music", "Find songs, artists, or albums");
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 12,
        bottom: _currentTrack != null ? 100 : 60,
        left: 12,
        right: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        final isCurrent = _currentTrack?["id"] == item["id"];
        return _buildTrackCard(
          item: item,
          isCurrent: isCurrent,
          onTap: () => _play(item),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    if (_favorites.any((f) => f["id"] == item["id"])) {
                      _favorites.removeWhere((f) => f["id"] == item["id"]);
                      _showSnackBar("Removed from favorites");
                    } else {
                      _favorites.add(item);
                      _showSnackBar("Added to favorites");
                    }
                  });
                  _saveAppState();
                },
                child: Icon(
                  _favorites.any((f) => f["id"] == item["id"])
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _favorites.any((f) => f["id"] == item["id"]) ? Colors.red : _subtitleColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _addToPlaylist(item),
                child: Icon(Icons.playlist_add_rounded, color: _subtitleColor, size: 20),
              ),
              const SizedBox(height: 6),
              // Download button
              GestureDetector(
                onTap: () {
                  final id = item["id"]?.toString() ?? "";
                  if (_isDownloaded(id)) {
                    _showSnackBar("Already downloaded");
                  } else if (_isDownloading(id)) {
                    _showSnackBar("Downloading...");
                  } else {
                    _downloadTrack(item);
                  }
                },
                child: _buildDownloadIcon(item["id"]?.toString() ?? ""),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackCard({
    required Map<String, dynamic> item,
    required bool isCurrent,
    required VoidCallback onTap,
    Widget? trailing,
    Widget? customAction,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? _primaryColor.withOpacity(0.1) : _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? _primaryColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _primaryColor.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.02),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: item["imageUrl"] != null && item["imageUrl"].toString().isNotEmpty
                            ? Image.network(
                                item["imageUrl"].toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildSmallDefaultArt(54),
                              )
                            : _buildSmallDefaultArt(54),
                      ),
                    ),
                    if (isCurrent)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.black.withOpacity(0.65),
                            child: Icon(
                              _isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                              color: _primaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["title"]?.toString() ?? "Unknown Title",
                        style: TextStyle(
                          color: isCurrent ? _primaryColor : _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item["artist"]?.toString() ?? "Unknown Artist",
                        style: TextStyle(
                          color: isCurrent ? _primaryColor.withOpacity(0.8) : _subtitleColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item["duration"]?.toString() ?? "0:00",
                          style: TextStyle(
                            color: _subtitleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
                if (customAction != null) ...[
                  const SizedBox(width: 4),
                  customAction,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadIcon(String trackId) {
    if (_isDownloaded(trackId)) {
      return const Icon(Icons.offline_bolt_rounded, color: Color(0xFF1DB954), size: 20);
    }
    if (_downloadProgress.containsKey(trackId)) {
      final progress = _downloadProgress[trackId]!;
      if (progress < 0) {
        return const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20);
      }
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: progress < 1.0 ? progress : null,
          strokeWidth: 2,
          color: const Color(0xFF1DB954),
        ),
      );
    }
    return Icon(Icons.download_rounded, color: _subtitleColor, size: 20);
  }

  Widget _buildSmallDefaultArt(double size) {
    return Container(
      width: size,
      height: size,
      color: _surfaceColor,
      child: Icon(Icons.music_note_rounded, color: _subtitleColor, size: size * 0.4),
    );
  }

  Widget _buildTrackDefaultArt() => _buildSmallDefaultArt(54);
  Widget _buildPlaylistDefaultArt() => _buildSmallDefaultArt(54);
  Widget _buildFavoriteDefaultArt() => _buildSmallDefaultArt(54);

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: _subtitleColor.withOpacity(0.4)),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _subtitleColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTab() {
    if (_playlist.isEmpty) {
      return _buildEmptyState(Icons.queue_music_rounded, "Your playlist is empty",
          "Add songs from search results to build your playlist");
    }

    return Column(
      children: [
        _buildListHeader(
          label: "CURRENT PLAYLIST",
          count: "${_playlist.length} ${_playlist.length == 1 ? 'song' : 'songs'}",
          actions: [
            _buildIconChip(
              icon: Icons.shuffle_rounded,
              active: _isShuffle,
              color: _isShuffle ? _primaryColor : _subtitleColor,
              onTap: _toggleShuffle,
            ),
            const SizedBox(width: 8),
            _buildIconChip(
              icon: Icons.delete_outline_rounded,
              active: false,
              color: Colors.red,
              onTap: () => _showClearConfirm(
                title: "Clear Playlist",
                message: "Remove all songs from playlist?",
                onConfirm: () => _clearPlaylist(),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: 8,
              bottom: _currentTrack != null ? 100 : 60,
              left: 12,
              right: 12,
            ),
            itemCount: _playlist.length,
            itemBuilder: (context, index) {
              final item = _playlist[index];
              final isCurrent = index == _currentIndex;
              return _buildTrackCard(
                item: item,
                isCurrent: isCurrent,
                onTap: () {
                  if (mounted) setState(() => _currentIndex = index);
                  _play(item);
                },
                customAction: GestureDetector(
                  onTap: () => _removeFromPlaylist(index),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: _subtitleColor, size: 18),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return _buildEmptyState(Icons.favorite_border_rounded, "No favorites yet",
          "Tap the heart icon on any song to add it to favorites");
    }

    return Column(
      children: [
        _buildListHeader(
          label: "YOUR FAVORITES",
          count: "${_favorites.length} ${_favorites.length == 1 ? 'song' : 'songs'}",
          actions: [
            _buildIconChip(
              icon: Icons.delete_sweep_rounded,
              active: false,
              color: Colors.red,
              onTap: () => _showClearConfirm(
                title: "Clear Favorites",
                message: "Remove all favorite songs?",
                onConfirm: () {
                  if (mounted) setState(() => _favorites.clear());
                  _showSnackBar("Cleared all favorites");
                  _saveAppState();
                },
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: 8,
              bottom: _currentTrack != null ? 100 : 60,
              left: 12,
              right: 12,
            ),
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final item = _favorites[index];
              final isCurrent = _currentTrack?["id"] == item["id"];
              return _buildTrackCard(
                item: item,
                isCurrent: isCurrent,
                onTap: () => _play(item),
                customAction: GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _favorites.removeAt(index);
                      if (_currentTrack?["id"] == item["id"]) _isFavorite = false;
                    });
                    _showSnackBar("Removed from favorites");
                    _saveAppState();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader({
    required String label,
    required String count,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildIconChip({
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : _cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color.withOpacity(0.4) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showClearConfirm({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(color: _textColor, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(message, style: TextStyle(color: _subtitleColor, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: _subtitleColor, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text("Clear",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsTab() {
    if (_downloads.isEmpty) {
      return _buildEmptyState(
        Icons.download_rounded,
        "No downloads yet",
        "Tap the download icon on any song to save it offline",
      );
    }

    return Column(
      children: [
        _buildListHeader(
          label: "OFFLINE SONGS",
          count: "${_downloads.length} ${_downloads.length == 1 ? 'song' : 'songs'}",
          actions: [
            _buildIconChip(
              icon: Icons.delete_sweep_rounded,
              active: false,
              color: Colors.red,
              onTap: () => _showClearConfirm(
                title: "Clear Downloads",
                message: "Delete all downloaded files from device?",
                onConfirm: () {
                  for (final d in List.from(_downloads)) {
                    _deleteDownload(d);
                  }
                },
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: 8,
              bottom: _currentTrack != null ? 100 : 60,
              left: 12,
              right: 12,
            ),
            itemCount: _downloads.length,
            itemBuilder: (context, index) {
              final item = _downloads[index];
              final isCurrent = _currentTrack?["id"] == item["id"];
              final fileSize = item["fileSize"] as int? ?? 0;
              return _buildDownloadCard(
                item: item,
                isCurrent: isCurrent,
                fileSize: fileSize,
                onTap: () => _playDownloadedTrack(item),
                onDelete: () => _showClearConfirm(
                  title: "Delete Download",
                  message: "Remove \"${item["title"]}\" from device?",
                  onConfirm: () => _deleteDownload(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadCard({
    required Map<String, dynamic> item,
    required bool isCurrent,
    required int fileSize,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? _primaryColor.withOpacity(0.1) : _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? _primaryColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: _primaryColor.withOpacity(0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: item["imageUrl"] != null && item["imageUrl"].toString().isNotEmpty
                            ? Image.network(
                                item["imageUrl"].toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildSmallDefaultArt(54),
                              )
                            : _buildSmallDefaultArt(54),
                      ),
                    ),
                    if (isCurrent)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.black.withOpacity(0.65),
                            child: Icon(
                              _isPlaying ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                              color: _primaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    // Offline badge
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(Icons.offline_bolt_rounded, color: Colors.black, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["title"]?.toString() ?? "Unknown Title",
                        style: TextStyle(
                          color: isCurrent ? _primaryColor : _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item["artist"]?.toString() ?? "Unknown Artist",
                        style: TextStyle(
                          color: isCurrent ? _primaryColor.withOpacity(0.8) : _subtitleColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item["duration"]?.toString() ?? "0:00",
                              style: TextStyle(color: _subtitleColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (fileSize > 0)
                            Text(
                              _formatFileSize(fileSize),
                              style: TextStyle(color: _subtitleColor.withOpacity(0.7), fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red.withOpacity(0.7), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySheet() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildSheetHeader(
            title: "History",
            onClose: () => Navigator.pop(context),
          ),
          Expanded(
            child: _history.isEmpty
                ? _buildEmptyState(Icons.history_rounded, "No history yet",
                    "Your search and play history will appear here")
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final isSearch = item["type"] == "search";
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSearch
                                  ? Colors.blue.withOpacity(0.1)
                                  : _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isSearch ? Icons.search_rounded : Icons.play_arrow_rounded,
                              color: isSearch ? Colors.blue.shade300 : _primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            isSearch
                                ? (item["query"]?.toString() ?? "")
                                : (item["track"]["title"]?.toString() ?? "Unknown Title"),
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatHistoryTime(DateTime.parse(item["time"])),
                            style: TextStyle(color: _subtitleColor, fontSize: 11),
                          ),
                          trailing: isSearch
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.text = item["query"]?.toString() ?? "";
                                    _search(item["query"]?.toString() ?? "");
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.north_west_rounded,
                                        color: Colors.blue.shade300, size: 16),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    _play(item["track"]);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.play_arrow_rounded,
                                        color: _primaryColor, size: 16),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    if (mounted) setState(() => _history.clear());
                    Navigator.pop(context);
                    _showSnackBar("History cleared");
                    _saveAppState();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Clear All History",
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSheet() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildSheetHeader(
            title: "Current Playlist",
            subtitle: "${_playlist.length} songs • ${_formatTotalDuration()}",
            onClose: () => Navigator.pop(context),
            trailingActions: [
              _buildIconChip(
                icon: Icons.shuffle_rounded,
                active: _isShuffle,
                color: _isShuffle ? _primaryColor : _subtitleColor,
                onTap: _toggleShuffle,
              ),
              const SizedBox(width: 8),
            ],
          ),
          Expanded(
            child: _playlist.isEmpty
                ? _buildEmptyState(Icons.queue_music_rounded, "Playlist is empty",
                    "Add songs to start your playlist")
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _playlist.length,
                    itemBuilder: (context, index) {
                      final item = _playlist[index];
                      final isCurrent = index == _currentIndex;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? _primaryColor.withOpacity(0.1) : _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? _primaryColor.withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item["imageUrl"] != null &&
                                    item["imageUrl"].toString().isNotEmpty
                                ? Image.network(
                                    item["imageUrl"].toString(),
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildSmallDefaultArt(46),
                                  )
                                : _buildSmallDefaultArt(46),
                          ),
                          title: Text(
                            item["title"]?.toString() ?? "Unknown Title",
                            style: TextStyle(
                              color: isCurrent ? _primaryColor : _textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item["artist"]?.toString() ?? "Unknown Artist",
                            style: TextStyle(
                              color: isCurrent
                                  ? _primaryColor.withOpacity(0.7)
                                  : _subtitleColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  item["duration"]?.toString() ?? "0:00",
                                  style: TextStyle(
                                    color: _subtitleColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCurrent && _isPlaying) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.equalizer_rounded,
                                    color: _primaryColor, size: 18),
                              ],
                            ],
                          ),
                          onTap: () {
                            if (mounted) setState(() => _currentIndex = index);
                            _play(item);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (_playlist.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _showClearConfirm(
                    title: "Clear Playlist",
                    message: "Remove all songs from playlist?",
                    onConfirm: () {
                      _clearPlaylist();
                      Navigator.pop(context);
                    },
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Clear Playlist",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader({
    required String title,
    String? subtitle,
    required VoidCallback onClose,
    List<Widget>? trailingActions,
  }) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: _subtitleColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingActions != null) ...trailingActions,
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.close_rounded, color: _subtitleColor, size: 18),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.06)),
      ],
    );
  }

  Widget _buildSheetDefaultArt() => _buildSmallDefaultArt(46);


  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatHistoryTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    if (difference.inDays < 7) return "${difference.inDays}d ago";
    
    return "${time.day}/${time.month}/${time.year}";
  }

  String _formatTotalDuration() {
    if (_playlist.isEmpty) return "0:00";
    
    int totalSeconds = 0;
    for (var track in _playlist) {
      if (track["durationSeconds"] != null) {
        totalSeconds += int.tryParse(track["durationSeconds"].toString()) ?? 0;
      }
    }
    
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}