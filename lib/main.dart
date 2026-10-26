import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/bluetooth_service.dart';
import 'services/sync_service.dart';
import 'services/system_service.dart';
import 'services/appearance_preferences.dart';
import 'screens/settings_screen.dart';
import 'widgets/mobile_landscape_layout.dart';
import 'widgets/window_header_actions.dart';
import 'widgets/window_resize_frame.dart';

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
  late final AppearancePreferences _appearance;
  late final PcSyncService _syncService;
  late final bool _ownsSyncService;
  late final BluetoothService _bluetoothService;
  late final bool _ownsBluetoothService;
  late final SystemService _systemService;
  late final bool _ownsSystemService;

  @override
  void initState() {
    super.initState();
    _appearance = AppearancePreferences(widget.prefs);

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
    _appearance.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    if (_appearance.colorMode == 'dark' || _appearance.colorMode == 'black') {
      _appearance.setColorMode('light');
    } else if (_appearance.colorMode == 'light' || _appearance.colorMode == 'white') {
      _appearance.setColorMode('auto');
    } else {
      _appearance.setColorMode('dark');
    }
  }

  void _updateDisplayScale(double val) {
    _appearance.setDisplayScale(val);
  }

  void _updateFontScale(double val) {
    _appearance.setFontScale(val);
  }

  void _resetDisplayScale() {
    _appearance.resetDisplayScale();
  }

  void _resetFontScale() {
    _appearance.resetFontScale();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_syncService, _appearance]),
      builder: (context, _) {
        final activeSeedColor = (_appearance.dynamicColors && _syncService.phoneThemeColor != null)
            ? _syncService.phoneThemeColor!
            : (_appearance.dynamicColors
                ? (_syncService.phoneThemeColor ?? _fallbackAccentColor)
                : _appearance.customPrimaryColor);

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightColorScheme;
            ColorScheme darkColorScheme;

            if (_appearance.dynamicColors) {
              if (_syncService.phoneThemeColor != null) {
                lightColorScheme = ColorScheme.fromSeed(
                  seedColor: activeSeedColor,
                  brightness: Brightness.light,
                );
                darkColorScheme = ColorScheme.fromSeed(
                  seedColor: activeSeedColor,
                  brightness: Brightness.dark,
                );
              } else {
                lightColorScheme = lightDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: activeSeedColor,
                      brightness: Brightness.light,
                    );
                darkColorScheme = darkDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: activeSeedColor,
                      brightness: Brightness.dark,
                    );
              }
            } else {
              lightColorScheme = ColorScheme.fromSeed(
                seedColor: activeSeedColor,
                brightness: Brightness.light,
              );
              darkColorScheme = ColorScheme.fromSeed(
                seedColor: activeSeedColor,
                brightness: Brightness.dark,
              );
            }

            final isBlackMode = _appearance.colorMode == 'black';
            final isWhiteMode = _appearance.colorMode == 'white';

            if (isBlackMode) {
              darkColorScheme = darkColorScheme.copyWith(
                surface: const Color(0xFF000000),
                surfaceContainer: const Color(0xFF101010),
                surfaceContainerHigh: const Color(0xFF161616),
                surfaceContainerHighest: const Color(0xFF1E1E1E),
                surfaceContainerLow: const Color(0xFF080808),
                surfaceContainerLowest: const Color(0xFF000000),
              );
            }

            if (isWhiteMode) {
              lightColorScheme = lightColorScheme.copyWith(
                surface: const Color(0xFFFFFFFF),
                surfaceContainer: const Color(0xFFF7F7F7),
                surfaceContainerHigh: const Color(0xFFEFEFEF),
                surfaceContainerHighest: const Color(0xFFE8E8E8),
                surfaceContainerLow: const Color(0xFFFCFCFC),
                surfaceContainerLowest: const Color(0xFFFFFFFF),
              );
            }

            final transparency = _appearance.windowTransparency;
            if (transparency > 0.0) {
              final opacity = (1.0 - transparency).clamp(0.0, 1.0);
              Color transparentColor(Color original, double factor) {
                if (factor >= 1.0) return original;
                return original.withValues(alpha: (original.a * factor).clamp(0.0, 1.0));
              }

              darkColorScheme = darkColorScheme.copyWith(
                surface: transparentColor(darkColorScheme.surface, opacity),
                surfaceContainer: transparentColor(darkColorScheme.surfaceContainer, opacity),
                surfaceContainerHigh: transparentColor(darkColorScheme.surfaceContainerHigh, opacity),
                surfaceContainerHighest: transparentColor(darkColorScheme.surfaceContainerHighest, opacity),
                surfaceContainerLow: transparentColor(darkColorScheme.surfaceContainerLow, opacity),
                surfaceContainerLowest: transparentColor(darkColorScheme.surfaceContainerLowest, opacity),
              );
              lightColorScheme = lightColorScheme.copyWith(
                surface: transparentColor(lightColorScheme.surface, opacity),
                surfaceContainer: transparentColor(lightColorScheme.surfaceContainer, opacity),
                surfaceContainerHigh: transparentColor(lightColorScheme.surfaceContainerHigh, opacity),
                surfaceContainerHighest: transparentColor(lightColorScheme.surfaceContainerHighest, opacity),
                surfaceContainerLow: transparentColor(lightColorScheme.surfaceContainerLow, opacity),
                surfaceContainerLowest: transparentColor(lightColorScheme.surfaceContainerLowest, opacity),
              );
            }

            final displayScale = _appearance.displayScale;
            final fontScale = _appearance.fontScale;
            final fontFamily = _appearance.customFontFamily;

            return MaterialApp(
              title: 'Ever Dialer PC',
              debugShowCheckedModeBanner: false,
              themeMode: _appearance.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: fontFamily,
                colorScheme: lightColorScheme,
                scaffoldBackgroundColor: isWhiteMode
                    ? const Color(0xFFFFFFFF).withValues(alpha: (1.0 - transparency).clamp(0.0, 1.0))
                    : lightColorScheme.surface,
                iconTheme: IconThemeData(
                  color: lightColorScheme.onSurface,
                  size: (22 * displayScale.clamp(0.4, 2.0)).clamp(12.0, 44.0),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: lightColorScheme.onSurface,
                  ),
                ),
                visualDensity: VisualDensity(
                  horizontal: ((displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
                  vertical: ((displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamily: fontFamily,
                colorScheme: darkColorScheme,
                scaffoldBackgroundColor: isBlackMode
                    ? const Color(0xFF000000).withValues(alpha: (1.0 - transparency).clamp(0.0, 1.0))
                    : darkColorScheme.surface,
                iconTheme: IconThemeData(
                  color: darkColorScheme.onSurface,
                  size: (22 * displayScale.clamp(0.4, 2.0)).clamp(12.0, 44.0),
                ),
                iconButtonTheme: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: darkColorScheme.onSurface,
                  ),
                ),
                visualDensity: VisualDensity(
                  horizontal: ((displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
                  vertical: ((displayScale.clamp(0.4, 2.0) - 1.0) * 4).clamp(-4.0, 4.0),
                ),
              ),
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                final mediaQuery = MediaQuery.of(context);
                final effectiveDisplay = displayScale.clamp(0.25, 2.0);
                return WindowResizeFrame(
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: TextScaler.linear(fontScale * effectiveDisplay),
                    ),
                    child: child,
                  ),
                );
              },
              home: EverDialerHomePage(
                themeMode: _appearance.themeMode,
                onToggleTheme: _toggleTheme,
                bluetoothService: _bluetoothService,
                syncService: _syncService,
                systemService: _systemService,
                appearance: _appearance,
                prefs: widget.prefs,
                displayScale: displayScale,
                fontScale: fontScale,
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
  final AppearancePreferences? appearance;
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
    this.appearance,
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
  late final AppearancePreferences _appearance;
  late final bool _ownsAppearance;

  @override
  void initState() {
    super.initState();
    if (widget.appearance != null) {
      _appearance = widget.appearance!;
      _ownsAppearance = false;
    } else {
      _appearance = AppearancePreferences(widget.prefs);
      _ownsAppearance = true;
    }

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
    if (_ownsAppearance) {
      _appearance.dispose();
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
          appearance: _appearance,
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
                  overflow: TextOverflow.ellipsis,
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
              appearance: _appearance,
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
                overflow: TextOverflow.ellipsis,
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
