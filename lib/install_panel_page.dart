import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg       = Color(0xFF0C0E13);
const _surface  = Color(0xFF14161D);
const _surface2 = Color(0xFF1B1D26);
const _accent   = Color(0xFF4F8EF7);
const _success  = Color(0xFF4ADE80);
const _error    = Color(0xFFFC8181);
const _warning  = Color(0xFFFBBF24);
const _text     = Color(0xFFE2E8F0);
const _textDim  = Color(0xFF8892A4);
const _textHint = Color(0xFF4A5568);
const _border   = Color(0xFF232530);
const _purple   = Color(0xFFA78BFA);

const _colNormal  = Color(0xFFCDD6F4);
const _colSuccess = Color(0xFF4ADE80);
const _colError   = Color(0xFFFC8181);
const _colInfo    = Color(0xFF89B4FA);
const _colInput   = Color(0xFFF9E2AF);
const _colSystem  = Color(0xFF6C7086);

enum _Mode  { panel, wings }
enum _LT    { normal, success, error, info, input, system }

enum _Stage {
  initial,
  mainMenu,
  panelExisting,
  dbName,
  dbUser,
  dbPass,
  timezone,
  emailLet,
  adminEmail,
  adminUsername,
  adminFirstName,
  adminLastName,
  adminPassword,
  panelFqdn,
  panelUfw,
  panelHttps,
  agreeCheckip,
  dnsFail,
  panelConfirm,
  panelInstalling,
  telemetry,
  certbotFail,
  wingsExisting,
  wingsUfw,
  wingsDbHost,
  wingsDbExternal,
  wingsPanelAddr,
  wingsDbFirewall,
  wingsDbUser,
  wingsDbPass,
  wingsHttps,
  wingsFqdn,
  wingsConfirm,
  wingsInstalling,
  done,
}

class _LogEntry {
  final String   message;
  final _LT      type;
  final DateTime time;
  const _LogEntry({required this.message, required this.type, required this.time});
}

class InstallPanelPage extends StatefulWidget {
  final String? ipVps;
  final String? passwordVps;
  final String? domainPanel;
  final String? domainNode;
  final String? adminEmail;
  final String? adminUsername;
  final String? adminPassword;

  const InstallPanelPage({
    super.key,
    this.ipVps,
    this.passwordVps,
    this.domainPanel,
    this.domainNode,
    this.adminEmail,
    this.adminUsername,
    this.adminPassword,
  });

  @override
  State<InstallPanelPage> createState() => _InstallPanelPageState();
}

class _InstallPanelPageState extends State<InstallPanelPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _ipCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _panelCtrl;
  late final TextEditingController _nodeCtrl;
  late final TextEditingController _adminEmailCtrl;
  late final TextEditingController _adminUsernameCtrl;
  late final TextEditingController _adminPasswordCtrl;

  bool  _passVisible      = false;
  bool  _adminPassVisible = false;
  bool  _formReady        = false;
  _Mode _mode             = _Mode.panel;

  final List<_LogEntry> _logs = [];
  bool _isConnecting = false;
  bool _isInstalling = false;
  bool _isFinished   = false;
  bool _hasError     = false;
  final ScrollController _scroll = ScrollController();

  SSHClient?  _client;
  SSHSession? _shell;
  Timer?      _keepalive;

  _Stage _stage        = _Stage.initial;
  String _outBuf       = '';
  final  List<String> _queue = [];
  bool   _queueBusy    = false;

  // Watchdog: detect stuck stage
  Timer?   _watchdog;
  DateTime _lastActivity = DateTime.now();
  _Stage   _lastWatchStage = _Stage.initial;

  String get _ip         => _ipCtrl.text.trim();
  String get _pass       => _passCtrl.text.trim();
  String get _panel      => _panelCtrl.text.trim();
  String get _node       => _nodeCtrl.text.trim();
  String get _email      => _adminEmailCtrl.text.trim();
  String get _adminUser  => _adminUsernameCtrl.text.trim();
  String get _adminPass  => _adminPasswordCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _ipCtrl            = TextEditingController(text: widget.ipVps          ?? '');
    _passCtrl          = TextEditingController(text: widget.passwordVps    ?? '');
    _panelCtrl         = TextEditingController(text: widget.domainPanel    ?? '');
    _nodeCtrl          = TextEditingController(text: widget.domainNode     ?? '');
    _adminEmailCtrl    = TextEditingController(text: widget.adminEmail     ?? '');
    _adminUsernameCtrl = TextEditingController(text: widget.adminUsername  ?? '');
    _adminPasswordCtrl = TextEditingController(text: widget.adminPassword  ?? '');

    _formReady = widget.ipVps != null &&
                 widget.passwordVps != null &&
                 widget.domainPanel != null &&
                 widget.adminEmail  != null &&
                 widget.adminUsername != null &&
                 widget.adminPassword != null;
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _keepalive?.cancel();
    try { _shell?.close(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    _scroll.dispose();
    for (final c in [_ipCtrl, _passCtrl, _panelCtrl, _nodeCtrl,
                     _adminEmailCtrl, _adminUsernameCtrl, _adminPasswordCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _log(String msg, {_LT type = _LT.normal}) {
    if (!mounted) return;
    setState(() => _logs.add(_LogEntry(message: msg, type: type, time: DateTime.now())));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  static String _stripAnsi(String raw) => raw
      .replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKHFABCDJMPX]'), '')
      .replaceAll(RegExp(r'\x1B\[\?[0-9;]*[hl]'), '')
      .replaceAll(RegExp(r'\x1B[()][A-Z0]'), '')
      .replaceAll(RegExp(r'\x1B\][^\x07]*\x07'), '')
      .replaceAll('\r', '');

  void _onShellOutput(String raw) {
    if (raw.isEmpty) return;
    _lastActivity = DateTime.now();
    _outBuf += _stripAnsi(raw);
    final lines = _outBuf.split('\n');
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      _logLine(line);
      _processLine(line);
    }
    _outBuf = lines.last;
    // Only treat partial buffer as a prompt if it looks like one
    // (ends with : ? ] or typical prompt chars, not mid-sentence output)
    if (_outBuf.isNotEmpty) {
      final partial = _outBuf.trim();
      final lp = partial.toLowerCase();
      final looksLikePrompt =
          partial.endsWith(':') || partial.endsWith('?') ||
          partial.endsWith(']') || partial.endsWith('):') ||
          lp.endsWith('(y/n)') || lp.endsWith('[yes]') ||
          lp.endsWith('[no]') || lp.endsWith('[yes]:') ||
          lp.endsWith('[no]:') || lp.contains('input 0-') ||
          lp.contains('[y/n]') || lp.contains('(y/n)');
      if (looksLikePrompt) {
        _processLine(partial);
      }
    }
  }

  void _logLine(String line) {
    final l = line.toLowerCase();
    _LT type = _LT.normal;
    if (l.contains('success') || l.contains('✓') || l.contains('complete') ||
        (l.contains('installed') && !l.contains('already'))) {
      type = _LT.success;
    } else if (l.contains('error') || l.contains('failed') || l.contains('✗')) {
      final benign = l.contains('dpkg') || l.contains('apt') || l.contains('certbot') ||
          l.contains('letsencrypt') || l.contains('le-sa') || l.contains('acme') ||
          l.contains('debug') || l.contains('wings installation') || _isFinished;
      type = benign ? _LT.normal : _LT.error;
    } else if (line.startsWith('*') || l.contains('installing') || l.contains('downloading') ||
               l.contains('configuring') || l.contains('setting up')) {
      type = _LT.info;
    }
    _log(line, type: type);
  }

  void _processLine(String line) {
    final l = line.toLowerCase().trim();

    void send(String r, _Stage next) {
      _stage = next;
      _lastActivity = DateTime.now();
      _queue.add(r);
      _processQueue();
    }

    void sendKeep(String r) {
      _lastActivity = DateTime.now();
      _queue.add(r);
      _processQueue();
    }

    // ── Global ToS / newsletter handlers ─────────────────────────────────
    if (l.contains('terms of service') && l.contains('agree') ||
        l.contains('le-sa.org') || l.contains('letsencrypt.org/documents') ||
        (l.contains('do you agree') && (l.contains('terms') || l.contains('register')))) {
      sendKeep('Y\n');
      _log('▶  Y (certbot ToS)', type: _LT.input);
      return;
    }

    if (l.contains('electronic frontier foundation') ||
        (l.contains('share your email') && l.contains('eff'))) {
      sendKeep('N\n');
      _log('▶  N (EFF newsletter)', type: _LT.input);
      return;
    }

    switch (_stage) {

      // ── INITIAL ──────────────────────────────────────────────────────────
      case _Stage.initial:
        if (l.contains('pterodactyl') ||
            l.contains('what would you like to do') ||
            l.contains('input 0-')) {
          _stage = _Stage.mainMenu;
          if (l.contains('input 0-')) {
            // Prompt already here — respond now
            if (_mode == _Mode.panel) {
              send('0\n', _Stage.panelExisting);
            } else {
              send('1\n', _Stage.wingsExisting);
            }
          }
        }
        break;

      // ── MAIN MENU ────────────────────────────────────────────────────────
      case _Stage.mainMenu:
        if (l.contains('input 0-') || l.contains('enter your choice') ||
            l.contains('select an option') || (l.endsWith(':') && l.contains('0'))) {
          if (_mode == _Mode.panel) {
            send('0\n', _Stage.panelExisting);
          } else {
            send('1\n', _Stage.wingsExisting);
          }
        }
        break;

      // ── PANEL: Existing install check ────────────────────────────────────
      case _Stage.panelExisting:
        if (l.contains('are you sure') || l.contains('want to proceed')) {
          send('y\n', _Stage.dbName);
        } else if (l.contains('database name') || l.contains('database configuration') ||
                   l.contains('latest pterodactyl/panel')) {
          _stage = _Stage.dbName;
          _processLine(line);
        }
        break;

      // ── DB NAME ───────────────────────────────────────────────────────────
      case _Stage.dbName:
        if (l.contains('database name') || l.contains('db name')) {
          send('\n', _Stage.dbUser);
        }
        break;

      // ── DB USER ───────────────────────────────────────────────────────────
      case _Stage.dbUser:
        if (l.contains('database username') || l.contains('db user') ||
            l.contains('database user')) {
          send('\n', _Stage.dbPass);
        }
        break;

      // ── DB PASS ───────────────────────────────────────────────────────────
      // Actual prompt: "Password [press enter for auto-generated]:"
      case _Stage.dbPass:
        if (l.contains('password') &&
            (l.contains('press enter') || l.contains('auto-generated') ||
             l.contains('auto generated') || l.contains('randomly') ||
             l.contains('blank') || l.contains('database password'))) {
          send('pterodactyl123\n', _Stage.timezone);
        }
        break;

      // ── TIMEZONE ─────────────────────────────────────────────────────────
      case _Stage.timezone:
        if (l.contains('timezone') || l.contains('time zone')) {
          send('Asia/Jakarta\n', _Stage.emailLet);
        }
        break;

      // ── LET'S ENCRYPT EMAIL ──────────────────────────────────────────────
      // Actual prompt: "Email address for Let's Encrypt [...]:"
      case _Stage.emailLet:
        if ((l.contains("let's encrypt") || l.contains('letsencrypt') ||
             l.contains('certbot')) &&
            (l.contains('email') || l.contains('address'))) {
          send('$_email\n', _Stage.adminEmail);
        } else if (l.contains('provide the email') || l.contains('enter email')) {
          send('$_email\n', _Stage.adminEmail);
        }
        break;

      // ── ADMIN EMAIL ───────────────────────────────────────────────────────
      case _Stage.adminEmail:
        if (l.contains('email address') && l.contains('admin') ||
            l.contains('email address for the initial')) {
          send('$_email\n', _Stage.adminUsername);
        }
        break;

      // ── ADMIN USERNAME ────────────────────────────────────────────────────
      case _Stage.adminUsername:
        if (l.contains('username') && (l.contains('admin') || l.contains('initial'))) {
          send('$_adminUser\n', _Stage.adminFirstName);
        }
        break;

      // ── ADMIN FIRST NAME ─────────────────────────────────────────────────
      case _Stage.adminFirstName:
        if (l.contains('first name')) {
          send('$_adminUser\n', _Stage.adminLastName);
        }
        break;

      // ── ADMIN LAST NAME ───────────────────────────────────────────────────
      case _Stage.adminLastName:
        if (l.contains('last name')) {
          send('User\n', _Stage.adminPassword);
        }
        break;

      // ── ADMIN PASSWORD ────────────────────────────────────────────────────
      case _Stage.adminPassword:
        if (l.contains('password') && (l.contains('admin') || l.contains('initial'))) {
          send('$_adminPass\n', _Stage.panelFqdn);
        }
        break;

      // ── PANEL FQDN ────────────────────────────────────────────────────────
      // Actual: "Set the FQDN (e.g. panel.example.com):"
      case _Stage.panelFqdn:
        if (l.contains('fqdn') || (l.contains('domain') && l.contains('panel'))) {
          send('$_panel\n', _Stage.panelUfw);
        }
        break;

      // ── PANEL UFW ─────────────────────────────────────────────────────────
      case _Stage.panelUfw:
        if ((l.contains('ufw') || l.contains('firewall')) &&
            (l.contains('configure') || l.contains('setup') || l.endsWith(':') || l.endsWith('?'))) {
          send('y\n', _Stage.panelHttps);
        }
        break;

      // ── PANEL HTTPS ───────────────────────────────────────────────────────
      case _Stage.panelHttps:
        if ((l.contains("let's encrypt") || l.contains('https') || l.contains('ssl')) &&
            (l.contains('configure') || l.contains('setup') || l.contains('enable'))) {
          send('y\n', _Stage.agreeCheckip);
        }
        break;

      // ── AGREE / CHECK IP ─────────────────────────────────────────────────
      // Actual: "I agree that this HTTPS request is performed..." or DNS check
      case _Stage.agreeCheckip:
        if (l.contains('i agree') || l.contains('agree that') ||
            l.contains('check your ip') || l.contains('confirm dns') ||
            l.contains('https request')) {
          send('y\n', _Stage.dnsFail);
        } else if (l.contains('dns verified') || l.contains('resolving dns') ||
                   l.contains('####')) {
          _stage = _Stage.panelConfirm;
        }
        break;

      // ── DNS FAIL ─────────────────────────────────────────────────────────
      case _Stage.dnsFail:
        if (l.contains('proceed anyways') || l.contains('proceed anyway') ||
            l.contains('continue anyway')) {
          send('y\n', _Stage.panelConfirm);
        } else if (l.contains('dns verified') || l.contains('####') ||
                   l.contains('continue with installation') ||
                   l.contains('do you want to continue')) {
          _stage = _Stage.panelConfirm;
          _processLine(line);
        }
        break;

      // ── PANEL CONFIRM ─────────────────────────────────────────────────────
      // Actual: "Do you want to continue? (y/N):" or "Do you wish to continue?"
      // NOT "initial configuration completed AND continue with installation" on same line
      case _Stage.panelConfirm:
        if (l.contains('continue with installation') ||
            l.contains('do you want to continue') ||
            l.contains('do you wish to continue') ||
            l.contains('proceed with installation') ||
            (l.contains('continue') && _isYesNo(l))) {
          _queue.clear();
          send('y\n', _Stage.panelInstalling);
        }
        break;

      // ── PANEL INSTALLING ─────────────────────────────────────────────────
      case _Stage.panelInstalling:
        if (l.contains('telemetry') || l.contains('anonymous telemetry') ||
            l.endsWith('(yes/no) [yes]:') || l.endsWith('[yes]:')) {
          send('yes\n', _Stage.telemetry);
        } else if (l.contains('still assume ssl') || l.contains('assume ssl')) {
          send('n\n', _Stage.certbotFail);
        } else if (_isYesNo(l) && !l.contains('telemetry')) {
          sendKeep('y\n');
        } else if (l.contains('thank you for using this script') ||
                   l.contains('panel installation completed') ||
                   l.contains('installation of panel completed') ||
                   l.contains('pterodactyl panel installed')) {
          _onPanelDone();
        }
        break;

      // ── TELEMETRY ─────────────────────────────────────────────────────────
      case _Stage.telemetry:
        if (l.contains('telemetry') || l.contains('anonymous') ||
            l.endsWith('(yes/no) [yes]:') || l.endsWith('[yes]:')) {
          send('yes\n', _Stage.panelInstalling);
        } else if (l.contains('still assume ssl') || l.contains('assume ssl')) {
          _stage = _Stage.certbotFail;
          _processLine(line);
        } else if (l.contains('thank you for using this script') ||
                   l.contains('panel installation completed') ||
                   l.contains('installation of panel completed')) {
          _onPanelDone();
        }
        break;

      // ── CERTBOT FAIL ─────────────────────────────────────────────────────
      case _Stage.certbotFail:
        if (l.contains('still assume ssl') || l.contains('assume ssl') ||
            _isYesNo(l)) {
          send('n\n', _Stage.panelInstalling);
        }
        break;

      // ── WINGS: Existing check ─────────────────────────────────────────────
      case _Stage.wingsExisting:
        if (l.contains('are you sure') || l.contains('want to proceed')) {
          send('y\n', _Stage.wingsUfw);
        } else if ((l.contains('configure ufw') || l.contains('firewall')) ||
                   l.contains('latest pterodactyl/wings') ||
                   l.contains('the installer will install docker')) {
          _stage = _Stage.wingsUfw;
          _processLine(line);
        }
        break;

      // ── WINGS UFW ─────────────────────────────────────────────────────────
      case _Stage.wingsUfw:
        if ((l.contains('ufw') || l.contains('firewall')) &&
            (l.contains('configure') || l.contains('setup') || l.endsWith(':') || l.endsWith('?'))) {
          send('y\n', _Stage.wingsDbHost);
        }
        break;

      // ── WINGS DB HOST ─────────────────────────────────────────────────────
      case _Stage.wingsDbHost:
        if (l.contains('database host') || l.contains('user for database host')) {
          send('y\n', _Stage.wingsDbExternal);
        }
        break;

      // ── WINGS DB EXTERNAL ─────────────────────────────────────────────────
      case _Stage.wingsDbExternal:
        if (l.contains('externally') || l.contains('external') ||
            l.contains('accessible from outside')) {
          send('y\n', _Stage.wingsPanelAddr);
        }
        break;

      // ── WINGS PANEL ADDR ─────────────────────────────────────────────────
      case _Stage.wingsPanelAddr:
        if ((l.contains('panel address') || l.contains('panel addr') ||
             l.contains('blank for any')) && l.contains('enter')) {
          send('\n', _Stage.wingsDbFirewall);
        }
        break;

      // ── WINGS DB FIREWALL ─────────────────────────────────────────────────
      case _Stage.wingsDbFirewall:
        if (l.contains('port 3306') || l.contains('incoming traffic')) {
          send('y\n', _Stage.wingsDbUser);
        } else if (l.contains('database host username') || l.contains('pterodactyluser')) {
          _stage = _Stage.wingsDbUser;
          _processLine(line);
        }
        break;

      // ── WINGS DB USER ─────────────────────────────────────────────────────
      case _Stage.wingsDbUser:
        if (l.contains('database host username') || l.contains('pterodactyluser') ||
            (l.contains('username') && l.contains('database'))) {
          send('\n', _Stage.wingsDbPass);
        }
        break;

      // ── WINGS DB PASS ─────────────────────────────────────────────────────
      case _Stage.wingsDbPass:
        if (l.contains('database host password') || l.contains('database password') ||
            (l.contains('password') && l.contains('database'))) {
          send('pterodactyl123\n', _Stage.wingsHttps);
        }
        break;

      // ── WINGS HTTPS ───────────────────────────────────────────────────────
      case _Stage.wingsHttps:
        if ((l.contains("let's encrypt") || l.contains('https') || l.contains('ssl')) &&
            (l.contains('configure') || l.contains('setup') || l.contains('enable'))) {
          send('y\n', _Stage.wingsFqdn);
        }
        break;

      // ── WINGS FQDN ────────────────────────────────────────────────────────
      case _Stage.wingsFqdn:
        if (l.contains('fqdn') ||
            (l.contains('domain') && (l.contains('wings') || l.contains('node') || l.contains('example.com')))) {
          send('$_node\n', _Stage.wingsConfirm);
        }
        break;

      // ── WINGS CONFIRM ─────────────────────────────────────────────────────
      case _Stage.wingsConfirm:
        if (l.contains('proceed with installation') ||
            l.contains('continue with installation') ||
            l.contains('do you want to continue') ||
            l.contains('do you wish to continue') ||
            (l.contains('continue') && _isYesNo(l))) {
          _queue.clear();
          send('y\n', _Stage.wingsInstalling);
        }
        break;

      // ── WINGS INSTALLING ──────────────────────────────────────────────────
      case _Stage.wingsInstalling:
        if (line.contains('Wings installation completed') ||
            (l.contains('wings') && l.contains('installation') && l.contains('completed'))) {
          _stage = _Stage.done;
          _log('✓ Wings terinstall. Menghubungkan node ke panel...', type: _LT.success);
          _autoConfigureNode();
        } else if (_isYesNo(l)) {
          sendKeep('y\n');
        }
        break;

      case _Stage.done:
        break;
    }
  }

  void _onPanelDone() {
    if (_isFinished) return;
    _keepalive?.cancel();
    _stage = _Stage.done;
    if (mounted) {
      setState(() {
        _isInstalling = false;
        _isFinished   = true;
        _hasError     = false;
      });
    }
    _log('', type: _LT.normal);
    _log('╔══════════════════════════════════════╗', type: _LT.success);
    _log('║   PANEL BERHASIL TERINSTALL  ✓       ║', type: _LT.success);
    _log('╚══════════════════════════════════════╝', type: _LT.success);
    _log('🌐 https://$_panel', type: _LT.info);
    _log('👤 $_adminUser  •  $_adminPass', type: _LT.info);
  }

  bool _isYesNo(String l) =>
      l.endsWith('(y/n):') || l.endsWith('(y/n)') ||
      l.endsWith('[y/n]:') || l.endsWith('[y/n]') ||
      l.endsWith('(yes/no):') || l.endsWith('(yes/no)') ||
      l.endsWith('(yes/no) [yes]:') || l.endsWith('(yes/no) [no]:') ||
      l.endsWith('[yes]:') || l.endsWith('[no]:');

  Future<void> _processQueue() async {
    if (_queueBusy || _queue.isEmpty) return;
    _queueBusy = true;
    try {
      while (_queue.isNotEmpty) {
        final r = _queue.removeAt(0);
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted || _shell == null) break;
        try {
          _shell!.stdin.add(utf8.encode(r));
        } catch (e) {
          _log('✗ Gagal kirim input: $e', type: _LT.error);
          break;
        }
        final d = r.trim();
        if (d.isNotEmpty) _log('▶  $d', type: _LT.input);
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _queueBusy = false;
    }
  }

  void _resetClient() {
    _watchdog?.cancel();
    _watchdog = null;
    _keepalive?.cancel();
    _keepalive = null;
    try { _shell?.close(); } catch (_) {}
    try { _client?.close(); } catch (_) {}
    _client = null;
    _shell  = null;
  }

  Future<void> _startInstall() async {
    setState(() {
      _isConnecting = true;
      _isInstalling = false;
      _isFinished   = false;
      _hasError     = false;
      _stage        = _Stage.initial;
      _logs.clear();
      _outBuf       = '';
      _queue.clear();
      _queueBusy    = false;
      _lastActivity = DateTime.now();
      _lastWatchStage = _Stage.initial;
    });

    // ── Watchdog: resend last expected input if stuck >90s ─────────────────
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isInstalling || _isFinished) return;
      final idleSeconds = DateTime.now().difference(_lastActivity).inSeconds;
      if (idleSeconds > 90) {
        _log('⚠  Tidak ada output >90 detik (stage: $_stage). Mencoba lanjut...', type: _LT.system);
        _lastActivity = DateTime.now();
        // Send enter to possibly unblock
        if (_shell != null && mounted) {
          try { _shell!.stdin.add(utf8.encode('\n')); } catch (_) {}
        }
      }
    });

    try {
      _resetClient();
      _log('Menghubungkan ke $_ip:22…', type: _LT.system);
      _log('Mode: ${_mode == _Mode.panel ? "Install Panel" : "Install Wings"}', type: _LT.system);

      final socket = await SSHSocket.connect(_ip, 22).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Koneksi SSH timeout (20s)'),
      );
      _client = SSHClient(socket, username: 'root', onPasswordRequest: () => _pass);
      await _client!.authenticated.timeout(const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Auth timeout (15s)'));

      _log('✓ Koneksi SSH berhasil.', type: _LT.success);
      setState(() { _isConnecting = false; _isInstalling = true; });

      _shell = await _client!.shell(pty: const SSHPtyConfig(type: 'xterm', width: 220, height: 50));

      _shell!.stdout.cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_onShellOutput, onDone: _onShellDone);
      _shell!.stderr.cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_onShellOutput);

      _keepalive = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isInstalling) { try { _client?.ping(); } catch (_) {} }
      });

      await Future.delayed(const Duration(milliseconds: 800));
      _shell!.stdin.add(utf8.encode('bash <(curl -s https://pterodactyl-installer.se)\n'));

    } on TimeoutException catch (e) {
      _log('✗ ${e.message}', type: _LT.error);
      if (mounted) setState(() { _isConnecting = false; _isInstalling = false; _isFinished = true; _hasError = true; });
    } catch (e) {
      _log('✗ Kesalahan koneksi: $e', type: _LT.error);
      if (mounted) setState(() { _isConnecting = false; _isInstalling = false; _isFinished = true; _hasError = true; });
    }
  }

  void _onShellDone() {
    if (!mounted || _isFinished) return;
    _keepalive?.cancel();
    if (_stage == _Stage.done) return;
    if (_stage == _Stage.wingsInstalling) {
      _log('⚠  Shell ditutup. Mencoba konfigurasi node...', type: _LT.system);
      _autoConfigureNode();
      return;
    }
    if (_mode == _Mode.panel && _stage == _Stage.panelInstalling) {
      _onPanelDone();
      return;
    }
    setState(() { _isInstalling = false; _isFinished = true; _hasError = true; });
    _log('Sesi SSH ditutup sebelum selesai (stage: $_stage).', type: _LT.system);
  }

  Future<void> _autoConfigureNode() async {
    if (!mounted || _client == null) return;
    _log('⚙  Membuat API key dan konfigurasi node...', type: _LT.info);

    try {
      final session = await _client!.execute('bash -s');

      final script = r'''
#!/bin/bash
set -eo pipefail

echo "[1/6] Menunggu panel siap..."
sleep 6

echo "[2/6] Membuat API key aplikasi..."
RAND_ID=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)
RAND_TOK=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)

ENCRYPTED=$(php -r "
  require '/var/www/pterodactyl/vendor/autoload.php';
  \$app = require '/var/www/pterodactyl/bootstrap/app.php';
  \$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();
  echo app('encrypter')->encrypt('$RAND_TOK');
" 2>/dev/null)

if [ -z "$ENCRYPTED" ]; then
  echo "ERROR: Gagal enkripsi token — pastikan panel sudah terinstall."
  exit 1
fi

USER_ID=$(mysql -u pterodactyl -p'pterodactyl123' panel -sN \
  -e "SELECT id FROM users WHERE root_admin=1 LIMIT 1" 2>/dev/null)

if [ -z "$USER_ID" ]; then
  echo "ERROR: User admin tidak ditemukan di database."
  exit 1
fi

mysql -u pterodactyl -p'pterodactyl123' panel \
  -e "INSERT INTO api_keys (user_id,key_type,identifier,token,allowed_ips,memo,created_at,updated_at)
      VALUES ($USER_ID,2,'$RAND_ID','$ENCRYPTED',NULL,'AutoNode',NOW(),NOW())" 2>/dev/null

FULL_KEY="ptla_${RAND_ID}${RAND_TOK}"
echo "[2/6] API key siap."

echo "[3/6] Membuat location..."
LOC_RESP=$(curl -sf -X POST "https://__PANEL__/api/application/locations" \
  -H "Authorization: Bearer $FULL_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"short":"auto","long":"Auto Location"}' 2>/dev/null)

LOC_ID=$(echo "$LOC_RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [ -z "$LOC_ID" ]; then
  echo "ERROR: Gagal membuat location. Response: $LOC_RESP"
  exit 1
fi
echo "[3/6] Location ID=$LOC_ID"

echo "[4/6] Membuat node..."
NODE_RESP=$(curl -sf -X POST "https://__PANEL__/api/application/nodes" \
  -H "Authorization: Bearer $FULL_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"name\": \"Node-Auto\",
    \"location_id\": $LOC_ID,
    \"fqdn\": \"__NODE__\",
    \"scheme\": \"https\",
    \"memory\": 8192,
    \"memory_overallocate\": 0,
    \"disk\": 50000,
    \"disk_overallocate\": 0,
    \"upload_size\": 100,
    \"daemon_sftp\": 2022,
    \"daemon_listen\": 8080
  }" 2>/dev/null)

NODE_ID=$(echo "$NODE_RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [ -z "$NODE_ID" ]; then
  echo "ERROR: Gagal membuat node. Response: $NODE_RESP"
  exit 1
fi
echo "[4/6] Node ID=$NODE_ID"

echo "[5/6] Mengunduh konfigurasi Wings..."
CONFIG=$(curl -sf "https://__PANEL__/api/application/nodes/$NODE_ID/configuration" \
  -H "Authorization: Bearer $FULL_KEY" \
  -H "Accept: application/json" 2>/dev/null)

if [ -z "$CONFIG" ] || echo "$CONFIG" | grep -q '"error"'; then
  echo "ERROR: Gagal unduh config node. Response: $CONFIG"
  exit 1
fi

mkdir -p /etc/pterodactyl
printf '%s\n' "$CONFIG" > /etc/pterodactyl/config.yml
echo "[5/6] config.yml ditulis."

echo "[6/6] Menjalankan Wings..."
systemctl enable wings 2>/dev/null || true
systemctl restart wings

for i in $(seq 1 5); do
  sleep 3
  if systemctl is-active --quiet wings; then
    echo "NODE_DONE:$NODE_ID"
    exit 0
  fi
done

echo "WINGS_NOT_RUNNING: Wings gagal start"
systemctl status wings --no-pager 2>&1 | tail -8
exit 1
'''
          .replaceAll('__PANEL__', _panel)
          .replaceAll('__NODE__', _node);

      session.stdin.add(utf8.encode(script));
      await session.stdin.close();

      String fullOut = '';
      await for (final chunk in session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))) {
        fullOut += chunk;
        for (final raw in chunk.split('\n')) {
          final t = raw.trim();
          if (t.isEmpty) continue;
          if (t.startsWith('ERROR:') || t.startsWith('WINGS_NOT_RUNNING:')) {
            _log('✗ $t', type: _LT.error);
          } else if (t.startsWith('[') && t.contains('/6]')) {
            _log('⚙  $t', type: _LT.info);
          } else if (!t.startsWith('NODE_DONE:')) {
            _log(t, type: _LT.normal);
          }
        }
      }

      session.stderr.cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((chunk) {
        for (final line in chunk.split('\n')) {
          final t = line.trim();
          if (t.isNotEmpty && !t.contains('mysql: [Warning]')) {
            _log('[stderr] $t', type: _LT.system);
          }
        }
      });

      if (fullOut.contains('NODE_DONE:')) {
        final nodeId = fullOut.split('NODE_DONE:').last.trim().split('\n').first.trim();
        if (mounted) {
          setState(() { _isInstalling = false; _isFinished = true; _hasError = false; });
          _log('', type: _LT.normal);
          _log('╔══════════════════════════════════════╗', type: _LT.success);
          _log('║   WINGS + NODE BERHASIL TERPASANG ✓  ║', type: _LT.success);
          _log('╚══════════════════════════════════════╝', type: _LT.success);
          _log('📦 Node #$nodeId aktif — node HIJAU di panel.', type: _LT.success);
          _log('🌐 Panel: https://$_panel', type: _LT.info);
          _log('👤 $_adminUser  •  $_adminPass', type: _LT.info);
        }
      } else {
        if (mounted) {
          setState(() { _isInstalling = false; _isFinished = true; _hasError = true; });
          _log('⚠  Wings terinstall tapi node belum terhubung. Setup manual via panel.', type: _LT.error);
        }
      }
    } catch (e) {
      _log('⚠  Error setup node: $e', type: _LT.error);
      if (mounted) setState(() { _isInstalling = false; _isFinished = true; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: _textDim),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _mode == _Mode.panel ? 'Install Panel' : 'Install Wings',
          style: const TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all_rounded, size: 18, color: _textDim),
              tooltip: 'Salin semua log',
              onPressed: () {
                final all = _logs.map((e) => '[${_fmt(e.time)}] ${e.message}').join('\n');
                Clipboard.setData(ClipboardData(text: all));
                _snack('Log disalin ke clipboard');
              },
            ),
          if (_formReady && !_isInstalling)
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 18, color: _textDim),
              tooltip: 'Edit konfigurasi',
              onPressed: () => setState(() { _formReady = false; _logs.clear(); }),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SafeArea(child: _formReady ? _terminal() : _form()),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          _modeSelector(),
          const SizedBox(height: 22),

          _sectionTitle('Koneksi VPS'),
          const SizedBox(height: 12),
          _label('IP Address VPS'),
          _field(_ipCtrl, '123.45.67.89',
              icon: Icons.dns_outlined, keyboard: TextInputType.url,
              validator: (v) => v!.trim().isEmpty ? 'IP wajib diisi' : null),
          const SizedBox(height: 14),
          _label('Password Root'),
          _passField(_passCtrl, 'Password VPS', _passVisible,
              () => setState(() => _passVisible = !_passVisible),
              validator: (v) => v!.trim().isEmpty ? 'Password wajib diisi' : null),
          const SizedBox(height: 22),

          _sectionTitle('Domain'),
          const SizedBox(height: 12),

          if (_mode == _Mode.panel || _mode == _Mode.wings) ...[
            _label('Domain Panel'),
            _field(_panelCtrl, 'panel.contoh.com',
                icon: Icons.web_outlined, keyboard: TextInputType.url,
                validator: (v) => v!.trim().isEmpty ? 'Domain panel wajib diisi' : null),
            const SizedBox(height: 14),
          ],

          _label('Domain Node'),
          _field(_nodeCtrl, 'node.contoh.com',
              icon: Icons.storage_outlined, keyboard: TextInputType.url,
              validator: (v) => v!.trim().isEmpty ? 'Domain node wajib diisi' : null),
          const SizedBox(height: 22),

          if (_mode == _Mode.panel) ...[
            _sectionTitle('Akun Admin Panel'),
            const SizedBox(height: 12),
            _label('Email Admin'),
            _field(_adminEmailCtrl, 'admin@contoh.com',
                icon: Icons.email_outlined, keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                }),
            const SizedBox(height: 14),
            _label('Username Admin'),
            _field(_adminUsernameCtrl, 'admin',
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Username wajib diisi' : null),
            const SizedBox(height: 14),
            _label('Password Admin'),
            _passField(_adminPasswordCtrl, 'Min. 8 karakter', _adminPassVisible,
                () => setState(() => _adminPassVisible = !_adminPassVisible),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Password wajib diisi';
                  if (v.trim().length < 8) return 'Minimal 8 karakter';
                  return null;
                }),
            const SizedBox(height: 22),
          ],

          _warningBox(),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                setState(() => _formReady = true);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(
              _mode == _Mode.panel ? 'Lanjut ke Install Panel' : 'Lanjut ke Install Wings',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _modeSelector() => Container(
    decoration: BoxDecoration(
      color: _surface, borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
        child: Text('Pilih Mode Instalasi',
            style: const TextStyle(color: _text, fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
      _modeOption(
        _Mode.panel,
        Icons.web_rounded,
        'Install Panel',
        'Instalasi Pterodactyl Panel saja pada VPS ini',
        _accent,
      ),
      Divider(height: 1, color: _border),
      _modeOption(
        _Mode.wings,
        Icons.storage_rounded,
        'Install Wings',
        'Instalasi Wings (daemon) saja pada VPS ini\nlalu otomatis hubungkan node ke panel',
        _purple,
      ),
    ]),
  );

  Widget _modeOption(_Mode mode, IconData icon, String title, String sub, Color color) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(selected ? 0.18 : 0.07),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withOpacity(selected ? 0.4 : 0.15)),
            ),
            child: Icon(icon, color: selected ? color : _textHint, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: selected ? color : _text, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(color: _textDim, fontSize: 11.5, height: 1.4)),
          ])),
          const SizedBox(width: 8),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? color : _textHint, width: 2),
              color: selected ? color : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 11)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _warningBox() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _warning.withOpacity(0.05), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _warning.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.schedule_rounded, color: _warning, size: 15),
      const SizedBox(width: 9),
      Expanded(child: Text(
        _mode == _Mode.panel
            ? 'Estimasi: 10–20 menit. Jangan tutup aplikasi.'
            : 'Estimasi: 15–25 menit (termasuk auto-configure node).\nJangan tutup aplikasi.',
        style: const TextStyle(color: _warning, fontSize: 12, height: 1.5),
      )),
    ]),
  );

  Widget _terminal() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (_mode == _Mode.panel ? _accent : _purple).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _mode == _Mode.panel ? Icons.web_rounded : Icons.storage_rounded,
                color: _mode == _Mode.panel ? _accent : _purple, size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_ip, style: const TextStyle(color: _text, fontSize: 13.5,
                    fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                _chip('root', _textHint),
                const SizedBox(width: 5),
                _chip(_mode == _Mode.panel ? 'panel' : 'wings',
                    _mode == _Mode.panel ? _accent : _purple),
              ]),
              const SizedBox(height: 3),
              Text(
                _mode == _Mode.panel ? _panel : '$_panel  ·  $_node',
                style: const TextStyle(color: _textDim, fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ])),
            const SizedBox(width: 8),
            _statusBadge(),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                child: Row(children: [
                  Row(children: [
                    _dot(const Color(0xFFFC5C65)), const SizedBox(width: 5),
                    _dot(const Color(0xFFFFD166)), const SizedBox(width: 5),
                    _dot(const Color(0xFF43D9AD)),
                  ]),
                  const SizedBox(width: 12),
                  const Icon(Icons.terminal_rounded, color: _textHint, size: 13),
                  const SizedBox(width: 6),
                  const Text('shell output', style: TextStyle(color: _textHint, fontSize: 11.5)),
                  const Spacer(),
                  Text(_logs.isEmpty ? '—' : '${_logs.length} lines',
                      style: const TextStyle(color: _textHint, fontSize: 11)),
                ]),
              ),
              Expanded(
                child: _logs.isEmpty ? _emptyState() : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => _logRow(_logs[i]),
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: _bottomBar(),
      ),
    ]);
  }

  Widget _bottomBar() {
    if (_isFinished && !_hasError) {
      return Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _success.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _success.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded, color: _success, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _mode == _Mode.panel ? 'Panel Berhasil Terinstall ✓' : 'Wings + Node Aktif ✓',
                style: const TextStyle(color: _success, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'https://$_panel'));
                  _snack('URL disalin ✓');
                },
                child: Row(children: [
                  Expanded(child: Text('https://$_panel',
                      style: const TextStyle(color: _textDim, fontSize: 12, fontFamily: 'monospace'))),
                  Icon(Icons.copy_rounded, color: _success.withOpacity(0.5), size: 13),
                ]),
              ),
              if (_mode == _Mode.panel) ...[
                const SizedBox(height: 2),
                Text('$_adminUser  •  $_adminPass',
                    style: const TextStyle(color: _textDim, fontSize: 11.5)),
              ],
            ])),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Kembali'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _textDim, side: const BorderSide(color: _border),
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]);
    }

    if (_hasError) {
      return ElevatedButton.icon(
        onPressed: () { _resetClient(); _startInstall(); },
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _error.withOpacity(0.12), foregroundColor: _error,
          minimumSize: const Size(double.infinity, 50), elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _error.withOpacity(0.3)),
          ),
        ),
      );
    }

    final busy = _isConnecting || _isInstalling;
    return ElevatedButton.icon(
      onPressed: busy ? null : _startInstall,
      icon: busy
          ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white60))
          : const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        _isConnecting
            ? 'Menghubungkan…'
            : _isInstalling
                ? (_mode == _Mode.panel ? 'Menginstall Panel…' : 'Menginstall Wings…')
                : (_mode == _Mode.panel ? 'Mulai Install Panel' : 'Mulai Install Wings'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent, foregroundColor: Colors.white,
        disabledBackgroundColor: _accent.withOpacity(0.35),
        disabledForegroundColor: Colors.white54,
        minimumSize: const Size(double.infinity, 50), elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _logRow(_LogEntry e) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_fmt(e.time)} ',
          style: const TextStyle(color: _textHint, fontSize: 10.5, fontFamily: 'monospace')),
      Expanded(child: Text(e.message,
          style: TextStyle(color: _logColor(e.type), fontSize: 11.5,
              fontFamily: 'monospace', height: 1.45))),
    ]),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.terminal_rounded, color: _textHint, size: 34),
      const SizedBox(height: 10),
      const Text('Output akan muncul di sini', style: TextStyle(color: _textHint, fontSize: 13)),
      const SizedBox(height: 4),
      const Text('Tekan tombol di bawah untuk mulai',
          style: TextStyle(color: _textHint, fontSize: 11.5)),
    ]),
  );

  Widget _statusBadge() {
    if (_isConnecting) return _badge('Connecting', _warning, spinning: true);
    if (_isInstalling) return _badge('Installing', _accent, spinning: true);
    if (_isFinished && !_hasError) return _badge('Done', _success);
    if (_hasError) return _badge('Error', _error);
    return _badge('Idle', _textHint);
  }

  Widget _badge(String label, Color color, {bool spinning = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (spinning)
        SizedBox(width: 8, height: 8,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
      else
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );

  Color _logColor(_LT t) {
    switch (t) {
      case _LT.success: return _colSuccess;
      case _LT.error:   return _colError;
      case _LT.info:    return _colInfo;
      case _LT.input:   return _colInput;
      case _LT.system:  return _colSystem;
      case _LT.normal:  return _colNormal;
    }
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2,'0')}:'
      '${t.minute.toString().padLeft(2,'0')}:'
      '${t.second.toString().padLeft(2,'0')}';

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(color: _text, fontSize: 13.5, fontWeight: FontWeight.w600));

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(color: _textDim, fontSize: 12.5,
        fontWeight: FontWeight.w500)),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textHint, fontSize: 13),
    filled: true, fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _accent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _error.withOpacity(0.6))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _error, width: 1.5)),
  );

  Widget _field(TextEditingController ctrl, String hint, {
    IconData? icon, TextInputType? keyboard, String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    style: const TextStyle(color: _text, fontSize: 14),
    keyboardType: keyboard,
    decoration: _deco(hint).copyWith(
      prefixIcon: icon != null ? Icon(icon, color: _textHint, size: 17) : null,
    ),
    validator: validator,
  );

  Widget _passField(TextEditingController ctrl, String hint, bool visible,
      VoidCallback toggle, {String? Function(String?)? validator}) =>
    TextFormField(
      controller: ctrl, obscureText: !visible,
      style: const TextStyle(color: _text, fontSize: 14),
      decoration: _deco(hint).copyWith(
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _textHint, size: 17),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _textHint, size: 17),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10.5)),
  );

  Widget _dot(Color color) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: _surface2, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }
}
