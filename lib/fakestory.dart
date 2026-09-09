import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FakeStoryPage extends StatefulWidget {
  const FakeStoryPage({Key? key}) : super(key: key);

  @override
  State<FakeStoryPage> createState() => _FakeStoryPageState();
}

class _FakeStoryPageState extends State<FakeStoryPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  bool _isLoading = false;
  bool _imageGenerated = false;
  Uint8List? _generatedImage;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = "OTAX AYUN💕";
    _captionController.text = "Bismillah Until Jannah";
    _avatarUrlController.text =
        "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
  }

  Future<void> _generateStory() async {
    if (_usernameController.text.isEmpty) {
      _showToast("Masukkan username");
      return;
    }

    if (_captionController.text.isEmpty) {
      _showToast("Masukkan caption");
      return;
    }

    if (_avatarUrlController.text.isEmpty) {
      _showToast("Masukkan URL avatar");
      return;
    }

    setState(() {
      _isLoading = true;
      _imageGenerated = false;
    });

    try {
      final encodedUsername = Uri.encodeComponent(_usernameController.text);
      final encodedCaption = Uri.encodeComponent(_captionController.text);
      final encodedAvatar = Uri.encodeComponent(_avatarUrlController.text);

      final apiUrl =
          'https://api.ryzumi.net/api/image/fake-story?username=$encodedUsername&caption=$encodedCaption&avatar=$encodedAvatar';

      final response = await http
          .get(
        Uri.parse(apiUrl),
        headers: {'accept': 'image/png'},
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        setState(() {
          _generatedImage = response.bodyBytes;
          _imageGenerated = true;
        });
        _showToast("Story berhasil dibuat!");
      } else {
        throw Exception('Gagal membuat story. Status: ${response.statusCode}');
      }
    } catch (e) {
      _showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToGallery() async {
    if (_generatedImage == null) {
      _showToast("Buat story terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final result = await ImageGallerySaverPlus.saveImage(
        _generatedImage!,
        name: "fake_story_${DateTime.now().millisecondsSinceEpoch}",
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showToast("✅ Story disimpan ke galeri!");
      } else {
        _showToast("❌ Gagal menyimpan story");
      }
    } catch (e) {
      _showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _shareStory() async {
    if (_generatedImage == null) {
      _showToast("Buat story terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/fake_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedImage!);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lihat fake story ini!',
        subject: 'Fake Instagram Story',
      );
    } catch (e) {
      _showToast("Error membagikan story");
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _resetForm() {
    setState(() {
      _usernameController.clear();
      _captionController.clear();
      _avatarUrlController.clear();
      _generatedImage = null;
      _imageGenerated = false;
    });
    _usernameController.text = "OTAX AYUN💕";
    _captionController.text = "Bismillah Until Jannah✨";
    _avatarUrlController.text =
        "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
  }

  void _pasteFromClipboard() {
    _showToast("Tempel dari clipboard");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pembuat Fake Story",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E), // Deep Blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _resetForm,
            tooltip: "Reset Form",
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F7FF),
              Color(0xFFE8EAF6),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE3F2FD), width: 1),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A237E).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Pratinjau Story",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A237E),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _generatedImage != null
                              ? Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      _generatedImage!,
                                      fit: BoxFit.contain,
                                      height: 300,
                                    ),
                                  ),
                                )
                              : Container(
                                  height: 300,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF1A237E)
                                              .withOpacity(0.05),
                                        ),
                                        child: Icon(
                                          Icons.photo_camera_outlined,
                                          size: 60,
                                          color: Colors.blueGrey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        "Story akan muncul di sini",
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade600,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Isi form di bawah untuk membuat pratinjau",
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade400,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          const SizedBox(height: 20),
                          if (_imageGenerated)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: const Color(0xFF4CAF50), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Story Siap Digunakan!",
                                    style: TextStyle(
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
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
              const SizedBox(height: 25),

              // Form Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE3F2FD), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Username Field
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 18, color: Colors.blueGrey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  "Username Instagram",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(
                                color: Colors.blueGrey.shade900,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: "Masukkan username Instagram",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1A237E),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              maxLength: 30,
                            ),
                          ],
                        ),
                      ),

                      // Caption Field
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 18, color: Colors.blueGrey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  "Caption Story",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _captionController,
                              style: TextStyle(
                                color: Colors.blueGrey.shade900,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: "Masukkan caption story...",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1A237E),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              maxLines: 3,
                              maxLength: 100,
                            ),
                          ],
                        ),
                      ),

                      // Avatar URL Field
                      Container(
                        margin: const EdgeInsets.only(bottom: 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.link,
                                    size: 18, color: Colors.blueGrey.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  "URL Foto Profil",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _avatarUrlController,
                              style: TextStyle(
                                color: Colors.blueGrey.shade900,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: "https://contoh.com/avatar.jpg",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1A237E),
                                    width: 2,
                                  ),
                                ),
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(4),
                                  child: ElevatedButton(
                                    onPressed: _pasteFromClipboard,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1A237E).withOpacity(0.1),
                                      foregroundColor: const Color(0xFF1A237E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      "Tempel",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1A237E),
                                      ),
                                    ),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EAF6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFC5CAE9),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: const Color(0xFF1A237E)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Pastikan URL adalah link langsung ke gambar (format: .jpg, .png, dll)",
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade700,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _generateStory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF1A237E).withOpacity(0.3),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 22, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Text(
                                      "BUAT FAKE STORY",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_imageGenerated) ...[
                        const SizedBox(height: 30),
                        const Divider(height: 1, color: Color(0xFFE0E0E0)),
                        const SizedBox(height: 20),
                        Text(
                          "Bagikan Story Anda",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSharing ? null : _saveToGallery,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF1A237E), width: 1.5),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSharing
                                          ? Icons.hourglass_bottom
                                          : Icons.save_alt_rounded,
                                      color: const Color(0xFF1A237E),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isSharing ? "Menyimpan..." : "SIMPAN",
                                      style: TextStyle(
                                        color: const Color(0xFF1A237E),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSharing ? null : _shareStory,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      const Color(0xFF1565C0).withOpacity(0.3),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSharing
                                          ? Icons.hourglass_bottom
                                          : Icons.share_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isSharing ? "Membagikan..." : "BAGIKAN",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Guide Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE3F2FD), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1A237E).withOpacity(0.1),
                            ),
                            child: Icon(Icons.help_outline_rounded,
                                color: const Color(0xFF1A237E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Panduan Penggunaan",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.blueGrey.shade900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStep(1, "Masukkan username Instagram"),
                          _buildStep(2, "Tulis caption story yang diinginkan"),
                          _buildStep(3, "Tempel URL langsung ke foto profil"),
                          _buildStep(4, "Klik tombol 'Buat Fake Story'"),
                          _buildStep(5, "Tunggu hingga gambar muncul"),
                          _buildStep(6, "Simpan atau bagikan hasilnya"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFC5CAE9),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                color: const Color(0xFF1A237E), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Pastikan URL gambar adalah link langsung yang berakhir dengan ekstensi .jpg, .png, atau format gambar lainnya",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A237E).withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "$number",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.blueGrey.shade800,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _captionController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }
}