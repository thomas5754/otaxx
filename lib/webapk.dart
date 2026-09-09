import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _bg       = Color(0xFF070B12);
const Color _surface  = Color(0xFF0D1018);
const Color _card     = Color(0xFF111520);
const Color _card2    = Color(0xFF151A28);
const Color _border   = Color(0xFF1C2235);
const Color _border2  = Color(0xFF252D42);

const Color _cyan     = Color(0xFF00D4FF);
const Color _cyanDim  = Color(0xFF0A3D55);
const Color _blue     = Color(0xFF4B8FFF);
const Color _blueDim  = Color(0xFF162040);
const Color _green    = Color(0xFF00E57A);
const Color _greenDim = Color(0xFF003D20);
const Color _red      = Color(0xFFFF4F6A);
const Color _redDim   = Color(0xFF3D0A12);
const Color _amber    = Color(0xFFFFB340);
const Color _purple   = Color(0xFFA78BFA);

const Color _text     = Color(0xFFE2EAF8);
const Color _textSub  = Color(0xFF6B7A9B);
const Color _textMute = Color(0xFF2E3650);

const Color _lcNorm   = Color(0xFFB8C4DC);
const Color _lcOk     = Color(0xFF00E57A);
const Color _lcErr    = Color(0xFFFF4F6A);
const Color _lcInfo   = Color(0xFF60A5FA);
const Color _lcSys    = Color(0xFF4A546A);
const Color _lcStep   = Color(0xFFA78BFA);

enum _SS { idle, running, done, failed }
enum _LT { norm, ok, err, info, sys, step }

class _Step {
  final String   id;
  final String   label;
  final IconData icon;
  _SS            status = _SS.idle;
  _Step({required this.id, required this.label, required this.icon});
}

class _LogEntry {
  final String   msg;
  final _LT      type;
  final DateTime ts;
  const _LogEntry(this.msg, this.type, this.ts);
}

List<_Step> _freshSteps() => [
  _Step(id: 'update',  label: 'System Update',  icon: Icons.sync_alt_rounded),
  _Step(id: 'nodejs',  label: 'Node.js 20',      icon: Icons.code_rounded),
  _Step(id: 'java',    label: 'Java 17',         icon: Icons.memory_rounded),
  _Step(id: 'android', label: 'Android SDK',     icon: Icons.android_rounded),
  _Step(id: 'flutter', label: 'Flutter SDK',     icon: Icons.flutter_dash_rounded),
  _Step(id: 'envpm2',  label: 'Env + PM2',       icon: Icons.tune_rounded),
  _Step(id: 'clone',   label: 'Clone Repo',      icon: Icons.cloud_download_rounded),
  _Step(id: 'dotenv',  label: 'Config .env',     icon: Icons.settings_rounded),
  _Step(id: 'nginx',   label: 'Nginx',           icon: Icons.dns_rounded),
  _Step(id: 'ufw',     label: 'UFW',             icon: Icons.shield_outlined),
  _Step(id: 'pm2run',  label: 'PM2 Start',       icon: Icons.play_circle_outline_rounded),
];

class InstallWeb2apkPage extends StatefulWidget {
  final String? ipVps;
  final String? passwordVps;
  final String? botToken;
  final String? adminIds;
  final String? requiredChannel;
  final String? webUrl;
  final String? domain;
  final String? port;

  const InstallWeb2apkPage({
    super.key,
    this.ipVps,
    this.passwordVps,
    this.botToken,
    this.adminIds,
    this.requiredChannel,
    this.webUrl,
    this.domain,
    this.port,
  });

  @override
  State<InstallWeb2apkPage> createState() => _InstallWeb2apkState();
}

class _InstallWeb2apkState extends State<InstallWeb2apkPage>
    with TickerProviderStateMixin {

  late final TextEditingController _ctrlIp;
  late final TextEditingController _ctrlPass;
  late final TextEditingController _ctrlToken;
  late final TextEditingController _ctrlAdmin;
  late final TextEditingController _ctrlChannel;
  late final TextEditingController _ctrlUrl;
  late final TextEditingController _ctrlDomain;
  late final TextEditingController _ctrlPort;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _showPass   = false;
  bool _showToken  = false;
  bool _formReady  = false;

  List<_Step>           _steps     = _freshSteps();
  final List<_LogEntry> _logs      = [];
  bool   _running                  = false;
  bool   _finished                 = false;
  bool   _errored                  = false;
  int    _doneCount                = 0;
  String _statusMsg                = '';
  final ScrollController _scroll   = ScrollController();

  SSHClient?  _sshClient;
  SSHSession? _sshShell;
  Timer?      _keepalive;
  String      _outBuf = '';

  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _progressAnim;

  String get _ip      => _ctrlIp.text.trim();
  String get _pass    => _ctrlPass.text.trim();
  String get _token   => _ctrlToken.text.trim();
  String get _admins  => _ctrlAdmin.text.trim();
  String get _channel => _ctrlChannel.text.trim();
  String get _rawUrl  => _ctrlUrl.text.trim();
  String get _domain  => _ctrlDomain.text.trim();
  String get _port    => _ctrlPort.text.trim().isEmpty ? '3000' : _ctrlPort.text.trim();

  String get _resolvedUrl {
    if (_rawUrl.isNotEmpty) return _rawUrl;
    if (_domain.isNotEmpty) return 'https://$_domain';
    return 'http://$_ip:$_port';
  }

  @override
  void initState() {
    super.initState();

    _ctrlIp      = TextEditingController(text: widget.ipVps           ?? '');
    _ctrlPass    = TextEditingController(text: widget.passwordVps     ?? '');
    _ctrlToken   = TextEditingController(text: widget.botToken        ?? '');
    _ctrlAdmin   = TextEditingController(text: widget.adminIds        ?? '');
    _ctrlChannel = TextEditingController(text: widget.requiredChannel ?? '');
    _ctrlUrl     = TextEditingController(text: widget.webUrl          ?? '');
    _ctrlDomain  = TextEditingController(text: widget.domain          ?? '');
    _ctrlPort    = TextEditingController(text: widget.port            ?? '3000');

    _formReady = widget.ipVps != null && widget.passwordVps != null &&
                 widget.botToken != null && widget.adminIds != null;

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _sshCleanup();
    _scroll.dispose();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    for (final c in [_ctrlIp, _ctrlPass, _ctrlToken, _ctrlAdmin,
                     _ctrlChannel, _ctrlUrl, _ctrlDomain, _ctrlPort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sshCleanup() {
    _keepalive?.cancel();
    _keepalive = null;
    try { _sshShell?.close(); } catch (_) {}
    try { _sshClient?.close(); } catch (_) {}
    _sshClient = null;
    _sshShell  = null;
  }

  void _addLog(String msg, [_LT type = _LT.norm]) {
    if (!mounted) return;
    setState(() => _logs.add(_LogEntry(msg, type, DateTime.now())));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static String _ansi(String raw) => raw
      .replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKHFABCDJMPX]'), '')
      .replaceAll(RegExp(r'\x1B\[\?[0-9;]*[hl]'), '')
      .replaceAll(RegExp(r'\x1B[()][A-Z0]'), '')
      .replaceAll(RegExp(r'\x1B\][^\x07]*\x07'), '')
      .replaceAll('\r', '');

  void _onData(String raw) {
    if (raw.isEmpty) return;
    _outBuf += _ansi(raw);
    final parts = _outBuf.split('\n');
    for (int i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isNotEmpty) _processLine(line);
    }
    _outBuf = parts.last;
    if (_outBuf.isNotEmpty) _processLine(_outBuf);
  }

  void _processLine(String line) {
    if (line.startsWith('OTAX_STEP:')) {
      _onStepBegin(line.substring(10).trim());
      return;
    }
    if (line.startsWith('OTAX_OK:')) {
      _onStepDone(line.substring(8).trim());
      return;
    }
    if (line.startsWith('OTAX_FAIL:')) {
      final rest = line.substring(10).trim();
      final id   = rest.split(' - ').first.trim();
      _onStepFail(id, rest);
      return;
    }
    if (line.contains('OTAX_INSTALL_COMPLETE')) {
      _onInstallComplete(success: true);
      return;
    }

    final l = line.toLowerCase();
    _LT type = _LT.norm;

    if (RegExp(r'\[([1-6])/6\]').hasMatch(line)) {
      type = _LT.step;
    } else if (l.contains('error') || l.contains('failed') || l.contains('fatal')) {
      final benign = l.contains('dpkg') || l.contains('apt-get') ||
          l.contains('[sdk]') || l.contains('gradle') ||
          l.contains('note:') || l.contains('0 upgraded');
      type = benign ? _LT.norm : _LT.err;
    } else if (l.contains('✓') || l.contains('success') || l.contains('complete') ||
               (l.contains('installed') && !l.contains('already'))) {
      type = _LT.ok;
    } else if (line.startsWith('[') || l.contains('installing') ||
               l.contains('downloading') || l.contains('cloning') ||
               l.contains('configuring') || l.contains('setting up')) {
      type = _LT.info;
    }

    _addLog(line, type);
  }

  void _onStepBegin(String id) {
    final idx = _steps.indexWhere((s) => s.id == id);
    if (idx < 0 || !mounted) return;
    setState(() {
      for (final s in _steps) {
        if (s.status == _SS.running) s.status = _SS.idle;
      }
      _steps[idx].status = _SS.running;
      _statusMsg = '${_steps[idx].label}…';
    });
    _addLog('▶ ${_steps[idx].label}', _LT.step);
  }

  void _onStepDone(String id) {
    final idx = _steps.indexWhere((s) => s.id == id);
    if (idx < 0 || !mounted) return;
    setState(() {
      _steps[idx].status = _SS.done;
      _doneCount = _steps.where((s) => s.status == _SS.done).length;
    });
    _progressCtrl.animateTo(_doneCount / _steps.length,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    _addLog('✓ ${_steps[idx].label}', _LT.ok);
  }

  void _onStepFail(String id, String detail) {
    final idx = _steps.indexWhere((s) => s.id == id);
    if (idx >= 0 && mounted) setState(() => _steps[idx].status = _SS.failed);
    if (mounted) setState(() => _errored = true);
    _addLog('✗ GAGAL: $detail', _LT.err);
  }

  void _onInstallComplete({required bool success}) {
    if (!mounted || _finished) return;
    _keepalive?.cancel();
    if (success) {
      _progressCtrl.animateTo(1.0, duration: const Duration(milliseconds: 700));
    }
    setState(() {
      _running  = false;
      _finished = true;
      _errored  = !success;
      _statusMsg = success ? 'Selesai ✓' : 'Gagal';
    });
    if (success) {
      _addLog('', _LT.norm);
      _addLog('╔══════════════════════════════════════╗', _LT.ok);
      _addLog('║   WEB2APK BERHASIL TERINSTALL  ✓     ║', _LT.ok);
      _addLog('╚══════════════════════════════════════╝', _LT.ok);
      _addLog('URL    → $_resolvedUrl', _LT.info);
      _addLog('Admin  → $_admins', _LT.info);
    } else {
      _addLog('✗ Instalasi gagal — periksa log di atas.', _LT.err);
    }
  }

  void _onShellClosed() {
    if (!mounted || _finished) return;
    _keepalive?.cancel();
    final ok = _doneCount >= (_steps.length * 0.8).ceil();
    _onInstallComplete(success: ok);
  }

  Future<void> _startInstall() async {
    setState(() {
      _running   = true;
      _finished  = false;
      _errored   = false;
      _doneCount = 0;
      _statusMsg = 'Menghubungkan SSH…';
      _steps     = _freshSteps();
      _logs.clear();
      _outBuf    = '';
    });
    _progressCtrl.reset();

    _addLog('OTAX Web2APK Auto-Installer', _LT.sys);
    _addLog('Host    → $_ip', _LT.sys);
    _addLog('Port    → $_port', _LT.sys);
    if (_domain.isNotEmpty) _addLog('Domain  → $_domain', _LT.sys);
    _addLog('URL     → $_resolvedUrl', _LT.sys);
    _addLog('─' * 44, _LT.sys);

    try {
      _sshCleanup();

      final socket = await SSHSocket.connect(_ip, 22).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Koneksi SSH timeout (20s)'),
      );

      _sshClient = SSHClient(
        socket,
        username: 'root',
        onPasswordRequest: () => _pass,
      );

      await _sshClient!.authenticated.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Autentikasi timeout (15s)'),
      );

      _addLog('✓ Terhubung sebagai root@$_ip', _LT.ok);
      if (mounted) setState(() => _statusMsg = 'Menyiapkan installer…');

      _sshShell = await _sshClient!.shell(
        pty: const SSHPtyConfig(type: 'xterm', width: 220, height: 50),
      );

      _sshShell!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_onData, onDone: _onShellClosed);

      _sshShell!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_onData);

      _keepalive = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_running && !_finished) {
          try { _sshClient?.ping(); } catch (_) {}
        }
      });

      await Future.delayed(const Duration(milliseconds: 700));
      await _deliverScript(_buildScript());

    } on TimeoutException catch (e) {
      _addLog('✗ ${e.message}', _LT.err);
      _onInstallComplete(success: false);
    } catch (e) {
      _addLog('✗ Error: $e', _LT.err);
      _onInstallComplete(success: false);
    }
  }

  Future<void> _deliverScript(String script) async {
    final b64    = base64.encode(utf8.encode(script));
    const chunk  = 800;
    final nChunk = (b64.length / chunk).ceil();

    _addLog('Script ${(script.length / 1024).toStringAsFixed(1)} KB → '
            '$nChunk chunks @ $chunk chars', _LT.sys);

    _write('rm -f /tmp/_w.b64 /tmp/_w.sh\n');
    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < b64.length; i += chunk) {
      final part = b64.substring(i, min(i + chunk, b64.length));
      _write("printf '%s' '$part' >> /tmp/_w.b64\n");
      await Future.delayed(const Duration(milliseconds: 60));
    }

    await Future.delayed(const Duration(milliseconds: 700));
    _addLog('Decode & jalankan installer…', _LT.info);
    _write('base64 -d /tmp/_w.b64 > /tmp/_w.sh && chmod +x /tmp/_w.sh && bash /tmp/_w.sh\n');
  }

  void _write(String s) => _sshShell?.stdin.add(utf8.encode(s));

  String _buildScript() {
    String sedEsc(String v) => v
        .replaceAll('\\', '\\\\')
        .replaceAll('|', '\\|')
        .replaceAll('&', '\\&');

    final host     = _domain.isNotEmpty ? _domain : '_';
    final finalUrl = _resolvedUrl;
    final appPort  = _port;

    return r"""#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export FLUTTER_HOME=/opt/flutter
export PATH=$PATH:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/flutter/bin

_step() { echo "OTAX_STEP:$1"; }
_ok()   { echo "OTAX_OK:$1"; }
_fail() { echo "OTAX_FAIL:$1 - $2"; exit 1; }

set -eo pipefail
echo "=== OTAX Web2APK Installer started ==="

_step "update"
echo "[1/6] Updating system packages..."
apt-get update -qq 2>&1 | tail -3 || _fail "update" "apt-get update failed"
apt-get upgrade -y -qq 2>&1 | tail -3
echo "  System updated."
_ok "update"

_step "nodejs"
echo "[2/6] Installing Node.js 20..."
if ! command -v node &>/dev/null || [[ $(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v') -lt 18 ]]; then
  apt-get install -y curl 2>/dev/null | tail -1 || true
  curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | bash - >/dev/null 2>&1
  apt-get install -y nodejs 2>&1 | tail -3 || _fail "nodejs" "Failed to install nodejs"
fi
echo "  Node.js $(node -v) — npm v$(npm -v)"
_ok "nodejs"

_step "java"
echo "[3/6] Installing Java 17 (OpenJDK)..."
apt-get install -y openjdk-17-jdk 2>&1 | tail -3 || _fail "java" "Failed to install Java 17"
export JAVA_HOME=$(update-java-alternatives -l 2>/dev/null | grep "java-17" | awk '{print $3}' | head -1)
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}
echo "  $(java -version 2>&1 | head -n1)"
_ok "java"

_step "android"
echo "[4/6] Setting up Android SDK (platforms-34 + build-tools-34)..."
apt-get install -y wget unzip zip lib32z1 lib32stdc++6 2>/dev/null | tail -2 || true

mkdir -p "$ANDROID_HOME/cmdline-tools"
cd "$ANDROID_HOME/cmdline-tools"

if [ ! -d "latest" ]; then
  echo "  Downloading Android command-line tools..."
  wget -q "https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip" -O tools.zip \
    || _fail "android" "Failed to download Android cmdline-tools"
  unzip -q tools.zip
  [ -d "cmdline-tools" ] && mv cmdline-tools latest || true
  rm -f tools.zip
fi

chmod -R 777 "$ANDROID_HOME"
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

echo "  Accepting SDK licenses..."
yes 2>/dev/null | sdkmanager --licenses >/dev/null 2>&1 || true

echo "  Installing platforms;android-34, build-tools;34.0.0, platform-tools..."
sdkmanager --verbose \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  "platform-tools" 2>&1 | grep -E '^\[|Downloading|Installing|done$|^Done' | tail -20 \
  || _fail "android" "sdkmanager gagal"

echo "  Android SDK 34 installed."
_ok "android"

_step "flutter"
echo "[5/6] Installing Flutter SDK..."
apt-get install -y git curl xz-utils 2>/dev/null | tail -2 || true

if [ ! -d "/opt/flutter" ]; then
  echo "  Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 /opt/flutter 2>&1 | tail -4 \
    || _fail "flutter" "Failed to clone Flutter"
fi

ln -sf /opt/flutter/bin/flutter /usr/bin/flutter 2>/dev/null || true
ln -sf /opt/flutter/bin/dart    /usr/bin/dart    2>/dev/null || true

export PATH=$PATH:/opt/flutter/bin
flutter precache --android 2>&1 | tail -5 || true
flutter config --no-analytics 2>/dev/null || true

echo "  $(flutter --version 2>&1 | head -n1)"
echo "  Flutter path: $(which flutter)"
_ok "flutter"

_step "envpm2"
echo "[6/6] Configuring env vars + installing PM2..."

sed -i '/^JAVA_HOME=/d;/^ANDROID_HOME=/d;/^FLUTTER_HOME=/d' /etc/environment 2>/dev/null || true
printf 'JAVA_HOME=%s\nANDROID_HOME=/opt/android-sdk\nFLUTTER_HOME=/opt/flutter\n' \
  "$JAVA_HOME" >> /etc/environment

if ! grep -q 'OTAX_W2A' /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc << 'BEOF'
# OTAX_W2A — Web2APK installer
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export FLUTTER_HOME=/opt/flutter
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/opt/flutter/bin
BEOF
fi

npm install -g pm2 2>&1 | tail -3 || _fail "envpm2" "Failed to install PM2"
echo "  PM2 v$(pm2 --version)"
_ok "envpm2"

_step "clone"
echo "=== Cloning web2apknew repo ==="
cd /root
rm -rf web2apknew
git clone https://github.com/OtaStoree/web2apknew.git 2>&1 | tail -4 \
  || _fail "clone" "Failed to clone web2apk repo"
cd /root/web2apknew
npm install 2>&1 | tail -5 || _fail "clone" "npm install failed"

echo "  Downloading gradle-wrapper.jar..."
GRADLE_JAR=/root/web2apknew/android-template/gradle/wrapper/gradle-wrapper.jar
mkdir -p "$(dirname "$GRADLE_JAR")"
GRADLE_JAR_OK=false
for JAR_URL in \
  "https://raw.githubusercontent.com/gradle/gradle/v7.5.0/gradle/wrapper/gradle-wrapper.jar" \
  "https://raw.githubusercontent.com/android/nowinandroid/main/gradle/wrapper/gradle-wrapper.jar" \
  "https://raw.githubusercontent.com/spring-io/gradle-wrapper/main/gradle/wrapper/gradle-wrapper.jar"; do
  wget -q --timeout=30 "$JAR_URL" -O "$GRADLE_JAR" 2>/dev/null && \
  [ "$(stat -c%s "$GRADLE_JAR" 2>/dev/null || echo 0)" -gt 50000 ] && \
  GRADLE_JAR_OK=true && break || true
done
if [ "$GRADLE_JAR_OK" = "false" ]; then
  echo "  Warning: gradle-wrapper.jar download failed — akan pakai system gradle sebagai fallback"
fi
echo "  Clone + npm install complete."
_ok "clone"

""" +
"""
_step "dotenv"
echo "=== Configuring .env ==="
cp /root/web2apknew/.env.example /root/web2apknew/.env

sed -i "s|BOT_TOKEN=.*|BOT_TOKEN=${sedEsc(_token)}|"                   /root/web2apknew/.env
sed -i "s|ADMIN_IDS=.*|ADMIN_IDS=${sedEsc(_admins)}|"                 /root/web2apknew/.env
sed -i "s|REQUIRED_CHANNEL=.*|REQUIRED_CHANNEL=${sedEsc(_channel)}|"  /root/web2apknew/.env
sed -i "s|WEB_URL=.*|WEB_URL=${sedEsc(finalUrl)}|"                    /root/web2apknew/.env
sed -i "s|WEB_PORT=.*|WEB_PORT=$appPort|"                             /root/web2apknew/.env

echo "  .env result:"
grep -v '^#' /root/web2apknew/.env | grep -v '^\$'
_ok "dotenv"

_step "nginx"
echo "=== Setting up Nginx ==="
apt-get install -y nginx 2>&1 | tail -3 || _fail "nginx" "Failed to install nginx"
rm -f /etc/nginx/sites-enabled/default

""" +
r"""
cat > /etc/nginx/sites-available/web2apk << 'NGINXEOF'
server {
""" + "    server_name $host;\n" + r"""
    client_max_body_size 100m;
    client_body_timeout 300s;

    location / {
        proxy_pass         http://localhost:""" + appPort + r""";
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host               $host;
        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 1800s;
        proxy_send_timeout    1800s;
        proxy_read_timeout    1800s;
        proxy_buffering off;
        proxy_cache    off;
        chunked_transfer_encoding on;
    }
    listen 80;
}
NGINXEOF

ln -sf /etc/nginx/sites-available/web2apk /etc/nginx/sites-enabled/web2apk
nginx -t 2>&1 || _fail "nginx" "nginx config test failed"
systemctl reload nginx 2>/dev/null || systemctl start nginx 2>/dev/null || service nginx restart 2>/dev/null || true
echo "  Nginx running."
_ok "nginx"

_step "ufw"
echo "=== Configuring UFW ==="
apt-get install -y ufw 2>/dev/null | tail -2 || true
ufw allow 22/tcp   >/dev/null 2>&1 || true
ufw allow 80/tcp   >/dev/null 2>&1 || true
ufw allow 443/tcp  >/dev/null 2>&1 || true
""" + "ufw allow $appPort/tcp >/dev/null 2>&1 || true\n" + r"""
echo y | ufw enable >/dev/null 2>&1 || true
echo "  UFW: $(ufw status | head -1)"
_ok "ufw"

_step "pm2run"
echo "=== Starting Web2APK with PM2 ==="
cd /root/web2apknew
pm2 delete web2apknew 2>/dev/null || true

if ! command -v flutter &>/dev/null; then
  ln -sf /opt/flutter/bin/flutter /usr/bin/flutter 2>/dev/null || true
  ln -sf /opt/flutter/bin/dart    /usr/bin/dart    2>/dev/null || true
fi

echo "  Flutter: $(which flutter 2>/dev/null || echo 'not found')"

""" + "pm2 start src/bot.js --name \"web2apknew\" 2>&1 | tail -6 || _fail \"pm2run\" \"pm2 start failed\"\n" + r"""
env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root 2>/dev/null | tail -2 || true
pm2 save >/dev/null 2>&1 || true
echo "  PM2 status:"
pm2 status
_ok "pm2run"

echo ""
echo "OTAX_INSTALL_COMPLETE"
""" + 'echo "URL: $finalUrl"\n' +
'echo "PORT: $appPort"\n' +
'echo "ADMIN: $_admins"\n' +
r"""rm -f /tmp/_w.b64 /tmp/_w.sh
""";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.0, 0.025),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: _formReady
              ? _buildTerminalView(key: const ValueKey('t'))
              : _buildFormView(key: const ValueKey('f')),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _textSub),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      _glowIcon(Icons.bolt_rounded, _cyan, size: 17),
      const SizedBox(width: 9),
      const Text(
        'Web2APK Installer',
        style: TextStyle(
          color: _text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ]),
    actions: [
      if (_logs.isNotEmpty)
        _iconBtn(Icons.content_copy_rounded, 'Salin log', _copyLogs),
      if (_formReady && !_running)
        _iconBtn(Icons.tune_rounded, 'Edit konfigurasi',
            () => setState(() { _formReady = false; _steps = _freshSteps(); })),
      const SizedBox(width: 4),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _border),
    ),
  );

  void _copyLogs() {
    Clipboard.setData(ClipboardData(
      text: _logs.map((e) => '[${_ts(e.ts)}] ${e.msg}').join('\n'),
    ));
    _snack('Log disalin ✓');
  }

  Widget _buildFormView({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _banner(),
          const SizedBox(height: 18),
          _formStepsPreview(),
          const SizedBox(height: 24),

          _formSection(Icons.dns_outlined, 'Koneksi VPS'),
          const SizedBox(height: 14),
          _lbl('IP Address VPS'),
          _fld(_ctrlIp, '123.45.67.89',
              icon: Icons.router_outlined, kb: TextInputType.url,
              val: _req('IP wajib diisi')),
          const SizedBox(height: 11),
          _lbl('Password Root SSH'),
          _pFld(_ctrlPass, 'password root', _showPass,
              () => setState(() => _showPass = !_showPass),
              val: _req('Password wajib diisi')),
          const SizedBox(height: 11),
          _lbl('Domain  (opsional — untuk Nginx)'),
          _fld(_ctrlDomain, 'tools.domain.com',
              icon: Icons.language_outlined, kb: TextInputType.url),
          const SizedBox(height: 26),

          _formSection(Icons.smart_toy_outlined, 'Konfigurasi Bot Telegram'),
          const SizedBox(height: 14),
          _lbl('BOT_TOKEN  ·  dari @BotFather'),
          _pFld(_ctrlToken, '1234567890:AABB…', _showToken,
              () => setState(() => _showToken = !_showToken),
              val: (v) {
                if (v!.trim().isEmpty) return 'Token wajib diisi';
                if (!v.contains(':')) return 'Format tidak valid (contoh: 123456:ABC…)';
                return null;
              }),
          const SizedBox(height: 11),
          _lbl('ADMIN_IDS  ·  Telegram User ID kamu'),
          _fld(_ctrlAdmin, '123456789',
              icon: Icons.manage_accounts_outlined, kb: TextInputType.number,
              val: _req('Admin ID wajib diisi')),
          const SizedBox(height: 11),
          _lbl('REQUIRED_CHANNEL  ·  opsional'),
          _fld(_ctrlChannel, '@nama_channel',
              icon: Icons.alternate_email_rounded),
          const SizedBox(height: 11),
          _lbl('WEB_URL  ·  opsional  (kosong = otomatis dari domain/IP)'),
          _fld(_ctrlUrl, 'https://tools.domain.com',
              icon: Icons.link_rounded, kb: TextInputType.url),
          const SizedBox(height: 26),

          _formSection(Icons.settings_ethernet_rounded, 'Konfigurasi Server'),
          const SizedBox(height: 14),
          _lbl('PORT  ·  default 3000'),
          _fld(_ctrlPort, '3000',
              icon: Icons.electrical_services_rounded, kb: TextInputType.number,
              val: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 65535) return 'Port tidak valid (1–65535)';
                return null;
              }),
          const SizedBox(height: 26),

          _warningCard(),
          const SizedBox(height: 20),
          _submitButton(),
        ]),
      ),
    );
  }

  Widget _banner() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border2),
      boxShadow: [BoxShadow(color: _cyan.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 4))],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_cyan.withOpacity(0.9), _blue],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OTAX Web2APK Auto-Installer',
            style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w700,
                letterSpacing: 0.2)),
        SizedBox(height: 6),
        Text(
          'Node.js 20 · Java 17 · Android SDK 34 · Flutter SDK\n'
          'Nginx · UFW · PM2 · Auto-edit .env · Custom Port',
          style: TextStyle(color: _textSub, fontSize: 12, height: 1.6),
        ),
      ])),
    ]),
  );

  Widget _formStepsPreview() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('11 LANGKAH OTOMATIS',
        style: TextStyle(color: _textMute, fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 1.2)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 5, runSpacing: 5,
      children: _freshSteps().map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.icon, color: _textMute, size: 11),
          const SizedBox(width: 5),
          Text(s.label, style: const TextStyle(color: _textSub, fontSize: 10.5)),
        ]),
      )).toList(),
    ),
  ]);

  Widget _formSection(IconData icon, String title) => Row(children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: _cyanDim, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cyan.withOpacity(0.2)),
      ),
      child: Icon(icon, color: _cyan, size: 15),
    ),
    const SizedBox(width: 10),
    Text(title,
        style: const TextStyle(color: _text, fontSize: 13.5, fontWeight: FontWeight.w600)),
  ]);

  Widget _warningCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _amber.withOpacity(0.05),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: _amber.withOpacity(0.18)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.schedule_rounded, color: _amber.withOpacity(0.85), size: 15),
      const SizedBox(width: 10),
      const Expanded(child: Text(
        'Estimasi waktu: 15–25 menit (termasuk Flutter)\n'
        'Jangan tutup aplikasi. Koneksi SSH dijaga otomatis tiap 25 detik.',
        style: TextStyle(color: _amber, fontSize: 12, height: 1.55),
      )),
    ]),
  );

  Widget _submitButton() => GestureDetector(
    onTap: () {
      if (_formKey.currentState!.validate()) {
        setState(() => _formReady = true);
      }
    },
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_cyan.withOpacity(0.85), _blue],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [BoxShadow(color: _cyan.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Lanjut ke Instalasi',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
      ]),
    ),
  );

  Widget _buildTerminalView({Key? key}) => Column(
    key: key,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: _serverBar(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: _progressBar(),
      ),
      SizedBox(
        height: 52,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          itemCount: _steps.length,
          itemBuilder: (_, i) => _stepChip(_steps[i]),
        ),
      ),
      Container(margin: const EdgeInsets.only(top: 6), height: 1, color: _border),
      Expanded(child: _terminalOutput()),
      _bottomBar(),
    ],
  );

  Widget _serverBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: _card, borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _border2),
    ),
    child: Row(children: [
      Row(children: [
        _wDot(const Color(0xFFFF5F57)),
        const SizedBox(width: 5),
        _wDot(const Color(0xFFFFBD2E)),
        const SizedBox(width: 5),
        _wDot(const Color(0xFF28C840)),
      ]),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('root@$_ip',
              style: const TextStyle(
                  color: _text, fontSize: 12.5, fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
          const SizedBox(width: 8),
          _pill(':$_port', _blueDim, _blue),
          if (_domain.isNotEmpty) ...[
            const SizedBox(width: 5),
            _pill(_domain, _cyanDim, _cyan),
          ],
        ]),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            _statusMsg.isEmpty ? 'Siap' : _statusMsg,
            key: ValueKey(_statusMsg),
            style: TextStyle(
              fontSize: 11,
              color: _finished && !_errored ? _green
                   : _errored ? _red
                   : _running ? _cyan : _textSub,
            ),
          ),
        ),
      ])),
      const SizedBox(width: 8),
      _statusBadge(),
    ]),
  );

  Widget _progressBar() => Row(children: [
    Text('$_doneCount/${_steps.length}',
        style: const TextStyle(color: _textSub, fontSize: 10.5)),
    const SizedBox(width: 10),
    Expanded(
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (_, __) {
          final v = _progressAnim.value;
          return Stack(children: [
            Container(height: 4, decoration: BoxDecoration(
              color: _card2, borderRadius: BorderRadius.circular(6),
            )),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _errored ? [_red, _red.withOpacity(0.6)]
                          : _finished ? [_green, _green.withOpacity(0.7)]
                          : [_cyan, _blue],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(
                    color: (_errored ? _red : _finished ? _green : _cyan).withOpacity(0.5),
                    blurRadius: 6,
                  )],
                ),
              ),
            ),
          ]);
        },
      ),
    ),
    const SizedBox(width: 10),
    AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, __) => Text(
        '${(_progressAnim.value * 100).round()}%',
        style: TextStyle(
          fontSize: 10.5, fontWeight: FontWeight.w600,
          color: _errored ? _red : _finished ? _green : _cyan,
        ),
      ),
    ),
  ]);

  Widget _stepChip(_Step s) {
    final Color fg;
    final Widget icn;

    switch (s.status) {
      case _SS.idle:
        fg  = _textMute;
        icn = Icon(s.icon, color: _textMute, size: 11);
        break;
      case _SS.running:
        fg  = _cyan;
        icn = AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Opacity(
            opacity: _pulseAnim.value,
            child: SizedBox(width: 11, height: 11,
                child: CircularProgressIndicator(strokeWidth: 1.4, color: _cyan)),
          ),
        );
        break;
      case _SS.done:
        fg  = _green;
        icn = const Icon(Icons.check_rounded, color: _green, size: 11);
        break;
      case _SS.failed:
        fg  = _red;
        icn = const Icon(Icons.close_rounded, color: _red, size: 11);
        break;
    }

    final isActive = s.status == _SS.running || s.status == _SS.done;

    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withOpacity(s.status == _SS.idle ? 0.0 : 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: fg.withOpacity(s.status == _SS.running ? 0.65 : 0.2),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icn,
        const SizedBox(width: 5),
        Text(s.label, style: TextStyle(
          color: isActive ? fg : _textSub,
          fontSize: 10.5,
          fontWeight: s.status == _SS.running ? FontWeight.w700 : FontWeight.normal,
        )),
      ]),
    );
  }

  Widget _terminalOutput() => Container(
    margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          const Icon(Icons.terminal_rounded, color: _textMute, size: 12),
          const SizedBox(width: 7),
          Text('shell output — $_ip:$_port',
              style: const TextStyle(color: _textMute, fontSize: 10.5,
                  fontFamily: 'monospace')),
          const Spacer(),
          Text('${_logs.length} lines',
              style: const TextStyle(color: _textMute, fontSize: 10)),
        ]),
      ),
      Expanded(
        child: _logs.isEmpty ? _emptyTerminal() : ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(10),
          itemCount: _logs.length,
          itemBuilder: (_, i) => _logRow(_logs[i]),
        ),
      ),
    ]),
  );

  Widget _logRow(_LogEntry e) {
    final color = _lcColor(e.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.1),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_ts(e.ts)} ',
            style: const TextStyle(color: _textMute, fontSize: 9.5,
                fontFamily: 'monospace')),
        if (e.type == _LT.step)
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _purple.withOpacity(0.3)),
            ),
            child: Text(e.msg, style: const TextStyle(color: _lcStep,
                fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          )
        else
          Expanded(child: Text(e.msg, style: TextStyle(
              color: color, fontSize: 10.5, fontFamily: 'monospace', height: 1.45))),
      ]),
    );
  }

  Widget _emptyTerminal() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Opacity(
          opacity: 0.15 + _pulseAnim.value * 0.25,
          child: const Icon(Icons.terminal_rounded, color: _textSub, size: 42),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Output SSH akan muncul di sini',
          style: TextStyle(color: _textSub, fontSize: 13)),
      const SizedBox(height: 5),
      const Text('Tekan tombol di bawah untuk memulai',
          style: TextStyle(color: _textMute, fontSize: 11.5)),
    ]),
  );

  Widget _bottomBar() {
    if (_finished && !_errored) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _greenDim, borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _green.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: _green.withOpacity(0.06), blurRadius: 16)],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _green.withOpacity(0.3)),
                ),
                child: const Icon(Icons.check_circle_rounded, color: _green, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Web2APK Berhasil Terinstall! 🎉',
                    style: TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _resolvedUrl));
                    _snack('URL disalin ✓');
                  },
                  child: Row(children: [
                    Expanded(child: Text(_resolvedUrl,
                        style: const TextStyle(color: _lcNorm, fontSize: 12,
                            fontFamily: 'monospace'))),
                    Icon(Icons.copy_rounded, color: _green.withOpacity(0.6), size: 14),
                  ]),
                ),
                const SizedBox(height: 3),
                Text('Admin ID: $_admins',
                    style: const TextStyle(color: _textSub, fontSize: 11.5)),
              ])),
            ]),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 15),
            label: const Text('Kembali'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSub,
              side: BorderSide(color: _border2),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ]),
      );
    }

    if (_errored) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: _redDim, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: _red, size: 15),
              const SizedBox(width: 9),
              const Text('Instalasi gagal — lihat log di atas',
                  style: TextStyle(color: _red, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _formReady = false;
                  _steps = _freshSteps();
                }),
                icon: const Icon(Icons.edit_rounded, size: 13),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSub, side: BorderSide(color: _border2),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(flex: 2, child: _actionBtn(
              'Coba Ulang', Icons.refresh_rounded,
              () { _sshCleanup(); _startInstall(); },
              color: _red,
            )),
          ]),
        ]),
      );
    }

    if (_running) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                _sshCleanup();
                setState(() { _running = false; _finished = true; _errored = true; });
                _addLog('✗ Dibatalkan oleh pengguna.', _LT.err);
              },
              icon: const Icon(Icons.stop_circle_outlined, size: 14, color: _textSub),
              label: const Text('Batalkan', style: TextStyle(color: _textSub, fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ),
          _actionBtn(
            'Sedang menginstall…  ($_doneCount/${_steps.length} langkah)',
            Icons.hourglass_top_rounded, null,
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: _actionBtn('Mulai Instalasi Sekarang',
          Icons.rocket_launch_rounded, _startInstall),
    );
  }

  Widget _statusBadge() {
    if (_running && !_finished)  return _badge('Installing', _cyan, spin: true);
    if (_finished && !_errored)  return _badge('Done', _green);
    if (_errored)                return _badge('Error', _red);
    return _badge('Idle', _textMute);
  }

  Widget _badge(String label, Color c, {bool spin = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (spin)
        SizedBox(width: 7, height: 7,
            child: CircularProgressIndicator(strokeWidth: 1.4, color: c))
      else
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: c, fontSize: 10.5,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap, {Color? color}) {
    final c = color ?? _cyan;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 50,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? LinearGradient(
                  colors: color != null
                      ? [c.withOpacity(0.8), c]
                      : [_cyan.withOpacity(0.85), _blue],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
              : null,
          color: onTap == null ? _card2 : null,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: onTap == null ? _border2 : Colors.transparent,
          ),
          boxShadow: onTap != null
              ? [BoxShadow(color: c.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_running && onTap == null)
            const SizedBox(width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white54))
          else
            Icon(icon, color: onTap != null ? Colors.white : _textSub, size: 17),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(
            color: onTap != null ? Colors.white : _textSub,
            fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.2,
          )),
        ]),
      ),
    );
  }

  Widget _glowIcon(IconData icon, Color color, {double size = 16}) => Container(
    width: 30, height: 30,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)],
    ),
    child: Icon(icon, color: color, size: size),
  );

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) =>
    IconButton(
      icon: Icon(icon, size: 16, color: _textSub),
      tooltip: tooltip,
      onPressed: onTap,
    );

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(color: _textSub, fontSize: 11.5,
        fontWeight: FontWeight.w500)),
  );

  String? Function(String?) _req(String msg) =>
      (v) => v!.trim().isEmpty ? msg : null;

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textMute, fontSize: 13),
    filled: true, fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _cyan.withOpacity(0.7), width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _red.withOpacity(0.5))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _red, width: 1.5)),
    errorStyle: const TextStyle(color: _red, fontSize: 11),
  );

  Widget _fld(TextEditingController c, String hint, {
    IconData? icon, TextInputType? kb, String? Function(String?)? val,
  }) => TextFormField(
    controller: c,
    style: const TextStyle(color: _text, fontSize: 13.5),
    keyboardType: kb,
    decoration: _deco(hint).copyWith(
      prefixIcon: icon != null ? Icon(icon, color: _textMute, size: 16) : null,
    ),
    validator: val,
  );

  Widget _pFld(TextEditingController c, String hint, bool vis, VoidCallback toggle,
      {String? Function(String?)? val}) =>
    TextFormField(
      controller: c, obscureText: !vis,
      style: const TextStyle(color: _text, fontSize: 13.5),
      decoration: _deco(hint).copyWith(
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _textMute, size: 16),
        suffixIcon: IconButton(
          icon: Icon(vis ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _textMute, size: 16),
          onPressed: toggle,
        ),
      ),
      validator: val,
    );

  Widget _wDot(Color c) => Container(
    width: 11, height: 11,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _pill(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 10.5)),
  );

  Color _lcColor(_LT t) {
    switch (t) {
      case _LT.ok:   return _lcOk;
      case _LT.err:  return _lcErr;
      case _LT.info: return _lcInfo;
      case _LT.sys:  return _lcSys;
      case _LT.step: return _lcStep;
      case _LT.norm: return _lcNorm;
    }
  }

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2,'0')}:'
      '${t.minute.toString().padLeft(2,'0')}:'
      '${t.second.toString().padLeft(2,'0')}';

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontSize: 13)),
    backgroundColor: _card2, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    margin: const EdgeInsets.all(14),
    duration: const Duration(seconds: 2),
  ));
}
