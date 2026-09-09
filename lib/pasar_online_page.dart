import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart';

const _c0   = Color(0xFF000000);
const _c1   = Color(0xFF0C0C0C);
const _c2   = Color(0xFF141414);
const _c3   = Color(0xFF1C1C1C);
const _c4   = Color(0xFF242424);
const _red  = Color(0xFFD32F2F);
const _redD = Color(0xFF8B0000);
const _w100 = Color(0xFFFFFFFF);
const _w70  = Color(0xB3FFFFFF);
const _w45  = Color(0x73FFFFFF);
const _w20  = Color(0x33FFFFFF);
const _w08  = Color(0x14FFFFFF);
const _grn  = Color(0xFF22C55E);
const _amb  = Color(0xFFF59E0B);
const _sold = Color(0xFF6366F1);
const _exp  = Color(0xFFEF4444);

const _cats = [
  {'label': 'Semua',   'icon': Icons.apps_rounded,           'color': Color(0xFFD32F2F)},
  {'label': 'Games',   'icon': Icons.sports_esports_rounded, 'color': Color(0xFF7C3AED)},
  {'label': 'Diamond', 'icon': Icons.diamond_outlined,        'color': Color(0xFF0EA5E9)},
  {'label': 'Joki',    'icon': Icons.emoji_events_rounded,   'color': Color(0xFFF59E0B)},
  {'label': 'Tools',   'icon': Icons.build_rounded,          'color': Color(0xFF10B981)},
  {'label': 'Lainnya', 'icon': Icons.more_horiz_rounded,     'color': Color(0xFF6B7280)},
];

bool _isVid(String url) {
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.mp4')  || u.endsWith('.mov')  || u.endsWith('.webm') ||
         u.endsWith('.avi')  || u.endsWith('.mkv')  || u.endsWith('.3gp')  ||
         u.endsWith('.flv')  || u.endsWith('.wmv')  ||
         u.contains('youtu.be') || u.contains('youtube.com/watch') ||
         u.contains('streamable.com') || u.contains('tiktok.com') ||
         (u.contains('drive.google.com') && u.contains('video'));
}

class JasaPostItem {
  final String id, judul, kategori, deskripsi, harga;
  final String kontakWa, kontakTg, kontakTelp;
  final String namaToko, username, createdAtStr;
  final List<String> media;
  final bool isSold;
  final int stok;
  final int expiredAt;       // ms timestamp, 0 = tidak ada expiry
  final String expiredAtStr; // string readable dari server

  const JasaPostItem({
    required this.id,         required this.judul,        required this.kategori,
    required this.deskripsi,  required this.harga,        required this.kontakWa,
    required this.kontakTg,   required this.kontakTelp,   required this.namaToko,
    required this.username,   required this.createdAtStr,  required this.media,
    required this.isSold,     required this.stok,
    this.expiredAt = 0,       this.expiredAtStr = '',
  });

  factory JasaPostItem.fromJson(Map<String, dynamic> j) {
    final rawMedia  = j['media'] ?? j['gambar'];
    final mediaList = (rawMedia as List?)?.map((e) => e.toString()).toList() ?? [];
    final rawStok   = j['stok'];
    int stokVal = -1;
    if (rawStok != null) stokVal = (rawStok is int) ? rawStok : (int.tryParse(rawStok.toString()) ?? -1);
    final rawExp = j['expiredAt'];
    int expVal = 0;
    if (rawExp != null) expVal = (rawExp is int) ? rawExp : (int.tryParse(rawExp.toString()) ?? 0);
    return JasaPostItem(
      id:           j['id']?.toString() ?? '',
      judul:        j['judul'] ?? '',
      kategori:     j['kategori'] ?? 'Lainnya',
      deskripsi:    j['deskripsi'] ?? '',
      harga:        j['harga']?.toString() ?? '0',
      kontakWa:     j['kontakWa'] ?? '',
      kontakTg:     j['kontakTg'] ?? '',
      kontakTelp:   j['kontakTelp'] ?? '',
      namaToko:     j['namaToko'] ?? '',
      username:     j['username'] ?? '',
      createdAtStr: j['createdAtStr'] ?? '',
      media:        mediaList,
      isSold:       j['isSold'] == true || j['sold'] == true,
      stok:         stokVal,
      expiredAt:    expVal,
      expiredAtStr: j['expiredAtStr']?.toString() ?? '',
    );
  }

  bool get stokTracked     => stok >= 0;
  bool get effectivelySold => isSold || stok == 0;
  bool get hasExpiry       => expiredAt > 0;
  bool get isExpired       => hasExpiry && DateTime.now().millisecondsSinceEpoch > expiredAt;

  bool get expiresSoon {
    if (!hasExpiry || isExpired) return false;
    return (expiredAt - DateTime.now().millisecondsSinceEpoch) < const Duration(days: 1).inMilliseconds;
  }

  String get sisaWaktuLabel {
    if (!hasExpiry) return '';
    final sisa = expiredAt - DateTime.now().millisecondsSinceEpoch;
    if (sisa <= 0) return 'Kadaluarsa';
    final d = sisa ~/ 86400000;
    final h = (sisa % 86400000) ~/ 3600000;
    if (d >= 1) return '$d hari lagi';
    if (h >= 1) return '$h jam lagi';
    return '< 1 jam lagi';
  }

  String get stokLabel {
    if (!stokTracked) return 'Unlimited';
    if (stok == 0)   return 'Habis';
    return '$stok tersisa';
  }
}

class PasarOnlinePage extends StatefulWidget {
  final String sessionKey, username, role;
  const PasarOnlinePage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });
  @override
  State<PasarOnlinePage> createState() => _State();
}

class _State extends State<PasarOnlinePage> with SingleTickerProviderStateMixin {
  List<JasaPostItem> _all = [], _filtered = [];
  bool _loading = true;
  String _selCat = 'Semua', _q = '', _soldFilter = 'Semua';
  late AnimationController _ac;
  late Animation<double> _fade;
  final _searchTxt = TextEditingController();

  bool get _isAdmin => widget.role == 'KINGZ';

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _load();
  }
  @override void dispose() { _ac.dispose(); _searchTxt.dispose(); super.dispose(); }

  Future<void> _load({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    _ac.reset();
    if (!refresh) {
      final p = await SharedPreferences.getInstance();
      final c = p.getString('jp_cache');
      if (c != null) { _parse(c); setState(() => _loading = false); _ac.forward(); }
    }
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:4113/jasapost/list?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        (await SharedPreferences.getInstance()).setString('jp_cache', r.body);
        _parse(r.body);
      }
    } catch (_) {}
    if (mounted) { setState(() => _loading = false); _ac.forward(); }
  }

  void _parse(String raw) {
    try {
      final d = jsonDecode(raw);
      final l = (d['data'] ?? d) as List;
      _all = l.map((e) => JasaPostItem.fromJson(e)).toList();
      _applyFilter();
    } catch (_) {}
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((x) {
        final mc = _selCat == 'Semua' || x.kategori == _selCat;
        final q  = _q.toLowerCase();
        final mq = q.isEmpty || x.judul.toLowerCase().contains(q) ||
            x.namaToko.toLowerCase().contains(q) || x.deskripsi.toLowerCase().contains(q);
        final ms = _soldFilter == 'Semua'
            || (_soldFilter == 'Tersedia' && !x.effectivelySold)
            || (_soldFilter == 'Terjual'  &&  x.effectivelySold);
        return mc && mq && ms;
      }).toList();
    });
  }

  Color    _catColor(String c) => (_cats.firstWhere((e) => e['label'] == c, orElse: () => _cats.last)['color'] as Color);
  IconData _catIcon(String c)  => (_cats.firstWhere((e) => e['label'] == c, orElse: () => _cats.last)['icon'] as IconData);

  String _fmt(String p) {
    try {
      final n = int.parse(p.replaceAll(RegExp(r'[^0-9]'), ''));
      return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    } catch (_) { return 'Rp $p'; }
  }

  Future<void> _open(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
    catch (_) { _toast(context, 'Tidak bisa membuka link', err: true); }
  }

  void _toast(BuildContext ctx, String msg, {bool err = false, Color? custom}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _w100, fontSize: 13, fontWeight: FontWeight.w500)),
      backgroundColor: custom ?? (err ? _redD.withOpacity(0.95) : const Color(0xFF052E16)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _deletePost(String id, BuildContext sheetCtx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: _c2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Iklan?', style: TextStyle(color: _w100, fontWeight: FontWeight.w700)),
        content: const Text('Iklan ini akan dihapus permanen.', style: TextStyle(color: _w45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Batal', style: TextStyle(color: _w45))),
          TextButton(onPressed: () => Navigator.pop(dlgCtx, true),
              child: const Text('Hapus', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await http
          .delete(Uri.parse('$baseUrl/jasapost/delete?key=${widget.sessionKey}&id=$id'))
          .timeout(const Duration(seconds: 8));
      final d = jsonDecode(r.body);
      if (d['valid'] == true) {
        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
        _toast(context, 'Iklan berhasil dihapus');
        _load(refresh: true);
      } else {
        _toast(context, d['message'] ?? 'Gagal hapus', err: true);
      }
    } catch (_) { _toast(context, 'Koneksi gagal', err: true); }
  }

  Future<void> _markSold(String id, bool sold, BuildContext sheetCtx,
      {required void Function(bool) onDone}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl/jasapost/markSold?key=${widget.sessionKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'sold': sold}),
      ).timeout(const Duration(seconds: 8));
      final d = jsonDecode(r.body);
      if (d['valid'] == true) {
        onDone(sold);
        _toast(context, sold ? '✅ Iklan ditandai TERJUAL' : '🔄 Iklan ditandai TERSEDIA',
            custom: sold ? _sold.withOpacity(0.9) : const Color(0xFF052E16));
        _load(refresh: true);
      } else {
        _toast(context, d['message'] ?? 'Gagal update status', err: true);
      }
    } catch (_) { _toast(context, 'Koneksi gagal', err: true); }
  }

  Future<void> _editStok(JasaPostItem item, BuildContext sheetCtx,
      {required void Function(int) onDone}) async {
    final stokCtrl = TextEditingController(text: item.stok >= 0 ? item.stok.toString() : '');
    bool busy = false;
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(builder: (ctx2, ss2) {
        Future<void> doUpdate() async {
          final raw = stokCtrl.text.trim();
          final newStok = raw.isEmpty ? -1 : (int.tryParse(raw) ?? -1);
          if (newStok < -1) { _toast(ctx2, 'Stok tidak valid', err: true); return; }
          ss2(() => busy = true);
          try {
            final r = await http.post(
              Uri.parse('$baseUrl/jasapost/updateStok?key=${widget.sessionKey}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'id': item.id, 'stok': newStok}),
            ).timeout(const Duration(seconds: 8));
            final d = jsonDecode(r.body);
            if (d['valid'] == true) {
              Navigator.pop(ctx2);
              onDone(newStok);
              _toast(context, newStok < 0 ? 'Stok diset ke Unlimited' : 'Stok diupdate: $newStok unit');
              _load(refresh: true);
            } else {
              _toast(ctx2, d['message'] ?? 'Gagal update stok', err: true);
            }
          } catch (_) { _toast(ctx2, 'Koneksi gagal', err: true); }
          ss2(() => busy = false);
        }
        return AlertDialog(
          backgroundColor: _c2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Stok', style: TextStyle(color: _w100, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Sekarang: ${item.stokLabel}',
                style: const TextStyle(color: _w45, fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: stokCtrl, keyboardType: TextInputType.number, autofocus: true,
              style: const TextStyle(color: _w100, fontSize: 16, fontWeight: FontWeight.w700),
              cursorColor: _red,
              decoration: InputDecoration(
                hintText: 'Kosongkan = Unlimited',
                hintStyle: const TextStyle(color: _w20, fontSize: 14),
                filled: true, fillColor: _c3,
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: _w45, size: 17),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _amb, width: 1.2)),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _QuickChip('0', 0, stokCtrl, ss2), const SizedBox(width: 6),
              _QuickChip('1', 1, stokCtrl, ss2), const SizedBox(width: 6),
              _QuickChip('5', 5, stokCtrl, ss2), const SizedBox(width: 6),
              _QuickChip('10', 10, stokCtrl, ss2),
            ]),
            const SizedBox(height: 6),
            const Text('Stok 0 → otomatis TERJUAL\nKosong → Unlimited',
                style: TextStyle(color: _w20, fontSize: 11, height: 1.5)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Batal', style: TextStyle(color: _w45))),
            TextButton(
              onPressed: busy ? null : doUpdate,
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _amb, strokeWidth: 1.5))
                  : const Text('Simpan', style: TextStyle(color: _amb, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      }),
    );
    stokCtrl.dispose();
  }

  // ─── SHEET: POST IKLAN ────────────────────────────────────────────────────
  void _openPost() {
    final kodeC  = TextEditingController();
    final namaC  = TextEditingController();
    final judulC = TextEditingController();
    final descC  = TextEditingController();
    final hargaC = TextEditingController();
    final stokC  = TextEditingController();
    final waC    = TextEditingController();
    final tgC    = TextEditingController();
    final telC   = TextEditingController();
    final mediaCtrls = [TextEditingController()];
    String selCat = 'Games';
    bool busy = false, kodeOk = false;
    String kodeExpiredAtStr = '';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {

        Future<void> verify() async {
          if (kodeC.text.trim().isEmpty) return;
          ss(() => busy = true);
          try {
            final r = await http.get(Uri.parse(
                '$baseUrl/jasapost/verifyKode?key=${widget.sessionKey}&kodePost=${kodeC.text.trim()}'));
            final d = jsonDecode(r.body);
            ss(() {
              kodeOk = d['valid'] == true;
              kodeExpiredAtStr = d['expiredAtStr']?.toString() ?? '';
              busy = false;
            });
            if (!kodeOk && ctx.mounted) _toast(ctx, d['message'] ?? 'Kode tidak valid', err: true);
          } catch (_) { ss(() => busy = false); _toast(ctx, 'Koneksi gagal', err: true); }
        }

        Future<void> submit() async {
          if (!kodeOk) { _toast(ctx, 'Verifikasi kode post dulu', err: true); return; }
          if (namaC.text.isEmpty || judulC.text.isEmpty || hargaC.text.isEmpty) {
            _toast(ctx, 'Nama toko, judul & harga wajib diisi', err: true); return;
          }
          if (waC.text.isEmpty && tgC.text.isEmpty && telC.text.isEmpty) {
            _toast(ctx, 'Minimal satu kontak wajib diisi', err: true); return;
          }
          final mediaUrls = mediaCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
          for (final u in mediaUrls) {
            if (!u.startsWith('http')) { _toast(ctx, 'URL media harus diawali https://...', err: true); return; }
          }
          final stokRaw = stokC.text.trim();
          final stokVal = stokRaw.isEmpty ? -1 : (int.tryParse(stokRaw) ?? -1);

          ss(() => busy = true);
          try {
            final r = await http.post(
              Uri.parse('http://127.0.0.1:4113/jasapost/post?key=${widget.sessionKey}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'kodePost': kodeC.text.trim(), 'namaToko': namaC.text.trim(),
                'judul': judulC.text.trim(),   'kategori': selCat,
                'deskripsi': descC.text.trim(), 'harga': hargaC.text.trim(),
                'kontakWa': waC.text.trim(),   'kontakTg': tgC.text.trim(),
                'kontakTelp': telC.text.trim(), 'media': mediaUrls, 'gambar': mediaUrls,
                'stok': stokVal,
              }),
            );
            final d = jsonDecode(r.body);
            if (d['valid'] == true) {
              if (ctx.mounted) Navigator.pop(ctx);
              _toast(context, 'Iklan berhasil diposting 🎉');
              _load(refresh: true);
            } else {
              _toast(ctx, d['message'] ?? 'Gagal posting', err: true);
            }
          } catch (_) { _toast(ctx, 'Koneksi gagal', err: true); }
          ss(() => busy = false);
        }

        return _BSheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Handle(),
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pasang Iklan', style: TextStyle(color: _w100, fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Isi form di bawah untuk memasang iklan', style: TextStyle(color: _w45, fontSize: 13)),
            ])),
            GestureDetector(onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close_rounded, color: _w45, size: 22)),
          ]),
          const SizedBox(height: 32),

          _SecLabel('KODE POST'),
          Row(children: [
            Expanded(child: _TF(ctrl: kodeC, hint: 'Masukkan kode post',
                icon: Icons.vpn_key_outlined, enabled: !kodeOk,
                caps: TextCapitalization.characters)),
            const SizedBox(width: 10),
            _Btn42(onTap: kodeOk ? null : verify, busy: busy && !kodeOk,
                color: kodeOk ? _grn : _red, icon: kodeOk ? Icons.check_rounded : Icons.east_rounded),
          ]),
          if (kodeOk) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _grn.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _grn.withOpacity(0.2)),
              ),
              child: Row(children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: _grn, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kode valid — silakan lanjut',
                      style: TextStyle(color: _grn, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (kodeExpiredAtStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.timer_outlined, color: _amb, size: 11),
                      const SizedBox(width: 5),
                      Text('Iklan akan berakhir: $kodeExpiredAtStr',
                          style: const TextStyle(color: _amb, fontSize: 11)),
                    ]),
                  ],
                ])),
              ]),
            ),
          ],
          const SizedBox(height: 28),

          _SecLabel('NAMA TOKO'),
          _TF(ctrl: namaC, hint: 'Nama toko atau penjual', icon: Icons.storefront_outlined),
          const SizedBox(height: 28),

          _SecLabel('DETAIL PRODUK'),
          _TF(ctrl: judulC, hint: 'Judul iklan', icon: Icons.title_rounded),
          const SizedBox(height: 10),
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
            children: _cats.skip(1).map((cat) {
              final on = selCat == cat['label'] as String;
              return GestureDetector(
                onTap: () => ss(() => selCat = cat['label'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: on ? (cat['color'] as Color).withOpacity(0.15) : _c2,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: on ? (cat['color'] as Color).withOpacity(0.5) : _c3),
                  ),
                  child: Text(cat['label'] as String, style: TextStyle(
                    color: on ? cat['color'] as Color : _w45,
                    fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.normal,
                  )),
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 10),
          _TF(ctrl: descC, hint: 'Deskripsi produk / jasa', icon: Icons.notes_rounded, lines: 3),
          const SizedBox(height: 10),
          _TF(ctrl: hargaC, hint: 'Harga (angka)', icon: Icons.payments_outlined, kb: TextInputType.number),
          const SizedBox(height: 28),

          _SecLabel('STOK PRODUK'),
          _TF(ctrl: stokC, hint: 'Kosongkan = Unlimited', icon: Icons.inventory_2_outlined, kb: TextInputType.number),
          const SizedBox(height: 6),
          const Text('Stok 0 → otomatis ditandai TERJUAL', style: TextStyle(color: _w20, fontSize: 11)),
          const SizedBox(height: 28),

          _SecLabel('MEDIA PRODUK (FOTO / VIDEO)'),
          const Text('Maks. 5 media — paste URL foto atau video (.mp4, YouTube, dll)',
              style: TextStyle(color: _w45, fontSize: 12)),
          const SizedBox(height: 10),
          ...List.generate(mediaCtrls.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: mediaCtrls[i], keyboardType: TextInputType.url,
                style: const TextStyle(color: _w100, fontSize: 14, fontWeight: FontWeight.w500),
                cursorColor: _red,
                onChanged: (_) => ss(() {}),
                decoration: InputDecoration(
                  hintText: 'https://... (foto atau video)',
                  hintStyle: const TextStyle(color: _w20, fontSize: 13),
                  prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      _isVid(mediaCtrls[i].text) ? Icons.videocam_outlined : Icons.image_outlined,
                      size: 17, color: _isVid(mediaCtrls[i].text) ? _amb : _w45,
                    )),
                  prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                  filled: true, fillColor: _c2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: _red, width: 1.2)),
                ),
              )),
              if (i > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ss(() => mediaCtrls.removeAt(i)),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: _redD.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.close_rounded, color: _red, size: 17),
                  ),
                ),
              ],
            ]),
          )),
          if (mediaCtrls.length < 5)
            GestureDetector(
              onTap: () => ss(() => mediaCtrls.add(TextEditingController())),
              child: Container(
                width: double.infinity, height: 42,
                decoration: BoxDecoration(color: _c2, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _c3)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_rounded, color: _w45, size: 16),
                  const SizedBox(width: 6),
                  Text('Tambah Media (${mediaCtrls.length}/5)',
                      style: const TextStyle(color: _w45, fontSize: 12)),
                ]),
              ),
            ),
          const SizedBox(height: 28),

          _SecLabel('KONTAK PENJUAL'),
          const Text('Minimal satu kontak wajib diisi', style: TextStyle(color: _w45, fontSize: 12)),
          const SizedBox(height: 10),
          _TFfa(ctrl: waC, hint: 'WhatsApp (628xxx)', faIcon: FontAwesomeIcons.whatsapp,
              accentColor: const Color(0xFF25D366), kb: TextInputType.phone),
          const SizedBox(height: 8),
          _TFfa(ctrl: tgC, hint: 'Telegram (@username)', faIcon: FontAwesomeIcons.telegram,
              accentColor: const Color(0xFF0088CC)),
          const SizedBox(height: 8),
          _TF(ctrl: telC, hint: 'Nomor Telepon', icon: Icons.phone_outlined, kb: TextInputType.phone),
          const SizedBox(height: 36),

          GestureDetector(
            onTap: busy ? null : submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 54,
              decoration: BoxDecoration(color: busy ? _c3 : _red, borderRadius: BorderRadius.circular(16)),
              child: Center(child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _w100, strokeWidth: 1.8))
                  : const Text('Posting Sekarang', style: TextStyle(color: _w100, fontSize: 15, fontWeight: FontWeight.w700))),
            ),
          ),
        ]));
      }),
    );
  }

  // ─── SHEET: GENERATE KODE ─────────────────────────────────────────────────
  void _openGenKode() {
    final numC  = TextEditingController(text: '5');
    final hariC = TextEditingController(text: '7');
    bool busy = false;
    List<Map<String, dynamic>> hasil = []; // {kode, expiredAtStr}

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {

        Future<void> gen() async {
          final jml  = int.tryParse(numC.text.trim())  ?? 1;
          final hari = int.tryParse(hariC.text.trim()) ?? 7;
          if (hari < 1) { _toast(ctx, 'Minimal 1 hari', err: true); return; }
          ss(() { busy = true; hasil = []; });
          try {
            final r = await http.post(
              Uri.parse('http://127.0.0.1:4113/jasapost/generateKode?key=${widget.sessionKey}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'jumlah': jml, 'hari': hari}),
            );
            final d = jsonDecode(r.body);
            if (d['valid'] == true) {
              final list = (d['kodes'] as List?) ?? [];
              ss(() {
                hasil = list.map<Map<String, dynamic>>((e) => e is Map
                    ? {'kode': e['kode']?.toString() ?? '', 'expiredAtStr': e['expiredAtStr']?.toString() ?? ''}
                    : {'kode': e.toString(), 'expiredAtStr': ''}).toList();
                busy = false;
              });
            } else {
              ss(() => busy = false);
              _toast(ctx, d['message'] ?? 'Gagal', err: true);
            }
          } catch (_) { ss(() => busy = false); _toast(ctx, 'Koneksi gagal', err: true); }
        }

        return _BSheet(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Handle(),
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Generate Kode', style: TextStyle(color: _w100, fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Kode sekali pakai dengan masa aktif', style: TextStyle(color: _w45, fontSize: 13)),
            ])),
            GestureDetector(onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close_rounded, color: _w45, size: 22)),
          ]),
          const SizedBox(height: 32),

          _SecLabel('JUMLAH KODE (MAKS. 50)'),
          _TF(ctrl: numC, hint: 'Jumlah kode', icon: Icons.tag_rounded, kb: TextInputType.number),
          const SizedBox(height: 20),

          _SecLabel('MASA AKTIF IKLAN (HARI)'),
          _TF(ctrl: hariC, hint: 'Jumlah hari aktif', icon: Icons.timer_outlined, kb: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            _DayChip('1 hr',  1,  hariC, ss), const SizedBox(width: 6),
            _DayChip('3 hr',  3,  hariC, ss), const SizedBox(width: 6),
            _DayChip('7 hr',  7,  hariC, ss), const SizedBox(width: 6),
            _DayChip('14 hr', 14, hariC, ss), const SizedBox(width: 6),
            _DayChip('30 hr', 30, hariC, ss),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Iklan yang memakai kode ini akan otomatis dihapus\nsaat masa aktif habis',
            style: TextStyle(color: _w20, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 20),

          Center(child: _Btn42(
              onTap: busy ? null : gen, busy: busy, color: _amb, icon: Icons.auto_awesome_rounded)),

          if (hasil.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(children: [
              Container(width: 5, height: 5, decoration: const BoxDecoration(color: _grn, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('${hasil.length} kode berhasil dibuat',
                  style: const TextStyle(color: _grn, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  final all = hasil.map((e) => e['kode']).join('\n');
                  Clipboard.setData(ClipboardData(text: all));
                  _toast(ctx, 'Semua kode disalin');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _c2, borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.copy_all_rounded, color: _w45, size: 13),
                    SizedBox(width: 5),
                    Text('Salin Semua', style: TextStyle(color: _w45, fontSize: 11)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: _c2, borderRadius: BorderRadius.circular(16)),
              child: Column(children: List.generate(hasil.length, (i) {
                final kode   = hasil[i]['kode'] as String;
                final expStr = hasil[i]['expiredAtStr'] as String;
                return GestureDetector(
                  onTap: () { Clipboard.setData(ClipboardData(text: kode)); _toast(ctx, 'Kode "$kode" disalin'); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                        border: i < hasil.length - 1 ? const Border(bottom: BorderSide(color: _c3)) : null),
                    child: Row(children: [
                      const Icon(Icons.key_rounded, color: _amb, size: 14),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kode, style: const TextStyle(
                            color: _w100, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                        if (expStr.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.timer_off_outlined, color: _exp, size: 10),
                            const SizedBox(width: 4),
                            Text('Kadaluarsa: $expStr',
                                style: const TextStyle(color: _exp, fontSize: 10, fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ])),
                      const Icon(Icons.copy_rounded, color: _w20, size: 14),
                    ]),
                  ),
                );
              })),
            ),
          ],
          const SizedBox(height: 8),
        ]));
      }),
    );
  }

  // ─── SHEET: DETAIL ────────────────────────────────────────────────────────
  void _openDetail(JasaPostItem item) {
    final cc        = _catColor(item.kategori);
    final ci        = _catIcon(item.kategori);
    final hasMedia  = item.media.isNotEmpty;
    final mediaPage = ValueNotifier<int>(0);
    final canManage = _isAdmin || widget.username == item.username;
    bool localSold  = item.effectivelySold;
    int  localStok  = item.stok;
    bool soldBusy   = false;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, ss) =>
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DraggableScrollableSheet(
            initialChildSize: hasMedia ? 0.90 : 0.72, maxChildSize: 0.96, minChildSize: 0.45,
            builder: (_, ctrl) => Container(
              decoration: const BoxDecoration(
                  color: _c1, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: ListView(controller: ctrl, padding: EdgeInsets.zero, children: [

                if (hasMedia) ...[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      height: 260,
                      child: Stack(children: [
                        if (localSold)
                          Positioned.fill(child: Container(
                            color: Colors.black54,
                            child: Center(child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(color: _sold, borderRadius: BorderRadius.circular(99)),
                              child: const Text('TERJUAL', style: TextStyle(
                                  color: _w100, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            )),
                          )),
                        PageView.builder(
                          itemCount: item.media.length,
                          onPageChanged: (i) => mediaPage.value = i,
                          itemBuilder: (_, i) => _buildMediaTile(item.media[i], height: 260),
                        ),
                        Positioned(bottom: 0, left: 0, right: 0, child: Container(
                          height: 80,
                          decoration: BoxDecoration(gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, _c1],
                          )),
                        )),
                        ValueListenableBuilder<int>(
                          valueListenable: mediaPage,
                          builder: (_, cur, __) => Stack(children: [
                            Positioned(top: 10, right: 10, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                              child: Row(children: [
                                Icon(_isVid(item.media[cur]) ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                                    color: _isVid(item.media[cur]) ? _amb : _w70, size: 11),
                                const SizedBox(width: 4),
                                Text('${cur + 1}/${item.media.length}',
                                    style: const TextStyle(color: _w70, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            )),
                            if (item.media.length > 1)
                              Positioned(bottom: 14, left: 0, right: 0,
                                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(item.media.length, (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: cur == i ? 20 : 6, height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                        color: cur == i ? _w100 : _w20,
                                        borderRadius: BorderRadius.circular(99)),
                                  )),
                                )),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ] else ...[
                  const _Handle(),
                ],

                Padding(
                  padding: EdgeInsets.fromLTRB(22, hasMedia ? 8 : 0, 22,
                      MediaQuery.of(context).padding.bottom + 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (hasMedia) const _Handle(),

                    // Sold banner (no media)
                    if (!hasMedia && localSold)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _sold.withOpacity(0.12), borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _sold.withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: _sold, size: 16),
                          const SizedBox(width: 10),
                          const Text('Produk ini sudah TERJUAL',
                              style: TextStyle(color: _sold, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),

                    // Expiry banner
                    if (item.hasExpiry)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: item.isExpired
                              ? _exp.withOpacity(0.1)
                              : item.expiresSoon
                                  ? _amb.withOpacity(0.08)
                                  : _w08,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isExpired
                                ? _exp.withOpacity(0.35)
                                : item.expiresSoon
                                    ? _amb.withOpacity(0.3)
                                    : _w20.withOpacity(0.3),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            item.isExpired ? Icons.timer_off_rounded : Icons.timer_outlined,
                            color: item.isExpired ? _exp : item.expiresSoon ? _amb : _w45, size: 14,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: item.isExpired
                              ? const Text('Iklan ini sudah kadaluarsa',
                                  style: TextStyle(color: _exp, fontSize: 12, fontWeight: FontWeight.w700))
                              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Berakhir: ${item.expiredAtStr}',
                                      style: TextStyle(
                                        color: item.expiresSoon ? _amb : _w70,
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                      )),
                                  const SizedBox(height: 1),
                                  Text(item.sisaWaktuLabel,
                                      style: TextStyle(
                                        color: item.expiresSoon ? _exp : _w45, fontSize: 11)),
                                ]),
                          ),
                        ]),
                      ),

                    // Meta row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: cc.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(ci, size: 11, color: cc),
                          const SizedBox(width: 5),
                          Text(item.kategori, style: TextStyle(color: cc, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const Spacer(),
                      if (localSold)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _sold.withOpacity(0.15), borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: _sold.withOpacity(0.4)),
                          ),
                          child: const Text('TERJUAL', style: TextStyle(
                              color: _sold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      if (!localSold && localStok == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.12), borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: _red.withOpacity(0.4)),
                          ),
                          child: const Text('STOK HABIS', style: TextStyle(
                              color: _red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      if (item.createdAtStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(item.createdAtStr, style: const TextStyle(color: _w45, fontSize: 11)),
                      ],
                    ]),
                    const SizedBox(height: 14),

                    Text(item.judul, style: const TextStyle(
                        color: _w100, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.storefront_outlined, color: _w45, size: 13),
                      const SizedBox(width: 6),
                      Text(item.namaToko, style: const TextStyle(color: _w45, fontSize: 13)),
                      const SizedBox(width: 10),
                      const Icon(Icons.person_outline_rounded, color: _w20, size: 12),
                      const SizedBox(width: 4),
                      Text(item.username, style: const TextStyle(color: _w20, fontSize: 11)),
                    ]),
                    const SizedBox(height: 20),

                    if (item.deskripsi.isNotEmpty) ...[
                      Text(item.deskripsi, style: const TextStyle(color: _w70, fontSize: 14, height: 1.7)),
                      const SizedBox(height: 20),
                    ],

                    // Price + stok
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: _c2, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('HARGA', style: TextStyle(
                              color: _w20, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(_fmt(item.harga), style: const TextStyle(
                              color: _w100, fontSize: 22, fontWeight: FontWeight.w800)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('STOK', style: TextStyle(
                              color: _w20, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(
                            localStok < 0 ? 'Unlimited' : localStok == 0 ? 'Habis' : '$localStok unit',
                            style: TextStyle(
                              color: localStok == 0 ? _red : localStok < 0 ? _grn : _amb,
                              fontSize: 15, fontWeight: FontWeight.w800,
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    const Text('HUBUNGI PENJUAL', style: TextStyle(
                        color: _w45, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    if (item.kontakWa.isNotEmpty)
                      _CtxBtn(faIcon: FontAwesomeIcons.whatsapp, label: 'WhatsApp',
                          value: item.kontakWa, color: const Color(0xFF25D366),
                          onTap: () => _open('https://wa.me/${item.kontakWa.replaceAll('+', '')}')),
                    if (item.kontakTg.isNotEmpty)
                      _CtxBtn(faIcon: FontAwesomeIcons.telegram, label: 'Telegram',
                          value: item.kontakTg, color: const Color(0xFF0088CC),
                          onTap: () => _open('https://t.me/${item.kontakTg.replaceAll('@', '')}')),
                    if (item.kontakTelp.isNotEmpty)
                      _CtxBtn(icon: Icons.phone_rounded, label: 'Telepon',
                          value: item.kontakTelp, color: const Color(0xFF10B981),
                          onTap: () => _open('tel:${item.kontakTelp}')),

                    if (canManage) ...[
                      const SizedBox(height: 24),
                      const Text('KELOLA IKLAN', style: TextStyle(
                          color: _w45, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: soldBusy ? null : () async {
                              ss(() => soldBusy = true);
                              await _markSold(item.id, !localSold, sheetCtx,
                                  onDone: (s) => ss(() { localSold = s; soldBusy = false; }));
                              ss(() => soldBusy = false);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 52,
                              decoration: BoxDecoration(
                                color: localSold ? _grn.withOpacity(0.12) : _sold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color: localSold ? _grn.withOpacity(0.35) : _sold.withOpacity(0.35)),
                              ),
                              child: Center(child: soldBusy
                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                                      color: localSold ? _grn : _sold, strokeWidth: 1.5))
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(localSold ? Icons.refresh_rounded : Icons.check_circle_outline_rounded,
                                          color: localSold ? _grn : _sold, size: 16),
                                      const SizedBox(width: 8),
                                      Text(localSold ? 'Tandai Tersedia' : 'Tandai Terjual',
                                          style: TextStyle(color: localSold ? _grn : _sold,
                                              fontSize: 13, fontWeight: FontWeight.w700)),
                                    ])),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _editStok(item.copyWith(stok: localStok), sheetCtx,
                            onDone: (s) => ss(() {
                              localStok = s;
                              if (s == 0 && !localSold) localSold = true;
                              if (s > 0 && localSold && item.stok == 0) localSold = false;
                            }),
                          ),
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: _amb.withOpacity(0.12), borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _amb.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: _amb, size: 20),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _deletePost(item.id, sheetCtx),
                        child: Container(
                          width: double.infinity, height: 50,
                          decoration: BoxDecoration(
                            color: _redD.withOpacity(0.15), borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _red.withOpacity(0.25)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.delete_outline_rounded, color: _red, size: 17),
                            SizedBox(width: 8),
                            Text('Hapus Iklan', style: TextStyle(
                                color: _red, fontSize: 14, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _c0,
        extendBody: true,
        body: Column(children: [
          _buildAppBar(),
          _buildSearch(),
          _buildCatBar(),
          _buildSoldFilter(),
          Expanded(child: _buildBody()),
        ]),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildAppBar() {
    final totalTersedia = _all.where((x) => !x.effectivelySold).length;
    final totalTerjual  = _all.where((x) => x.effectivelySold).length;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _w100, size: 19)),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pasar Online',
                style: TextStyle(color: _w100, fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 2),
            _loading
                ? const Text('Memuat...', style: TextStyle(color: _w45, fontSize: 12))
                : Text('$totalTersedia tersedia · $totalTerjual terjual',
                    style: const TextStyle(color: _w45, fontSize: 12)),
          ])),
          if (_isAdmin) ...[
            GestureDetector(
              onTap: _openGenKode,
              child: Container(
                width: 38, height: 38, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: _amb.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.confirmation_number_outlined, color: _amb, size: 17),
              ),
            ),
          ],
          GestureDetector(
            onTap: () => _load(refresh: true),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _c2, shape: BoxShape.circle),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(color: _w20, strokeWidth: 1.5))
                  : const Icon(Icons.refresh_rounded, color: _w45, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(color: _c1, borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: _searchTxt,
          style: const TextStyle(color: _w100, fontSize: 14),
          cursorColor: _red,
          onChanged: (v) { _q = v; _applyFilter(); },
          decoration: InputDecoration(
            hintText: 'Cari iklan atau nama toko...',
            hintStyle: const TextStyle(color: _w20, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: _w45, size: 18),
            suffixIcon: _q.isNotEmpty
                ? GestureDetector(onTap: () { _searchTxt.clear(); _q = ''; _applyFilter(); },
                    child: const Icon(Icons.close_rounded, color: _w45, size: 16))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildCatBar() {
    return SizedBox(
      height: 50,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        scrollDirection: Axis.horizontal,
        children: _cats.map((cat) {
          final on  = _selCat == cat['label'] as String;
          final col = cat['color'] as Color;
          return GestureDetector(
            onTap: () { setState(() => _selCat = cat['label'] as String); _applyFilter(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: on ? col.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: on ? col.withOpacity(0.45) : _c3),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (on) ...[Icon(cat['icon'] as IconData, size: 12, color: col), const SizedBox(width: 5)],
                Text(cat['label'] as String, style: TextStyle(
                  color: on ? col : _w45, fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.normal,
                )),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSoldFilter() {
    const opts   = ['Semua', 'Tersedia', 'Terjual'];
    final colors = [_w45, _grn, _sold];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(children: [
        const Icon(Icons.filter_list_rounded, color: _w20, size: 13),
        const SizedBox(width: 8),
        ...List.generate(opts.length, (i) {
          final on = _soldFilter == opts[i];
          return GestureDetector(
            onTap: () { setState(() => _soldFilter = opts[i]); _applyFilter(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: on ? colors[i].withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: on ? colors[i].withOpacity(0.5) : _c3, width: 1),
              ),
              child: Text(opts[i], style: TextStyle(
                color: on ? colors[i] : _w20, fontSize: 11,
                fontWeight: on ? FontWeight.w700 : FontWeight.normal,
              )),
            ),
          );
        }),
        const Spacer(),
        Text('${_filtered.length} iklan', style: const TextStyle(color: _w20, fontSize: 11)),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading && _filtered.isEmpty) {
      return const Center(child: SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(color: _red, strokeWidth: 1.5)));
    }
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.storefront_outlined, color: _c3, size: 56),
        const SizedBox(height: 16),
        Text(
          _soldFilter == 'Terjual' ? 'Belum ada yang terjual'
              : _soldFilter == 'Tersedia' ? 'Tidak ada iklan tersedia'
              : 'Belum ada iklan',
          style: const TextStyle(color: _w45, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text('Jadilah yang pertama posting!', style: TextStyle(color: _w20, fontSize: 13)),
      ]));
    }
    return FadeTransition(
      opacity: _fade,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true), color: _red, backgroundColor: _c2,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _buildCard(_filtered[i]),
        ),
      ),
    );
  }

  Widget _buildMediaTile(String url, {double height = 170}) {
    if (_isVid(url)) {
      return GestureDetector(
        onTap: () => _open(url),
        child: SizedBox(
          height: height, width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_c3, _c0]))),
            CustomPaint(painter: _VideoBgPainter()),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.15), shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.6), width: 1.5),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: _red, size: 34),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam_rounded, color: _amb, size: 11),
                  SizedBox(width: 5),
                  Text('Ketuk untuk putar video', style: TextStyle(color: _w70, fontSize: 11)),
                ]),
              ),
            ])),
          ]),
        ),
      );
    }
    return Image.network(url, fit: BoxFit.cover, width: double.infinity, height: height,
      errorBuilder: (_, __, ___) => Container(height: height, color: _c2,
          child: const Center(child: Icon(Icons.broken_image_outlined, color: _w20, size: 32))),
      loadingBuilder: (_, child, p) => p == null ? child
          : Container(height: height, color: _c2,
              child: const Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: _w20, strokeWidth: 1.5)))),
    );
  }

  Widget _buildCard(JasaPostItem item) {
    final cc       = _catColor(item.kategori);
    final ci       = _catIcon(item.kategori);
    final hasMedia = item.media.isNotEmpty;
    final sold     = item.effectivelySold;

    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Opacity(
        opacity: sold ? 0.65 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _c1, borderRadius: BorderRadius.circular(18),
            border: sold
                ? Border.all(color: _sold.withOpacity(0.2))
                : item.expiresSoon
                    ? Border.all(color: _exp.withOpacity(0.35))
                    : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            if (hasMedia)
              SizedBox(
                height: 170,
                child: Stack(children: [
                  _buildMediaTile(item.media.first),
                  Positioned(bottom: 0, left: 0, right: 0, child: Container(
                    height: 70,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, _c1],
                    )),
                  )),
                  if (sold)
                    Positioned.fill(child: Container(
                      color: Colors.black45,
                      child: Center(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: _sold, borderRadius: BorderRadius.circular(99)),
                        child: const Text('TERJUAL', style: TextStyle(
                            color: _w100, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      )),
                    )),
                  Positioned(top: 10, right: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                    child: Row(children: [
                      Icon(_isVid(item.media.first) ? Icons.videocam_rounded : Icons.photo_library_outlined,
                          color: _isVid(item.media.first) ? _amb : _w70, size: 11),
                      const SizedBox(width: 4),
                      Text('${item.media.length}',
                          style: const TextStyle(color: _w70, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                  Positioned(top: 10, left: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: cc.withOpacity(0.85), borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(ci, size: 11, color: _w100),
                      const SizedBox(width: 4),
                      Text(item.kategori, style: const TextStyle(
                          color: _w100, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  )),
                  if (item.stokTracked)
                    Positioned(bottom: 14, left: 10, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
                      child: Row(children: [
                        Icon(Icons.inventory_2_outlined,
                            color: item.stok == 0 ? _red : item.stok <= 3 ? _amb : _grn, size: 9),
                        const SizedBox(width: 4),
                        Text(item.stok == 0 ? 'Habis' : '${item.stok} unit',
                            style: TextStyle(
                                color: item.stok == 0 ? _red : item.stok <= 3 ? _amb : _grn,
                                fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                  // expiry countdown badge
                  if (item.hasExpiry && !item.isExpired)
                    Positioned(bottom: 14, right: 10, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.expiresSoon ? _exp.withOpacity(0.9) : Colors.black54,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(children: [
                        Icon(Icons.timer_outlined,
                            color: item.expiresSoon ? _w100 : _w45, size: 9),
                        const SizedBox(width: 4),
                        Text(item.sisaWaktuLabel,
                            style: TextStyle(
                              color: item.expiresSoon ? _w100 : _w45,
                              fontSize: 10, fontWeight: FontWeight.w700,
                            )),
                      ]),
                    )),
                ]),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!hasMedia)
                  Row(children: [
                    Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(ci, color: cc, size: 13)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: cc.withOpacity(0.08), borderRadius: BorderRadius.circular(99)),
                      child: Text(item.kategori, style: TextStyle(
                          color: cc, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    if (sold)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _sold.withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
                        child: const Text('TERJUAL', style: TextStyle(
                            color: _sold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    if (!sold && item.stokTracked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (item.stok == 0 ? _red : item.stok <= 3 ? _amb : _grn).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(99)),
                        child: Text(item.stok == 0 ? 'Habis' : '${item.stok} stok',
                            style: TextStyle(
                                color: item.stok == 0 ? _red : item.stok <= 3 ? _amb : _grn,
                                fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                if (!hasMedia) const SizedBox(height: 8),
                Text(item.judul,
                    style: TextStyle(
                        color: sold ? _w45 : _w100,
                        fontSize: 15, fontWeight: FontWeight.w700, height: 1.2,
                        decoration: sold ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: _w45),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(item.namaToko, style: const TextStyle(color: _w45, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.deskripsi, style: const TextStyle(color: _w45, fontSize: 12, height: 1.4),
                      maxLines: hasMedia ? 1 : 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Text(_fmt(item.harga), style: TextStyle(
                      color: sold ? _w45 : _w100, fontSize: 14, fontWeight: FontWeight.w800,
                      decoration: sold ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: _w45)),
                  const Spacer(),
                  if (!hasMedia && item.hasExpiry && !item.isExpired) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.expiresSoon ? _exp.withOpacity(0.15) : _w08,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.timer_outlined,
                            color: item.expiresSoon ? _exp : _w45, size: 9),
                        const SizedBox(width: 3),
                        Text(item.sisaWaktuLabel,
                            style: TextStyle(
                                color: item.expiresSoon ? _exp : _w45,
                                fontSize: 9, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (item.kontakWa.isNotEmpty)   _dot(const Color(0xFF25D366)),
                  if (item.kontakTg.isNotEmpty)   _dot(const Color(0xFF0088CC)),
                  if (item.kontakTelp.isNotEmpty) _dot(const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: _w20, size: 16),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 7, height: 7, margin: const EdgeInsets.only(left: 5),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _openPost,
        child: Container(
          height: 52, width: double.infinity,
          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(99)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_rounded, color: _w100, size: 20),
            SizedBox(width: 8),
            Text('Pasang Iklan', style: TextStyle(color: _w100, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final int value;
  final TextEditingController ctrl;
  final StateSetter ss;
  const _QuickChip(this.label, this.value, this.ctrl, this.ss);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => ss(() => ctrl.text = value.toString()),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _c3, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(color: _w70, fontSize: 11, fontWeight: FontWeight.w600)),
    ),
  );
}

class _DayChip extends StatelessWidget {
  final String label;
  final int value;
  final TextEditingController ctrl;
  final StateSetter ss;
  const _DayChip(this.label, this.value, this.ctrl, this.ss);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => ss(() => ctrl.text = value.toString()),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _amb.withOpacity(0.08), borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _amb.withOpacity(0.2)),
      ),
      child: Text(label, style: const TextStyle(color: _amb, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}

class _VideoBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x08FFFFFF)..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

extension _JasaPostItemCopy on JasaPostItem {
  JasaPostItem copyWith({bool? isSold, int? stok}) => JasaPostItem(
    id: id, judul: judul, kategori: kategori, deskripsi: deskripsi, harga: harga,
    kontakWa: kontakWa, kontakTg: kontakTg, kontakTelp: kontakTelp,
    namaToko: namaToko, username: username, createdAtStr: createdAtStr,
    media: media, isSold: isSold ?? this.isSold, stok: stok ?? this.stok,
    expiredAt: expiredAt, expiredAtStr: expiredAtStr,
  );
}

class _BSheet extends StatelessWidget {
  final Widget child;
  const _BSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: DraggableScrollableSheet(
        initialChildSize: 0.93, maxChildSize: 0.97, minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: _c1, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(22, 10, 22, MediaQuery.of(context).viewInsets.bottom + 36),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 32, height: 3, margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(color: _c4, borderRadius: BorderRadius.circular(99)),
    ),
  );
}

class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(
        color: _w45, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData? icon;
  final TextInputType kb;
  final bool enabled;
  final int lines;
  final TextCapitalization caps;
  const _TF({required this.ctrl, required this.hint, this.icon,
    this.kb = TextInputType.text, this.enabled = true, this.lines = 1,
    this.caps = TextCapitalization.none});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: kb, maxLines: lines, enabled: enabled,
    textCapitalization: caps,
    style: const TextStyle(color: _w100, fontSize: 14, fontWeight: FontWeight.w500),
    cursorColor: _red,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: _w20, fontSize: 14),
      prefixIcon: icon != null
          ? Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(icon, size: 17, color: _w45))
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      filled: true, fillColor: enabled ? _c2 : _c1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _red, width: 1.2)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
    ),
  );
}

class _TFfa extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData faIcon;
  final TextInputType kb;
  final Color accentColor;
  const _TFfa({required this.ctrl, required this.hint, required this.faIcon,
    this.kb = TextInputType.text, required this.accentColor});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: kb,
    style: const TextStyle(color: _w100, fontSize: 14, fontWeight: FontWeight.w500),
    cursorColor: _red,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: _w20, fontSize: 14),
      prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FaIcon(faIcon, size: 15, color: accentColor)),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      filled: true, fillColor: _c2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: accentColor.withOpacity(0.5), width: 1.2)),
    ),
  );
}

class _Btn42 extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;
  final Color color;
  final IconData icon;
  const _Btn42({required this.onTap, required this.color, required this.icon, this.busy = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 50, height: 50,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
      child: Center(child: busy
          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: color, strokeWidth: 1.5))
          : Icon(icon, color: color, size: 19)),
    ),
  );
}

class _CtxBtn extends StatelessWidget {
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? faIcon;
  const _CtxBtn({required this.label, required this.value, required this.color,
    required this.onTap, this.icon, this.faIcon});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: _c2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Center(child: faIcon != null
              ? FaIcon(faIcon, size: 14, color: color)
              : Icon(icon, size: 16, color: color))),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(value, style: const TextStyle(color: _w70, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        Icon(Icons.north_east_rounded, color: color.withOpacity(0.35), size: 14),
      ]),
    ),
  );
}
