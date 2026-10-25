import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/sync_service.dart';
import '../services/system_service.dart';
import '../services/appearance_preferences.dart';
import '../widgets/bluetooth_container.dart';
import '../widgets/rivo_components.dart';
import '../widgets/window_header_actions.dart';
import 'appearance_screen.dart';
import 'about_screen.dart';
import 'system_audio_screen.dart';

class SettingsScreen extends StatefulWidget {
  final BluetoothService bluetoothService;
  final PcSyncService? syncService;
  final SystemService? systemService;
  final AppearancePreferences appearance;

  // Legacy compatibility parameters
  final ThemeMode? themeMode;
  final VoidCallback? onToggleTheme;
  final double displayScale;
  final double fontScale;
  final ValueChanged<double>? onUpdateDisplayScale;
  final ValueChanged<double>? onUpdateFontScale;
  final VoidCallback? onResetDisplayScale;
  final VoidCallback? onResetFontScale;

  const SettingsScreen({
    super.key,
    required this.bluetoothService,
    required this.appearance,
    this.syncService,
    this.systemService,
    this.themeMode,
    this.onToggleTheme,
    this.displayScale = 1.0,
    this.fontScale = 1.0,
    this.onUpdateDisplayScale,
    this.onUpdateFontScale,
    this.onResetDisplayScale,
    this.onResetFontScale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Selected detail pane for dual-pane layout: 'appearance', 'system_audio', 'about'
  String _selectedSection = 'appearance';

  void _navigateToDetail(String section) {
    setState(() => _selectedSection = section);
  }

  void _pushScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.bluetoothService,
        if (widget.syncService != null) widget.syncService!,
        if (widget.systemService != null) widget.systemService!,
        widget.appearance,
      ]),
      builder: (context, _) {
        final state = widget.bluetoothService.state;

        return Scaffold(
          appBar: AppBar(
            flexibleSpace: WindowDragArea(
              onStartDrag: () => widget.systemService?.startWindowDrag(),
              onDoubleTap: () => widget.systemService?.toggleMaximizeWindow(),
              child: const SizedBox.expand(),
            ),
            title: const Text('Settings'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              WindowHeaderActions(
                syncService: widget.syncService,
                systemService: widget.systemService,
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth >= 800;

              if (isWideScreen) {
                // Dual pane layout
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left master pane
                    SizedBox(
                      width: (constraints.maxWidth * 0.42).clamp(320.0, 380.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        child: _buildMasterList(
                          state: state,
                          isWideScreen: true,
                        ),
                      ),
                    ),

                    // Right detail pane
                    Expanded(
                      child: _buildDetailPane(state),
                    ),
                  ],
                );
              }

              // Single pane layout for smaller screens
              return _buildMasterList(
                state: state,
                isWideScreen: false,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMasterList({
    required BluetoothState state,
    required bool isWideScreen,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Top Section: Bluetooth Connection & Sync ────────
          BluetoothContainer(
            state: state,
            syncService: widget.syncService,
            onToggle: (enable) {
              widget.bluetoothService.toggleSpeakerMode(enable);
              widget.syncService?.setPcSyncEnabled(enable);
            },
            onDisconnect: (mac) => widget.bluetoothService.disconnectDevice(mac),
          ),

          const SizedBox(height: 18),

          // ── 2. Appearance Section ──────────────────────────────
          const RivoSectionHeader(title: 'Appearance'),
          RivoExpressiveCard(
            color: isWideScreen && _selectedSection == 'appearance'
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            child: RivoListItem(
              headline: 'Interface',
              supporting: 'Themes, colors, display scaling, and fonts',
              leadingIcon: Icons.palette_outlined,
              iconColor: const Color(0xFF9C27B0),
              onClick: () {
                if (isWideScreen) {
                  _navigateToDetail('appearance');
                } else {
                  _pushScreen(AppearanceScreen(
                    appearance: widget.appearance,
                    systemService: widget.systemService,
                    syncService: widget.syncService,
                  ));
                }
              },
            ),
          ),

          const SizedBox(height: 14),

          // ── 3. System & Audio Section ──────────────────────────
          const RivoSectionHeader(title: 'System & Audio'),
          RivoExpressiveCard(
            color: isWideScreen && _selectedSection == 'system_audio'
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            child: RivoListItem(
              headline: 'System & Audio',
              supporting: 'Autostart, Exit on Close, system tray, and PipeWire audio routing',
              leadingIcon: Icons.settings_suggest_outlined,
              iconColor: const Color(0xFFFF9800),
              onClick: () {
                if (isWideScreen) {
                  _navigateToDetail('system_audio');
                } else {
                  _pushScreen(SystemAudioScreen(
                    systemService: widget.systemService,
                    bluetoothService: widget.bluetoothService,
                    syncService: widget.syncService,
                  ));
                }
              },
            ),
          ),

          const SizedBox(height: 14),

          // ── 4. About Section ───────────────────────────────────
          const RivoSectionHeader(title: 'About'),
          RivoExpressiveCard(
            color: isWideScreen && _selectedSection == 'about'
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            child: RivoListItem(
              headline: 'About Ever Dialer',
              supporting: 'Version, developer, license, and community',
              leadingIcon: Icons.info_outline,
              iconColor: const Color(0xFF2196F3),
              onClick: () {
                if (isWideScreen) {
                  _navigateToDetail('about');
                } else {
                  _pushScreen(AboutScreen(
                    systemService: widget.systemService,
                    syncService: widget.syncService,
                  ));
                }
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailPane(BluetoothState state) {
    switch (_selectedSection) {
      case 'appearance':
        return AppearanceScreen(
          appearance: widget.appearance,
          isPane: true,
        );
      case 'system_audio':
        return SystemAudioScreen(
          systemService: widget.systemService,
          bluetoothService: widget.bluetoothService,
          syncService: widget.syncService,
          isPane: true,
        );
      case 'about':
      default:
        return const AboutScreen(isPane: true);
    }
  }
}
