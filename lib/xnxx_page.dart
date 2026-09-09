import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdultSafePage extends StatefulWidget {
  const AdultSafePage({Key? key}) : super(key: key);

  @override
  State<AdultSafePage> createState() => _AdultSafePageState();
}

class _AdultSafePageState extends State<AdultSafePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _videoData;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  Future<void> _searchVideos() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results.clear();
      _videoData = null;
      _disposeVideoPlayer();
    });
    try {
      final res = await http.get(Uri.parse("https://restapi-v2.simplebot.my.id/search/xnxx?q=${Uri.encodeComponent(q)}"));
      final json = jsonDecode(res.body);
      if (json["status"] == true) {
        _results = List<Map<String, dynamic>>.from(json["result"].map((e) => {
          "title": e["title"],
          "info": e["info"],
          "link": e["link"],
        }));
      } else {
        _errorMessage = "Tidak ada hasil";
      }
    } catch (e) {
      _errorMessage = "Gagal mencari video";
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _downloadVideo(String link) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _disposeVideoPlayer();
    try {
      final res = await http.get(Uri.parse("https://restapi-v2.simplebot.my.id/download/xnxx?url=${Uri.encodeComponent(link)}"));
      final json = jsonDecode(res.body);
      if (json["status"] == true) {
        _videoData = json["result"];
        await _initPlayer();
      } else {
        _errorMessage = "Gagal mendownload video";
      }
    } catch (e) {
      _errorMessage = "Terjadi kesalahan";
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _initPlayer() async {
    try {
      final url = _videoData?["mp4"];
      if (url == null) return;
      _disposeVideoPlayer();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade500,
        ),
        placeholder: Container(color: Colors.black),
      );
      if (mounted) setState(() {});
    } catch (e) {
      _errorMessage = "Gagal memutar video";
      if (mounted) setState(() {});
    }
  }

  void _disposeVideoPlayer() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _shareVideo() async {
    final url = _videoData?["mp4"];
    if (url == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4");
      await file.writeAsBytes(res.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this video!');
    } catch (e) {
      _errorMessage = "Gagal membagikan video";
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _resultItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
      ),
      elevation: 4,
      child: InkWell(
        onTap: () => _downloadVideo(item["link"]),
        borderRadius: BorderRadius.circular(15),
        splashColor: Colors.redAccent.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 120,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item["title"], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(item["info"] ?? "-", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text("PLAY", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
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
  }

  Widget _videoPlayerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 1)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _chewieController != null && _videoController != null && _videoController!.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.redAccent),
                            const SizedBox(height: 16),
                            const Text("Memuat video...", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _shareVideo,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text("SHARE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _videoData = null;
                        _disposeVideoPlayer();
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text("KEMBALI", style: TextStyle(fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "BOKEP Downloader",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.redAccent),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Cari video...",
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _searchVideos(),
                    ),
                  ),
                  IconButton(
                    onPressed: _searchVideos,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.redAccent),
                    const SizedBox(height: 10),
                    const Text("Memuat...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            if (_videoData == null && _results.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Hasil Pencarian (${_results.length})",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) => _resultItem(_results[i]),
                      ),
                    ),
                  ],
                ),
              ),
            if (_videoData != null)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        _videoData?["title"] ?? "Video",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(child: _videoPlayerSection()),
                  ],
                ),
              ),
            if (_results.isEmpty && _videoData == null && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_filled, color: Colors.redAccent.withOpacity(0.7), size: 80),
                      const SizedBox(height: 20),
                      const Text("Cari Video", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text("Masukkan kata kunci dan tekan enter", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeVideoPlayer();
    super.dispose();
  }
}