import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/bluetooth_service.dart';
import '../services/sync_service.dart';
import '../widgets/rivo_components.dart';
import '../widgets/audio_status_card.dart';
import '../widgets/window_header_actions.dart';

class SystemAudioScreen extends StatelessWidget {
  final SystemService? systemService;
  final BluetoothService bluetoothService;
  final PcSyncService? syncService;
  final bool isPane;

  const SystemAudioScreen({
    super.key,
    required this.bluetoothService,
    this.systemService,
    this.syncService,
    this.isPane = false,
  });

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      bluetoothService,
      ?systemService,
      ?syncService,
    ];

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final state = bluetoothService.state;

        final content = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isPane ? 24.0 : 18.0,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RivoSectionHeader(title: 'System & Startup'),
              if (systemService != null)
                RivoExpressiveCard(
                  child: Column(
                    children: [
                      RivoSwitchListItem(
                        headline: 'Autostart',
                        supporting: 'Launch Ever Dialer automatically on login',
                        leadingIcon: Icons.power_settings_new,
                        iconColor: const Color(0xFFFF9800),
                        value: systemService!.autostartEnabled,
                        onChanged: (val) => systemService!.setAutostartEnabled(val),
                      ),
                      const RivoDivider(),
                      RivoSwitchListItem(
                        headline: 'Exit on Close',
                        supporting: 'Exit the app completely when closed instead of running in the background',
                        leadingIcon: Icons.exit_to_app_rounded,
                        iconColor: const Color(0xFFE53935),
                        value: systemService!.exitOnClose,
                        onChanged: (val) => systemService!.setExitOnClose(val),
                      ),
                      const RivoDivider(),
                      RivoSwitchListItem(
                        headline: 'Show in system tray',
                        supporting: 'Keep running in background when closed',
                        leadingIcon: Icons.call_to_action_outlined,
                        iconColor: const Color(0xFF2196F3),
                        value: systemService!.systemTrayEnabled,
                        onChanged: (val) => systemService!.setSystemTrayEnabled(val),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              const RivoSectionHeader(title: 'Audio Subsystem'),
              AudioStatusCard(
                state: state,
                onUnmute: () => bluetoothService.unmuteSpeaker(),
                onVolumeChanged: (vol) => bluetoothService.setVolume(vol),
                onRepairAudio: () => bluetoothService.repairAudioRouting(),
                onSelectSink: (sink) => bluetoothService.setOutputSink(sink),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );

        if (isPane) {
          return content;
        }

        return Scaffold(
          appBar: AppBar(
            flexibleSpace: WindowDragArea(
              onStartDrag: () => systemService?.startWindowDrag(),
              onDoubleTap: () => systemService?.toggleMaximizeWindow(),
              child: const SizedBox.expand(),
            ),
            title: const Text('System & Audio'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              WindowHeaderActions(
                syncService: syncService,
                systemService: systemService,
              ),
            ],
          ),
          body: content,
        );
      },
    );
  }
}
