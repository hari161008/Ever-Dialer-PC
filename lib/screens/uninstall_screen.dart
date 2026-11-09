import 'package:flutter/material.dart';
import '../services/system_service.dart';
import '../services/sync_service.dart';
import '../widgets/rivo_components.dart';
import '../widgets/window_header_actions.dart';

class UninstallScreen extends StatefulWidget {
  final SystemService? systemService;
  final PcSyncService? syncService;
  final bool isPane;

  const UninstallScreen({
    super.key,
    this.systemService,
    this.syncService,
    this.isPane = false,
  });

  @override
  State<UninstallScreen> createState() => _UninstallScreenState();
}

class _UninstallScreenState extends State<UninstallScreen> {
  String? _detectedPackageType;
  bool _isUninstalling = false;

  @override
  void initState() {
    super.initState();
    _checkPackageStatus();
  }

  Future<void> _checkPackageStatus() async {
    final service = widget.systemService ?? SystemService();
    final pkg = await service.detectSystemPackage();
    if (mounted) {
      setState(() => _detectedPackageType = pkg);
    }
  }

  Future<void> _handleUninstall() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: colorScheme.error,
          ),
          title: const Text('Confirm Uninstallation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to uninstall Ever Dialer PC? This action cannot be undone.',
                style: TextStyle(fontSize: 14),
              ),
              if (_detectedPackageType != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _detectedPackageType!.contains('~/.local')
                            ? Icons.install_desktop_outlined
                            : Icons.admin_panel_settings_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _detectedPackageType!.contains('~/.local')
                              ? 'Will remove $_detectedPackageType and associated desktop shortcuts.'
                              : 'You will be prompted for your password to remove $_detectedPackageType.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Uninstall'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isUninstalling = true);

    try {
      final service = widget.systemService ?? SystemService();
      await service.performUninstall(
        removeSysPackage: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUninstalling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete uninstallation: $e'),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isPane ? 24.0 : 18.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Warning Card ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    size: 30,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uninstall Ever Dialer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cleanly remove all desktop shortcuts, background daemons, cached phone data, and system integrations from this computer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Cleanup Summary ───────────────────────────
          const RivoSectionHeader(title: 'What Will Be Removed'),
          RivoExpressiveCard(
            child: Column(
              children: [
                _buildRemovalItem(
                  icon: Icons.launch_outlined,
                  title: 'Desktop Application Launchers',
                  subtitle: '~/.local/share/applications/ever_dialer_pc.desktop',
                  colorScheme: colorScheme,
                ),
                const RivoDivider(),
                _buildRemovalItem(
                  icon: Icons.power_settings_new_outlined,
                  title: 'Autostart on Boot',
                  subtitle: '~/.config/autostart/ever_dialer_pc.desktop',
                  colorScheme: colorScheme,
                ),
                const RivoDivider(),
                _buildRemovalItem(
                  icon: Icons.image_outlined,
                  title: 'Desktop System Icons',
                  subtitle: '~/.local/share/icons/hicolor/...',
                  colorScheme: colorScheme,
                ),
                const RivoDivider(),
                _buildRemovalItem(
                  icon: Icons.sync_disabled_outlined,
                  title: 'Bluetooth Sync Daemon',
                  subtitle: 'Terminates active bt_sync_daemon.py and lock files',
                  colorScheme: colorScheme,
                ),
                const RivoDivider(),
                _buildRemovalItem(
                  icon: Icons.folder_delete_outlined,
                  title: 'Cached Data & Preferences',
                  subtitle: 'Removes local cache, paired sync data & preferences',
                  colorScheme: colorScheme,
                ),
                if (_detectedPackageType != null) ...[
                  const RivoDivider(),
                  _buildRemovalItem(
                    icon: _detectedPackageType!.contains('~/.local')
                        ? Icons.install_desktop_outlined
                        : Icons.admin_panel_settings_outlined,
                    title: 'Installed Application Files',
                    subtitle: _detectedPackageType!,
                    colorScheme: colorScheme,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Uninstall Action Button ───────────────────
          FilledButton.icon(
            onPressed: _isUninstalling ? null : _handleUninstall,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isUninstalling
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.onError,
                    ),
                  )
                : const Icon(Icons.delete_forever, size: 20),
            label: Text(
              _isUninstalling ? 'Uninstalling...' : 'Uninstall Ever Dialer',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );

    if (widget.isPane) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: WindowDragArea(
          onStartDrag: () => widget.systemService?.startWindowDrag(),
          onDoubleTap: () => widget.systemService?.toggleMaximizeWindow(),
          child: const SizedBox.expand(),
        ),
        title: const Text('Uninstall Ever Dialer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          WindowHeaderActions(
            syncService: widget.syncService,
            systemService: widget.systemService,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildRemovalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: colorScheme.outline,
          ),
        ],
      ),
    );
  }
}
