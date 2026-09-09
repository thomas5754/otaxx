package com.otax.ayun;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MLVpnCaptureService extends VpnService {

    private static final String TAG = "OTAXVpn";
    public static final String ACTION_START    = "com.otax.ayun.VPN_START";
    public static final String ACTION_STOP     = "com.otax.ayun.VPN_STOP";
    public static final String EXTRA_PACKAGES  = "target_packages";

    // ─── Game Database ────────────────────────────────────────────────────
    public static final Map<String, String[]> GAME_DB = new HashMap<String, String[]>() {{
        put("com.mobile.legends",                    new String[]{"Mobile Legends", "ml"});
        put("com.mobile.legends.indonesia",          new String[]{"Mobile Legends ID", "ml"});
        put("com.dts.freefireth",                    new String[]{"Free Fire", "ff"});
        put("com.dts.freefiremax",                   new String[]{"Free Fire MAX", "ff"});
        put("com.roblox.client",                     new String[]{"Roblox", "roblox"});
        put("com.tencent.ig",                        new String[]{"PUBG Mobile", "pubg"});
        put("com.pubg.imobile",                      new String[]{"PUBG Mobile (Global)", "pubg"});
        put("com.activision.callofduty.shooter",     new String[]{"COD Mobile", "cod"});
        put("com.miHoYo.GenshinImpact",              new String[]{"Genshin Impact", "genshin"});
        put("com.supercell.clashofclans",            new String[]{"Clash of Clans", "coc"});
        put("com.supercell.clashroyale",             new String[]{"Clash Royale", "cr"});
        put("com.HoYoverse.hkrpgoversea",           new String[]{"Honkai Star Rail", "hsr"});
        put("com.riotgames.league.wildrift",         new String[]{"Wild Rift", "wr"});
    }};

    // ─── Port Filters per game ───────────────────────────────────────────
    private static final Set<Integer> SKIP_PORTS = new HashSet<>(Arrays.asList(
        53, 80, 443, 123, 22, 25, 587, 993, 995, 8080, 8443, 3478, 3479
    ));

    private static final int MIN_GAME_PORT = 1024;

    // ─── Callbacks ────────────────────────────────────────────────────────
    public interface OnIPFoundListener {
        void onIPFound(String ip, int port, String gameName, String gamePackage);
    }
    public static volatile OnIPFoundListener ipFoundListener = null;
    public static volatile String activeGamePackage = "";
    public static volatile String activeGameName    = "";

    // ─── Flutter communication ────────────────────────────────────────────
    public static EventChannel.EventSink eventSink = null;
    public static MethodChannel methodChannel = null;

    // ─── State ────────────────────────────────────────────────────────────
    private String[] targetPackages = null;
    private volatile boolean running = false;
    private ParcelFileDescriptor tun = null;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private ExecutorService executor;

    private final ConcurrentHashMap<String, Socket>         tcpRelays  = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, DatagramSocket> udpRelays  = new ConcurrentHashMap<>();

    // IP per session — reset saat game mulai koneksi baru
    private final ConcurrentHashMap<String, String> reportedIPs = new ConcurrentHashMap<>();

    // Candidate tracking: hitung berapa kali IP:port muncul sebelum dilaporkan
    private final ConcurrentHashMap<String, Integer> ipHitCount = new ConcurrentHashMap<>();

    // ─── Cleanup handler untuk ipHitCount ─────────────────────────────────
    private Handler cleanupHandler = new Handler(Looper.getMainLooper());
    private Runnable cleanupTask = new Runnable() {
        @Override
        public void run() {
            ipHitCount.clear();
            Log.d(TAG, "Cleaned up ipHitCount");
            cleanupHandler.postDelayed(this, 5 * 60 * 1000); // setiap 5 menit
        }
    };

    // ─── Lifecycle ────────────────────────────────────────────────────────
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopCapture();
            return START_NOT_STICKY;
        }
        if (!running) {
            if (intent != null && intent.hasExtra(EXTRA_PACKAGES))
                targetPackages = intent.getStringArrayExtra(EXTRA_PACKAGES);
            startForegroundNotif();
            executor = Executors.newCachedThreadPool();
            startCapture();
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        stopCapture();
        super.onDestroy();
    }

    // ─── Start VPN ────────────────────────────────────────────────────────
    private void startCapture() {
        executor.submit(() -> {
            try {
                Builder b = new Builder();
                b.setSession("OTAX Scanner");
                b.addAddress("10.88.0.1", 30);
                b.addDnsServer("8.8.8.8");
                b.addRoute("0.0.0.0", 0);
                b.setMtu(1500);
                b.setBlocking(true);

                String[] pkgsToScan = (targetPackages != null && targetPackages.length > 0)
                    ? targetPackages
                    : GAME_DB.keySet().toArray(new String[0]);

                boolean anyAdded = false;
                for (String pkg : pkgsToScan) {
                    try {
                        b.addAllowedApplication(pkg);
                        anyAdded = true;
                    } catch (Exception ignored) {
                        // Package mungkin tidak terinstal
                    }
                }
                if (!anyAdded) b.addDisallowedApplication(getPackageName());

                tun = b.establish();
                if (tun == null) {
                    Log.e(TAG, "VPN establishment failed");
                    return;
                }
                running = true;
                Log.d(TAG, "VPN active");

                // Mulai cleanup berkala
                cleanupHandler.postDelayed(cleanupTask, 5 * 60 * 1000);

                readLoop();
            } catch (Exception e) {
                Log.e(TAG, "startCapture error: " + e.getMessage(), e);
            }
        });
    }

    // ─── Read Loop ────────────────────────────────────────────────────────
    private void readLoop() {
        FileInputStream  in  = new FileInputStream(tun.getFileDescriptor());
        FileOutputStream out = new FileOutputStream(tun.getFileDescriptor());
        byte[] buf = new byte[32767];
        try {
            while (running) {
                int len = in.read(buf);
                if (len <= 0) continue;
                dispatchPacket(Arrays.copyOf(buf, len), len, out);
            }
        } catch (Exception e) {
            if (running) Log.e(TAG, "readLoop error: " + e.getMessage());
        } finally {
            closeAll();
        }
    }

    // ─── Packet Dispatch ──────────────────────────────────────────────────
    private void dispatchPacket(byte[] pkt, int len, FileOutputStream tunOut) {
        if (len < 20) return;
        int version = (pkt[0] >> 4) & 0xF;
        if (version != 4) return;

        int ihl      = (pkt[0] & 0xF) * 4;
        int protocol = pkt[9] & 0xFF;  // 6=TCP 17=UDP
        int totalLen = ((pkt[2] & 0xFF) << 8) | (pkt[3] & 0xFF);
        if (ihl < 20 || len < ihl + 4 || totalLen > len) return;

        String dstIP = (pkt[16]&0xFF)+"."+(pkt[17]&0xFF)+"."+(pkt[18]&0xFF)+"."+(pkt[19]&0xFF);
        String srcIP = (pkt[12]&0xFF)+"."+(pkt[13]&0xFF)+"."+(pkt[14]&0xFF)+"."+(pkt[15]&0xFF);
        int srcPort  = ((pkt[ihl]   & 0xFF) << 8) | (pkt[ihl+1] & 0xFF);
        int dstPort  = ((pkt[ihl+2] & 0xFF) << 8) | (pkt[ihl+3] & 0xFF);

        // Filter 1: Skip IP privat/loopback
        if (isPrivate(dstIP)) {
            forwardOnly(pkt, len, ihl, protocol, srcIP, srcPort, dstIP, dstPort, tunOut);
            return;
        }

        // Filter 2: Skip port yang jelas BUKAN game server
        boolean isGamePort = dstPort >= MIN_GAME_PORT && !SKIP_PORTS.contains(dstPort);

        if (isGamePort) {
            // Filter 3: Confidence counter
            String candidateKey = dstIP + ":" + dstPort;
            int hits = ipHitCount.getOrDefault(candidateKey, 0) + 1;
            ipHitCount.put(candidateKey, hits);

            String gameKey  = activeGamePackage.isEmpty() ? "unknown" : activeGamePackage;
            String prevIP   = reportedIPs.get(gameKey);
            boolean isNew   = !candidateKey.equals(prevIP);

            if (hits >= 2 && isNew) {
                reportedIPs.put(gameKey, candidateKey);
                final String ip   = dstIP;
                final int    port = dstPort;
                final String gPkg = activeGamePackage;
                final String gName = activeGameName.isEmpty() ? "Game" : activeGameName;

                Log.d(TAG, "🎯 GAME SERVER: " + ip + ":" + port + " (" + gName + ")");

                // Kirim ke listener lokal (misal ke MainActivity)
                mainHandler.post(() -> {
                    if (ipFoundListener != null) {
                        ipFoundListener.onIPFound(ip, port, gName, gPkg);
                    }
                });

                // Kirim ke Flutter via EventChannel
                if (eventSink != null) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("type", "ip_found");
                    map.put("ip", ip);
                    map.put("port", port);
                    map.put("game_name", gName);
                    map.put("game_package", gPkg);
                    eventSink.success(map);
                }
            }
        }

        // Relay semua packet agar koneksi tidak putus
        final byte[] fp = pkt;
        final int fl = len;
        final int fi = ihl;
        final String fd = dstIP;
        final int fdp = dstPort;
        final String fs = srcIP;
        final int fsp = srcPort;

        if (protocol == 6) {
            executor.submit(() -> handleTCP(fp, fl, fi, fs, fsp, fd, fdp, tunOut));
        } else if (protocol == 17) {
            executor.submit(() -> handleUDP(fp, fl, fi, fsp, fd, fdp, tunOut));
        }
    }

    // Forward packet tanpa inspect (private IP / well-known port)
    private void forwardOnly(byte[] pkt, int len, int ihl, int protocol,
                              String srcIP, int srcPort, String dstIP, int dstPort,
                              FileOutputStream tunOut) {
        final byte[] fp=pkt; final int fl=len; final int fi=ihl;
        final String fd=dstIP; final int fdp=dstPort;
        final String fs=srcIP; final int fsp=srcPort;
        if (protocol == 6) {
            executor.submit(() -> handleTCP(fp, fl, fi, fs, fsp, fd, fdp, tunOut));
        } else if (protocol == 17) {
            executor.submit(() -> handleUDP(fp, fl, fi, fsp, fd, fdp, tunOut));
        }
    }

    // ─── TCP Relay ─────────────────────────────────────────────────────────
    private void handleTCP(byte[] pkt, int len, int ihl,
                            String srcIP, int srcPort,
                            String dstIP, int dstPort, FileOutputStream tunOut) {
        int flags  = pkt[ihl+13] & 0xFF;
        boolean isSYN = (flags & 0x02) != 0;
        boolean isFIN = (flags & 0x01) != 0;
        boolean isRST = (flags & 0x04) != 0;
        String key = srcIP+":"+srcPort+"→"+dstIP+":"+dstPort;

        if (isSYN && !tcpRelays.containsKey(key)) {
            try {
                Socket sock = new Socket();
                protect(sock);
                sock.connect(new InetSocketAddress(dstIP, dstPort), 5000);
                sock.setKeepAlive(true);
                tcpRelays.put(key, sock);
                final Socket fs = sock;
                final String fsi=srcIP; final int fsp=srcPort;
                final String fdi=dstIP; final int fdp=dstPort;
                executor.submit(() -> {
                    try {
                        InputStream si = fs.getInputStream();
                        byte[] rb = new byte[32767];
                        int rl;
                        while ((rl = si.read(rb)) > 0) {
                            byte[] resp = buildTCPPacket(rb, rl, fdi, fdp, fsi, fsp, 0x18);
                            if (resp != null) {
                                synchronized(tunOut) {
                                    tunOut.write(resp);
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.v(TAG, "TCP relay read error: " + e.getMessage());
                    } finally {
                        tcpRelays.remove(key);
                        try { fs.close(); } catch (Exception ignored) {}
                    }
                });
            } catch (Exception e) {
                Log.v(TAG, "TCP connect error: " + e.getMessage());
            }
        }
        if (isFIN || isRST) {
            Socket s = tcpRelays.remove(key);
            if (s != null) {
                try { s.close(); } catch (Exception ignored) {}
            }
            return;
        }
        Socket sock = tcpRelays.get(key);
        if (sock == null || sock.isClosed()) return;
        int tcpHLen    = ((pkt[ihl+12]>>4)&0xF)*4;
        int dataOffset = ihl + tcpHLen;
        int dataLen    = len - dataOffset;
        if (dataLen <= 0) return;
        try {
            OutputStream so = sock.getOutputStream();
            so.write(pkt, dataOffset, dataLen);
            so.flush();
        } catch (Exception e) {
            tcpRelays.remove(key);
            Log.v(TAG, "TCP write error: " + e.getMessage());
        }
    }

    // ─── UDP Relay ─────────────────────────────────────────────────────────
    private void handleUDP(byte[] pkt, int len, int ihl,
                           int srcPort, String dstIP, int dstPort, FileOutputStream tunOut) {
        int payloadOffset = ihl + 8;
        int payloadLen    = len - payloadOffset;
        if (payloadLen <= 0) return;
        String key = srcPort+"→"+dstIP+":"+dstPort;
        DatagramSocket sock = udpRelays.get(key);
        if (sock == null || sock.isClosed()) {
            try {
                sock = new DatagramSocket();
                protect(sock);
                udpRelays.put(key, sock);
                final DatagramSocket fs = sock;
                final int fsp = srcPort;
                final String fdi = dstIP;
                final int fdp = dstPort;
                executor.submit(() -> {
                    byte[] rb = new byte[32767];
                    try {
                        while (!fs.isClosed()) {
                            DatagramPacket dp = new DatagramPacket(rb, rb.length);
                            fs.receive(dp);
                            byte[] resp = buildUDPPacket(dp.getData(), dp.getLength(),
                                dp.getAddress().getHostAddress(), dp.getPort(), "10.88.0.1", fsp);
                            if (resp != null) {
                                synchronized(tunOut) {
                                    tunOut.write(resp);
                                }
                            }
                        }
                    } catch (Exception e) {
                        Log.v(TAG, "UDP relay receive error: " + e.getMessage());
                    } finally {
                        udpRelays.remove(key);
                    }
                });
            } catch (Exception e) {
                Log.v(TAG, "UDP socket creation error: " + e.getMessage());
                return;
            }
        }
        try {
            DatagramPacket dp = new DatagramPacket(pkt, payloadOffset, payloadLen,
                InetAddress.getByName(dstIP), dstPort);
            sock.send(dp);
        } catch (Exception e) {
            Log.v(TAG, "UDP send error: " + e.getMessage());
        }
    }

    // ─── Packet Builders ─────────────────────────────────────────────────
    private byte[] buildTCPPacket(byte[] payload, int pLen,
                                   String srcIP, int srcPort, String dstIP, int dstPort, int flags) {
        try {
            int tot = 40 + pLen;
            byte[] p = new byte[tot];
            p[0] = 0x45;
            p[2] = (byte)((tot>>8) & 0xFF);
            p[3] = (byte)(tot & 0xFF);
            p[4] = 0;
            p[5] = 1;
            p[6] = 0x40;
            p[8] = 0x40;
            p[9] = 0x06;
            fillIP(p,12,srcIP);
            fillIP(p,16,dstIP);
            int ck = checksum(p,0,20);
            p[10] = (byte)((ck>>8) & 0xFF);
            p[11] = (byte)(ck & 0xFF);
            p[20] = (byte)((srcPort>>8) & 0xFF);
            p[21] = (byte)(srcPort & 0xFF);
            p[22] = (byte)((dstPort>>8) & 0xFF);
            p[23] = (byte)(dstPort & 0xFF);
            p[32] = 0x50;
            p[33] = (byte)(flags & 0xFF);
            p[34] = (byte)0xFF;
            p[35] = (byte)0xFF;
            System.arraycopy(payload,0,p,40,pLen);
            return p;
        } catch (Exception e) {
            Log.e(TAG, "buildTCPPacket error: " + e.getMessage());
            return null;
        }
    }

    private byte[] buildUDPPacket(byte[] payload, int pLen,
                                   String srcIP, int srcPort, String dstIP, int dstPort) {
        try {
            int tot = 28 + pLen;
            byte[] p = new byte[tot];
            p[0] = 0x45;
            p[2] = (byte)((tot>>8) & 0xFF);
            p[3] = (byte)(tot & 0xFF);
            p[6] = 0x40;
            p[8] = 0x40;
            p[9] = 0x11;
            fillIP(p,12,srcIP);
            fillIP(p,16,dstIP);
            int ck = checksum(p,0,20);
            p[10] = (byte)((ck>>8) & 0xFF);
            p[11] = (byte)(ck & 0xFF);
            p[20] = (byte)((srcPort>>8) & 0xFF);
            p[21] = (byte)(srcPort & 0xFF);
            p[22] = (byte)((dstPort>>8) & 0xFF);
            p[23] = (byte)(dstPort & 0xFF);
            int ul = 8 + pLen;
            p[24] = (byte)((ul>>8) & 0xFF);
            p[25] = (byte)(ul & 0xFF);
            System.arraycopy(payload,0,p,28,pLen);
            return p;
        } catch (Exception e) {
            Log.e(TAG, "buildUDPPacket error: " + e.getMessage());
            return null;
        }
    }

    private void fillIP(byte[] p, int o, String ip) {
        try {
            String[] s = ip.split("\\.");
            p[o] = (byte)Integer.parseInt(s[0]);
            p[o+1] = (byte)Integer.parseInt(s[1]);
            p[o+2] = (byte)Integer.parseInt(s[2]);
            p[o+3] = (byte)Integer.parseInt(s[3]);
        } catch (Exception e) {
            Log.e(TAG, "fillIP error: " + e.getMessage());
        }
    }

    private int checksum(byte[] buf, int off, int len) {
        int sum = 0;
        for (int i=off; i<off+len-1; i+=2) {
            sum += ((buf[i] & 0xFF) << 8) | (buf[i+1] & 0xFF);
        }
        if (len % 2 != 0) {
            sum += (buf[off+len-1] & 0xFF) << 8;
        }
        while ((sum >> 16) != 0) {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }
        return ~sum & 0xFFFF;
    }

    private boolean isPrivate(String ip) {
        if (ip == null) return true;
        return ip.startsWith("10.88.") || ip.startsWith("127.") || ip.startsWith("0.")
            || ip.startsWith("10.") || ip.startsWith("192.168.") || ip.startsWith("169.254.")
            || ip.startsWith("100.64.") || ip.startsWith("198.18.");
    }

    // ─── Public method untuk Flutter (dipanggil via MethodChannel) ────────
    public void setActiveGame(String packageName, String gameName) {
        activeGamePackage = packageName;
        activeGameName = gameName;
        Log.d(TAG, "Active game set to: " + gameName + " (" + packageName + ")");
    }

    // ─── Stop ─────────────────────────────────────────────────────────────
    private void stopCapture() {
        running = false;
        cleanupHandler.removeCallbacks(cleanupTask);
        for (Socket s : tcpRelays.values()) {
            try { s.close(); } catch (Exception ignored) {}
        }
        for (DatagramSocket s : udpRelays.values()) {
            try { s.close(); } catch (Exception ignored) {}
        }
        tcpRelays.clear();
        udpRelays.clear();
        reportedIPs.clear();
        ipHitCount.clear();
        if (tun != null) {
            try { tun.close(); } catch (Exception ignored) {}
            tun = null;
        }
        if (executor != null) {
            executor.shutdownNow();
            executor = null;
        }
        ipFoundListener = null;
        activeGamePackage = "";
        activeGameName = "";
        // Jangan set eventSink = null di sini, biarkan channel mengelola
        stopForeground(true);
        stopSelf();
    }

    private void closeAll() {
        stopCapture();
    }

    private void startForegroundNotif() {
        String ch = "otax_vpn";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel nc = new NotificationChannel(ch, "OTAX Scanner", NotificationManager.IMPORTANCE_LOW);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(nc);
        }
        Notification n = new Notification.Builder(this, ch)
            .setSmallIcon(android.R.drawable.ic_lock_power_off)
            .setContentTitle("OTAX — Game Scanner")
            .setContentText("Mendeteksi IP server game...")
            .setOngoing(true)
            .build();
        startForeground(1338, n);
    }
}