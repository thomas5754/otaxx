import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FakeTweetPage extends StatefulWidget {
  const FakeTweetPage({Key? key}) : super(key: key);

  @override
  State<FakeTweetPage> createState() => _FakeTweetPageState();
}

class _FakeTweetPageState extends State<FakeTweetPage> {
  // Controllers untuk semua parameter
  final TextEditingController _bgController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _tweetController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _retweetsController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _likesController = TextEditingController();
  bool _verified = true; // untuk verified switch

  bool _isLoading = false;
  bool _imageGenerated = false;
  Uint8List? _generatedImage;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    // Set default values
    _bgController.text = "light";
    _avatarController.text =
        "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
    _imageController.text =
        "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
    _nameController.text = "OTA 💕 Ayun";
    _usernameController.text = "👑 OTAX";
    _tweetController.text = "Selalu Nantikan Pembaruan OTAX";
    _dateController.text = "2025-05-04T10:30:00";
    _retweetsController.text = "999";
    _commentsController.text = "888";
    _likesController.text = "7777";
  }

  Future<void> _generateTweet() async {
    // Validasi field wajib
    if (_nameController.text.isEmpty) {
      _showToast("Masukkan nama tampilan");
      return;
    }
    if (_usernameController.text.isEmpty) {
      _showToast("Masukkan username Twitter");
      return;
    }
    if (_tweetController.text.isEmpty) {
      _showToast("Masukkan konten tweet");
      return;
    }

    setState(() {
      _isLoading = true;
      _imageGenerated = false;
    });

    try {
      // Encode semua parameter
      final bg = Uri.encodeComponent(_bgController.text);
      final avatar = Uri.encodeComponent(_avatarController.text);
      final image = Uri.encodeComponent(_imageController.text);
      final name = Uri.encodeComponent(_nameController.text);
      final username = Uri.encodeComponent(_usernameController.text);
      final tweet = Uri.encodeComponent(_tweetController.text);
      final date = Uri.encodeComponent(_dateController.text);
      final retweets = Uri.encodeComponent(_retweetsController.text);
      final comment = Uri.encodeComponent(_commentsController.text);
      final likes = Uri.encodeComponent(_likesController.text);
      final verified = _verified ? "true" : "false";

      final apiUrl =
          'https://api.ryzumi.net/api/image/faketweet?bg=$bg&avatar=$avatar&image=$image&name=$name&username=$username&tweet=$tweet&date=$date&retweets=$retweets&comment=$comment&likes=$likes&verified=$verified';

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
        _showToast("Tweet berhasil dibuat!");
      } else {
        throw Exception('Gagal membuat tweet. Status: ${response.statusCode}');
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
      _showToast("Buat tweet terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final result = await ImageGallerySaverPlus.saveImage(
        _generatedImage!,
        name: "fake_tweet_${DateTime.now().millisecondsSinceEpoch}",
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showToast("✅ Tweet disimpan ke galeri!");
      } else {
        _showToast("❌ Gagal menyimpan tweet");
      }
    } catch (e) {
      _showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _shareTweet() async {
    if (_generatedImage == null) {
      _showToast("Buat tweet terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/fake_tweet_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedImage!);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lihat fake tweet ini!',
        subject: 'Fake Twitter Tweet',
      );
    } catch (e) {
      _showToast("Error membagikan tweet");
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
      _bgController.text = "light";
      _avatarController.text =
          "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
      _imageController.text =
          "https://i.pinimg.com/originals/03/28/21/03282165e143dc1aabc6335fe3ab8fbe.jpg";
      _nameController.text = "OTAX For You";
      _usernameController.text = "OTAX";
      _tweetController.text = "Just Have Fun Broo";
      _dateController.text = "2025-05-04T10:30:00";
      _retweetsController.text = "999";
      _commentsController.text = "888";
      _likesController.text = "7777";
      _verified = true;
      _generatedImage = null;
      _imageGenerated = false;
    });
  }

  void _pasteFromClipboard(TextEditingController controller) {
    // Implementasi paste dari clipboard bisa ditambahkan, untuk sederhana kita tampilkan toast
    _showToast("Tempel dari clipboard (simulasi)");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pembuat Fake Tweet",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
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
                                  "Pratinjau Tweet",
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
                                        "Tweet akan muncul di sini",
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
                                    "Tweet Siap Digunakan!",
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
                      // Background Theme
                      _buildDropdownField(
                        label: "Tema Latar",
                        icon: Icons.palette_outlined,
                        value: _bgController.text,
                        items: const ["light", "dark"],
                        onChanged: (val) {
                          setState(() {
                            _bgController.text = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: "Nama Tampilan",
                        icon: Icons.badge_outlined,
                        hint: "Masukkan nama tampilan",
                        maxLength: 50,
                      ),

                      // Username Field
                      _buildTextField(
                        controller: _usernameController,
                        label: "Username Twitter",
                        icon: Icons.alternate_email,
                        hint: "Masukkan username (tanpa @)",
                        maxLength: 30,
                      ),

                      // Tweet Content
                      _buildTextField(
                        controller: _tweetController,
                        label: "Konten Tweet",
                        icon: Icons.chat_bubble_outline,
                        hint: "Apa yang ingin kamu tweet?",
                        maxLines: 3,
                        maxLength: 280,
                      ),

                      // Avatar URL
                      _buildTextField(
                        controller: _avatarController,
                        label: "URL Foto Profil",
                        icon: Icons.link,
                        hint: "https://contoh.com/avatar.jpg",
                        onPaste: () => _pasteFromClipboard(_avatarController),
                      ),

                      // Image URL (Media)
                      _buildTextField(
                        controller: _imageController,
                        label: "URL Media (opsional)",
                        icon: Icons.image_outlined,
                        hint: "https://contoh.com/gambar.jpg",
                        onPaste: () => _pasteFromClipboard(_imageController),
                      ),

                      // Date
                      _buildTextField(
                        controller: _dateController,
                        label: "Waktu Tweet (ISO 8601)",
                        icon: Icons.calendar_today_outlined,
                        hint: "2025-05-04T10:30:00",
                      ),

                      // Retweets, Comments, Likes in Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _retweetsController,
                              label: "Retweets",
                              icon: Icons.repeat,
                              hint: "999",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _commentsController,
                              label: "Komentar",
                              icon: Icons.comment_outlined,
                              hint: "888",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _likesController,
                              label: "Suka",
                              icon: Icons.favorite_border,
                              hint: "7777",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Verified Switch
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: const Color(0xFF1DA1F2), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              "Akun Terverifikasi",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey.shade800,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _verified,
                              onChanged: (val) {
                                setState(() {
                                  _verified = val;
                                });
                              },
                              activeColor: const Color(0xFF1DA1F2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _generateTweet,
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
                                      "BUAT FAKE TWEET",
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
                          "Bagikan Tweet Anda",
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
                                onPressed: _isSharing ? null : _shareTweet,
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
                          _buildStep(1, "Isi semua field yang diperlukan (nama, username, tweet)"),
                          _buildStep(2, "Ubah tema latar sesuai keinginan (light/dark)"),
                          _buildStep(3, "Masukkan URL foto profil dan media (jika ada)"),
                          _buildStep(4, "Atur jumlah retweet, komentar, dan suka"),
                          _buildStep(5, "Tentukan status verifikasi akun"),
                          _buildStep(6, "Klik 'Buat Fake Tweet' dan tunggu hasilnya"),
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
                                "Pastikan URL gambar adalah link langsung (berakhiran .jpg, .png, dll). Untuk waktu gunakan format ISO 8601: YYYY-MM-DDTHH:MM:SS",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    VoidCallback? onPaste,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Text(
                label,
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
            controller: controller,
            style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 16),
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
              ),
              suffixIcon: onPaste != null
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        onPressed: onPaste,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                          foregroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.blueGrey.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.blueGrey.shade700),
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: TextStyle(color: Colors.blueGrey.shade900),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
    _bgController.dispose();
    _avatarController.dispose();
    _imageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _tweetController.dispose();
    _dateController.dispose();
    _retweetsController.dispose();
    _commentsController.dispose();
    _likesController.dispose();
    super.dispose();
  }
}