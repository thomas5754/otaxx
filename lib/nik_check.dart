import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class NikCheckerPage extends StatefulWidget {
  const NikCheckerPage({super.key});

  @override
  State<NikCheckerPage> createState() => _NikCheckerPageState();
}

class _NikCheckerPageState extends State<NikCheckerPage>
    with TickerProviderStateMixin {
  final TextEditingController _nikController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;
  String? _responseTime;

  late final AnimationController _resultAnim;
  late final AnimationController _scanAnim;
  late final AnimationController _pulseAnim;
  late final AnimationController _shimmerAnim;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _scanLine;
  late final Animation<double> _pulse;
  late final Animation<double> _shimmer;

  // ── Colour Palette ────────────────────────────────────────
  static const Color bg        = Color(0xFF0D0608);
  static const Color card      = Color(0xFF1C0E10);
  static const Color cardHigh  = Color(0xFF241318);
  static const Color rose      = Color(0xFFE8002D);
  static const Color roseDim   = Color(0xFFB0001F);
  static const Color roseGlow  = Color(0xFFFF1744);
  static const Color roseSoft  = Color(0xFFFF6B81);
  static const Color gold      = Color(0xFFFFB347);
  static const Color ivory     = Color(0xFFF5E6E8);
  static const Color muted     = Color(0xFF7A5560);
  static const Color divider   = Color(0xFF2A1518);

  @override
  void initState() {
    super.initState();

    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scanAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _shimmerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();

    _fadeIn = CurvedAnimation(
        parent: _resultAnim, curve: Curves.easeOutQuint);
    _slideUp = Tween<Offset>(
            begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _resultAnim, curve: Curves.easeOutExpo));
    _scanLine = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerAnim, curve: Curves.linear));
  }

  @override
  void dispose() {
    _nikController.dispose();
    _resultAnim.dispose();
    _scanAnim.dispose();
    _pulseAnim.dispose();
    _shimmerAnim.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────
  Future<void> _checkNik() async {
    final nik = _nikController.text.trim();
    if (nik.isEmpty) { _setError('NIK tidak boleh kosong.'); return; }
    if (!RegExp(r'^\d{16}$').hasMatch(nik)) {
      _setError('Format NIK tidak valid (harus 16 digit angka).');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; _result = null; });
    _scanAnim.repeat();

    try {
      final url = Uri.parse(
          'https://rynekoo-api.hf.space/tools/nikparser?nik=$nik');
      final response =
          await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['result'] != null) {
          setState(() {
            _result = decoded['result'] as Map<String, dynamic>;
            _responseTime = decoded['responseTime']?.toString();
            _errorMessage = null;
          });
          _resultAnim.forward(from: 0);
        } else {
          _setError('Data tidak ditemukan untuk NIK tersebut.');
        }
      } else {
        _setError('Server error: ${response.statusCode}');
      }
    } catch (_) {
      _setError('Koneksi gagal. Periksa jaringan Anda.');
    } finally {
      _scanAnim.stop();
      _scanAnim.reset();
      setState(() => _isLoading = false);
    }
  }

  void _setError(String msg) {
    setState(() { _errorMessage = msg; _result = null; _isLoading = false; });
    _scanAnim.stop();
    _scanAnim.reset();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: rose.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: rose.withOpacity(0.2), blurRadius: 12)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: roseSoft, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$label disalin',
                  style: const TextStyle(
                    color: ivory,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Input Card ────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rose.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(color: rose.withOpacity(0.08), blurRadius: 24, spreadRadius: 2),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // — Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [rose.withOpacity(0.12), rose.withOpacity(0.04)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(color: rose.withOpacity(0.12), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rose.withOpacity(0.12),
                    border: Border.all(color: rose.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(Icons.fingerprint, color: rose, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERIFIKASI NIK',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 2.5,
                        color: ivory,
                      ),
                    ),
                    Text(
                      'Nomor Induk Kependudukan — 16 digit',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 11.5,
                        color: muted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Opacity(
                    opacity: _pulse.value,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rose,
                        boxShadow: [
                          BoxShadow(color: rose.withOpacity(0.6), blurRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                // — TextField with scan overlay
                Stack(
                  children: [
                    TextField(
                      controller: _nikController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      style: const TextStyle(
                        color: ivory,
                        fontSize: 22,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: '0000000000000000',
                        hintStyle: TextStyle(
                          color: muted.withOpacity(0.4),
                          fontFamily: 'Rajdhani',
                          fontSize: 22,
                          letterSpacing: 4,
                        ),
                        filled: true,
                        fillColor: bg.withOpacity(0.7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        prefixIcon: Icon(
                          Icons.credit_card_rounded,
                          color: rose.withOpacity(0.6),
                          size: 22,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: rose.withOpacity(0.2), width: 1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: roseGlow, width: 1.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: (_) => _checkNik(),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedBuilder(
                            animation: _scanLine,
                            builder: (_, __) => CustomPaint(
                              painter: _ScanPainter(
                                  progress: _scanLine.value, color: rose),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // — Button
                GestureDetector(
                  onTap: _isLoading ? null : _checkNik,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? LinearGradient(
                              colors: [cardHigh, cardHigh.withOpacity(0.7)])
                          : const LinearGradient(
                              colors: [roseDim, rose, roseGlow],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                  color: rose.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6)),
                            ],
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: rose.withOpacity(0.6),
                                    strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'MEMINDAI NIK...',
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                  color: muted,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'VERIFIKASI NIK',
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error Banner ──────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rose.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rose.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: rose.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: roseSoft, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: ivory,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Cards ──────────────────────────────────────────
  Widget _buildResults() {
    final r = _result!;

    final String nik        = r['nik']?.toString() ?? _nikController.text.trim();
    final String kelamin    = r['kelamin']?.toString() ?? '';
    final String lahir      = r['lahir']?.toString() ?? '';
    final String lahirFull  = r['lahir_lengkap']?.toString() ?? '';

    final Map provinsi   = r['provinsi']   as Map? ?? {};
    final Map kotakab    = r['kotakab']    as Map? ?? {};
    final Map kecamatan  = r['kecamatan']  as Map? ?? {};
    final Map tambahan   = r['tambahan']   as Map? ?? {};

    final String kodeWilayah = r['kode_wilayah']?.toString() ?? '';
    final String nomorUrut   = r['nomor_urut']?.toString() ?? '';

    final String provinsiNama  = provinsi['nama']?.toString() ?? '';
    final String provinsiKode  = provinsi['kode']?.toString() ?? '';
    final String kotaJenis     = kotakab['jenis']?.toString() ?? '';
    final String kotaNama      = kotakab['nama']?.toString() ?? '';
    final String kotaKode      = kotakab['kode']?.toString() ?? '';
    final String kecNama       = kecamatan['nama']?.toString() ?? '';

    return Column(
      children: [
        // ── Hero Card ─────────────────────────────────────
        _buildHeroCard(
          nik: nik,
          kelamin: kelamin,
          lahir: lahirFull.isNotEmpty ? lahirFull : lahir,
          usia: tambahan['usia']?.toString() ?? '',
          kategori: tambahan['kategori_usia']?.toString() ?? '',
        ),

        const SizedBox(height: 14),

        // ── Identitas ─────────────────────────────────────
        _buildSection(
          title: 'IDENTITAS',
          icon: Icons.badge_outlined,
          accent: rose,
          rows: [
            _RowItem('NIK',           nik,    copy: true),
            _RowItem('Jenis Kelamin', kelamin),
            _RowItem('Tanggal Lahir', lahirFull.isNotEmpty ? lahirFull : lahir),
            _RowItem('Usia',          tambahan['usia']?.toString()),
            _RowItem('Kategori Usia', tambahan['kategori_usia']?.toString()),
            _RowItem('Ulang Tahun',   tambahan['ultah']?.toString()),
          ],
        ),

        // ── Domisili ──────────────────────────────────────
        _buildSection(
          title: 'DOMISILI',
          icon: Icons.location_city_rounded,
          accent: gold,
          rows: [
            _RowItem('Provinsi',       '$provinsiNama ($provinsiKode)'),
            _RowItem('Kota/Kabupaten', '$kotaJenis $kotaNama ($kotaKode)'.trim()),
            _RowItem('Kecamatan',      kecNama.isNotEmpty ? kecNama : null),
            _RowItem('Kode Wilayah',   kodeWilayah.isNotEmpty ? kodeWilayah : null),
            _RowItem('Nomor Urut',     nomorUrut.isNotEmpty ? nomorUrut : null),
          ],
        ),

        // ── Tambahan ──────────────────────────────────────
        _buildSection(
          title: 'INFO TAMBAHAN',
          icon: Icons.auto_awesome_rounded,
          accent: roseSoft,
          rows: [
            _RowItem('Zodiak',  tambahan['zodiak']?.toString()),
            _RowItem('Pasaran', tambahan['pasaran']?.toString()),
          ],
        ),

        // — Footer
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, size: 13, color: muted.withOpacity(0.5)),
              const SizedBox(width: 5),
              Text(
                _responseTime != null
                    ? 'Diproses dalam $_responseTime'
                    : 'Data dari sumber resmi',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 11.5,
                  color: muted.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeroCard({
    required String nik,
    required String kelamin,
    required String lahir,
    required String usia,
    required String kategori,
  }) {
    final isFemale = kelamin.contains('PEREMPUAN');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0810), Color(0xFF2C0E18), Color(0xFF1A0810)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rose.withOpacity(0.22), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: rose.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withOpacity(0.4), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status chip + gender
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rose.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rose.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: rose, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'TERVERIFIKASI',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: roseSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                isFemale ? Icons.face_4_rounded : Icons.face_6_rounded,
                color: rose.withOpacity(0.5),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                kelamin,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: roseSoft,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // NIK with shimmer
          AnimatedBuilder(
            animation: _shimmer,
            builder: (_, child) {
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: const [ivory, Colors.white, ivory],
                  stops: [
                    (_shimmer.value - 0.5).clamp(0.0, 1.0),
                    _shimmer.value.clamp(0.0, 1.0),
                    (_shimmer.value + 0.5).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds),
                child: child,
              );
            },
            child: Text(
              _formatNik(nik),
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 5,
              ),
            ),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: rose.withOpacity(0.12)),
          const SizedBox(height: 14),

          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (lahir.isNotEmpty) _heroChip(Icons.cake_rounded, lahir),
              if (usia.isNotEmpty) _heroChip(Icons.hourglass_bottom_rounded, usia),
              if (kategori.isNotEmpty) _heroChip(Icons.person_rounded, kategori),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: rose.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rose.withOpacity(0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: roseSoft.withOpacity(0.7)),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ivory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color accent,
    required List<_RowItem> rows,
  }) {
    final visible = rows.where((r) =>
        r.value != null &&
        r.value!.trim().isNotEmpty &&
        r.value != ' ()' &&
        r.value != '()').toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 2,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: accent.withOpacity(0.08)),

          // Rows
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
            child: Column(
              children: [
                for (int i = 0; i < visible.length; i++) ...[
                  _buildRow(visible[i], accent),
                  if (i < visible.length - 1)
                    Container(height: 1, color: divider),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_RowItem row, Color accent) {
    return InkWell(
      onTap: row.copy ? () => _copy(row.value!, row.label) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                row.label,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: Text(
                row.value!,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ivory,
                  height: 1.3,
                ),
              ),
            ),
            if (row.copy)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 1),
                child: Icon(Icons.copy_all_rounded,
                    size: 14, color: accent.withOpacity(0.35)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatNik(String nik) {
    if (nik.length != 16) return nik;
    return '${nik.substring(0, 4)} ${nik.substring(4, 8)} '
        '${nik.substring(8, 12)} ${nik.substring(12, 16)}';
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rose.withOpacity(0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: ivory, size: 16),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: rose, size: 16),
            const SizedBox(width: 8),
            const Text(
              'NIK CHECKER',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                color: ivory,
                fontSize: 16,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Subtle background grid
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          // Top glow orb
          Positioned(
            top: -100, left: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [rose.withOpacity(0.07), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom glow
          Positioned(
            bottom: -80, right: -80,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [roseDim.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(child: _buildInputCard()),
                ),

                if (_errorMessage != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    sliver: SliverToBoxAdapter(child: _buildError()),
                  ),

                if (_result != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    sliver: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: _buildResults(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data Model ────────────────────────────────────────────────
class _RowItem {
  final String label;
  final String? value;
  final bool copy;
  const _RowItem(this.label, this.value, {this.copy = false});
}

// ── Scan Line Painter ─────────────────────────────────────────
class _ScanPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ScanPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.5),
          color.withOpacity(0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromLTWH(0, y - 24, size.width, 48));
    canvas.drawRect(Rect.fromLTWH(0, y - 24, size.width, 48), paint);
  }

  @override
  bool shouldRepaint(_ScanPainter o) => o.progress != progress;
}

// ── Background Painter ────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8002D).withOpacity(0.025)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BgPainter o) => false;
}
