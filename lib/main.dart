import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/bluetooth_service.dart';
import 'widgets/bluetooth_container.dart';
import 'widgets/audio_status_card.dart';

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

  IconData _getThemeIcon() {
    switch (widget.themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeTooltip() {
    switch (widget.themeMode) {
      case ThemeMode.dark:
        return 'Theme: Dark';
      case ThemeMode.light:
        return 'Theme: Light';
      case ThemeMode.system:
        return 'Theme: System Dynamic';
    }
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
          IconButton(
            icon: Icon(_getThemeIcon(), color: colorScheme.onSurfaceVariant),
            tooltip: _getThemeTooltip(),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
            tooltip: 'Refresh Hardware Status',
            onPressed: () {
              _bluetoothService.refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hardware state refreshed'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _bluetoothService,
        builder: (context, _) {
          final state = _bluetoothService.state;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary Container: "Bluetooth Connection"
                BluetoothContainer(
                  state: state,
                  onToggle: (enable) => _bluetoothService.toggleSpeakerMode(enable),
                  onDisconnect: (mac) => _bluetoothService.disconnectDevice(mac),
                ),

                const SizedBox(height: 18),

                // Audio Output & Unmute Card
                AudioStatusCard(
                  state: state,
                  onUnmute: () => _bluetoothService.unmuteSpeaker(),
                  onVolumeChanged: (vol) => _bluetoothService.setVolume(vol),
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
