import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DomainOsintPage extends StatefulWidget {
  const DomainOsintPage({super.key});

  @override
  State<DomainOsintPage> createState() => _DomainOsintPageState();
}

class _DomainOsintPageState extends State<DomainOsintPage>
    with TickerProviderStateMixin {
  final TextEditingController _domainController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _dnsData;
  List<Map<String, dynamic>> _certRecords = [];
  List<String> _uniqueSubdomains = [];
  String? _errorMessage;
  String? _scannedDomain;

  late final AnimationController _pulseAnim;
  late final AnimationController _scanAnim;
  late final AnimationController _resultAnim;

  late final Animation<double> _pulse;
  late final Animation<double> _scan;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // ── Palette ───────────────────────────────────────────────
  static const Color bg       = Color(0xFF0D0608);
  static const Color card     = Color(0xFF1C0E10);
  static const Color cardHi   = Color(0xFF241318);
  static const Color rose     = Color(0xFFE8002D);
  static const Color roseDim  = Color(0xFFB0001F);
  static const Color roseGlow = Color(0xFFFF1744);
  static const Color roseSoft = Color(0xFFFF6B81);
  static const Color gold     = Color(0xFFFFB347);
  static const Color teal     = Color(0xFF26C6DA);
  static const Color ivory    = Color(0xFFF5E6E8);
  static const Color muted    = Color(0xFF7A5560);
  static const Color div      = Color(0xFF2A1518);

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scanAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));
    _scan = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut));
    _fadeIn = CurvedAnimation(
        parent: _resultAnim, curve: Curves.easeOutQuint);
    _slideUp = Tween<Offset>(
            begin: const Offset(0, 0.16), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _resultAnim, curve: Curves.easeOutExpo));
  }

  @override
  void dispose() {
    _domainController.dispose();
    _pulseAnim.dispose();
    _scanAnim.dispose();
    _resultAnim.dispose();
    super.dispose();
  }

  // ── Fetch ─────────────────────────────────────────────────
  Future<void> _checkDomain() async {
    final domain = _domainController.text.trim().toLowerCase();
    if (domain.isEmpty) {
      _setError('Masukkan nama domain terlebih dahulu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _dnsData = null;
      _certRecords = [];
      _uniqueSubdomains = [];
      _scannedDomain = domain;
    });
    _scanAnim.repeat();

    try {
      final results = await Future.wait([
        _fetchDns(domain),
        _fetchSubdomains(domain),
      ]);

      final dns = results[0] as Map<String, dynamic>?;
      final certs = results[1] as List<Map<String, dynamic>>;

      // Extract unique subdomains from cert records
      final Set<String> subSet = {};
      for (final c in certs) {
        final nm = c['name_value']?.toString() ?? '';
        final cn = c['common_name']?.toString() ?? '';
        for (final s in [nm, cn]) {
          if (s.isNotEmpty) {
            for (final part in s.split('\n')) {
              final t = part.trim();
              if (t.isNotEmpty) subSet.add(t);
            }
          }
        }
      }
      final subList = subSet.toList()..sort();

      if (dns != null || certs.isNotEmpty) {
        setState(() {
          _dnsData = dns;
          _certRecords = certs;
          _uniqueSubdomains = subList;
        });
        _resultAnim.forward(from: 0);
      } else {
        _setError('Tidak ada data ditemukan untuk domain ini.');
      }
    } catch (e) {
      _setError('Koneksi gagal. Periksa jaringan Anda.');
    } finally {
      _scanAnim.stop();
      _scanAnim.reset();
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchDns(String domain) async {
    try {
      final url = Uri.parse(
          'https://api.siputzx.my.id/api/tools/dns?domain=$domain');
      final resp =
          await http.get(url).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        return j['status'] == true ? j['data'] as Map<String, dynamic>? : null;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchSubdomains(String domain) async {
    try {
      final url = Uri.parse(
          'https://rynekoo-api.hf.space/tools/finder/subdomain-finder?domain=$domain');
      final resp =
          await http.get(url).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        if (j['success'] == true && j['result'] is List) {
          return (j['result'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  void _setError(String msg) {
    setState(() {
      _errorMessage = msg;
      _dnsData = null;
      _certRecords = [];
      _uniqueSubdomains = [];
      _isLoading = false;
    });
    _scanAnim.stop();
    _scanAnim.reset();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: rose.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                    color: rose.withOpacity(0.2), blurRadius: 12)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: roseSoft, size: 15),
                const SizedBox(width: 8),
                Text(
                  '$label disalin',
                  style: const TextStyle(
                    color: ivory,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
          BoxShadow(
              color: rose.withOpacity(0.08),
              blurRadius: 24,
              spreadRadius: 2),
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // header bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rose.withOpacity(0.12),
                  rose.withOpacity(0.04)
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                  bottom:
                      BorderSide(color: rose.withOpacity(0.12), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rose.withOpacity(0.1),
                    border: Border.all(
                        color: rose.withOpacity(0.3), width: 1),
                  ),
                  child:
                      const Icon(Icons.travel_explore, color: rose, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DOMAIN OSINT',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 2.5,
                        color: ivory,
                      ),
                    ),
                    Text(
                      'Subdomain & Certificate Scanner',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 11,
                        color: muted,
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
                          BoxShadow(
                              color: rose.withOpacity(0.6), blurRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                Stack(
                  children: [
                    TextField(
                      controller: _domainController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(
                        color: ivory,
                        fontSize: 17,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        hintText: 'contoh: example.com',
                        hintStyle: TextStyle(
                          color: muted.withOpacity(0.5),
                          fontFamily: 'Rajdhani',
                          fontSize: 16,
                        ),
                        filled: true,
                        fillColor: bg.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 17),
                        prefixIcon: Icon(Icons.dns_rounded,
                            color: rose.withOpacity(0.55), size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: rose.withOpacity(0.2), width: 1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: roseGlow, width: 1.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onSubmitted: (_) => _checkDomain(),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedBuilder(
                            animation: _scan,
                            builder: (_, __) => CustomPaint(
                              painter: _ScanPainter(
                                  progress: _scan.value, color: rose),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isLoading ? null : _checkDomain,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? LinearGradient(colors: [
                              cardHi,
                              cardHi.withOpacity(0.7)
                            ])
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
                                  blurRadius: 14,
                                  offset: const Offset(0, 5)),
                            ],
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                    color: rose.withOpacity(0.6),
                                    strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'MEMINDAI...',
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
                              Icon(Icons.radar_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'SCAN DOMAIN',
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

  // ── Error ─────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rose.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rose.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: rose.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: roseSoft, size: 19),
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

  // ── Section wrapper ───────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.13), width: 1),
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
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.1),
                  accent.withOpacity(0.03),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(
                  bottom:
                      BorderSide(color: accent.withOpacity(0.1), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
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
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ── Data row ──────────────────────────────────────────────
  Widget _buildRow(String label, String? value,
      {bool copy = false, Color? valueColor}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: copy ? () => _copy(value, label) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 12,
                  color: muted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? ivory,
                  height: 1.35,
                ),
              ),
            ),
            if (copy)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_all_rounded,
                    size: 13, color: rose.withOpacity(0.35)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowDivider() =>
      Container(height: 1, color: div, margin: EdgeInsets.zero);

  // ── DNS info block ────────────────────────────────────────
  Widget _buildDnsSection() {
    if (_dnsData == null) return const SizedBox.shrink();
    final dns = _dnsData!;
    final records = dns['records'] as Map<String, dynamic>? ?? {};

    final List<Widget> rows = [
      _buildRow('Domain', dns['unicodeDomain']?.toString(), copy: true),
      _rowDivider(),
      _buildRow('Punycode', dns['punycodeDomain']?.toString(), copy: true),
    ];

    // NS Records
    final nsAnswers =
        records['ns']?['response']?['answer'] as List? ?? [];
    if (nsAnswers.isNotEmpty) {
      rows.add(_rowDivider());
      rows.add(_sectionLabel('Name Servers'));
      for (final ns in nsAnswers) {
        final t = ns['record']?['target']?.toString();
        if (t != null && t.isNotEmpty) {
          rows.add(_buildRow('NS', t, copy: true));
        }
      }
    }

    // A Records
    final aAnswers =
        records['a']?['response']?['answer'] as List? ?? [];
    if (aAnswers.isNotEmpty) {
      rows.add(_rowDivider());
      rows.add(_sectionLabel('A Records'));
      for (final a in aAnswers) {
        final d = a['record']?['data']?.toString();
        if (d != null && d.isNotEmpty) {
          rows.add(_buildRow('IP', d, copy: true, valueColor: teal));
        }
      }
    }

    // SOA
    final soaAnswers =
        records['soa']?['response']?['answer'] as List? ?? [];
    if (soaAnswers.isNotEmpty) {
      final soa = soaAnswers.first['record'];
      rows.add(_rowDivider());
      rows.add(_sectionLabel('SOA Record'));
      rows.add(_buildRow('Primary NS', soa?['host']?.toString(), copy: true));
      rows.add(_buildRow('Admin', soa?['admin']?.toString(), copy: true));
      rows.add(_buildRow('Serial', soa?['serial']?.toString()));
      rows.add(_buildRow('Refresh', soa?['refresh']?.toString()));
      rows.add(_buildRow('Retry', soa?['retry']?.toString()));
      rows.add(_buildRow('Expire', soa?['expire']?.toString()));
      rows.add(_buildRow('Min TTL', soa?['minimum']?.toString()));
    }

    return _buildSection(
      title: 'DNS INFORMATION',
      icon: Icons.dns_rounded,
      accent: rose,
      children: rows,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: muted,
        ),
      ),
    );
  }

  // ── Subdomain list ────────────────────────────────────────
  Widget _buildSubdomainSection() {
    if (_uniqueSubdomains.isEmpty) return const SizedBox.shrink();
    return _buildSection(
      title: 'SUBDOMAINS',
      icon: Icons.language_rounded,
      accent: gold,
      badge: '${_uniqueSubdomains.length} found',
      children: [
        const SizedBox(height: 4),
        ..._uniqueSubdomains.map((s) => _buildSubItem(s)).toList(),
      ],
    );
  }

  Widget _buildSubItem(String sub) {
    return InkWell(
      onTap: () => _copy(sub, sub),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: gold.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sub,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ivory,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Icon(Icons.copy_all_rounded,
                size: 13, color: gold.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }

  // ── Certificate records ───────────────────────────────────
  Widget _buildCertSection() {
    if (_certRecords.isEmpty) return const SizedBox.shrink();

    // Deduplicate by serial_number
    final Map<String, Map<String, dynamic>> bySerial = {};
    for (final c in _certRecords) {
      final serial = c['serial_number']?.toString() ?? c['id'].toString();
      bySerial.putIfAbsent(serial, () => c);
    }
    final unique = bySerial.values.toList();

    return _buildSection(
      title: 'SSL CERTIFICATES',
      icon: Icons.verified_rounded,
      accent: teal,
      badge: '${unique.length} certs',
      children: [
        const SizedBox(height: 4),
        ...unique.map((c) => _buildCertCard(c)).toList(),
      ],
    );
  }

  Widget _buildCertCard(Map<String, dynamic> cert) {
    final cn          = cert['common_name']?.toString() ?? '';
    final issuer      = cert['issuer_name']?.toString() ?? '';
    final notBefore   = _fmtDate(cert['not_before']?.toString());
    final notAfter    = _fmtDate(cert['not_after']?.toString());
    final serial      = cert['serial_number']?.toString() ?? '';
    final timestamp   = _fmtDate(cert['entry_timestamp']?.toString());

    // Check if expired
    final expiry = cert['not_after']?.toString();
    bool isExpired = false;
    if (expiry != null) {
      try {
        isExpired = DateTime.parse(expiry).isBefore(DateTime.now());
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? rose.withOpacity(0.2)
              : teal.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CN + status
          Row(
            children: [
              Expanded(
                child: Text(
                  cn,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ivory,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExpired
                      ? rose.withOpacity(0.12)
                      : teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isExpired
                        ? rose.withOpacity(0.3)
                        : teal.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isExpired ? 'EXPIRED' : 'VALID',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isExpired ? roseSoft : teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: div),
          const SizedBox(height: 8),
          // Issuer (short)
          Row(
            children: [
              Icon(Icons.account_balance_rounded,
                  size: 12, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _shortIssuer(issuer),
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 12,
                    color: muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Validity range
          Row(
            children: [
              Icon(Icons.date_range_rounded,
                  size: 12, color: muted),
              const SizedBox(width: 6),
              Text(
                '$notBefore  →  $notAfter',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 12,
                  color: isExpired ? roseSoft.withOpacity(0.7) : teal.withOpacity(0.8),
                ),
              ),
            ],
          ),
          if (serial.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _copy(serial, 'Serial'),
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 12, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      serial,
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 11,
                        color: muted,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (timestamp.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 12, color: muted.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  'Logged: $timestamp',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 11,
                    color: muted.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _shortIssuer(String issuer) {
    // Extract CN value from "C=US, O=Let's Encrypt, CN=R12"
    final cnMatch = RegExp(r'CN=([^,]+)').firstMatch(issuer);
    final oMatch = RegExp(r'O=([^,]+)').firstMatch(issuer);
    if (cnMatch != null && oMatch != null) {
      return '${oMatch.group(1)} — ${cnMatch.group(1)}';
    }
    return issuer;
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  // ── Summary banner ────────────────────────────────────────
  Widget _buildSummaryBanner() {
    final subCount = _uniqueSubdomains.length;
    final certCount = (() {
      final Map<String, bool> seen = {};
      for (final c in _certRecords) {
        seen[c['serial_number']?.toString() ?? c['id'].toString()] = true;
      }
      return seen.length;
    })();
    final hasDns = _dnsData != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0810), Color(0xFF2C0E18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rose.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: rose.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rose.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rose.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: rose, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SCAN SELESAI',
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
              Icon(Icons.language_rounded,
                  size: 14, color: muted.withOpacity(0.6)),
              const SizedBox(width: 5),
              Text(
                _scannedDomain ?? '',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 13,
                  color: muted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statChip(
                  icon: Icons.language_rounded,
                  label: 'Subdomains',
                  value: subCount.toString(),
                  color: gold),
              const SizedBox(width: 10),
              _statChip(
                  icon: Icons.verified_rounded,
                  label: 'Sertifikat',
                  value: certCount.toString(),
                  color: teal),
              const SizedBox(width: 10),
              _statChip(
                  icon: Icons.dns_rounded,
                  label: 'DNS',
                  value: hasDns ? 'OK' : '-',
                  color: rose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 10,
                color: muted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasResult =
        _dnsData != null || _certRecords.isNotEmpty || _uniqueSubdomains.isNotEmpty;

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
                  color: ivory, size: 15),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, color: rose, size: 16),
            const SizedBox(width: 8),
            const Text(
              'DOMAIN OSINT',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                color: ivory,
                fontSize: 15,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          // Glow orbs
          Positioned(
            top: -100, left: -60,
            child: _glowOrb(300, rose, 0.06),
          ),
          Positioned(
            bottom: -80, right: -80,
            child: _glowOrb(220, roseDim, 0.04),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildInputCard()),
                ),

                if (_errorMessage != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(child: _buildError()),
                  ),

                if (hasResult)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideUp,
                          child: Column(
                            children: [
                              _buildSummaryBanner(),
                              _buildDnsSection(),
                              _buildSubdomainSection(),
                              _buildCertSection(),
                              const SizedBox(height: 28),
                            ],
                          ),
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

  Widget _glowOrb(double size, Color color, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ),
      ),
    );
  }
}

// ── Scan Painter ──────────────────────────────────────────────
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
      ).createShader(Rect.fromLTWH(0, y - 22, size.width, 44));
    canvas.drawRect(Rect.fromLTWH(0, y - 22, size.width, 44), paint);
  }

  @override
  bool shouldRepaint(_ScanPainter o) => o.progress != progress;
}

// ── Background Painter ────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8002D).withOpacity(0.022)
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
