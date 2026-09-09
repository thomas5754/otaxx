import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class IqcPage extends StatefulWidget {
  const IqcPage({Key? key}) : super(key: key);

  @override
  State<IqcPage> createState() => _IqcPageState();
}

class _IqcPageState extends State<IqcPage> {
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _batteryController = TextEditingController();
  final TextEditingController _carrierController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = false;
  bool _imageGenerated = false;
  Uint8List? _generatedImage;
  bool _isSharing = false;

  final List<String> _carrierOptions = [
    "Telkomsel",
    "Indosat",
    "XL",
    "Tri",
    "Smartfren",
    "Axis",
    "By.U",
  ];

  String _selectedCarrier = "Telkomsel";

  @override
  void initState() {
    super.initState();
    _timeController.text = "18:00";
    _batteryController.text = "40";
    _selectedCarrier = "Telkomsel";
    _messageController.text = "Halo bang";
  }

  Future<void> _generateIqc() async {
    if (_timeController.text.isEmpty) {
      _showToast("Masukkan waktu");
      return;
    }

    if (_batteryController.text.isEmpty) {
      _showToast("Masukkan persentase baterai");
      return;
    }

    if (_messageController.text.isEmpty) {
      _showToast("Masukkan pesan");
      return;
    }

    setState(() {
      _isLoading = true;
      _imageGenerated = false;
    });

    try {
      final battery = int.tryParse(
              _batteryController.text.replaceAll(RegExp(r'[^\d]'), '')) ??
          0;

      if (battery < 0 || battery > 100) {
        _showToast("Baterai harus antara 0-100");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final params = {
        'time': _timeController.text,
        'batteryPercentage': battery.toString(),
        'carrierName': _selectedCarrier,
        'messageText': _messageController.text,
        'emojiStyle': 'apple'
      };

      final queryString = Uri(queryParameters: params).query;
      final apiUrl = 'https://brat.siputzx.my.id/iphone-quoted?$queryString';

      final response = await http.get(
        Uri.parse(apiUrl),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        setState(() {
          _generatedImage = response.bodyBytes;
          _imageGenerated = true;
        });
        _showToast("IQC berhasil dibuat!");
      } else {
        throw Exception('Gagal membuat IQC. Status: ${response.statusCode}');
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
      _showToast("Buat IQC terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final result = await ImageGallerySaverPlus.saveImage(
        _generatedImage!,
        name: "iqc_${DateTime.now().millisecondsSinceEpoch}",
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        _showToast("✅ IQC disimpan ke galeri!");
      } else {
        _showToast("❌ Gagal menyimpan IQC");
      }
    } catch (e) {
      _showToast("Error: ${e.toString()}");
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null) {
      _showToast("Buat IQC terlebih dahulu!");
      return;
    }

    try {
      setState(() {
        _isSharing = true;
      });

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/iqc_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(_generatedImage!);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lihat iPhone Quote Chat ini!',
        subject: 'iPhone Quote Chat',
      );
    } catch (e) {
      _showToast("Error membagikan gambar");
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
      _timeController.clear();
      _batteryController.clear();
      _messageController.clear();
      _selectedCarrier = "Telkomsel";
      _generatedImage = null;
      _imageGenerated = false;
    });
    _timeController.text = "18:00";
    _batteryController.text = "40";
    _messageController.text = "Halo bang";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "iPhone Quote Chat",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50), // Elegant Dark Blue
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
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
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
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
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
                                  color: const Color(0xFF2C3E50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Pratinjau iPhone Quote",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C3E50),
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
                                      color: Colors.grey.shade300,
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
                                          color: const Color(0xFF2C3E50)
                                              .withOpacity(0.05),
                                        ),
                                        child: Icon(
                                          Icons.phone_iphone_outlined,
                                          size: 60,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        "iPhone Quote akan muncul di sini",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Isi form untuk membuat pratinjau",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
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
                                color: const Color(0xFF27AE60).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF27AE60),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: const Color(0xFF27AE60), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "iPhone Quote Siap!",
                                    style: TextStyle(
                                      color: const Color(0xFF229954),
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
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Time and Battery Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 18, color: Colors.grey.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Waktu",
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _timeController,
                                  style: TextStyle(
                                    color: Colors.grey.shade900,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "18:00",
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
                                        color: Color(0xFF2C3E50),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.battery_charging_full,
                                        size: 18, color: Colors.grey.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Baterai (%)",
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _batteryController,
                                  style: TextStyle(
                                    color: Colors.grey.shade900,
                                    fontSize: 16,
                                  ),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: "40",
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
                                        color: Color(0xFF2C3E50),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Carrier Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.network_cell,
                                  size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                "Operator",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedCarrier,
                              dropdownColor: Colors.white,
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2C3E50),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              icon: Icon(Icons.arrow_drop_down,
                                  color: Colors.grey.shade700),
                              items: _carrierOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        color: Colors.grey.shade900,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCarrier = newValue!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Message Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.message_outlined,
                                  size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                "Pesan",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _messageController,
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: "Tulis pesan di sini...",
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
                                  color: Color(0xFF2C3E50),
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
                      const SizedBox(height: 15),

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD5DBE1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: const Color(0xFF2C3E50)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Format: waktu (contoh: 18:00), baterai (0-100), operator, dan pesan",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _generateIqc,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF2C3E50).withOpacity(0.3),
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
                                      "BUAT IPHONE QUOTE",
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
                          "Bagikan Hasil Anda",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
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
                                      color: Color(0xFF2C3E50), width: 1.5),
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
                                      color: const Color(0xFF2C3E50),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isSharing ? "Menyimpan..." : "SIMPAN",
                                      style: TextStyle(
                                        color: const Color(0xFF2C3E50),
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
                                onPressed: _isSharing ? null : _shareImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3498DB),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      const Color(0xFF3498DB).withOpacity(0.3),
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
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
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
                              color: const Color(0xFF2C3E50).withOpacity(0.1),
                            ),
                            child: Icon(Icons.help_outline_rounded,
                                color: const Color(0xFF2C3E50), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Panduan Penggunaan",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.grey.shade900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStep(1, "Masukkan waktu (contoh: 18:00)"),
                          _buildStep(2, "Masukkan persentase baterai (0-100)"),
                          _buildStep(3, "Pilih operator seluler"),
                          _buildStep(4, "Tulis pesan yang ingin ditampilkan"),
                          _buildStep(5, "Klik 'Buat iPhone Quote'"),
                          _buildStep(6, "Simpan atau bagikan hasilnya"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD5DBE1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                color: const Color(0xFF2C3E50), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Contoh format lengkap: Waktu = 18:00, Baterai = 40%, Operator = Indosat, Pesan = Halo bang",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
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
              color: const Color(0xFF2C3E50),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C3E50).withOpacity(0.3),
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
                  color: Colors.grey.shade800,
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
    _timeController.dispose();
    _batteryController.dispose();
    _carrierController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}