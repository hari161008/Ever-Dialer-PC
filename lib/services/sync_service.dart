import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CallType { incoming, outgoing, missed }

class SyncedContactPhone {
  final String number;
  final int type;
  final String label;

  const SyncedContactPhone({
    required this.number,
    this.type = 2,
    this.label = 'Mobile',
  });

  factory SyncedContactPhone.fromJson(Map<String, dynamic> json) {
    return SyncedContactPhone(
      number: json['number']?.toString() ?? '',
      type: json['type'] is int ? json['type'] as int : 2,
      label: json['label']?.toString() ?? 'Mobile',
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'type': type,
    'label': label,
  };
}

class SyncedContact {
  final String id;
  final String name;
  final String phone;
  final bool isFavorite;
  final String? account;
  final String? photoBase64;
  final List<SyncedContactPhone> phones;
  final List<String> emails;
  final List<String> addresses;
  final List<String> sourceAccounts;
  final String? note;

  const SyncedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.isFavorite = false,
    this.account,
    this.photoBase64,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.sourceAccounts = const [],
    this.note,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory SyncedContact.fromJson(Map<String, dynamic> json) {
    List<SyncedContactPhone> parsedPhones = [];
    if (json['phones'] is List) {
      parsedPhones = (json['phones'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => SyncedContactPhone.fromJson(p))
          .toList();
    }
    final rawPhone = json['phone']?.toString() ?? '';
    if (parsedPhones.isEmpty && rawPhone.isNotEmpty) {
      parsedPhones = [SyncedContactPhone(number: rawPhone, label: 'Mobile')];
    }

    List<String> parsedEmails = [];
    if (json['emails'] is List) {
      parsedEmails = (json['emails'] as List).map((e) => e.toString()).toList();
    }

    List<String> parsedAddresses = [];
    if (json['addresses'] is List) {
      parsedAddresses = (json['addresses'] as List).map((a) => a.toString()).toList();
    }

    List<String> parsedAccounts = [];
    if (json['accounts'] is List) {
      parsedAccounts = (json['accounts'] as List).map((a) => a.toString()).toList();
    } else if (json['account'] != null) {
      parsedAccounts = [json['account'].toString()];
    }

    return SyncedContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      phone: rawPhone,
      isFavorite: json['isFavorite'] == true,
      account: json['account']?.toString(),
      photoBase64: json['photoBase64']?.toString(),
      phones: parsedPhones,
      emails: parsedEmails,
      addresses: parsedAddresses,
      sourceAccounts: parsedAccounts,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'isFavorite': isFavorite,
    'account': account,
    'photoBase64': photoBase64,
    'phones': phones.map((p) => p.toJson()).toList(),
    'emails': emails,
    'addresses': addresses,
    'accounts': sourceAccounts,
    'note': note,
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
  final int count;

  const SyncedCallLog({
    required this.id,
    required this.name,
    required this.number,
    required this.type,
    required this.timestamp,
    required this.duration,
    this.simSlot = 1,
    this.count = 1,
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

    int count = 1;
    final rawCount = json['count'];
    if (rawCount is int) {
      count = rawCount;
    } else if (rawCount is String) {
      count = int.tryParse(rawCount) ?? 1;
    }

    return SyncedCallLog(
      id: json['id']?.toString() ?? '${json['number']}_$rawTime',
      name: json['name']?.toString() ?? (json['number']?.toString() ?? 'Unknown'),
      number: json['number']?.toString() ?? '',
      type: parsedType,
      timestamp: time,
      duration: Duration(seconds: durSec),
      simSlot: (json['simSlot'] is int) ? (json['simSlot'] as int) + 1 : 1,
      count: count,
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
    'count': count,
  };
}

class SyncedSmsMessage {
  final String id;
  final String body;
  final DateTime timestamp;
  final bool isOutgoing;
  final bool isPinned;
  final bool isStarred;

  const SyncedSmsMessage({
    required this.id,
    required this.body,
    required this.timestamp,
    required this.isOutgoing,
    this.isPinned = false,
    this.isStarred = false,
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
      isPinned: json['isPinned'] == true,
      isStarred: json['isStarred'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isOutgoing': isOutgoing,
    'isPinned': isPinned,
    'isStarred': isStarred,
  };
}

class SyncedSmsCategory {
  final String id;
  final String name;
  final List<String> contactPhones;
  final bool isCustom;
  final bool isVisible;

  const SyncedSmsCategory({
    required this.id,
    required this.name,
    this.contactPhones = const [],
    this.isCustom = false,
    this.isVisible = true,
  });

  factory SyncedSmsCategory.fromJson(Map<String, dynamic> json) {
    final phones = <String>[];
    if (json['contactPhones'] is List) {
      for (final p in json['contactPhones'] as List) {
        phones.add(p.toString());
      }
    }
    return SyncedSmsCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactPhones: phones,
      isCustom: json['isCustom'] == true,
      isVisible: json['isVisible'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contactPhones': contactPhones,
    'isCustom': isCustom,
    'isVisible': isVisible,
  };
}

class SyncedCallCategory {
  final String id;
  final String name;
  final List<String> contactPhones;
  final bool isCustom;
  final bool isVisible;

  const SyncedCallCategory({
    required this.id,
    required this.name,
    this.contactPhones = const [],
    this.isCustom = false,
    this.isVisible = true,
  });

  factory SyncedCallCategory.fromJson(Map<String, dynamic> json) {
    final phones = <String>[];
    if (json['contactPhones'] is List) {
      for (final p in json['contactPhones'] as List) {
        phones.add(p.toString());
      }
    }
    return SyncedCallCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactPhones: phones,
      isCustom: json['isCustom'] == true,
      isVisible: json['isVisible'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contactPhones': contactPhones,
    'isCustom': isCustom,
    'isVisible': isVisible,
  };
}

class SyncedContactGroup {
  final String id;
  final String name;
  final List<String> contactIds;
  final String? accountType;
  final String? accountName;

  const SyncedContactGroup({
    required this.id,
    required this.name,
    this.contactIds = const [],
    this.accountType,
    this.accountName,
  });

  factory SyncedContactGroup.fromJson(Map<String, dynamic> json) {
    final ids = <String>[];
    if (json['contactIds'] is List) {
      for (final id in json['contactIds'] as List) {
        ids.add(id.toString());
      }
    }
    return SyncedContactGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactIds: ids,
      accountType: json['accountType']?.toString(),
      accountName: json['accountName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contactIds': contactIds,
    if (accountType != null) 'accountType': accountType,
    if (accountName != null) 'accountName': accountName,
  };
}

class SyncedSmsThread {
  final String id;
  final String contactName;
  final String phone;
  final String snippet;
  final DateTime timestamp;
  final int unreadCount;
  final bool isPinned;
  final List<SyncedSmsMessage> messages;

  const SyncedSmsThread({
    required this.id,
    required this.contactName,
    required this.phone,
    required this.snippet,
    required this.timestamp,
    this.unreadCount = 0,
    this.isPinned = false,
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
      isPinned: json['isPinned'] == true,
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
    'isPinned': isPinned,
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

class SyncedVolumeStream {
  final int current;
  final int max;

  const SyncedVolumeStream({this.current = 0, this.max = 15});

  factory SyncedVolumeStream.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return SyncedVolumeStream(
        current: json['current'] is int ? json['current'] as int : 0,
        max: json['max'] is int ? json['max'] as int : 15,
      );
    }
    return const SyncedVolumeStream();
  }

  Map<String, dynamic> toJson() => {
    'current': current,
    'max': max,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncedVolumeStream &&
        other.current == current &&
        other.max == max;
  }

  @override
  int get hashCode => Object.hash(current, max);
}

class SyncedPhoneVolume {
  final SyncedVolumeStream ring;
  final SyncedVolumeStream notification;
  final SyncedVolumeStream call;
  final SyncedVolumeStream alarm;
  final SyncedVolumeStream media;

  const SyncedPhoneVolume({
    this.ring = const SyncedVolumeStream(),
    this.notification = const SyncedVolumeStream(),
    this.call = const SyncedVolumeStream(),
    this.alarm = const SyncedVolumeStream(),
    this.media = const SyncedVolumeStream(),
  });

  factory SyncedPhoneVolume.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return SyncedPhoneVolume(
        ring: SyncedVolumeStream.fromJson(json['ring']),
        notification: SyncedVolumeStream.fromJson(json['notification']),
        call: SyncedVolumeStream.fromJson(json['call']),
        alarm: SyncedVolumeStream.fromJson(json['alarm']),
        media: SyncedVolumeStream.fromJson(json['media']),
      );
    }
    return const SyncedPhoneVolume();
  }

  Map<String, dynamic> toJson() => {
    'ring': ring.toJson(),
    'notification': notification.toJson(),
    'call': call.toJson(),
    'alarm': alarm.toJson(),
    'media': media.toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncedPhoneVolume &&
        other.ring == ring &&
        other.notification == notification &&
        other.call == call &&
        other.alarm == alarm &&
        other.media == media;
  }

  @override
  int get hashCode => Object.hash(ring, notification, call, alarm, media);
}

class SyncedTelemetry {
  final int batteryLevel; // 0 to 100, or -1 if unknown
  final bool isBatteryCharging;
  final int wifiLevel; // -1 if disconnected/off, 0 to 4
  final bool isWifiConnected;
  final int cellularLevel; // -1 if unknown/no signal, 0 to 4
  final bool isHotspotOn;
  final String dataNetworkType; // "5G", "4G", "LTE", etc. or ""
  final SyncedPhoneVolume volume;

  const SyncedTelemetry({
    this.batteryLevel = -1,
    this.isBatteryCharging = false,
    this.wifiLevel = -1,
    this.isWifiConnected = false,
    this.cellularLevel = -1,
    this.isHotspotOn = false,
    this.dataNetworkType = '',
    this.volume = const SyncedPhoneVolume(),
  });

  factory SyncedTelemetry.fromJson(Map<String, dynamic> json) {
    return SyncedTelemetry(
      batteryLevel: json['batteryLevel'] is int ? json['batteryLevel'] as int : -1,
      isBatteryCharging: json['isCharging'] == true,
      wifiLevel: json['wifiLevel'] is int ? json['wifiLevel'] as int : -1,
      isWifiConnected: json['isWifiConnected'] == true,
      cellularLevel: json['cellularLevel'] is int ? json['cellularLevel'] as int : -1,
      isHotspotOn: json['isHotspotOn'] == true,
      dataNetworkType: json['dataNetworkType']?.toString() ?? '',
      volume: SyncedPhoneVolume.fromJson(json['volume']),
    );
  }

  Map<String, dynamic> toJson() => {
    'batteryLevel': batteryLevel,
    'isCharging': isBatteryCharging,
    'wifiLevel': wifiLevel,
    'isWifiConnected': isWifiConnected,
    'cellularLevel': cellularLevel,
    'isHotspotOn': isHotspotOn,
    'dataNetworkType': dataNetworkType,
    'volume': volume.toJson(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncedTelemetry &&
        other.batteryLevel == batteryLevel &&
        other.isBatteryCharging == isBatteryCharging &&
        other.wifiLevel == wifiLevel &&
        other.isWifiConnected == isWifiConnected &&
        other.cellularLevel == cellularLevel &&
        other.isHotspotOn == isHotspotOn &&
        other.dataNetworkType == dataNetworkType &&
        other.volume == volume;
  }

  @override
  int get hashCode => Object.hash(
        batteryLevel,
        isBatteryCharging,
        wifiLevel,
        isWifiConnected,
        cellularLevel,
        isHotspotOn,
        dataNetworkType,
        volume,
      );
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

  // Phone telemetry (battery, Wi-Fi, cellular)
  SyncedTelemetry _telemetry = const SyncedTelemetry();
  SyncedTelemetry get telemetry => _telemetry;

  // Real phone data (NO fake/unsaved contacts)
  List<SyncedContact> _contacts = [];
  final Map<String, String?> _phonePhotoCache = {};
  List<SyncedCallLog> _callLogs = [];
  List<SyncedSmsThread> _smsThreads = [];
  List<SyncedNote> _notes = [];

  // Category & Feature flags
  bool _syncFavouritesEnabled = true;
  bool _syncCallLogsEnabled = true;
  bool _syncContactsEnabled = true;
  bool _syncSmsEnabled = true;
  bool _syncNotesEnabled = true;
  bool _syncContactPfpEnabled = true;
  bool _confirmPlacingCall = false;

  bool get syncFavouritesEnabled => _syncFavouritesEnabled;
  bool get syncCallLogsEnabled => _syncCallLogsEnabled;
  bool get syncContactsEnabled => _syncContactsEnabled;
  bool get syncSmsEnabled => _syncSmsEnabled;
  bool get syncNotesEnabled => _syncNotesEnabled;
  bool get syncContactPfpEnabled => _syncContactPfpEnabled;
  bool get confirmPlacingCall => _confirmPlacingCall;

  Color? _phoneThemeColor;
  Color? get phoneThemeColor => _phoneThemeColor;
  int _defaultSim = 1;
  int get defaultSim => _defaultSim;
  int _simCount = 1;
  int get simCount => _simCount;
  Color _sim1Color = const Color(0xFF2E7D32);
  Color get sim1Color => _sim1Color;
  Color _sim2Color = const Color(0xFFC62828);
  Color get sim2Color => _sim2Color;

  bool _favoritesInList = false;
  bool get favoritesInList => _favoritesInList;

  void setFavoritesInList(bool value) {
    _favoritesInList = value;
    _prefs?.setBool('favorites_in_list', value);
    notifyListeners();
  }

  List<SyncedContact> get contacts => List.unmodifiable(_contacts);
  List<SyncedContact> get favourites =>
      List.unmodifiable(_contacts.where((c) => c.isFavorite));
  List<SyncedCallLog> get callLogs => List.unmodifiable(_callLogs);
  List<SyncedSmsThread> get smsThreads => List.unmodifiable(_smsThreads);
  List<SyncedNote> get notes => List.unmodifiable(_notes);
  List<SyncedSmsCategory> _smsCategories = [];
  List<SyncedSmsCategory> get smsCategories => List.unmodifiable(_smsCategories);
  List<SyncedCallCategory> _callCategories = [];
  List<SyncedCallCategory> get callCategories => List.unmodifiable(_callCategories);
  List<SyncedContactGroup> _contactGroups = [];
  List<SyncedContactGroup> get contactGroups => List.unmodifiable(_contactGroups);

  Set<String> _starredSmsMessageIds = {};
  Set<String> _pinnedSmsMessageIds = {};
  Set<String> _pinnedSmsThreadIds = {};

  bool isMessageStarred(String msgId) => _starredSmsMessageIds.contains(msgId);
  bool isMessagePinned(String msgId) => _pinnedSmsMessageIds.contains(msgId);

  bool isThreadPinned(String threadId) {
    if (_pinnedSmsThreadIds.contains(threadId)) return true;
    final thread = _smsThreads.cast<SyncedSmsThread?>().firstWhere(
      (t) => t?.id == threadId,
      orElse: () => null,
    );
    return thread?.isPinned ?? false;
  }

  bool isThreadStarred(String threadId) {
    final thread = _smsThreads.cast<SyncedSmsThread?>().firstWhere(
      (t) => t?.id == threadId,
      orElse: () => null,
    );
    if (thread == null) return false;
    return thread.messages.any((m) => isMessageStarred(m.id));
  }

  void toggleStarMessage(String msgId) {
    final willStar = !_starredSmsMessageIds.contains(msgId);
    if (willStar) {
      _starredSmsMessageIds.add(msgId);
    } else {
      _starredSmsMessageIds.remove(msgId);
    }
    _prefs?.setStringList('starred_sms_messages', _starredSmsMessageIds.toList());
    notifyListeners();

    _sendCommand({
      'cmd': 'star_sms_message',
      'messageId': msgId,
      'starred': willStar,
    });
  }

  void togglePinMessage(String msgId) {
    final willPin = !_pinnedSmsMessageIds.contains(msgId);
    if (willPin) {
      _pinnedSmsMessageIds.add(msgId);
    } else {
      _pinnedSmsMessageIds.remove(msgId);
    }
    _prefs?.setStringList('pinned_sms_messages', _pinnedSmsMessageIds.toList());
    notifyListeners();

    _sendCommand({
      'cmd': 'pin_sms_message',
      'messageId': msgId,
      'pinned': willPin,
    });
  }

  void togglePinThread(String threadId) {
    final willPin = !_pinnedSmsThreadIds.contains(threadId);
    if (willPin) {
      _pinnedSmsThreadIds.add(threadId);
    } else {
      _pinnedSmsThreadIds.remove(threadId);
    }
    _prefs?.setStringList('pinned_sms_threads', _pinnedSmsThreadIds.toList());
    notifyListeners();

    _sendCommand({
      'cmd': 'pin_sms_thread',
      'threadId': threadId,
      'pinned': willPin,
    });
  }

  Process? _daemonProcess;
  StreamSubscription? _stdoutSub;

  PcSyncService({SharedPreferences? prefs}) {
    _prefs = prefs;
    if (_prefs != null) {
      _pcSyncEnabled = _prefs!.getBool(_prefPcSyncEnabledKey) ?? false;
      _favoritesInList = _prefs!.getBool('favorites_in_list') ?? false;
      final savedThemeColor = _prefs!.getInt('last_synced_theme_color');
      if (savedThemeColor != null) {
        _phoneThemeColor = Color(savedThemeColor);
      }
    }
    _init();
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _favoritesInList = _prefs?.getBool('favorites_in_list') ?? _favoritesInList;
    final saved = _prefs?.getBool(_prefPcSyncEnabledKey) ?? false;
    if (saved != _pcSyncEnabled) {
      _pcSyncEnabled = saved;
      notifyListeners();
    }
    final savedThemeColor = _prefs?.getInt('last_synced_theme_color');
    if (savedThemeColor != null && _phoneThemeColor == null) {
      _phoneThemeColor = Color(savedThemeColor);
      notifyListeners();
    }

    _loadCachedData();

    if (_pcSyncEnabled) {
      _startBluetoothDaemon();
    }
  }

  void _loadCachedData() {
    final starred = _prefs?.getStringList('starred_sms_messages');
    if (starred != null) _starredSmsMessageIds = starred.toSet();
    final pinned = _prefs?.getStringList('pinned_sms_messages');
    if (pinned != null) _pinnedSmsMessageIds = pinned.toSet();
    final pinnedThreads = _prefs?.getStringList('pinned_sms_threads');
    if (pinnedThreads != null) _pinnedSmsThreadIds = pinnedThreads.toSet();

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
        'contactGroups': _contactGroups.map((g) => g.toJson()).toList(),
        'callLogs': _callLogs.take(50).map((c) => c.toJson()).toList(),
        'callCategories': _callCategories.map((c) => c.toJson()).toList(),
        'smsCategories': _smsCategories.map((c) => c.toJson()).toList(),
        'smsThreads': _smsThreads.map((t) => t.toJson()).toList(),
        'notes': _notes.map((n) => n.toJson()).toList(),
        'enabledFeatures': {
          'favourites': _syncFavouritesEnabled,
          'callLogs': _syncCallLogsEnabled,
          'contacts': _syncContactsEnabled,
          'sms': _syncSmsEnabled,
          'notes': _syncNotesEnabled,
          'contactPfp': _syncContactPfpEnabled,
          'confirmPlacingCall': _confirmPlacingCall,
        },
        'confirmPlacingCall': _confirmPlacingCall,
        'favoritesInList': _favoritesInList,
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
      } else if (event == 'telemetry') {
        final payload = data['payload'];
        if (payload is Map<String, dynamic>) {
          final newTelem = SyncedTelemetry.fromJson(payload);
          if (newTelem != _telemetry) {
            _telemetry = newTelem;
            notifyListeners();
          }
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
    _isConnected = true;
    _applyPayload(payload, saveCache: true);
    notifyListeners();
  }

  void _applyPayload(Map<String, dynamic> payload, {bool saveCache = true}) {
    // 1. Contacts
    if (payload.containsKey('contacts')) {
      _phonePhotoCache.clear();
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

    // 1b. Contact Groups
    if (payload.containsKey('contactGroups')) {
      final list = payload['contactGroups'];
      if (list is List) {
        _contactGroups = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedContactGroup.fromJson(item))
            .toList();
      } else {
        _contactGroups = [];
      }
    }

    // 2. Call Logs (capped to latest 50)
    if (payload.containsKey('callLogs')) {
      final list = payload['callLogs'];
      if (list is List) {
        _callLogs = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedCallLog.fromJson(item))
            .take(50)
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

    // Sync pinned and starred IDs from payload and individual messages
    for (final thread in _smsThreads) {
      if (thread.isPinned) _pinnedSmsThreadIds.add(thread.id);
      for (final msg in thread.messages) {
        if (msg.isPinned) _pinnedSmsMessageIds.add(msg.id);
        if (msg.isStarred) _starredSmsMessageIds.add(msg.id);
      }
    }
    if (payload.containsKey('starredSmsMessageIds')) {
      final list = payload['starredSmsMessageIds'];
      if (list is List) {
        _starredSmsMessageIds.addAll(list.map((e) => e.toString()));
        _prefs?.setStringList('starred_sms_messages', _starredSmsMessageIds.toList());
      }
    }
    if (payload.containsKey('pinnedSmsMessageIds')) {
      final list = payload['pinnedSmsMessageIds'];
      if (list is List) {
        _pinnedSmsMessageIds.addAll(list.map((e) => e.toString()));
        _prefs?.setStringList('pinned_sms_messages', _pinnedSmsMessageIds.toList());
      }
    }
    if (payload.containsKey('pinnedSmsThreadIds')) {
      final list = payload['pinnedSmsThreadIds'];
      if (list is List) {
        _pinnedSmsThreadIds.addAll(list.map((e) => e.toString()));
        _prefs?.setStringList('pinned_sms_threads', _pinnedSmsThreadIds.toList());
      }
    }
    if (payload.containsKey('smsCategories')) {
      final list = payload['smsCategories'];
      if (list is List) {
        _smsCategories = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedSmsCategory.fromJson(item))
            .toList();
      }
    }
    if (payload.containsKey('callCategories')) {
      final list = payload['callCategories'];
      if (list is List) {
        _callCategories = list
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncedCallCategory.fromJson(item))
            .toList();
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

    // 5. Enabled Features
    if (payload.containsKey('enabledFeatures')) {
      final features = payload['enabledFeatures'];
      if (features is Map<String, dynamic>) {
        _syncFavouritesEnabled = features['favourites'] != false;
        _syncCallLogsEnabled = features['callLogs'] != false;
        _syncContactsEnabled = features['contacts'] != false;
        _syncSmsEnabled = features['sms'] != false;
        _syncNotesEnabled = features['notes'] != false;
        _syncContactPfpEnabled = features['contactPfp'] != false;
        if (features.containsKey('confirmPlacingCall')) {
          _confirmPlacingCall = features['confirmPlacingCall'] == true;
        }
      }
    }
    if (payload.containsKey('confirmPlacingCall')) {
      _confirmPlacingCall = payload['confirmPlacingCall'] == true;
    }
    if (payload.containsKey('favoritesInList')) {
      _favoritesInList = payload['favoritesInList'] == true;
      _prefs?.setBool('favorites_in_list', _favoritesInList);
    } else if (payload.containsKey('favorites_in_list')) {
      _favoritesInList = payload['favorites_in_list'] == true;
      _prefs?.setBool('favorites_in_list', _favoritesInList);
    }

    if (payload.containsKey('themeColor')) {
      final colorStr = payload['themeColor'] as String?;
      if (colorStr != null && colorStr.isNotEmpty) {
        try {
          _phoneThemeColor = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
          _prefs?.setInt('last_synced_theme_color', _phoneThemeColor!.toARGB32());
        } catch (_) {
          _phoneThemeColor = null;
          _prefs?.remove('last_synced_theme_color');
        }
      } else {
        _phoneThemeColor = null;
        _prefs?.remove('last_synced_theme_color');
      }
    } else if (payload.containsKey('syncDynamicColors') && payload['syncDynamicColors'] == false) {
      _phoneThemeColor = null;
      _prefs?.remove('last_synced_theme_color');
    }
    if (payload.containsKey('defaultSim') && payload['defaultSim'] is int) {
      _defaultSim = payload['defaultSim'] as int;
    }
    if (payload.containsKey('simCount') && payload['simCount'] is int) {
      _simCount = payload['simCount'] as int;
    }
    if (payload.containsKey('sim1Color') && payload['sim1Color'] is String) {
      try {
        _sim1Color = Color(int.parse((payload['sim1Color'] as String).replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    if (payload.containsKey('sim2Color') && payload['sim2Color'] is String) {
      try {
        _sim2Color = Color(int.parse((payload['sim2Color'] as String).replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    if (payload.containsKey('deviceName')) {
      _connectedDeviceName = payload['deviceName']?.toString();
    }

    if (payload.containsKey('telemetry')) {
      final telem = payload['telemetry'];
      if (telem is Map<String, dynamic>) {
        _telemetry = SyncedTelemetry.fromJson(telem);
      }
    }

    _lastSyncTime = DateTime.now();

    if (saveCache) {
      _saveCachedData();
    }
  }

  /// Look up contact photo (as Base64) by phone number.
  /// Matches on exact digits or normalized last 7+ digits across all phone numbers.
  String? getPhotoBase64ForNumber(String number) {
    if (!_syncContactPfpEnabled) return null;
    final cleanTarget = number.replaceAll(RegExp(r'\D'), '');
    if (cleanTarget.isEmpty) return null;

    if (_phonePhotoCache.containsKey(cleanTarget)) {
      return _phonePhotoCache[cleanTarget];
    }

    for (final contact in _contacts) {
      if (contact.photoBase64 == null || contact.photoBase64!.isEmpty) continue;

      final numbersToCheck = <String>[contact.phone];
      for (final p in contact.phones) {
        if (p.number.isNotEmpty) numbersToCheck.add(p.number);
      }

      for (final num in numbersToCheck) {
        final cleanContact = num.replaceAll(RegExp(r'\D'), '');
        if (cleanContact.isEmpty) continue;

        if (cleanContact == cleanTarget ||
            (cleanContact.length >= 7 &&
                cleanTarget.length >= 7 &&
                (cleanContact.endsWith(cleanTarget) ||
                    cleanTarget.endsWith(cleanContact)))) {
          _phonePhotoCache[cleanTarget] = contact.photoBase64;
          return contact.photoBase64;
        }
      }
    }

    _phonePhotoCache[cleanTarget] = null;
    return null;
  }

  void requestSyncNow() {
    _sendCommand({'cmd': 'request_sync'});
  }

  void requestTelemetryNow() {
    _sendCommand({'cmd': 'request_telemetry'});
  }

  void setPhoneVolume(String stream, int level) {
    _sendCommand({
      'cmd': 'set_volume',
      'stream': stream,
      'level': level,
    });
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

  Future<void> makeCall(String phoneNumber, {int? simSlot}) async {
    final clean = phoneNumber.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    debugPrint('[PcSyncService] makeCall requested for $clean (simSlot: $simSlot, isConnected: $_isConnected)');

    // 1. Send command via Bluetooth sync daemon
    final cmd = <String, dynamic>{
      'cmd': 'make_call',
      'number': clean,
    };
    if (simSlot != null && simSlot > 0) {
      cmd['simSlot'] = simSlot;
    }
    _sendCommand(cmd);

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

  SyncedSmsThread getOrCreateThreadForNumber(String phone, {String? contactName}) {
    final cleanPhone = phone.trim();
    final digits = cleanPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final index = _smsThreads.indexWhere((t) {
      final tDigits = t.phone.replaceAll(RegExp(r'[^\d+]'), '');
      return t.phone == cleanPhone || (digits.isNotEmpty && tDigits == digits);
    });
    if (index != -1) {
      return _smsThreads[index];
    }
    final newThread = SyncedSmsThread(
      id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
      contactName: (contactName != null && contactName.isNotEmpty) ? contactName : cleanPhone,
      phone: cleanPhone,
      snippet: '',
      timestamp: DateTime.now(),
      unreadCount: 0,
      messages: [],
    );
    _smsThreads.insert(0, newThread);
    _saveCachedData();
    notifyListeners();
    return newThread;
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

  void addContact(String name, String phone) {
    final cleanPhone = phone.trim();
    final cleanName = name.trim().isNotEmpty ? name.trim() : (cleanPhone.isNotEmpty ? cleanPhone : 'New Contact');
    if (cleanPhone.isEmpty && name.trim().isEmpty) return;

    final newContact = SyncedContact(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      phone: cleanPhone,
      phones: [SyncedContactPhone(number: cleanPhone, label: 'Mobile')],
    );
    _contacts.insert(0, newContact);
    _saveCachedData();
    notifyListeners();

    _sendCommand({
      'cmd': 'add_contact',
      'name': cleanName,
      'phone': cleanPhone,
    });
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

  void markSmsAsRead(String threadId) {
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _smsThreads[index];
      if (thread.unreadCount > 0) {
        _smsThreads[index] = SyncedSmsThread(
          id: thread.id,
          contactName: thread.contactName,
          phone: thread.phone,
          snippet: thread.snippet,
          timestamp: thread.timestamp,
          unreadCount: 0,
          messages: thread.messages,
        );
        _saveCachedData();
        notifyListeners();

        _sendCommand({
          'cmd': 'mark_sms_read',
          'threadId': threadId,
        });
      }
    }
  }

  void markSmsAsUnread(String threadId) {
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _smsThreads[index];
      if (thread.unreadCount == 0) {
        _smsThreads[index] = SyncedSmsThread(
          id: thread.id,
          contactName: thread.contactName,
          phone: thread.phone,
          snippet: thread.snippet,
          timestamp: thread.timestamp,
          unreadCount: 1,
          messages: thread.messages,
        );
        _saveCachedData();
        notifyListeners();
      }
    }
  }

  void deleteSmsMessage(String threadId, String messageId) {
    final tIndex = _smsThreads.indexWhere((t) => t.id == threadId);
    if (tIndex != -1) {
      final thread = _smsThreads[tIndex];
      final updatedMsgs = thread.messages.where((m) => m.id != messageId).toList();
      _smsThreads[tIndex] = SyncedSmsThread(
        id: thread.id,
        contactName: thread.contactName,
        phone: thread.phone,
        snippet: updatedMsgs.isNotEmpty ? updatedMsgs.last.body : '',
        timestamp: updatedMsgs.isNotEmpty ? updatedMsgs.last.timestamp : thread.timestamp,
        unreadCount: thread.unreadCount,
        messages: updatedMsgs,
      );
      _saveCachedData();
      notifyListeners();

      _sendCommand({
        'cmd': 'delete_sms_message',
        'threadId': threadId,
        'messageId': messageId,
      });
    }
  }

  void toggleSmsRead(String threadId) {
    final index = _smsThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _smsThreads[index];
      if (thread.unreadCount > 0) {
        markSmsAsRead(threadId);
      } else {
        markSmsAsUnread(threadId);
      }
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
