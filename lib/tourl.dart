import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:archive/archive.dart';
import 'package:mime/mime.dart';

class UploadToUrlPage extends StatefulWidget {
  const UploadToUrlPage({super.key});

  @override
  State<UploadToUrlPage> createState() => _UploadToUrlPageState();
}

class _UploadToUrlPageState extends State<UploadToUrlPage> {
  static const int maxCatboxSize = 50 * 1024 * 1024;

  FilePickerResult? _pickedFile;
  String? _fileName;
  int? _fileSize;
  String? _mimeType;
  Uint8List? _previewBytes;
  String? _uploadedUrl;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _pickedFile = result;
          _fileName = result.files.single.name;
          _fileSize = result.files.single.size;
          _mimeType = lookupMimeType(_fileName!);
          _previewBytes = _mimeType?.startsWith('image/') == true
              ? result.files.single.bytes
              : null;
          _uploadedUrl = null;
        });
      }
    } catch (e) {
      _showToast('Gagal memilih file: $e');
    }
  }

  Future<String> _zipFile(File file) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.zip';
    final encoder = ZipEncoder();
    final archive = Archive();
    final bytes = await file.readAsBytes();
    archive.addFile(ArchiveFile(file.path.split('/').last, bytes.length, bytes));
    final zipData = encoder.encode(archive);
    if (zipData == null) throw Exception('Gagal mengompres file');
    await File(zipPath).writeAsBytes(zipData);
    return zipPath;
  }

  Future<String> _uploadToCatbox(String path) async {
    final uri = Uri.parse('https://catbox.moe/user/api.php');
    final request = http.MultipartRequest('POST', uri)
      ..fields['reqtype'] = 'fileupload'
      ..fields['userhash'] = ''
      ..files.add(await http.MultipartFile.fromPath('fileToUpload', path));
    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200 && body.startsWith('https://')) {
      return body.trim();
    }
    throw Exception('Upload gagal: ${response.reasonPhrase}');
  }

  Future<void> _uploadFile() async {
    if (_pickedFile == null) {
      _showToast('Pilih file terlebih dahulu');
      return;
    }

    setState(() => _isUploading = true);

    String? tempPath;
    String? zipPath;
    try {
      final fileData = _pickedFile!.files.single;
      final tempDir = await getTemporaryDirectory();
      final originalFile = File('${tempDir.path}/${fileData.name}');
      await originalFile.writeAsBytes(fileData.bytes!);
      tempPath = originalFile.path;

      String uploadPath = tempPath;
      if (fileData.size > maxCatboxSize) {
        _showToast('File besar, sedang dikompres...');
        zipPath = await _zipFile(originalFile);
        uploadPath = zipPath;
      }

      _showToast('Mengupload...');
      final url = await _uploadToCatbox(uploadPath);
      setState(() => _uploadedUrl = url);
      _showToast('Upload berhasil!');
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      if (tempPath != null && File(tempPath).existsSync()) File(tempPath).deleteSync();
      if (zipPath != null && File(zipPath).existsSync()) File(zipPath).deleteSync();
      setState(() => _isUploading = false);
    }
  }

  void _copyToClipboard() {
    if (_uploadedUrl == null) return;
    Clipboard.setData(ClipboardData(text: _uploadedUrl!));
    _showToast('URL disalin ke clipboard');
  }

  void _shareUrl() {
    if (_uploadedUrl == null) return;
    Share.share(_uploadedUrl!);
  }

  void _reset() {
    setState(() {
      _pickedFile = null;
      _fileName = null;
      _fileSize = null;
      _mimeType = null;
      _previewBytes = null;
      _uploadedUrl = null;
    });
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = (bytes / 1024).floor().toInt().toString().length;
    i = (bytes / 1024).floor().toInt().toString().length;
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < suffixes.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Media ke URL',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
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
            colors: [Color(0xFFF5F7FF), Color(0xFFE8EAF6)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreviewCard(),
              const SizedBox(height: 20),
              _buildActionCard(),
              const SizedBox(height: 20),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pratinjau Media',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A237E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPreviewContent(),
            const SizedBox(height: 20),
            if (_pickedFile != null) _buildFileInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (_pickedFile == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 60, color: Colors.blueGrey.shade300),
            const SizedBox(height: 16),
            Text(
              'Belum ada file dipilih',
              style: TextStyle(color: Colors.blueGrey.shade600),
            ),
          ],
        ),
      );
    }

    if (_previewBytes != null) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: MemoryImage(_previewBytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_drive_file, size: 50, color: Colors.blueGrey.shade400),
              const SizedBox(height: 8),
              Text(
                'File non-gambar',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file, color: Colors.blueGrey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatBytes(_fileSize!),
                      style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_fileSize! > maxCatboxSize) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File lebih dari 50 MB, akan dikompres menjadi ZIP sebelum upload.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('PILIH MEDIA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A237E),
                  side: const BorderSide(color: Color(0xFF1A237E)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_pickedFile == null || _isUploading) ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'UPLOAD KE CATBOX',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            if (_uploadedUrl != null) ...[
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                'URL Hasil Upload',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: SelectableText(
                  _uploadedUrl!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text('COPY'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A237E),
                        side: const BorderSide(color: Color(0xFF1A237E)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareUrl,
                      icon: const Icon(Icons.share),
                      label: const Text('BAGIKAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
  return Container(
    decoration: _cardDecoration(),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: const Color(0xFF1A237E)),
              const SizedBox(width: 12),
              Text(
                'Informasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF263238),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '• Upload media ke Catbox.moe dan dapatkan URL langsung.\n'
            '• Batas file per upload: 50 MB (jika lebih akan di-zip).\n'
            '• Format file apa pun didukung.\n'
            '• URL akan langsung bisa digunakan.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF263238),
            ),
          ),
        ],
      ),
    ),
  );
}

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }
}