// create_vps_page.dart — VPS Manager Pro (DigitalOcean)
// Features: Multi API Key Manager (SharedPreferences), VPS Dashboard,
//           Create VPS, Reboot/PowerOn/PowerOff/Delete/Snapshot/Rebuild

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'install_panel_page.dart';

// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════
const _bg        = Color(0xFF090B10);
const _surface   = Color(0xFF111318);
const _surface2  = Color(0xFF181B24);
const _surface3  = Color(0xFF1F2230);
const _accent    = Color(0xFF4F8EF7);
const _accentDim = Color(0xFF3B72E0);
const _success   = Color(0xFF34D399);
const _error     = Color(0xFFFC8181);
const _warning   = Color(0xFFFBBF24);
const _info      = Color(0xFF60A5FA);
const _text      = Color(0xFFE2E8F0);
const _textDim   = Color(0xFF8892A4);
const _textHint  = Color(0xFF4A5568);
const _border    = Color(0xFF1E2130);
const _borderHi  = Color(0xFF2A2E40);

// ═══════════════════════════════════════════════════════════════
//  MODEL: API KEY
// ═══════════════════════════════════════════════════════════════
class ApiKeyEntry {
  final String id;
  String label;
  String key;
  bool isActive;

  ApiKeyEntry({
    required this.id,
    required this.label,
    required this.key,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'key': key,
        'isActive': isActive,
      };

  factory ApiKeyEntry.fromJson(Map<String, dynamic> j) => ApiKeyEntry(
        id: j['id'] as String,
        label: j['label'] as String,
        key: j['key'] as String,
        isActive: j['isActive'] as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════
//  PREFS HELPER
// ═══════════════════════════════════════════════════════════════
class _Prefs {
  static const _kApiKeys    = 'vps_api_keys';
  static const _kVpsPassMap = 'vps_pass_map';

  // ─── API Keys ────────────────────────────────────────────────
  static Future<List<ApiKeyEntry>> loadApiKeys() async {
    final sp  = await SharedPreferences.getInstance();
    final raw = sp.getString(_kApiKeys);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => ApiKeyEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveApiKeys(List<ApiKeyEntry> keys) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kApiKeys, jsonEncode(keys.map((e) => e.toJson()).toList()));
  }

  // ─── VPS Passwords (keyed by droplet id) ────────────────────
  static Future<Map<String, String>> loadPassMap() async {
    final sp  = await SharedPreferences.getInstance();
    final raw = sp.getString(_kVpsPassMap);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, v as String));
  }

  static Future<void> savePass(int dropletId, String password) async {
    final sp   = await SharedPreferences.getInstance();
    final map  = await loadPassMap();
    map[dropletId.toString()] = password;
    await sp.setString(_kVpsPassMap, jsonEncode(map));
  }

  static Future<String?> getPass(int dropletId) async {
    final m = await loadPassMap();
    return m[dropletId.toString()];
  }
}

// ═══════════════════════════════════════════════════════════════
//  DO API HELPER
// ═══════════════════════════════════════════════════════════════
class _DoApi {
  final String apiKey;
  static const _base = 'https://api.digitalocean.com/v2';

  const _DoApi(this.apiKey);

  Map<String, String> get _h =>
      {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> get(String path) async {
    final r = await http.get(Uri.parse('$_base$path'), headers: _h);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$_base$path'),
        headers: _h, body: jsonEncode(body));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final r = await http.delete(Uri.parse('$_base$path'), headers: _h);
    if (r.body.isEmpty) return {'status': r.statusCode};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Droplets
  Future<List<dynamic>> listDroplets() async {
    final d = await get('/droplets?per_page=100');
    return (d['droplets'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> getDroplet(int id) async {
    final d = await get('/droplets/$id');
    return (d['droplet'] as Map<String, dynamic>?) ?? {};
  }

  // Actions
  Future<void> reboot(int id)    => post('/droplets/$id/actions', {'type': 'reboot'}).then((_) {});
  Future<void> powerOn(int id)   => post('/droplets/$id/actions', {'type': 'power_on'}).then((_) {});
  Future<void> powerOff(int id)  => post('/droplets/$id/actions', {'type': 'power_off'}).then((_) {});
  Future<void> shutdown(int id)  => post('/droplets/$id/actions', {'type': 'shutdown'}).then((_) {});
  Future<void> rebuild(int id, String image) =>
      post('/droplets/$id/actions', {'type': 'rebuild', 'image': image}).then((_) {});
  Future<void> resize(int id, String size) =>
      post('/droplets/$id/actions', {'type': 'resize', 'size': size, 'disk': true}).then((_) {});

  // Snapshot
  Future<void> createSnapshot(int id, String name) =>
      post('/droplets/$id/actions', {'type': 'snapshot', 'name': name}).then((_) {});

  // Backups
  Future<void> enableBackups(int id)  => post('/droplets/$id/actions', {'type': 'enable_backups'}).then((_) {});
  Future<void> disableBackups(int id) => post('/droplets/$id/actions', {'type': 'disable_backups'}).then((_) {});

  // Delete
  Future<void> deleteDroplet(int id) => delete('/droplets/$id').then((_) {});

  // Snapshots list
  Future<List<dynamic>> listSnapshots(int id) async {
    final d = await get('/droplets/$id/snapshots');
    return (d['snapshots'] as List?) ?? [];
  }

  // Account
  Future<Map<String, dynamic>> getAccount() => get('/account');

  Future<String?> getPublicIp(int id) async {
    final d = await getDroplet(id);
    final nets = (d['networks']?['v4'] as List?) ?? [];
    for (final n in nets) {
      if ((n as Map)['type'] == 'public') return n['ip_address'] as String?;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
//  MAIN PAGE — VPS MANAGER
// ═══════════════════════════════════════════════════════════════
class CreateVpsPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const CreateVpsPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<CreateVpsPage> createState() => _CreateVpsPageState();
}

class _CreateVpsPageState extends State<CreateVpsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<ApiKeyEntry> _apiKeys = [];
  ApiKeyEntry? get _activeKey =>
      _apiKeys.isEmpty ? null : _apiKeys.firstWhere((k) => k.isActive, orElse: () => _apiKeys.first);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadKeys();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    final keys = await _Prefs.loadApiKeys();
    setState(() => _apiKeys = keys);
  }

  Future<void> _saveKeys() async {
    await _Prefs.saveApiKeys(_apiKeys);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor:  _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: _textDim),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accentDim]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          const Text('VPS Manager',
              style: TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (_activeKey != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _activeKey!.label,
                style: const TextStyle(color: _success, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
        ]),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _accent,
          indicatorWeight: 2,
          labelColor: _accent,
          unselectedLabelColor: _textDim,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: 'Kelola VPS'),
            Tab(icon: Icon(Icons.add_circle_outline_rounded, size: 16), text: 'Buat VPS'),
            Tab(icon: Icon(Icons.vpn_key_rounded, size: 16), text: 'API Keys'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _VpsDashboard(
            apiKey: _activeKey?.key,
            onNeedKey: () => _tab.animateTo(2),
          ),
          _CreateVpsTab(
            apiKey: _activeKey?.key,
            onNeedKey: () => _tab.animateTo(2),
          ),
          _ApiKeyTab(
            apiKeys: _apiKeys,
            onChanged: (keys) {
              _apiKeys = keys;
              _saveKeys();
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1 — VPS DASHBOARD
// ═══════════════════════════════════════════════════════════════
class _VpsDashboard extends StatefulWidget {
  final String? apiKey;
  final VoidCallback onNeedKey;

  const _VpsDashboard({this.apiKey, required this.onNeedKey});

  @override
  State<_VpsDashboard> createState() => _VpsDashboardState();
}

class _VpsDashboardState extends State<_VpsDashboard> {
  List<dynamic>  _droplets   = [];
  bool           _loading    = false;
  String?        _fetchError;
  Map<String, String> _passMap = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(_VpsDashboard old) {
    super.didUpdateWidget(old);
    if (old.apiKey != widget.apiKey) _init();
  }

  Future<void> _init() async {
    _passMap = await _Prefs.loadPassMap();
    await _fetchDroplets();
  }

  Future<void> _fetchDroplets() async {
    if (widget.apiKey == null) return;
    setState(() { _loading = true; _fetchError = null; });
    try {
      final api = _DoApi(widget.apiKey!);
      final list = await api.listDroplets();
      setState(() { _droplets = list; _loading = false; });
    } catch (e) {
      setState(() { _fetchError = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiKey == null) {
      return _emptyState(
        Icons.vpn_key_outlined,
        'Belum Ada API Key',
        'Tambahkan API Key DigitalOcean\ndi tab "API Keys" terlebih dahulu',
        action: TextButton.icon(
          onPressed: widget.onNeedKey,
          icon: const Icon(Icons.add, size: 15, color: _accent),
          label: const Text('Tambah API Key', style: TextStyle(color: _accent, fontSize: 13)),
        ),
      );
    }

    return RefreshIndicator(
      color: _accent,
      backgroundColor: _surface2,
      onRefresh: _fetchDroplets,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header stats ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                _statChip(Icons.dns_rounded, _droplets.length.toString(), 'Total VPS', _accent),
                const SizedBox(width: 10),
                _statChip(
                  Icons.circle_rounded,
                  _droplets.where((d) => d['status'] == 'active').length.toString(),
                  'Aktif',
                  _success,
                ),
                const SizedBox(width: 10),
                _statChip(
                  Icons.power_settings_new_rounded,
                  _droplets.where((d) => d['status'] != 'active').length.toString(),
                  'Offline',
                  _warning,
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),

          // ── Error ────────────────────────────────────────────
          if (_fetchError != null)
            SliverToBoxAdapter(child: _errorBanner(_fetchError!)),

          // ── Loading ──────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
            )
          else if (_droplets.isEmpty && !_loading)
            SliverFillRemaining(
              child: _emptyState(
                Icons.cloud_off_rounded,
                'Tidak Ada VPS',
                'Belum ada droplet.\nBuat VPS baru di tab "Buat VPS".',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DropletCard(
                    droplet: _droplets[i] as Map<String, dynamic>,
                    password: _passMap[_droplets[i]['id'].toString()],
                    apiKey: widget.apiKey!,
                    onRefresh: _fetchDroplets,
                  ),
                  childCount: _droplets.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String val, String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: _textDim, fontSize: 10.5)),
            ]),
          ]),
        ),
      );

  Widget _errorBanner(String msg) {
    const errColor = Color(0xFFFC8181);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: errColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: errColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Color(0xFFFC8181), size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFFC8181), fontSize: 12))),
            IconButton(
              onPressed: _fetchDroplets,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFC8181), size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      );
  }

  Widget _emptyState(IconData icon, String title, String sub, {Widget? action}) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _textHint, size: 48),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: _textDim, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(color: _textHint, fontSize: 13), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), action],
      ]));
}

// ═══════════════════════════════════════════════════════════════
//  DROPLET CARD
// ═══════════════════════════════════════════════════════════════
class _DropletCard extends StatefulWidget {
  final Map<String, dynamic> droplet;
  final String?              password;
  final String               apiKey;
  final VoidCallback         onRefresh;

  const _DropletCard({
    required this.droplet,
    required this.password,
    required this.apiKey,
    required this.onRefresh,
  });

  @override
  State<_DropletCard> createState() => _DropletCardState();
}

class _DropletCardState extends State<_DropletCard> {
  bool _expanded   = false;
  bool _actionBusy = false;

  Map<String, dynamic> get d => widget.droplet;

  String get _ip {
    final nets = (d['networks']?['v4'] as List?) ?? [];
    for (final n in nets) {
      if ((n as Map)['type'] == 'public') return n['ip_address'] as String;
    }
    return '—';
  }

  String get _status  => d['status'] as String? ?? 'unknown';
  bool   get _isActive => _status == 'active';

  Color get _statusColor => switch (_status) {
        'active'  => _success,
        'off'     => _warning,
        'archive' => _textDim,
        _         => _info,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _isActive ? _border : _borderHi),
      ),
      child: Column(
        children: [
          // ── Main Row ──────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Status indicator
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: _isActive
                        ? [BoxShadow(color: _success.withOpacity(0.5), blurRadius: 4)]
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // VPS Icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accent.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.dns_rounded, color: _accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      d['name'] as String? ?? '-',
                      style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.lan_outlined, color: _textHint, size: 11),
                      const SizedBox(width: 4),
                      Text(_ip, style: const TextStyle(color: _textDim, fontSize: 12, fontFamily: 'monospace')),
                    ]),
                  ]),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _status.toUpperCase(),
                    style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _textHint, size: 18,
                ),
              ]),
            ),
          ),

          // ── Expanded Details ──────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, thickness: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info grid
                  _infoGrid(),
                  const SizedBox(height: 14),

                  // Password row
                  if (widget.password != null) ...[
                    _infoRow('Password', widget.password!, mono: true, copyable: true),
                    const SizedBox(height: 14),
                  ],

                  // Action buttons
                  if (_actionBusy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
                      ),
                    )
                  else
                    _buildActionButtons(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoGrid() {
    final region = (d['region'] as Map?)?['name'] as String? ?? '-';
    final os     = '${(d['image'] as Map?)?['distribution'] ?? ''} '
                   '${(d['image'] as Map?)?['name'] ?? ''}';
    final vcpu   = (d['vcpus'] as int?)?.toString() ?? '-';
    final ram    = (d['memory'] as int?);
    final disk   = (d['disk']   as int?);
    final price  = (d['size_slug'] as String?) ?? '-';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3.2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 8,
      children: [
        _gridCell(Icons.location_on_outlined, 'Region', region),
        _gridCell(Icons.memory_rounded, 'RAM', ram != null ? '${ram} MB' : '-'),
        _gridCell(Icons.computer_rounded, 'vCPU', '$vcpu Core'),
        _gridCell(Icons.storage_rounded, 'Disk', disk != null ? '$disk GB' : '-'),
        _gridCell(Icons.tag_rounded, 'ID', '#${d['id']}'),
        _gridCell(Icons.sell_outlined, 'Paket', price),
      ],
    );
  }

  Widget _gridCell(IconData icon, String label, String val) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Icon(icon, color: _textHint, size: 13),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _textHint, fontSize: 10)),
            Text(val, style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ]),
        ]),
      );

  Widget _infoRow(String label, String value, {bool mono = false, bool copyable = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outlined, color: _warning, size: 13),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _text, fontSize: 13,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _snack('Password disalin ✓');
              },
              child: const Icon(Icons.copy_all_rounded, size: 14, color: _textDim),
            ),
        ]),
      );

  Widget _buildActionButtons() {
    return Column(children: [
      // Row 1: Power actions
      Row(children: [
        _actionBtn(
          icon: Icons.refresh_rounded,
          label: 'Reboot',
          color: _info,
          onTap: () => _confirm('Reboot VPS ini?', () async {
            await _DoApi(widget.apiKey).reboot(d['id'] as int);
            _snack('Reboot dimulai ✓');
            widget.onRefresh();
          }),
        ),
        const SizedBox(width: 8),
        if (_isActive)
          _actionBtn(
            icon: Icons.power_settings_new_rounded,
            label: 'Matikan',
            color: _warning,
            onTap: () => _confirm('Matikan VPS ini?', () async {
              await _DoApi(widget.apiKey).shutdown(d['id'] as int);
              _snack('Shutdown dimulai ✓');
              widget.onRefresh();
            }),
          )
        else
          _actionBtn(
            icon: Icons.play_arrow_rounded,
            label: 'Nyalakan',
            color: _success,
            onTap: () => _confirm('Nyalakan VPS ini?', () async {
              await _DoApi(widget.apiKey).powerOn(d['id'] as int);
              _snack('Power On dimulai ✓');
              widget.onRefresh();
            }),
          ),
        const SizedBox(width: 8),
        _actionBtn(
          icon: Icons.camera_alt_outlined,
          label: 'Snapshot',
          color: _accent,
          onTap: () => _snapshotDialog(d['id'] as int, d['name'] as String? ?? 'vps'),
        ),
      ]),
      const SizedBox(height: 8),
      // Row 2: Advanced
      Row(children: [
        _actionBtn(
          icon: Icons.backup_rounded,
          label: 'Backup ON',
          color: _success,
          onTap: () => _confirm('Aktifkan otomatis backup?', () async {
            await _DoApi(widget.apiKey).enableBackups(d['id'] as int);
            _snack('Backup diaktifkan ✓');
          }),
        ),
        const SizedBox(width: 8),
        _actionBtn(
          icon: Icons.view_list_rounded,
          label: 'Snapshots',
          color: _textDim,
          onTap: () => _showSnapshots(d['id'] as int),
        ),
        const SizedBox(width: 8),
        _actionBtn(
          icon: Icons.terminal_rounded,
          label: 'Install Panel',
          color: _accent,
          onTap: () {
            final ip = _ip;
            if (ip == '—') { _snack('IP belum tersedia', err: true); return; }
            final pw = widget.password ?? '';
            Navigator.push(context, MaterialPageRoute(builder: (_) => InstallPanelPage(
              ipVps: ip, passwordVps: pw,
              domainPanel: '', domainNode: '',
            )));
          },
        ),
      ]),
      const SizedBox(height: 12),
      // Delete button — full width, destructive
      OutlinedButton.icon(
        onPressed: () => _confirm(
          '⚠️ Hapus VPS ini?\nSemua data akan hilang permanen!',
          () async {
            await _DoApi(widget.apiKey).deleteDroplet(d['id'] as int);
            _snack('VPS dihapus');
            widget.onRefresh();
          },
          destructive: true,
        ),
        icon: const Icon(Icons.delete_forever_rounded, size: 15, color: _error),
        label: const Text('Hapus VPS', style: TextStyle(color: _error, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40),
          side: BorderSide(color: _error.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      );

  Future<void> _confirm(String msg, Future<void> Function() action, {bool destructive = false}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Konfirmasi', style: TextStyle(color: _text, fontSize: 16)),
        content: Text(msg, style: const TextStyle(color: _textDim, fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: _textDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _actionBusy = true);
              try { await action(); } catch (e) { _snack(e.toString(), err: true); }
              setState(() => _actionBusy = false);
            },
            child: Text('Ya, Lanjutkan',
                style: TextStyle(color: destructive ? _error : _accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _snapshotDialog(int id, String name) async {
    final ctrl = TextEditingController(text: '$name-snap-${DateTime.now().millisecondsSinceEpoch}');
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Buat Snapshot', style: TextStyle(color: _text, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _text, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Nama Snapshot',
            labelStyle: const TextStyle(color: _textDim),
            filled: true,
            fillColor: _surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accent),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: _textDim))),
          TextButton(
            onPressed: () async {
              final snapName = ctrl.text.trim();
              Navigator.pop(ctx);
              if (snapName.isEmpty) return;
              setState(() => _actionBusy = true);
              try {
                await _DoApi(widget.apiKey).createSnapshot(id, snapName);
                _snack('Snapshot "$snapName" sedang dibuat ✓');
              } catch (e) { _snack(e.toString(), err: true); }
              setState(() => _actionBusy = false);
            },
            child: const Text('Buat', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSnapshots(int id) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<dynamic>>(
        future: _DoApi(widget.apiKey).listSnapshots(id),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              backgroundColor: _surface2,
              content: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
            );
          }
          final list = snap.data ?? [];
          return AlertDialog(
            backgroundColor: _surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(children: [
              const Icon(Icons.camera_alt_outlined, color: _accent, size: 16),
              const SizedBox(width: 8),
              const Text('Snapshots', style: TextStyle(color: _text, fontSize: 15)),
              const Spacer(),
              Text('${list.length} snap', style: const TextStyle(color: _textDim, fontSize: 12)),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              height: 280,
              child: list.isEmpty
                  ? const Center(child: Text('Belum ada snapshot',
                        style: TextStyle(color: _textDim, fontSize: 13)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i] as Map;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _surface3,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.save_outlined, color: _accent, size: 14),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['name'] as String? ?? '-',
                                  style: const TextStyle(color: _text, fontSize: 13)),
                              Text('${s['size_gigabytes'] ?? 0} GB · ${s['created_at'] ?? '-'}',
                                  style: const TextStyle(color: _textDim, fontSize: 11)),
                            ])),
                          ]),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup', style: TextStyle(color: _textDim))),
            ],
          );
        },
      ),
    );
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: err ? _error.withOpacity(0.9) : _surface2,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2 — CREATE VPS
// ═══════════════════════════════════════════════════════════════
class _CreateVpsTab extends StatefulWidget {
  final String? apiKey;
  final VoidCallback onNeedKey;

  const _CreateVpsTab({this.apiKey, required this.onNeedKey});

  @override
  State<_CreateVpsTab> createState() => _CreateVpsTabState();
}

class _CreateVpsTabState extends State<_CreateVpsTab> {
  final _formKey         = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController(text: 'vps-otax');
  final _domainPanelCtrl = TextEditingController();
  final _domainNodeCtrl  = TextEditingController();

  String? _selectedRegion;
  String? _selectedSize;
  String? _selectedImage;

  bool _isCreating    = false;
  Map<String, dynamic>? _createdVps;
  String? _errorMessage;
  String? _statusMessage;

  final List<Map<String, String>> _regions = [
    {'slug': 'sgp1', 'name': 'Singapore',     'flag': '🇸🇬'},
    {'slug': 'nyc1', 'name': 'New York',       'flag': '🇺🇸'},
    {'slug': 'sfo3', 'name': 'San Francisco',  'flag': '🇺🇸'},
    {'slug': 'lon1', 'name': 'London',         'flag': '🇬🇧'},
    {'slug': 'fra1', 'name': 'Frankfurt',      'flag': '🇩🇪'},
    {'slug': 'ams3', 'name': 'Amsterdam',      'flag': '🇳🇱'},
    {'slug': 'blr1', 'name': 'Bangalore',      'flag': '🇮🇳'},
    {'slug': 'tor1', 'name': 'Toronto',        'flag': '🇨🇦'},
    {'slug': 'syd1', 'name': 'Sydney',         'flag': '🇦🇺'},
  ];

  final List<Map<String, String>> _sizes = [
  {'slug': 's-1vcpu-512mb-10gb', 'name': '1 vCPU / 512 MB / 10 GB',   'price': '\$4/mo'},
  {'slug': 's-1vcpu-1gb',        'name': '1 vCPU / 1 GB / 25 GB',     'price': '\$6/mo'},
  {'slug': 's-1vcpu-1gb-amd',    'name': '1 vCPU AMD / 1 GB / 25 GB', 'price': '\$7/mo'},
  {'slug': 's-1vcpu-2gb',        'name': '1 vCPU / 2 GB / 50 GB',     'price': '\$12/mo'},
  {'slug': 's-2vcpu-2gb',        'name': '2 vCPU / 2 GB / 60 GB',     'price': '\$18/mo'},
  {'slug': 's-2vcpu-4gb',        'name': '2 vCPU / 4 GB / 80 GB',     'price': '\$24/mo'},
  {'slug': 's-4vcpu-8gb',        'name': '4 vCPU / 8 GB / 160 GB',    'price': '\$48/mo'},
  {'slug': 's-6vcpu-16gb',       'name': '6 vCPU / 16 GB / 320 GB',   'price': '\$96/mo'},
  {'slug': 's-8vcpu-32gb',       'name': '8 vCPU / 32 GB / 640 GB',   'price': '\$192/mo'},
  {'slug': 's-16vcpu-64gb',      'name': '16 vCPU / 64 GB / 1280 GB', 'price': '\$384/mo'},
  {'slug': 's-24vcpu-128gb',     'name': '24 vCPU / 128 GB / 2560 GB','price': '\$768/mo'},
  // Memory Optimized tambahan
  {'slug': 'm-4vcpu-16gb',       'name': '4 vCPU / 16 GB / 160 GB SSD','price': '\$120/mo'},
  {'slug': 'm-8vcpu-32gb',       'name': '8 vCPU / 32 GB / 320 GB SSD','price': '\$240/mo'},
];

  final List<Map<String, String>> _images = [
    {'slug': 'ubuntu-20-04-x64',    'name': 'Ubuntu 20.04 LTS'},
    {'slug': 'ubuntu-22-04-x64',    'name': 'Ubuntu 22.04 LTS'},
    {'slug': 'ubuntu-24-04-x64',    'name': 'Ubuntu 24.04 LTS'},
    {'slug': 'debian-11-x64',       'name': 'Debian 11'},
    {'slug': 'debian-12-x64',       'name': 'Debian 12'},
    {'slug': 'centos-stream-9-x64', 'name': 'CentOS Stream 9'},
  ];

  String _generatePassword() {
    final rng  = Random.secure();
    const pool = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final body = List.generate(12, (_) => pool[rng.nextInt(pool.length)]).join();
    return 'V${body}!';
  }

  Future<void> _createVps() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegion == null || _selectedSize == null || _selectedImage == null) {
      setState(() => _errorMessage = 'Harap lengkapi semua pilihan dropdown.');
      return;
    }
    if (widget.apiKey == null) { widget.onNeedKey(); return; }

    final password = _generatePassword();
    setState(() {
      _isCreating   = true;
      _errorMessage = null;
      _createdVps   = null;
      _statusMessage = 'Mengirim permintaan ke DigitalOcean…';
    });

    final name = _nameCtrl.text.trim().isEmpty ? 'vps-otax' : _nameCtrl.text.trim();
    final api  = _DoApi(widget.apiKey!);

    try {
      final res = await http.post(
        Uri.parse('https://api.digitalocean.com/v2/droplets'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${widget.apiKey}',
        },
        body: jsonEncode({
          'name':    name,
          'region':  _selectedRegion,
          'size':    _selectedSize,
          'image':   _selectedImage,
          'ssh_keys': <String>[],
          'backups': false,
          'ipv6':    true,
          'user_data': '#cloud-config\npassword: $password\nchpasswd:\n  expire: False\nssh_pwauth: True\n',
          'tags': ['otax-vps', 'flutter-created'],
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201 || res.statusCode == 202) {
        final id = body['droplet']['id'] as int;
        await _Prefs.savePass(id, password);
        setState(() => _statusMessage = 'Droplet dibuat (ID: $id). Menunggu IP…');
        await _pollForIp(api, id, body['droplet']['name'] as String, password);
      } else {
        throw Exception(body['message'] ?? 'Gagal membuat VPS (HTTP ${res.statusCode})');
      }
    } catch (e) {
      setState(() {
        _errorMessage  = e.toString().replaceFirst('Exception: ', '');
        _isCreating    = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _pollForIp(_DoApi api, int id, String name, String pw) async {
    for (int i = 0; i < 24; i++) {
      setState(() => _statusMessage = 'Menunggu IP… (${i + 1}/24)');
      await Future.delayed(const Duration(seconds: 5));
      try {
        final d    = await api.getDroplet(id);
        final nets = (d['networks']?['v4'] as List?) ?? [];
        for (final n in nets) {
          if ((n as Map)['type'] == 'public') {
            setState(() {
              _createdVps = {
                'id':       id,
                'name':     d['name'],
                'ip':       n['ip_address'],
                'password': pw,
                'region':   (d['region'] as Map?)?['name'] ?? '-',
                'os':       '${(d['image'] as Map?)?['distribution'] ?? ''} ${(d['image'] as Map?)?['name'] ?? ''}',
                'size':     d['size_slug'] ?? _selectedSize,
                'vcpu':     d['vcpus'],
                'ram':      d['memory'],
                'disk':     d['disk'],
              };
              _isCreating    = false;
              _statusMessage = null;
            });
            return;
          }
        }
      } catch (_) { /* keep polling */ }
    }
    setState(() {
      _createdVps    = {'id': id, 'name': name, 'ip': null, 'password': pw};
      _isCreating    = false;
      _statusMessage = null;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainPanelCtrl.dispose();
    _domainNodeCtrl.dispose();
    super.dispose();
  }

  InputDecoration _field(String hint, {String? label, IconData? icon}) => InputDecoration(
        labelText:   label,
        labelStyle:  const TextStyle(color: _textDim, fontSize: 13),
        hintText:    hint,
        hintStyle:   const TextStyle(color: _textHint, fontSize: 13),
        prefixIcon:  icon != null ? Icon(icon, color: _textHint, size: 17) : null,
        filled:      true,
        fillColor:   _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _error)),
        errorStyle: const TextStyle(color: _error, fontSize: 11),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.apiKey == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.vpn_key_outlined, color: _textHint, size: 48),
        const SizedBox(height: 12),
        const Text('Tambahkan API Key dulu', style: TextStyle(color: _textDim, fontSize: 15)),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: widget.onNeedKey,
          icon: const Icon(Icons.add, size: 15, color: _accent),
          label: const Text('Tambah API Key', style: TextStyle(color: _accent)),
        ),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        _accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: _accent.withOpacity(0.18)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _accent, size: 15),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Buat Droplet DigitalOcean. Password akan otomatis tersimpan.',
                style: TextStyle(color: _accent.withOpacity(0.85), fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 22),

          // Name
          _sectionLabel('Konfigurasi VPS', Icons.tune_rounded),
          const SizedBox(height: 12),
          _fieldLabel('Nama Droplet'),
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(color: _text, fontSize: 14),
            decoration: _field('vps-otax', icon: Icons.dns_outlined),
          ),
          const SizedBox(height: 13),

          // Region
          _fieldLabel('Region Server'),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            dropdownColor: _surface2,
            style: const TextStyle(color: _text, fontSize: 13),
            icon: const Icon(Icons.expand_more_rounded, color: _textDim, size: 20),
            hint: const Text('Pilih region', style: TextStyle(color: _textHint, fontSize: 13)),
            items: _regions.map((r) => DropdownMenuItem(
              value: r['slug'],
              child: Row(children: [
                Text(r['flag']!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 10),
                Text('${r['name']!}  ·  ${r['slug']!}', style: const TextStyle(color: _text)),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => _selectedRegion = v),
            decoration: _field('').copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), hintText: null),
            validator: (v) => v == null ? 'Pilih region' : null,
          ),
          const SizedBox(height: 13),

          // Size
          _fieldLabel('Paket VPS'),
          DropdownButtonFormField<String>(
            value: _selectedSize,
            isExpanded: true,
            dropdownColor: _surface2,
            style: const TextStyle(color: _text, fontSize: 13),
            icon: const Icon(Icons.expand_more_rounded, color: _textDim, size: 20),
            hint: const Text('Pilih paket', style: TextStyle(color: _textHint, fontSize: 13)),
            items: _sizes.map((s) => DropdownMenuItem(
              value: s['slug'],
              child: Row(children: [
                Expanded(child: Text(s['name']!, style: const TextStyle(color: _text))),
                Text(s['price']!, style: const TextStyle(color: _textDim, fontSize: 12)),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => _selectedSize = v),
            decoration: _field('').copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), hintText: null),
            validator: (v) => v == null ? 'Pilih paket' : null,
          ),
          const SizedBox(height: 13),

          // Image
          _fieldLabel('Sistem Operasi'),
          DropdownButtonFormField<String>(
            value: _selectedImage,
            dropdownColor: _surface2,
            style: const TextStyle(color: _text, fontSize: 13),
            icon: const Icon(Icons.expand_more_rounded, color: _textDim, size: 20),
            hint: const Text('Pilih OS', style: TextStyle(color: _textHint, fontSize: 13)),
            items: _images.map((i) => DropdownMenuItem(
              value: i['slug'],
              child: Text(i['name']!, style: const TextStyle(color: _text)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedImage = v),
            decoration: _field('').copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), hintText: null),
            validator: (v) => v == null ? 'Pilih OS' : null,
          ),
          const SizedBox(height: 22),

          // Domain
          _sectionLabel('Domain (Opsional)', Icons.language_rounded),
          const SizedBox(height: 12),
          _fieldLabel('Domain Panel'),
          TextFormField(
            controller: _domainPanelCtrl,
            style: const TextStyle(color: _text, fontSize: 14),
            keyboardType: TextInputType.url,
            decoration: _field('panel.contoh.com', icon: Icons.web_outlined),
          ),
          const SizedBox(height: 13),
          _fieldLabel('Domain Node'),
          TextFormField(
            controller: _domainNodeCtrl,
            style: const TextStyle(color: _text, fontSize: 14),
            keyboardType: TextInputType.url,
            decoration: _field('node.contoh.com', icon: Icons.storage_outlined),
          ),
          const SizedBox(height: 26),

          // Action button / loading
          if (_isCreating)
            _buildLoadingCard()
          else
            ElevatedButton.icon(
              onPressed: _createVps,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Buat VPS Sekarang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),

          // Error
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        _error.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: _error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: _error, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _error, fontSize: 13))),
              ]),
            ),

          // Result
          if (_createdVps != null) _buildResultCard(),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) => Row(children: [
        Icon(icon, color: _accent, size: 14),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
            color: _accent, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _border)),
      ]);

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(color: _textDim, fontSize: 12.5, fontWeight: FontWeight.w500)),
      );

  Widget _buildLoadingCard() => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(color: _surface,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
        child: Column(children: [
          const SizedBox(width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _accent)),
          const SizedBox(height: 14),
          Text(_statusMessage ?? 'Memproses…',
              style: const TextStyle(color: _textDim, fontSize: 13), textAlign: TextAlign.center),
        ]),
      );

  Widget _buildResultCard() {
    final d     = _createdVps!;
    final ip    = d['ip'] as String?;
    final hasIp = ip != null;
    final color = hasIp ? _success : _warning;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          color: color.withOpacity(0.07),
          child: Row(children: [
            Icon(hasIp ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                color: color, size: 17),
            const SizedBox(width: 9),
            Text(hasIp ? '✅ VPS Berhasil Dibuat!' : '⏳ VPS Dibuat — Tunggu IP',
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(children: [
            _infoRow2('ID',       '#${d['id']}'),
            _infoRow2('Nama',     d['name'] ?? '-'),
            _infoRow2('IP',       ip ?? '— belum tersedia', hilight: hasIp, copy: ip),
            _infoRow2('Password', d['password'] ?? '-', copy: d['password'], mono: true),
            if (d['region'] != null) _infoRow2('Region', d['region']!),
            if (d['os'] != null) _infoRow2('OS', d['os']!),
            if (d['vcpu'] != null)
              _infoRow2('Spec',
                  '${d['vcpu']} vCPU · ${d['ram']} MB RAM · ${d['disk']} GB Disk'),
          ]),
        ),
        if (hasIp) ...[
          const Divider(height: 1, thickness: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: ElevatedButton.icon(
              onPressed: () {
                final panel = _domainPanelCtrl.text.trim();
                final node  = _domainNodeCtrl.text.trim();
                if (panel.isEmpty || node.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Isi Domain Panel & Node terlebih dahulu'),
                    backgroundColor: _error,
                  ));
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => InstallPanelPage(
                  ipVps: ip, passwordVps: d['password'],
                  domainPanel: panel, domainNode: node,
                )));
              },
              icon:  const Icon(Icons.terminal_rounded, size: 17),
              label: const Text('Install Panel Pterodactyl',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow2(String label, String val,
      {bool hilight = false, String? copy, bool mono = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: _textHint, fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(val, style: TextStyle(
            color: hilight ? _accent : _text,
            fontSize: 13,
            fontWeight: hilight ? FontWeight.w600 : FontWeight.normal,
            fontFamily: (mono || hilight) ? 'monospace' : null,
          ))),
          if (copy != null)
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: copy)),
              child: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(Icons.copy_all_rounded, size: 14, color: _textDim),
              ),
            ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3 — API KEY MANAGER
// ═══════════════════════════════════════════════════════════════
class _ApiKeyTab extends StatefulWidget {
  final List<ApiKeyEntry> apiKeys;
  final void Function(List<ApiKeyEntry>) onChanged;

  const _ApiKeyTab({required this.apiKeys, required this.onChanged});

  @override
  State<_ApiKeyTab> createState() => _ApiKeyTabState();
}

class _ApiKeyTabState extends State<_ApiKeyTab> {
  final _labelCtrl = TextEditingController();
  final _keyCtrl   = TextEditingController();
  bool  _keyVisible = false;
  bool  _validating = false;
  String? _validateError;

  Future<void> _validateAndAdd() async {
    final label = _labelCtrl.text.trim();
    final key   = _keyCtrl.text.trim();
    if (label.isEmpty || key.isEmpty) {
      setState(() => _validateError = 'Label dan API Key wajib diisi.');
      return;
    }
    setState(() { _validating = true; _validateError = null; });

    try {
      final api  = _DoApi(key);
      final data = await api.getAccount();
      if (data['account'] == null) throw Exception('API Key tidak valid');

      final entry = ApiKeyEntry(
        id:       DateTime.now().millisecondsSinceEpoch.toString(),
        label:    label,
        key:      key,
        isActive: widget.apiKeys.isEmpty, // first added = active
      );
      final updated = [...widget.apiKeys, entry];
      widget.onChanged(updated);
      _labelCtrl.clear();
      _keyCtrl.clear();
      setState(() { _validating = false; _validateError = null; });
      _snack('API Key "${entry.label}" berhasil ditambahkan ✓');
    } catch (e) {
      setState(() {
        _validating   = false;
        _validateError = 'API Key tidak valid atau tidak bisa terhubung.';
      });
    }
  }

  void _setActive(ApiKeyEntry entry) {
    final updated = widget.apiKeys.map((k) {
      return ApiKeyEntry(id: k.id, label: k.label, key: k.key,
          isActive: k.id == entry.id);
    }).toList();
    widget.onChanged(updated);
    _snack('"${entry.label}" diaktifkan sebagai key utama ✓');
  }

  void _delete(ApiKeyEntry entry) {
    final updated = widget.apiKeys.where((k) => k.id != entry.id).toList();
    if (updated.isNotEmpty && !updated.any((k) => k.isActive)) {
      updated.first.isActive = true;
    }
    widget.onChanged(updated);
    _snack('"${entry.label}" dihapus');
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Add new key ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.add_circle_outline_rounded, color: _accent, size: 16),
              const SizedBox(width: 8),
              const Text('Tambah API Key Baru',
                  style: TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),

            // Label
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: _text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nama / Label (cth: DO-Account-1)',
                hintStyle: const TextStyle(color: _textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.label_outline_rounded, color: _textHint, size: 17),
                filled: true, fillColor: _surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 10),

            // API Key
            TextField(
              controller: _keyCtrl,
              obscureText: !_keyVisible,
              style: const TextStyle(color: _text, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'dop_v1_xxxxxxxxxxxxxxxxxxxx',
                hintStyle: const TextStyle(color: _textHint, fontSize: 12),
                prefixIcon: const Icon(Icons.vpn_key_rounded, color: _textHint, size: 17),
                suffixIcon: IconButton(
                  icon: Icon(_keyVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _textHint, size: 17),
                  onPressed: () => setState(() => _keyVisible = !_keyVisible),
                ),
                filled: true, fillColor: _surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
              ),
            ),

            if (_validateError != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.error_outline, color: _error, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(_validateError!,
                    style: const TextStyle(color: _error, fontSize: 12))),
              ]),
            ],

            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _validating ? null : _validateAndAdd,
              icon: _validating
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_rounded, size: 16),
              label: Text(_validating ? 'Memvalidasi…' : 'Validasi & Simpan',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),

        // ── Key list ──────────────────────────────────────────
        if (widget.apiKeys.isNotEmpty) ...[
          Row(children: [
            const Text('API Keys Tersimpan',
                style: TextStyle(color: _textDim, fontSize: 12.5, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${widget.apiKeys.length}',
                  style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          ...widget.apiKeys.map((k) => _buildKeyCard(k)),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.vpn_key_off_outlined, color: _textHint, size: 40),
                const SizedBox(height: 10),
                const Text('Belum ada API Key',
                    style: TextStyle(color: _textDim, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Tambahkan API Key DigitalOcean di atas.',
                    style: TextStyle(color: _textHint, fontSize: 12)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildKeyCard(ApiKeyEntry k) {
    final masked = k.key.length > 12
        ? '${k.key.substring(0, 8)}••••••${k.key.substring(k.key.length - 4)}'
        : '••••••••';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: k.isActive ? _accent.withOpacity(0.05) : _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: k.isActive ? _accent.withOpacity(0.35) : _border, width: k.isActive ? 1.5 : 1),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: k.isActive ? _accent.withOpacity(0.12) : _surface2,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            k.isActive ? Icons.key_rounded : Icons.vpn_key_outlined,
            color: k.isActive ? _accent : _textDim,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(k.label,
                  style: TextStyle(
                    color: k.isActive ? _accent : _text,
                    fontSize: 14, fontWeight: FontWeight.w600,
                  )),
              if (k.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('AKTIF',
                      style: TextStyle(color: _success, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(masked,
                style: const TextStyle(color: _textDim, fontSize: 12, fontFamily: 'monospace')),
          ]),
        ),
        // Actions
        if (!k.isActive)
          GestureDetector(
            onTap: () => _setActive(k),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _accent.withOpacity(0.25)),
              ),
              child: const Text('Pakai', style: TextStyle(color: _accent, fontSize: 12,
                  fontWeight: FontWeight.w600)),
            ),
          ),
        GestureDetector(
          onTap: () => _confirmDelete(k),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _error.withOpacity(0.07),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: _error, size: 16),
          ),
        ),
      ]),
    );
  }

  void _confirmDelete(ApiKeyEntry k) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus API Key', style: TextStyle(color: _text, fontSize: 15)),
        content: Text('Hapus "${k.label}"?\nAksi ini tidak bisa dibatalkan.',
            style: const TextStyle(color: _textDim, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: _textDim))),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _delete(k); },
            child: const Text('Hapus', style: TextStyle(color: _error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: _surface2,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }
}
