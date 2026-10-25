import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/bluetooth_service.dart';
import 'services/sync_service.dart';
import 'services/system_service.dart';
import 'screens/settings_screen.dart';
import 'widgets/mobile_landscape_layout.dart';
import 'widgets/window_header_actions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(EverDialerApp(prefs: prefs));
}

// Default fallback accent color: KDE Gold/Amber system accent
const _fallbackAccentColor = Color(0xFFFFDD31);

class EverDialerApp extends StatefulWidget {
  final BluetoothService? bluetoothService;
  final PcSyncService? syncService;
  final SystemService? systemService;
  final SharedPreferences? prefs;

  const EverDialerApp({
    super.key,
    this.bluetoothService,
    this.syncService,
    this.systemService,
    this.prefs,
  });

  @override
  State<EverDialerApp> createState() => _EverDialerAppState();
}

class _EverDialerAppState extends State<EverDialerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _displayScale = 1.0;
  double _fontScale = 1.0;
  late final PcSyncService _syncService;
  late final bool _ownsSyncService;
  late final BluetoothService _bluetoothService;
  late final bool _ownsBluetoothService;
  late final SystemService _systemService;
  late final bool _ownsSystemService;

  @override
  void initState() {
    super.initState();
    final prefs = widget.prefs;
    if (prefs != null) {
      _displayScale = prefs.getDouble('display_scale') ?? 1.0;
      _fontScale = prefs.getDouble('font_scale') ?? 1.0;
      final themeStr = prefs.getString('theme_mode');
      if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      }
    }

    if (widget.syncService != null) {
      _syncService = widget.syncService!;
      _ownsSyncService = false;
    } else {
      _syncService = PcSyncService(prefs: widget.prefs);
      _ownsSyncService = true;
    }

    if (widget.bluetoothService != null) {
      _bluetoothService = widget.bluetoothService!;
      _ownsBluetoothService = false;
    } else {
      _bluetoothService = BluetoothService(prefs: widget.prefs);
      _ownsBluetoothService = true;
    }

    if (widget.systemService != null) {
      _systemService = widget.systemService!;
      _ownsSystemService = false;
    } else {
      _systemService = SystemService(prefs: widget.prefs);
      _ownsSystemService = true;
    }
  }

  @override
  void dispose() {
    if (_ownsSyncService) _syncService.dispose();
    if (_ownsBluetoothService) _bluetoothService.dispose();
    if (_ownsSystemService) _systemService.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
    widget.prefs?.setString('theme_mode', _themeMode.name);
  }

  void _updateDisplayScale(double val) {
    setState(() {
      _displayScale = double.parse(val.toStringAsFixed(2));
    });
    widget.prefs?.setDouble('display_scale', _displayScale);
  }

  void _updateFontScale(double val) {
    setState(() {
      _fontScale = double.parse(val.toStringAsFixed(2));
    });
    widget.prefs?.setDouble('font_scale', _fontScale);
  }

  void _resetDisplayScale() {
    _updateDisplayScale(1.0);
  }

  void _resetFontScale() {
    _updateFontScale(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _syncService,
      builder: (context, _) {
        final activeSeedColor = _syncService.phoneThemeColor ?? _fallbackAccentColor;

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final ColorScheme lightColorScheme = _syncService.phoneThemeColor != null
                ? ColorScheme.fromSeed(
                    seedColor: activeSeedColor,
                    brightness: Brightness.light,
                  )
                : (lightDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: activeSeedColor,
                      brightness: Brightness.light,
                    ));

            final ColorScheme darkColorScheme = _syncService.phoneThemeColor != null
                ? ColorScheme.fromSeed(
                    seedColor: activeSeedColor,
                    brightness: Brightness.dark,
                  )
                : (darkDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: activeSeedColor,
                      brightness: Brightness.dark,
                    ));

        return MaterialApp(
          title: 'Ever Dialer PC',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: lightColorScheme.surface,
            iconTheme: IconThemeData(
              size: (22 * _displayScale.clamp(0.4, 2.0)).clamp(12.0, 44.0),
            ),
            visualDensity: VisualDensity(
              horizontal: ((_displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
              vertical: ((_displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: darkColorScheme.surface,
            iconTheme: IconThemeData(
              size: (22 * _displayScale.clamp(0.4, 2.0)).clamp(12.0, 44.0),
            ),
            visualDensity: VisualDensity(
              horizontal: ((_displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
              vertical: ((_displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
            ),
          ),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final mediaQuery = MediaQuery.of(context);
            final effectiveDisplay = _displayScale.clamp(0.25, 2.0);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(_fontScale * effectiveDisplay),
              ),
              child: child,
            );
          },
          home: EverDialerHomePage(
            themeMode: _themeMode,
            onToggleTheme: _toggleTheme,
            bluetoothService: _bluetoothService,
            syncService: _syncService,
            systemService: _systemService,
            prefs: widget.prefs,
            displayScale: _displayScale,
            fontScale: _fontScale,
            onUpdateDisplayScale: _updateDisplayScale,
            onUpdateFontScale: _updateFontScale,
            onResetDisplayScale: _resetDisplayScale,
            onResetFontScale: _resetFontScale,
          ),
          );
        },
      );
    },
  );
}
}

class EverDialerHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final BluetoothService? bluetoothService;
  final PcSyncService? syncService;
  final SystemService? systemService;
  final SharedPreferences? prefs;
  final double displayScale;
  final double fontScale;
  final ValueChanged<double>? onUpdateDisplayScale;
  final ValueChanged<double>? onUpdateFontScale;
  final VoidCallback? onResetDisplayScale;
  final VoidCallback? onResetFontScale;

  const EverDialerHomePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    this.bluetoothService,
    this.syncService,
    this.systemService,
    this.prefs,
    this.displayScale = 1.0,
    this.fontScale = 1.0,
    this.onUpdateDisplayScale,
    this.onUpdateFontScale,
    this.onResetDisplayScale,
    this.onResetFontScale,
  });

  @override
  State<EverDialerHomePage> createState() => _EverDialerHomePageState();
}

class _EverDialerHomePageState extends State<EverDialerHomePage> {
  late final BluetoothService _bluetoothService;
  late final bool _ownsService;
  late final PcSyncService _syncService;
  late final bool _ownsSyncService;
  late final SystemService _systemService;
  late final bool _ownsSystemService;

  @override
  void initState() {
    super.initState();
    if (widget.bluetoothService != null) {
      _bluetoothService = widget.bluetoothService!;
      _ownsService = false;
    } else {
      _bluetoothService = BluetoothService(prefs: widget.prefs);
      _ownsService = true;
    }

    if (widget.syncService != null) {
      _syncService = widget.syncService!;
      _ownsSyncService = false;
    } else {
      _syncService = PcSyncService(prefs: widget.prefs);
      _ownsSyncService = true;
    }

    if (widget.systemService != null) {
      _systemService = widget.systemService!;
      _ownsSystemService = false;
    } else {
      _systemService = SystemService(prefs: widget.prefs);
      _ownsSystemService = true;
    }

    // Keep both services aligned as one unified feature
    final syncEnabled = _syncService.pcSyncEnabled;
    final speakerEnabled = _bluetoothService.state.speakerModeEnabled;
    if (syncEnabled != speakerEnabled) {
      final unified = syncEnabled || speakerEnabled;
      if (syncEnabled != unified) {
        _syncService.setPcSyncEnabled(unified);
      }
      if (speakerEnabled != unified) {
        _bluetoothService.toggleSpeakerMode(unified);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _bluetoothService.dispose();
    }
    if (_ownsSyncService) {
      _syncService.dispose();
    }
    if (_ownsSystemService) {
      _systemService.dispose();
    }
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          bluetoothService: _bluetoothService,
          syncService: _syncService,
          systemService: _systemService,
          themeMode: widget.themeMode,
          onToggleTheme: widget.onToggleTheme,
          displayScale: widget.displayScale,
          fontScale: widget.fontScale,
          onUpdateDisplayScale: widget.onUpdateDisplayScale,
          onUpdateFontScale: widget.onUpdateFontScale,
          onResetDisplayScale: widget.onResetDisplayScale,
          onResetFontScale: widget.onResetFontScale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([_syncService, _bluetoothService]),
      builder: (context, _) {
        final isUnifiedEnabled =
            _syncService.pcSyncEnabled || _bluetoothService.state.speakerModeEnabled;

        // When Bluetooth Connection & Sync is enabled:
        // Render the complete Mobile Ever Dialer landscape main screen layout!
        // The old speaker status and about are completely removed from the main screen.
        if (isUnifiedEnabled) {
          return Scaffold(
            appBar: AppBar(
              flexibleSpace: WindowDragArea(
                onStartDrag: () => _systemService.startWindowDrag(),
                onDoubleTap: () => _systemService.toggleMaximizeWindow(),
                child: const SizedBox.expand(),
              ),
              title: IgnorePointer(
                child: Text(
                  'Ever Dialer PC',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              actions: [
                WindowHeaderActions(
                  syncService: _syncService,
                  systemService: _systemService,
                ),
              ],
            ),
            body: MobileLandscapeLayout(
              syncService: _syncService,
              onOpenSettings: _openSettings,
            ),
          );
        }

        // When Bluetooth Connection & Sync is disabled: render standard dashboard
        return Scaffold(
          appBar: AppBar(
            flexibleSpace: WindowDragArea(
              onStartDrag: () => _systemService.startWindowDrag(),
              onDoubleTap: () => _systemService.toggleMaximizeWindow(),
              child: const SizedBox.expand(),
            ),
            title: IgnorePointer(
              child: Text(
                'Ever Dialer PC',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            actions: [
              WindowHeaderActions(
                syncService: _syncService,
                systemService: _systemService,
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: _bluetoothService,
            builder: (context, _) {
              final state = _bluetoothService.state;
              final isEnabled = state.speakerModeEnabled;
              final device = state.connectedDevice;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Dashboard Hero Card
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isEnabled
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    isEnabled
                                        ? Icons.bluetooth_audio
                                        : Icons.bluetooth_disabled_outlined,
                                    size: 30,
                                    color: isEnabled
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bluetooth Connection & Sync',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (device != null) ...[
                                        Text(
                                          '📱 Streaming from ${device.name}',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ] else if (isEnabled) ...[
                                        Text(
                                          'Ready • Discoverable as "${state.alias}"',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          'Bluetooth connection & sync are currently OFF',
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            Divider(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),

                            // Action Button to Go to Settings
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _openSettings,
                                    icon: const Icon(Icons.tune, size: 18),
                                    label: const Text('Bluetooth & Sync Settings'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Quick Status Summary Card
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
                                const SizedBox(width: 10),
                                Text(
                                  'About Ever Dialer PC',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ever Dialer PC connects with Ever Dialer Mobile over Bluetooth. Turn on "Bluetooth Connection & Sync" in Settings to sync data and display the full Mobile landscape view.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Click "Bluetooth & Sync Settings" above or Settings on the navigation rail to configure Bluetooth Connection & Sync, audio output, or appearance.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer Info
                    Center(
                      child: Text(
                        'PipeWire A2DP Audio Sink • BlueZ 5 • Fedora Linux • v1.0.0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
