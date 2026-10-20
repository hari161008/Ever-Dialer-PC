import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/bluetooth_service.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(EverDialerApp(prefs: prefs));
}

// Default fallback accent color: KDE Gold/Amber system accent
const _fallbackAccentColor = Color(0xFFFFDD31);

class EverDialerApp extends StatefulWidget {
  final BluetoothService? bluetoothService;
  final SharedPreferences? prefs;

  const EverDialerApp({
    super.key,
    this.bluetoothService,
    this.prefs,
  });

  @override
  State<EverDialerApp> createState() => _EverDialerAppState();
}

class _EverDialerAppState extends State<EverDialerApp> {
  ThemeMode _themeMode = ThemeMode.system;

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
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightColorScheme = lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackAccentColor,
              brightness: Brightness.light,
            );

        final ColorScheme darkColorScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _fallbackAccentColor,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Ever Dialer PC',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: lightColorScheme.surface,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: darkColorScheme.surface,
          ),
          home: EverDialerHomePage(
            themeMode: _themeMode,
            onToggleTheme: _toggleTheme,
            bluetoothService: widget.bluetoothService,
            prefs: widget.prefs,
          ),
        );
      },
    );
  }
}

class EverDialerHomePage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final BluetoothService? bluetoothService;
  final SharedPreferences? prefs;

  const EverDialerHomePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    this.bluetoothService,
    this.prefs,
  });

  @override
  State<EverDialerHomePage> createState() => _EverDialerHomePageState();
}

class _EverDialerHomePageState extends State<EverDialerHomePage> {
  late final BluetoothService _bluetoothService;
  late final bool _ownsService;

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
  }

  @override
  void dispose() {
    if (_ownsService) {
      _bluetoothService.dispose();
    }
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          bluetoothService: _bluetoothService,
          themeMode: widget.themeMode,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Ever Dialer PC',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Material You',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Settings Icon at Top Right Corner
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
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
                    side: BorderSide(
                      color: isEnabled
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : colorScheme.outlineVariant,
                      width: 1.2,
                    ),
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
                                    'Media Speaker Status',
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
                                      'Speaker mode is currently OFF',
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
                                label: const Text('Bluetooth & Speaker Settings'),
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
                    side: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1.2,
                    ),
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
                          'Ever Dialer PC enables your laptop to act as a wireless A2DP media speaker using Linux PipeWire and BlueZ.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Click the Settings icon at the top right to toggle the Bluetooth speaker mode, manage audio output, or change appearance themes.',
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
                    'PipeWire A2DP Audio Sink • BlueZ 5 • Fedora Linux',
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
  }
}
