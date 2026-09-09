
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class GlobalMusicPlayer {
  static final AudioPlayer player = AudioPlayer();
  static Map<String, dynamic>? currentTrack;
  static bool isPlaying = false;
  static String? currentAudioUrl;
}

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});
  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _searchResults = [];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final Color bloodRed = const Color(0xFFD32F2F);
  final Color darkRed = const Color(0xFF8E0000);
  final Color lightRed = const Color(0xFFFFEAEA);
  final Color deepBlack = const Color(0xFF0D0D0D);
  final Color cardDark = const Color(0xFF1C1C1C);
  final Color textGrey = const Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    GlobalMusicPlayer.player.positionStream.listen((p) {
      setState(() => _position = p);
    });
    GlobalMusicPlayer.player.durationStream.listen((d) {
      setState(() => _duration = d ?? Duration.zero);
    });
    GlobalMusicPlayer.player.playerStateStream.listen((state) {
      setState(() {
        GlobalMusicPlayer.isPlaying = state.playing;
      });
    });
  }

  Future<List<Map<String, dynamic>>> searchYouTube(String query) async {
    try {
      final res = await http.get(Uri.parse(
          "https://api.nekolabs.web.id/discovery/youtube/search?q=$query"));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final List list = body["result"] ?? [];
      return list
          .map<Map<String, dynamic>>((e) => {
                "title": e["title"] ?? "Unknown Title",
                "url": e["url"] ?? "",
                "channel": e["channel"] ?? "Unknown Channel",
                "thumbnail": e["thumbnail"] ??
                    "https://img.youtube.com/vi/${_extractVideoId(e["url"] ?? "")}/0.jpg"
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  String? _extractVideoId(String url) {
    final regExp = RegExp(
        r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<Map<String, dynamic>> _getMusicInfo(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final api = "https://api.nekolabs.web.id/downloader/youtube/play/v1?q=$encodedQuery";

      final res = await http
          .get(Uri.parse(api))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        throw Exception("API request failed with status ${res.statusCode}");
      }

      final body = jsonDecode(res.body);
      
      if (body["success"] != true) {
        throw Exception("API returned unsuccessful response");
      }

      final result = body["result"];
      
      if (result == null) {
        throw Exception("No result in API response");
      }

      // Extract metadata and download URL
      final metadata = result["metadata"] ?? {};
      final downloadUrl = result["downloadUrl"] ?? "";
      
      if (downloadUrl.isEmpty) {
        throw Exception("No download URL found in response");
      }

      return {
        "title": metadata["title"] ?? "Unknown Title",
        "channel": metadata["channel"] ?? "Unknown Channel",
        "duration": metadata["duration"] ?? "0:00",
        "cover": metadata["cover"] ?? "https://via.placeholder.com/120x68/1C1C1C/D32F2F?text=Music",
        "url": metadata["url"] ?? "",
        "downloadUrl": downloadUrl,
      };
    } catch (e) {
      print("Error in _getMusicInfo: $e");
      throw Exception("Failed to get music info: ${e.toString()}");
    }
  }

  Future<void> _fetchMusic() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults.clear();
    });
    
    try {
      // Jika input adalah URL, coba ekstrak video ID dan cari berdasarkan itu
      if (q.startsWith("http")) {
        final videoId = _extractVideoId(q);
        if (videoId != null) {
          try {
            // Coba dapatkan info musik dari API langsung
            final musicInfo = await _getMusicInfo(q);
            _searchResults = [{
              "title": musicInfo["title"],
              "url": musicInfo["url"],
              "channel": musicInfo["channel"],
              "thumbnail": musicInfo["cover"],
              "duration": musicInfo["duration"],
              "downloadUrl": musicInfo["downloadUrl"],
            }];
          } catch (e) {
            // Jika gagal, gunakan pencarian YouTube biasa
            _searchResults = await searchYouTube(q);
          }
        } else {
          _searchResults = await searchYouTube(q);
        }
      } else {
        // Jika input adalah teks pencarian
        try {
          // Coba dapatkan musik langsung dari API
          final musicInfo = await _getMusicInfo(q);
          _searchResults = [{
            "title": musicInfo["title"],
            "url": musicInfo["url"],
            "channel": musicInfo["channel"],
            "thumbnail": musicInfo["cover"],
            "duration": musicInfo["duration"],
            "downloadUrl": musicInfo["downloadUrl"],
          }];
        } catch (apiError) {
          // Jika API gagal, gunakan pencarian YouTube
          _searchResults = await searchYouTube(q);
        }
      }
      
      if (_searchResults.isEmpty) {
        _error = "No results found";
      }
    } catch (e) {
      _error = "Search failed: ${e.toString()}";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playMusic(Map<String, dynamic> track) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      String audioUrl;
      
      // Coba gunakan downloadUrl jika ada
      if (track.containsKey("downloadUrl") && track["downloadUrl"] != null && track["downloadUrl"].isNotEmpty) {
        audioUrl = track["downloadUrl"];
      } else {
        // Jika tidak ada, coba dapatkan dari API
        final musicInfo = await _getMusicInfo(track["title"]);
        audioUrl = musicInfo["downloadUrl"];
      }
      
      await GlobalMusicPlayer.player.stop();
      await GlobalMusicPlayer.player.setAudioSource(
        ProgressiveAudioSource(Uri.parse(audioUrl)),
      );
      
      GlobalMusicPlayer.currentTrack = track;
      GlobalMusicPlayer.currentAudioUrl = audioUrl;
      await GlobalMusicPlayer.player.play();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Now playing: ${track["title"]}"),
          backgroundColor: darkRed,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Playback error: $e");
      setState(() => _error = "Playback failed: ${e.toString()}");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to play: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (GlobalMusicPlayer.isPlaying) {
      await GlobalMusicPlayer.player.pause();
    } else {
      if (GlobalMusicPlayer.currentTrack != null) {
        await GlobalMusicPlayer.player.play();
      }
    }
  }

  Future<void> _downloadMusic(Map<String, dynamic> track) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      String audioUrl;
      
      // Cari URL audio terlebih dahulu
      if (track.containsKey("downloadUrl") && track["downloadUrl"] != null && track["downloadUrl"].isNotEmpty) {
        audioUrl = track["downloadUrl"];
      } else {
        final musicInfo = await _getMusicInfo(track["title"]);
        audioUrl = musicInfo["downloadUrl"];
      }
      
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode != 200) throw "Download failed";
      
      final dir = await getExternalStorageDirectory();
      final name = "${track["title"]?.toString().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'track'}.mp3";
      final file = File("${dir!.path}/$name");
      await file.writeAsBytes(response.bodyBytes);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloaded: $name"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkRed, bloodRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "MUSIC PLAYER",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),

            // Search Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Search music or paste YouTube URL...",
                          hintStyle: TextStyle(color: textGrey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: Icon(Icons.search, color: textGrey),
                        ),
                        onSubmitted: (_) => _fetchMusic(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [bloodRed, darkRed],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.white),
                        onPressed: _fetchMusic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error Message
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Results
            Expanded(
              child: _isLoading && _searchResults.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: bloodRed),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_note,
                                size: 80,
                                color: cardDark,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Search for music",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: textGrey,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Enter song name or YouTube URL",
                                style: TextStyle(color: textGrey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final track = _searchResults[index];
                            return Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _playMusic(track),
                                  borderRadius: BorderRadius.circular(15),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            track["thumbnail"] ??
                                                "https://via.placeholder.com/80x45/1C1C1C/D32F2F?text=YT",
                                            width: 80,
                                            height: 45,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: darkRed,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    color: bloodRed,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: darkRed,
                                                child: Icon(
                                                  Icons.music_note,
                                                  color: bloodRed,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 15),

                                        // Track Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track["title"] ?? "Unknown Title",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                track["channel"] ?? "Unknown Channel",
                                                style: TextStyle(
                                                  color: textGrey,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (track["duration"] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    track["duration"],
                                                    style: TextStyle(
                                                      color: bloodRed,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Download Button
                                        IconButton(
                                          icon: Icon(Icons.download,
                                              color: bloodRed),
                                          onPressed: () => _downloadMusic(track),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Now Playing Bar
            if (GlobalMusicPlayer.currentTrack != null)
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cardDark, darkRed.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: bloodRed,
                                inactiveTrackColor: cardDark,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: _position.inSeconds.toDouble(),
                                max: _duration.inSeconds.toDouble(),
                                onChanged: (value) async {
                                  await GlobalMusicPlayer.player
                                      .seek(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // Controls
                    Expanded(
                      child: Row(
                        children: [
                          // Track Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    GlobalMusicPlayer.currentTrack?["title"] ??
                                        "Unknown Track",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    GlobalMusicPlayer.currentTrack?["channel"] ??
                                        "Unknown Artist",
                                    style: TextStyle(
                                      color: textGrey,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Control Buttons
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous,
                                    color: Colors.white),
                                onPressed: () {},
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [bloodRed, darkRed],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    GlobalMusicPlayer.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next,
                                    color: Colors.white),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                        ],
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

  @override
  void dispose() {
    GlobalMusicPlayer.player.dispose();
    super.dispose();
  }
}
