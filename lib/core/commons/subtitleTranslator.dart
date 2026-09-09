// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:otax/ui/models/widgets/subtitles/subtitle.dart';

/// Penanda unik yang digunakan untuk memisahkan baris subtitle saat batch translate.
/// Karakter ini dipilih karena tidak mungkin muncul di teks subtitle biasa
/// dan tidak akan ikut diterjemahkan oleh Google Translate.
const _kSeparator = '\u2060|\u2060|\u2060|\u2060';

/// Ukuran batch maksimum per satu request translate (jumlah baris subtitle).
/// Terlalu besar → request timeout / rate limit.
/// Terlalu kecil → banyak request.
const _kBatchSize = 80;

/// Delay antar request batch agar tidak kena rate-limit Google.
const _kDelayBetweenBatches = Duration(milliseconds: 400);

/// Timeout per request ke Google Translate.
const _kRequestTimeout = Duration(seconds: 20);

class SubtitleTranslator {
  /// Terjemahkan seluruh list [Subtitle] ke bahasa [targetLang] (default: 'id' = Indonesia).
  ///
  /// Proses:
  /// 1. Kelompokkan dialogue ke dalam batch.
  /// 2. Setiap batch dijoin dengan [_kSeparator] lalu dikirim ke Google Translate.
  /// 3. Hasil di-split kembali dan di-map ke objek [Subtitle] baru.
  ///
  /// Jika translation gagal (network error, rate limit, dll), fungsi ini
  /// mengembalikan list asli tanpa crash supaya subtitle tetap tampil (meski bahasa asli).
  static Future<List<Subtitle>> translate(
    List<Subtitle> subtitles, {
    String targetLang = 'id',
    String sourceLang = 'auto',
    void Function(double progress)? onProgress,
  }) async {
    if (subtitles.isEmpty) return subtitles;

    final dialogues = subtitles.map((s) => s.dialogue).toList();
    final translatedDialogues = List<String>.from(dialogues); // fallback = asli

    // Bagi ke dalam batch
    final int totalBatches = (dialogues.length / _kBatchSize).ceil();

    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final start = batchIndex * _kBatchSize;
      final end = min(start + _kBatchSize, dialogues.length);
      final batchTexts = dialogues.sublist(start, end);

      try {
        final translated = await _translateBatch(
          batchTexts,
          targetLang: targetLang,
          sourceLang: sourceLang,
        );

        // Tempel hasil ke array output
        for (int i = 0; i < translated.length; i++) {
          if (start + i < translatedDialogues.length) {
            translatedDialogues[start + i] = translated[i].isNotEmpty
                ? translated[i]
                : dialogues[start + i]; // fallback ke asli kalau kosong
          }
        }
      } catch (e) {
        // Kalau batch ini gagal, biarkan pakai teks asli (sudah di-init dari dialogues)
        print('[SubtitleTranslator] Batch $batchIndex gagal: $e');
      }

      // Update progress callback
      onProgress?.call((batchIndex + 1) / totalBatches);

      // Delay antar batch kecuali batch terakhir
      if (batchIndex < totalBatches - 1) {
        await Future.delayed(_kDelayBetweenBatches);
      }
    }

    // Bangun ulang list Subtitle dengan dialogue yang sudah diterjemahkan
    return List.generate(subtitles.length, (i) {
      return Subtitle(
        start: subtitles[i].start,
        end: subtitles[i].end,
        alignment: subtitles[i].alignment,
        dialogue: translatedDialogues[i],
      );
    });
  }

  /// Terjemahkan satu batch teks.
  /// Teks digabung dengan separator unik, dikirim dalam 1 request, lalu dipisahkan lagi.
  static Future<List<String>> _translateBatch(
    List<String> texts, {
    required String targetLang,
    required String sourceLang,
  }) async {
    // Bersihkan teks dari karakter kontrol agar tidak merusak JSON response
    final cleaned = texts.map(_cleanText).toList();
    final joined = cleaned.join(_kSeparator);

    final uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      {
        'client': 'gtx',
        'sl': sourceLang,
        'tl': targetLang,
        'dt': 't',
        'q': joined,
      },
    );

    final response = await http.get(uri).timeout(_kRequestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Google Translate error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    // Response structure: [ [ ["translated", "original", ...], ...], ... ]
    final parts = decoded[0] as List<dynamic>;
    final resultJoined = parts
        .map((part) => (part[0] as String? ?? ''))
        .join('');

    // Split menggunakan separator (Google Translate mempertahankan karakter Unicode unik ini)
    // Kadang ada spasi ekstra di sekitar separator setelah translate
    final results = resultJoined
        .split(RegExp(r'\s*\u2060\|\u2060\|\u2060\|\u2060\s*'))
        .map((s) => s.trim())
        .toList();

    // Pastikan jumlah elemen sama dengan input.
    // Kalau kurang (misal separator hilang), fallback ke teks asli.
    if (results.length != texts.length) {
      print(
          '[SubtitleTranslator] Jumlah baris tidak cocok: input=${texts.length}, output=${results.length}');
      // Coba split lagi dengan pendekatan lebih longgar
      final fallbackResults = resultJoined.split('||||').map((s) => s.trim()).toList();
      if (fallbackResults.length == texts.length) return fallbackResults;
      // Kalau masih tidak cocok, kembalikan teks asli untuk batch ini
      return texts;
    }

    return results;
  }

  /// Bersihkan karakter khusus yang bisa merusak JSON response Google.
  static String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(_kSeparator, ' ') // hapus separator kalau kebetulan ada
        .trim();
  }
}
