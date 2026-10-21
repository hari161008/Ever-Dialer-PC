import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CallType { incoming, outgoing, missed }

class SyncedContact {
  final String id;
  final String name;
  final String phone;
  final bool isFavorite;
  final String? account;

  const SyncedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.isFavorite = false,
    this.account,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory SyncedContact.fromJson(Map<String, dynamic> json) {
    return SyncedContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString() ?? '',
      isFavorite: json['isFavorite'] == true,
      account: json['account']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'isFavorite': isFavorite,
    'account': account,
  };
}

class SyncedCallLog {
  final String id;
  final String name;
  final String number;
  final CallType type;
  final DateTime timestamp;
  final Duration duration;
  final int simSlot;

  const SyncedCallLog({
    required this.id,
    required this.name,
    required this.number,
    required this.type,
    required this.timestamp,
    required this.duration,
    this.simSlot = 1,
  });

  factory SyncedCallLog.fromJson(Map<String, dynamic> json) {
    CallType parsedType = CallType.incoming;
    final rawType = json['type'];
    if (rawType is String) {
      if (rawType.toLowerCase() == 'outgoing') {
        parsedType = CallType.outgoing;
      } else if (rawType.toLowerCase() == 'missed') {
        parsedType = CallType.missed;
      }
    } else if (rawType is int) {
      // Android CallLog.Calls.INCOMING_TYPE = 1, OUTGOING_TYPE = 2, MISSED_TYPE = 3
      if (rawType == 2) {
        parsedType = CallType.outgoing;
      } else if (rawType == 3) {
        parsedType = CallType.missed;
      }
    }

    DateTime time = DateTime.now();
    final rawTime = json['timestamp'] ?? json['date'];
    if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    int durSec = 0;
    final rawDur = json['duration'];
    if (rawDur is int) {
      durSec = rawDur;
    } else if (rawDur is String) {
      durSec = int.tryParse(rawDur) ?? 0;
    }

    return SyncedCallLog(
      id: json['id']?.toString() ?? '${json['number']}_$rawTime',
      name: json['name']?.toString() ?? (json['number']?.toString() ?? 'Unknown'),
      number: json['number']?.toString() ?? '',
      type: parsedType,
      timestamp: time,
      duration: Duration(seconds: durSec),
      simSlot: (json['simSlot'] is int) ? (json['simSlot'] as int) + 1 : 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'type': type.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'duration': duration.inSeconds,
    'simSlot': simSlot,
  };
}

class SyncedSmsMessage {
  final String id;
  final String body;
  final DateTime timestamp;
  final bool isOutgoing;

  const SyncedSmsMessage({
    required this.id,
    required this.body,
    required this.timestamp,
    required this.isOutgoing,
  });

  factory SyncedSmsMessage.fromJson(Map<String, dynamic> json) {
    DateTime time = DateTime.now();
    final rawTime = json['timestamp'] ?? json['date'];
    if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    return SyncedSmsMessage(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      timestamp: time,
      isOutgoing: json['isOutgoing'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isOutgoing': isOutgoing,
  };
}

class SyncedSmsThread {
  final String id;
  final String contactName;
  final String phone;
  final String snippet;
  final DateTime timestamp;
  final int unreadCount;
  final List<SyncedSmsMessage> messages;

  const SyncedSmsThread({
    required this.id,
    required this.contactName,
    required this.phone,
    required this.snippet,
    required this.timestamp,
    this.unreadCount = 0,
    required this.messages,
  });

  factory SyncedSmsThread.fromJson(Map<String, dynamic> json) {
    DateTime time = DateTime.now();
    final rawTime = json['timestamp'] ?? json['date'];
    if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    final msgs = <SyncedSmsMessage>[];
    if (json['messages'] is List) {
      for (final m in json['messages'] as List) {
        if (m is Map<String, dynamic>) {
          msgs.add(SyncedSmsMessage.fromJson(m));
        }
      }
    }

    return SyncedSmsThread(
      id: json['id']?.toString() ?? (json['threadId']?.toString() ?? ''),
      contactName: json['contactName']?.toString() ?? (json['address']?.toString() ?? 'Unknown'),
      phone: json['phone']?.toString() ?? (json['address']?.toString() ?? ''),
      snippet: json['snippet']?.toString() ?? (msgs.isNotEmpty ? msgs.last.body : ''),
      timestamp: time,
      unreadCount: (json['unreadCount'] is int) ? json['unreadCount'] as int : 0,
      messages: msgs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactName': contactName,
    'phone': phone,
    'snippet': snippet,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'unreadCount': unreadCount,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}

class SyncedNote {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;

  const SyncedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  SyncedNote copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
  }) {
    return SyncedNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory SyncedNote.fromJson(Map<String, dynamic> json) {
    DateTime time = DateTime.now();
    final rawTime = json['timestamp'] ?? json['lastModified'];
    if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? DateTime.now();
    }

    return SyncedNote(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? (json['contactName']?.toString() ?? 'Note'),
      content: json['content']?.toString() ?? '',
      timestamp: time,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

class PcSyncService extends ChangeNotifier {
  static const _prefPcSyncEnabledKey = 'pc_sync_enabled';
  static const _prefCachedDataKey = 'pc_sync_cached_data_v2';

  SharedPreferences? _prefs;
  bool _pcSyncEnabled = false;
  bool get pcSyncEnabled => _pcSyncEnabled;

  // Real connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Real phone data (NO fake/unsaved contacts)
  List<SyncedContact> _contacts = [];
  List<SyncedCallLog> _callLogs = [];
  List<SyncedSmsThread> _smsThreads = [];
  List<SyncedNote> _notes = [];

  List<SyncedContact> get contacts => List.unmodifiable(_contacts);
  List<SyncedContact> get favourites =>
      List.unmodifiable(_contacts.where((c) => c.isFavorite));
  List<SyncedCallLog> get callLogs => List.unmodifiable(_callLogs);
  List<SyncedSmsThread> get smsThreads => List.unmodifiable(_smsThreads);
  List<SyncedNote> get notes => List.unmodifiable(_notes);

  Process? _daemonProcess;
  StreamSubscription? _stdoutSub;

  PcSyncService({SharedPreferences? prefs}) {
    _prefs = prefs;
    if (_prefs != null) {
      _pcSyncEnabled = _prefs!.getBool(_prefPcSyncEnabledKey) ?? false;
    }
    _init();
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final saved = _prefs?.getBool(_prefPcSyncEnabledKey) ?? false;
    if (saved != _pcSyncEnabled) {
      _pcSyncEnabled = saved;
      notifyListeners();
    }

    _loadCachedData();

    if (_pcSyncEnabled) {
      _startBluetoothDaemon();
    }
  }

  void _loadCachedData() {
    final cached = _prefs?.getString(_prefCachedDataKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          _applyPayload(decoded, saveCache: false);
        }
      } catch (e) {
        debugPrint('[PcSyncService] Error loading cached sync data: $e');
      }
    }
  }

  void _saveCachedData() {
    if (_prefs == null) return;
    try {
      final payload = {
        'contacts': _contacts.map((c) => c.toJson()).toList(),
        'callLogs': _callLogs.map((c) => c.toJson()).toList(),
        'smsThreads': _smsThreads.map((t) => t.toJson()).toList(),
        'notes': _notes.map((n) => n.toJson()).toList(),
        'lastSyncTime': _lastSyncTime?.millisecondsSinceEpoch,
        'deviceName': _connectedDeviceName,
      };
      _prefs?.setString(_prefCachedDataKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('[PcSyncService] Error saving sync cache: $e');
    }
  }

  Future<void> setPcSyncEnabled(bool enabled) async {
    _pcSyncEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_prefPcSyncEnabledKey, enabled);

    if (enabled) {
      _startBluetoothDaemon();
    } else {
      _stopBluetoothDaemon();
    }
    notifyListeners();
  }

  void _startBluetoothDaemon() {
    _stopBluetoothDaemon();

    final scriptPath =
        '${File(Platform.resolvedExecutable).parent.path}/../lib/services/scripts/bt_sync_daemon.py';

    // Fallback path if running in debug or flutter run
    final candidatePaths = [
      'lib/services/scripts/bt_sync_daemon.py',
      scriptPath,
      '/home/hari/Computer Apps/Ever Dialer For PC/lib/services/scripts/bt_sync_daemon.py',
    ];

    String? validScript;
    for (final p in candidatePaths) {
      if (File(p).existsSync()) {
        validScript = p;
        break;
      }
    }

    if (validScript == null) {
      debugPrint('[PcSyncService] Cannot find bt_sync_daemon.py');
      return;
    }

    try {
      Process.runSync('pkill', ['-f', 'bt_sync_daemon.py']);
    } catch (_) {}

    try {
      Process.start('python3', [validScript]).then((process) {
        _daemonProcess = process;
        debugPrint('[PcSyncService] Started Bluetooth Sync Daemon (PID ${process.pid})');

        _stdoutSub = process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_onDaemonLine, onError: (err) {
              debugPrint('[PcSyncService] Daemon stdout error: $err');
            });

        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              debugPrint('[Daemon STDERR] $line');
            });

        process.exitCode.then((code) {
          debugPrint('[PcSyncService] Daemon exited with code $code');
          _isConnected = false;
          _daemonProcess = null;
          notifyListeners();
        });
      }).catchError((e) {
        debugPrint('[PcSyncService] Failed to spawn sync daemon: $e');
      });
    } catch (e) {
      debugPrint('[PcSyncService] Exception starting daemon: $e');
    }
  }

  void _onDaemonLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final data = jsonDecode(line);
      if (data is! Map<String, dynamic>) return;

      final event = data['event'];
      if (event == 'status') {
        _isConnected = data['connected'] == true;
        if (data['device'] != null) {
          _connectedDeviceName = data['device'].toString();
        }
        notifyListeners();
      } else if (event == 'sync_data') {
        final payload = data['payload'];
        if (payload is Map<String, dynamic>) {
          updateFromPayload(payload);
        }
      }
    } catch (e) {
      debugPrint('[PcSyncService] Error processing daemon output: $e');
    }
  }

  void _stopBluetoothDaemon() {
    _stdoutSub?.cancel();
    _stdoutSub = null;
    if (_daemonProcess != null) {
      try {
        _daemonProcess?.kill(ProcessSignal.sigterm);
      } catch (_) {}
      _daemonProcess = null;
    }
    _isConnected = false;
  }

  void updateFromPayload(Map<String, dynamic> payload) {
    _applyPayload(payload, saveCache: true);
    notifyListeners();
  }

  void _applyPayload(Map<String, dynamic> payload, {bool saveCache = true}) {
    // 1. Contacts
    if (payload.containsKey('contacts')) {
      final list = payload['contacts'];
      if (list is List) {
        _contacts = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedContact.fromJson(item))
            .toList();
      } else {
        _contacts = [];
      }
    }

    // 2. Call Logs
    if (payload.containsKey('callLogs')) {
      final list = payload['callLogs'];
      if (list is List) {
        _callLogs = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedCallLog.fromJson(item))
            .toList();
      } else {
        _callLogs = [];
      }
    }

    // 3. SMS Threads
    if (payload.containsKey('smsThreads')) {
      final list = payload['smsThreads'];
      if (list is List) {
        _smsThreads = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedSmsThread.fromJson(item))
            .toList();
      } else {
        _smsThreads = [];
      }
    }

    // 4. Notes
    if (payload.containsKey('notes')) {
      final list = payload['notes'];
      if (list is List) {
        _notes = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedNote.fromJson(item))
            .toList();
      } else {
        _notes = [];
      }
    }

    if (payload.containsKey('deviceName')) {
      _connectedDeviceName = payload['deviceName']?.toString();
    }

    _lastSyncTime = DateTime.now();

    if (saveCache) {
      _saveCachedData();
    }
  }

  void requestSyncNow() {
    _sendCommand({'cmd': 'request_sync'});
  }

  void addNote(String title, String content) {
    final note = SyncedNote(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Untitled Note' : title.trim(),
      content: content.trim(),
      timestamp: DateTime.now(),
    );
    _notes.insert(0, note);
    _saveCachedData();
    notifyListeners();

    _sendCommand({
      'cmd': 'add_note',
      'title': note.title,
      'content': note.content,
    });
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _saveCachedData();
    notifyListeners();

    _sendCommand({
      'cmd': 'delete_note',
      'id': id,
    });
  }

  Future<void> makeCall(String phoneNumber) async {
    final clean = phoneNumber.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    debugPrint('[PcSyncService] makeCall requested for $clean (isConnected: $_isConnected)');

    // 1. Send command via Bluetooth sync daemon
    _sendCommand({
      'cmd': 'make_call',
      'number': clean,
    });

    // 2. Fallback via ADB if Bluetooth is not connected
    if (!_isConnected) {
      try {
        await Process.run('adb', [
          'shell',
          'am',
          'start',
          '-a',
          'android.intent.action.CALL',
          '-d',
          'tel:$clean',
        ]);
      } catch (e) {
        debugPrint('[PcSyncService] ADB makeCall fallback error: $e');
      }
    }
  }

  void sendMessage(String threadId, String text) {
    if (text.trim().isEmpty) return;
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _smsThreads[index];
      final newMsg = SyncedSmsMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        body: text.trim(),
        timestamp: DateTime.now(),
        isOutgoing: true,
      );
      final updatedMessages = List<SyncedSmsMessage>.from(thread.messages)..add(newMsg);
      final updatedThread = SyncedSmsThread(
        id: thread.id,
        contactName: thread.contactName,
        phone: thread.phone,
        snippet: text.trim(),
        timestamp: DateTime.now(),
        unreadCount: 0,
        messages: updatedMessages,
      );
      _smsThreads.removeAt(index);
      _smsThreads.insert(0, updatedThread);
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'send_sms',
        'threadId': threadId,
        'phone': thread.phone,
        'text': text.trim(),
      });

      if (!_isConnected) {
        try {
          Process.run('adb', [
            'shell',
            'am',
            'start',
            '-a',
            'android.intent.action.SENDTO',
            '-d',
            'sms:${thread.phone}',
            '--es',
            'sms_body',
            text.trim(),
          ]);
        } catch (_) {}
      }
    }
  }

  Future<void> sendSmsToNumber(String phone, String text) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty || text.trim().isEmpty) return;
    final index = _smsThreads.indexWhere((t) =>
        t.phone.replaceAll(RegExp(r'[^\d+]'), '') ==
        cleanPhone.replaceAll(RegExp(r'[^\d+]'), ''));
    if (index != -1) {
      sendMessage(_smsThreads[index].id, text);
    } else {
      final newThread = SyncedSmsThread(
        id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
        contactName: cleanPhone,
        phone: cleanPhone,
        snippet: text.trim(),
        timestamp: DateTime.now(),
        unreadCount: 0,
        messages: [
          SyncedSmsMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            body: text.trim(),
            timestamp: DateTime.now(),
            isOutgoing: true,
          ),
        ],
      );
      _smsThreads.insert(0, newThread);
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'send_sms',
        'phone': cleanPhone,
        'text': text.trim(),
      });

      if (!_isConnected) {
        try {
          await Process.run('adb', [
            'shell',
            'am',
            'start',
            '-a',
            'android.intent.action.SENDTO',
            '-d',
            'sms:$cleanPhone',
            '--es',
            'sms_body',
            text.trim(),
          ]);
        } catch (_) {}
      }
    }
  }

  void toggleFavorite(String contactId) {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      final contact = _contacts[index];
      _contacts[index] = SyncedContact(
        id: contact.id,
        name: contact.name,
        phone: contact.phone,
        isFavorite: !contact.isFavorite,
        account: contact.account,
      );
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'toggle_favorite',
        'contactId': contactId,
        'isFavorite': _contacts[index].isFavorite,
      });
    }
  }

  void deleteCallLog(String id) {
    final index = _callLogs.indexWhere((l) => l.id == id);
    if (index != -1) {
      final removed = _callLogs.removeAt(index);
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'delete_call_log',
        'id': id,
        'number': removed.number,
      });
    }
  }

  void deleteSmsThread(String threadId) {
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final removed = _smsThreads.removeAt(index);
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'delete_sms_thread',
        'threadId': threadId,
        'phone': removed.phone,
      });
    }
  }

  void toggleSmsRead(String threadId) {
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _smsThreads[index];
      final newUnread = thread.unreadCount > 0 ? 0 : 1;
      _smsThreads[index] = SyncedSmsThread(
        id: thread.id,
        contactName: thread.contactName,
        phone: thread.phone,
        snippet: thread.snippet,
        timestamp: thread.timestamp,
        unreadCount: newUnread,
        messages: thread.messages,
      );
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'mark_sms_read',
        'threadId': threadId,
        'read': newUnread == 0,
      });
    }
  }

  void editNote(String id, String title, String content) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = SyncedNote(
        id: id,
        title: title.trim().isEmpty ? 'Untitled Note' : title.trim(),
        content: content.trim(),
        timestamp: DateTime.now(),
      );
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'edit_note',
        'id': id,
        'title': title.trim(),
        'content': content.trim(),
      });
    }
  }

  void blockNumber(String number) {
    final clean = number.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;

    _sendCommand({
      'cmd': 'block_number',
      'number': clean,
    });
  }

  void _sendCommand(Map<String, dynamic> cmd) {
    if (_daemonProcess != null) {
      try {
        _daemonProcess?.stdin.writeln(jsonEncode(cmd));
        _daemonProcess?.stdin.flush();
      } catch (e) {
        debugPrint('[PcSyncService] Error sending command to daemon: $e');
      }
    }
  }

  @override
  void dispose() {
    _stopBluetoothDaemon();
    super.dispose();
  }
}
