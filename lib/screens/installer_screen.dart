import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/system_service.dart';
import '../widgets/window_header_actions.dart';

// ── Material 3 Expressive Tonal Colors (Solid, No Gradients) ──────────────────
const Color kM3ESurfaceDark = Color(0xFF131316);
const Color kM3ESurfaceLowDark = Color(0xFF191A1F);
const Color kM3ESurfaceContainerDark = Color(0xFF212229);
const Color kM3ESurfaceContainerHighDark = Color(0xFF2A2B34);
const Color kM3ESurfaceContainerHighestDark = Color(0xFF343540);
const Color kM3EOutlineDark = Color(0xFF4A4B56);
const Color kM3EOutlineVariantDark = Color(0xFF2C2D37);
const Color kM3EOnSurfaceDark = Color(0xFFEDEDF2);
const Color kM3EOnSurfaceVariantDark = Color(0xFFA5A6B4);

// Default Accent Theme: Amber / Sunflower Yellow
const Color kM3EYellowPrimary = Color(0xFFFFDD31);
const Color kM3EYellowOnPrimary = Color(0xFF201B00);
const Color kM3EYellowContainer = Color(0xFF423700);
const Color kM3EYellowOnContainer = Color(0xFFFFE259);

/// Entry point application for the Linux Setup Wizard
class EverDialerInstallerApp extends StatelessWidget {
  final SharedPreferences? prefs;

  const EverDialerInstallerApp({super.key, this.prefs});

  @override
  Widget build(BuildContext context) {
    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: kM3EYellowPrimary,
      onPrimary: kM3EYellowOnPrimary,
      primaryContainer: kM3EYellowContainer,
      onPrimaryContainer: kM3EYellowOnContainer,
      secondary: Color(0xFFE2C46D),
      onSecondary: Color(0xFF3B2F00),
      secondaryContainer: Color(0xFF534500),
      onSecondaryContainer: Color(0xFFFFE088),
      tertiary: Color(0xFF8CD6B5),
      onTertiary: Color(0xFF003824),
      tertiaryContainer: Color(0xFF005136),
      onTertiaryContainer: Color(0xFFA8F2D0),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: kM3ESurfaceDark,
      onSurface: kM3EOnSurfaceDark,
      surfaceContainerLowest: Color(0xFF0E0E11),
      surfaceContainerLow: kM3ESurfaceLowDark,
      surfaceContainer: kM3ESurfaceContainerDark,
      surfaceContainerHigh: kM3ESurfaceContainerHighDark,
      surfaceContainerHighest: kM3ESurfaceContainerHighestDark,
      onSurfaceVariant: kM3EOnSurfaceVariantDark,
      outline: kM3EOutlineDark,
      outlineVariant: kM3EOutlineVariantDark,
    );

    return MaterialApp(
      title: 'Ever Dialer PC Setup Wizard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: kM3ESurfaceDark,
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: kM3ESurfaceDark,
        fontFamily: 'Inter',
      ),
      home: const InstallerScreen(),
    );
  }
}

/// Setup Wizard styled after Android Material 3 Expressive & Ever Haptics (No Gradient)
class InstallerScreen extends StatefulWidget {
  const InstallerScreen({super.key});

  @override
  State<InstallerScreen> createState() => _InstallerScreenState();
}

enum _WizardStep {
  setup,
  installing,
  completed,
  error,
}

/// Custom Clipper for an Android 15/16 Expressive Scallop / Flower badge shape
class ExpressiveScallopClipper extends CustomClipper<Path> {
  final int petals;
  final double depth;

  const ExpressiveScallopClipper({this.petals = 12, this.depth = 0.09});

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2;
    final rMin = baseRadius * (1.0 - depth);
    final rMax = baseRadius;
    final totalPoints = petals * 2;
    final step = (math.pi * 2) / totalPoints;

    for (int i = 0; i <= totalPoints; i++) {
      final angle = i * step - math.pi / 2;
      final isPeak = i.isEven;
      final r = isPeak ? rMax : rMin;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevAngle = (i - 1) * step - math.pi / 2;
        final prevR = (!isPeak) ? rMax : rMin;
        final midAngle = (prevAngle + angle) / 2;
        final midR = (prevR + r) / 2;
        final cx = center.dx + midR * math.cos(midAngle);
        final cy = center.dy + midR * math.sin(midAngle);
        path.quadraticBezierTo(cx, cy, x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(ExpressiveScallopClipper oldClipper) =>
      oldClipper.petals != petals || oldClipper.depth != depth;
}

class _InstallerScreenState extends State<InstallerScreen> with SingleTickerProviderStateMixin {
  final SystemService _systemService = SystemService();
  _WizardStep _currentStep = _WizardStep.setup;

  // Configuration options
  bool _isUserInstall = true; // true: ~/.local/share, false: /opt
  bool _createMenuShortcut = true;
  bool _createDesktopShortcut = true;
  bool _createCliSymlink = true;
  bool _autostartOnBoot = false;
  bool _launchAfterFinish = true;

  // Existing installation info
  String? _detectedExistingPackage;
  String? _installedPath;

  // Progress tracking
  int _currentTaskIndex = 0;
  String _currentTaskStatus = 'Preparing installation...';
  double _progressValue = 0.0;
  String? _errorMessage;

  final List<String> _installationTasks = [
    'Preparing target installation folder',
    'Extracting binaries and application resources',
    'Installing application icons to system theme',
    'Creating application menu launcher (.desktop)',
    'Creating desktop shortcut and trusted launcher',
    'Configuring command-line symlink in ~/.local/bin',
    'Setting up uninstaller and receipt metadata',
    'Updating system desktop database and icon caches',
  ];

  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    _checkExistingInstall();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingInstall() async {
    final home = Platform.environment['HOME'] ?? '';
    final detected = await _systemService.detectSystemPackage();

    String? existingPath;
    if (home.isNotEmpty && File('$home/.local/share/ever_dialer_pc/ever_dialer_pc').existsSync()) {
      existingPath = '$home/.local/share/ever_dialer_pc';
    } else if (home.isNotEmpty && File('$home/.local/opt/ever_dialer_pc/ever_dialer_pc').existsSync()) {
      existingPath = '$home/.local/opt/ever_dialer_pc';
    } else if (File('/opt/ever_dialer_pc/ever_dialer_pc').existsSync()) {
      existingPath = '/opt/ever_dialer_pc';
    }

    if (mounted) {
      setState(() {
        _detectedExistingPackage = detected;
        _installedPath = existingPath;
      });
    }
  }

  String _getTargetInstallDir() {
    final home = Platform.environment['HOME'] ?? '';
    if (_isUserInstall) {
      return '$home/.local/share/ever_dialer_pc';
    }
    return '/opt/ever_dialer_pc';
  }

  String _getSourceDir() {
    final appDir = Platform.environment['APPDIR'];
    if (appDir != null && Directory('$appDir/usr/bin').existsSync()) {
      return '$appDir/usr/bin';
    }
    final execDir = File(Platform.resolvedExecutable).parent.path;
    return execDir;
  }

  File? _findIconFile() {
    final appDir = Platform.environment['APPDIR'];
    final candidates = [
      if (appDir != null) '$appDir/ever_dialer_pc.png',
      if (appDir != null) '$appDir/usr/share/icons/hicolor/512x512/apps/ever_dialer_pc.png',
      '${_getSourceDir()}/data/flutter_assets/assets/icons/app_icon_512.png',
      '${_getSourceDir()}/data/flutter_assets/assets/icons/app_icon.png',
      '${_getSourceDir()}/ever_dialer_pc.png',
      'assets/icons/app_icon_512.png',
      'assets/icons/app_icon.png',
    ];

    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) return f;
    }
    return null;
  }

  File? _findUninstallScript() {
    final appDir = Platform.environment['APPDIR'];
    final candidates = [
      if (appDir != null) '$appDir/uninstall.sh',
      if (appDir != null) '$appDir/usr/bin/uninstall.sh',
      '${_getSourceDir()}/uninstall.sh',
      'uninstall.sh',
      'scripts/uninstall.sh',
    ];

    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) return f;
    }
    return null;
  }

  Future<void> _startInstallation() async {
    setState(() {
      _currentStep = _WizardStep.installing;
      _currentTaskIndex = 0;
      _progressValue = 0.08;
      _currentTaskStatus = _installationTasks[0];
    });

    try {
      final home = Platform.environment['HOME'] ?? '';
      final targetDir = _getTargetInstallDir();
      final sourceDir = _getSourceDir();

      // Task 0: Prepare target folder
      await _updateProgress(0, 'Preparing target folder: $targetDir');
      if (_isUserInstall) {
        await Directory(targetDir).create(recursive: true);
      } else {
        await Process.run('pkexec', ['mkdir', '-p', targetDir]);
      }

      // Task 1: Copy binaries and data
      await _updateProgress(1, 'Extracting binaries and application resources...');
      if (_isUserInstall) {
        await _copyDirectory(Directory(sourceDir), Directory(targetDir));
        final exe = File('$targetDir/ever_dialer_pc');
        if (exe.existsSync()) {
          await Process.run('chmod', ['+x', exe.path]);
        }
      } else {
        await Process.run('pkexec', ['cp', '-r', '$sourceDir/.', targetDir]);
        await Process.run('pkexec', ['chmod', '+x', '$targetDir/ever_dialer_pc']);
      }

      // Task 2: Install icons to system theme
      await _updateProgress(2, 'Installing icons to system desktop theme...');
      final iconFile = _findIconFile();
      if (iconFile != null) {
        if (_isUserInstall) {
          final iconSizes = ['512x512', '256x256', '128x128', '64x64', '48x48', '32x32'];
          for (final sz in iconSizes) {
            final iconDir = Directory('$home/.local/share/icons/hicolor/$sz/apps');
            await iconDir.create(recursive: true);
            await iconFile.copy('${iconDir.path}/ever_dialer_pc.png');
          }
          final pixmaps = Directory('$home/.local/share/pixmaps');
          await pixmaps.create(recursive: true);
          await iconFile.copy('${pixmaps.path}/ever_dialer_pc.png');
        } else {
          await Process.run('pkexec', ['bash', '-c', '''
for sz in 512x512 256x256 128x128 64x64 48x48 32x32; do
  mkdir -p "/usr/share/icons/hicolor/\$sz/apps"
  cp "${iconFile.path}" "/usr/share/icons/hicolor/\$sz/apps/ever_dialer_pc.png"
done
mkdir -p /usr/share/pixmaps
cp "${iconFile.path}" /usr/share/pixmaps/ever_dialer_pc.png
''']);
        }
      }

      // Task 3: Create application menu shortcut
      await _updateProgress(3, 'Creating application launcher entry (.desktop)...');
      final desktopEntryContent = '''[Desktop Entry]
Name=Ever Dialer PC
GenericName=Bluetooth Audio Companion
Comment=Stream phone audio to PC speakers and control dialer features
Exec="$targetDir/ever_dialer_pc" %U
Icon=ever_dialer_pc
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Utility;
StartupWMClass=ever_dialer_pc
Keywords=Bluetooth;Dialer;Audio;Speaker;A2DP;
''';

      if (_createMenuShortcut) {
        if (_isUserInstall) {
          final appsDir = Directory('$home/.local/share/applications');
          await appsDir.create(recursive: true);
          final menuFile = File('${appsDir.path}/ever_dialer_pc.desktop');
          await menuFile.writeAsString(desktopEntryContent);
          await Process.run('chmod', ['+x', menuFile.path]);
        } else {
          final tmpDesktop = File('/tmp/ever_dialer_pc.desktop');
          await tmpDesktop.writeAsString(desktopEntryContent);
          await Process.run('pkexec', ['cp', tmpDesktop.path, '/usr/share/applications/ever_dialer_pc.desktop']);
          await Process.run('pkexec', ['chmod', '+x', '/usr/share/applications/ever_dialer_pc.desktop']);
          try { await tmpDesktop.delete(); } catch (_) {}
        }
      }

      // Task 4: Create Desktop shortcut
      await _updateProgress(4, 'Creating Desktop workspace shortcut...');
      if (_createDesktopShortcut && home.isNotEmpty) {
        String desktopDir = '$home/Desktop';
        try {
          final res = Process.runSync('xdg-user-dir', ['DESKTOP']);
          if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
            desktopDir = res.stdout.toString().trim();
          }
        } catch (_) {}

        if (Directory(desktopDir).existsSync()) {
          final desktopIcon = File('$desktopDir/Ever Dialer PC.desktop');
          await desktopIcon.writeAsString(desktopEntryContent);
          await Process.run('chmod', ['+x', desktopIcon.path]);
          await Process.run('gio', ['set', desktopIcon.path, 'metadata::trusted', 'true']);
        }
      }

      // Task 5: Configure CLI symlink in ~/.local/bin
      await _updateProgress(5, 'Configuring terminal command shortcut (~/.local/bin)...');
      if (_createCliSymlink && home.isNotEmpty) {
        final binDir = Directory('$home/.local/bin');
        await binDir.create(recursive: true);
        final symlinkPath = '${binDir.path}/ever_dialer_pc';
        try {
          final oldLink = Link(symlinkPath);
          if (oldLink.existsSync()) await oldLink.delete();
        } catch (_) {}
        await Process.run('ln', ['-sf', '$targetDir/ever_dialer_pc', symlinkPath]);
      }

      // Task 6: Uninstaller script & Receipt
      await _updateProgress(6, 'Configuring uninstaller integration...');
      final uninstallScript = _findUninstallScript();
      if (uninstallScript != null) {
        if (_isUserInstall) {
          final destUninstall = File('$targetDir/uninstall.sh');
          await uninstallScript.copy(destUninstall.path);
          await Process.run('chmod', ['+x', destUninstall.path]);
        } else {
          await Process.run('pkexec', ['cp', uninstallScript.path, '$targetDir/uninstall.sh']);
          await Process.run('pkexec', ['chmod', '+x', '$targetDir/uninstall.sh']);
        }
      }

      // Autostart if selected
      if (_autostartOnBoot && home.isNotEmpty) {
        final autostartDir = Directory('$home/.config/autostart');
        await autostartDir.create(recursive: true);
        final autostartContent = '''[Desktop Entry]
Name=Ever Dialer PC
GenericName=Bluetooth Audio Companion
Comment=Launch Ever Dialer PC in background on system startup
Exec="$targetDir/ever_dialer_pc" --background
Icon=ever_dialer_pc
Terminal=false
Type=Application
Categories=AudioVideo;Utility;
StartupWMClass=ever_dialer_pc
''';
        final autoFile = File('${autostartDir.path}/ever_dialer_pc.desktop');
        await autoFile.writeAsString(autostartContent);
        await Process.run('chmod', ['+x', autoFile.path]);
      }

      // Write install receipt
      final receiptContent = '''# Ever Dialer PC Installation Receipt
version=1.0.0
install_dir=$targetDir
install_type=${_isUserInstall ? 'user' : 'system'}
installed_at=${DateTime.now().toIso8601String()}
installer=AppImage Setup Wizard
''';
      if (_isUserInstall) {
        await File('$targetDir/.install_info').writeAsString(receiptContent);
      }

      // Task 7: Update desktop caches
      await _updateProgress(7, 'Updating desktop database and icon caches...');
      await Process.run('bash', [
        '-c',
        '''
update-desktop-database "$home/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache "$home/.local/share/icons/hicolor" 2>/dev/null || true
kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
'''
      ]);

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _progressValue = 1.0;
          _currentStep = _WizardStep.completed;
        });
      }
    } catch (e, st) {
      debugPrint('[Installer] Error during installation: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _currentStep = _WizardStep.error;
        });
      }
    }
  }

  Future<void> _updateProgress(int taskIndex, String status) async {
    if (!mounted) return;
    setState(() {
      _currentTaskIndex = taskIndex;
      _currentTaskStatus = status;
      _progressValue = (taskIndex + 1) / (_installationTasks.length + 1);
    });
    await Future.delayed(const Duration(milliseconds: 140));
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final baseName = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is Directory) {
        final newDirectory = Directory('${destination.path}/$baseName');
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File('${destination.path}/$baseName');
        await entity.copy(newFile.path);
        if (baseName == 'ever_dialer_pc' || baseName.endsWith('.sh') || baseName.endsWith('.so')) {
          await Process.run('chmod', ['+x', newFile.path]);
        }
      }
    }
  }

  /// Launch application reliably decoupling from AppImage environment
  Future<void> _launchAppAt(String targetDir) async {
    final exe = '$targetDir/ever_dialer_pc';
    if (!File(exe).existsSync()) {
      debugPrint('[Installer] Binary not found at: $exe');
      return;
    }

    // Clean up environment variables so child process does not link to unmounted AppImage mount point
    final cleanEnv = Map<String, String>.from(Platform.environment);
    cleanEnv.remove('APPIMAGE');
    cleanEnv.remove('APPDIR');
    cleanEnv.remove('ARGV0');
    cleanEnv.remove('OWD');
    cleanEnv['LD_LIBRARY_PATH'] = '$targetDir/lib';

    bool launched = false;

    // 1. Try launching through gtk-launch or desktop entry if desktop launcher was installed
    final home = Platform.environment['HOME'] ?? '';
    final desktopFile = File('$home/.local/share/applications/ever_dialer_pc.desktop');
    if (desktopFile.existsSync()) {
      try {
        final res = await Process.run('gtk-launch', ['ever_dialer_pc.desktop'], environment: cleanEnv);
        if (res.exitCode == 0) {
          launched = true;
        }
      } catch (e) {
        debugPrint('[Installer] gtk-launch fallback: $e');
      }
    }

    // 2. Direct clean detached invocation via nohup
    if (!launched) {
      try {
        await Process.start(
          'nohup',
          [exe],
          workingDirectory: targetDir,
          environment: cleanEnv,
          mode: ProcessStartMode.detached,
        );
        launched = true;
      } catch (e) {
        debugPrint('[Installer] nohup start failed: $e, trying direct Process.start');
        try {
          await Process.start(
            exe,
            [],
            workingDirectory: targetDir,
            environment: cleanEnv,
            mode: ProcessStartMode.detached,
          );
          launched = true;
        } catch (e2) {
          debugPrint('[Installer] Direct launch failed: $e2');
        }
      }
    }

    // Give the child process a short moment to initialize and fork before closing the wizard
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  void _finishAndLaunch() {
    final targetDir = _getTargetInstallDir();
    if (_launchAfterFinish) {
      _launchAppAt(targetDir);
    } else {
      exit(0);
    }
  }

  void _launchExistingApp() {
    if (_installedPath != null) {
      _launchAppAt(_installedPath!);
    }
  }

  Future<void> _uninstallExisting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kM3ESurfaceContainerDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Confirm Uninstallation'),
        content: Text(
          'Are you sure you want to completely remove Ever Dialer PC from $_installedPath?',
          style: const TextStyle(color: kM3EOnSurfaceVariantDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _systemService.performUninstall(removeSysPackage: true);
      await _checkExistingInstall();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uninstall failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Window Draggable Strip with App Icon & Controls ────────
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: colorScheme.surfaceContainerLowest,
              child: Row(
                children: [
                  // App Icon Badge in Title Bar
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.phone_in_talk_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ever Dialer PC',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Setup',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Draggable center area
                  Expanded(
                    child: WindowDragArea(
                      onStartDrag: () => _systemService.startWindowDrag(),
                      onDoubleTap: () => _systemService.toggleMaximizeWindow(),
                      child: const SizedBox.expand(),
                    ),
                  ),

                  // Window Buttons
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Minimize',
                    onPressed: () => _systemService.minimizeWindow(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Close',
                    onPressed: () => exit(0),
                  ),
                ],
              ),
            ),

            // ── Main Content Area ────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildCurrentView(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(BuildContext context) {
    switch (_currentStep) {
      case _WizardStep.setup:
        return _buildExpressiveSetupView(context);
      case _WizardStep.installing:
        return _buildExpressiveInstallingView(context);
      case _WizardStep.completed:
        return _buildExpressiveCompletedView(context);
      case _WizardStep.error:
        return _buildExpressiveErrorView(context);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 1. EXPRESSIVE SETUP VIEW (No Gradients, Ever Haptics Inspired)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExpressiveSetupView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final home = Platform.environment['HOME'] ?? '';

    int activeCount = 1;
    if (_createMenuShortcut) activeCount++;
    if (_createDesktopShortcut) activeCount++;
    if (_createCliSymlink) activeCount++;
    if (_autostartOnBoot) activeCount++;
    const totalCount = 5;

    return Column(
      key: const ValueKey('expressive_setup_view'),
      children: [
        // ── Solid Hero Banner with Scallop Badge ───────────────────────
        _buildHeroBanner(
          context: context,
          title: 'Ever Dialer PC',
          subtitle: 'Install the Bluetooth companion dialer and audio streamer on your PC.',
          badgeIcon: Icons.phone_in_talk_rounded,
          tag: 'Linux Setup',
        ),

        // ── Selected Count Strip ──────────────────────────────────────
        Container(
          width: double.infinity,
          color: colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configuration',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$activeCount of $totalCount items enabled',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable Configuration Cards ────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Existing install banner if present (Ever Haptics EnableServiceCard style)
                if (_installedPath != null) ...[
                  _buildExistingInstallCard(context, colorScheme),
                  const SizedBox(height: 14),
                ],

                // ── Section 1: Target Destination ───────────────────────
                _buildSectionCard(
                  context: context,
                  title: 'INSTALLATION LOCATION',
                  subtitle: 'Select where Ever Dialer PC binaries will reside',
                  icon: Icons.folder_rounded,
                  children: [
                    _buildSelectionRow(
                      context: context,
                      title: 'User Space',
                      subtitle: '$home/.local/share/ever_dialer_pc',
                      badge: 'Recommended',
                      icon: Icons.person_rounded,
                      isSelected: _isUserInstall,
                      onTap: () => setState(() => _isUserInstall = true),
                    ),
                    const SizedBox(height: 8),
                    _buildSelectionRow(
                      context: context,
                      title: 'System Wide',
                      subtitle: '/opt/ever_dialer_pc (Root permissions required)',
                      badge: 'All Users',
                      icon: Icons.admin_panel_settings_rounded,
                      isSelected: !_isUserInstall,
                      onTap: () => setState(() => _isUserInstall = false),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Section 2: Desktop Integrations ─────────────────────
                _buildSectionCard(
                  context: context,
                  title: 'DESKTOP INTEGRATIONS',
                  subtitle: 'System shortcuts and desktop environment features',
                  icon: Icons.dashboard_customize_rounded,
                  children: [
                    _buildToggleRow(
                      context: context,
                      title: 'Application Menu Launcher',
                      subtitle: 'Add Ever Dialer to your Start menu & Application drawer',
                      icon: Icons.apps_rounded,
                      value: _createMenuShortcut,
                      onChanged: (v) => setState(() => _createMenuShortcut = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      context: context,
                      title: 'Desktop Workspace Shortcut',
                      subtitle: 'Place a quick launcher icon on your desktop wallpaper',
                      icon: Icons.desktop_windows_rounded,
                      value: _createDesktopShortcut,
                      onChanged: (v) => setState(() => _createDesktopShortcut = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      context: context,
                      title: 'Terminal CLI Command',
                      subtitle: 'Add `ever_dialer_pc` executable symlink into ~/.local/bin',
                      icon: Icons.terminal_rounded,
                      value: _createCliSymlink,
                      onChanged: (v) => setState(() => _createCliSymlink = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      context: context,
                      title: 'Start Minimized on Boot',
                      subtitle: 'Run background sync daemon when logging into your PC',
                      icon: Icons.power_settings_new_rounded,
                      value: _autostartOnBoot,
                      onChanged: (v) => setState(() => _autostartOnBoot = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── Solid Bottom Action Bar (Ever Haptics / M3E stadium button) ─
        _buildBottomBar(
          context: context,
          buttonText: 'Install Ever Dialer PC',
          icon: Icons.arrow_forward_rounded,
          onPressed: _startInstallation,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 2. EXPRESSIVE INSTALLING VIEW
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExpressiveInstallingView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('expressive_installing_view'),
      children: [
        _buildHeroBanner(
          context: context,
          title: 'Installing Files',
          subtitle: 'Please wait while binaries, desktop launchers, and assets are written.',
          badgeIcon: Icons.downloading_rounded,
          tag: '${(_progressValue * 100).toInt()}% Done',
        ),

        // Progress Indicator Strip
        Container(
          width: double.infinity,
          color: colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _currentTaskStatus,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Step ${_currentTaskIndex + 1}/${_installationTasks.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progressValue,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Task Items List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: _installationTasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final isDone = index < _currentTaskIndex;
              final isCurrent = index == _currentTaskIndex;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colorScheme.surfaceContainerHighest
                      : isDone
                          ? colorScheme.surfaceContainerHigh
                          : colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrent
                        ? colorScheme.primary
                        : isDone
                            ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                            : Colors.transparent,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? colorScheme.primary
                            : isCurrent
                                ? colorScheme.primary.withValues(alpha: 0.22)
                                : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? Icon(Icons.check_rounded, size: 16, color: colorScheme.onPrimary)
                            : isCurrent
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _installationTasks[index],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? colorScheme.onSurface
                              : isDone
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom progress indicator button
        _buildBottomBar(
          context: context,
          buttonText: 'Installing...',
          icon: null,
          onPressed: null,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 3. EXPRESSIVE COMPLETED VIEW
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExpressiveCompletedView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final targetDir = _getTargetInstallDir();

    return Column(
      key: const ValueKey('expressive_completed_view'),
      children: [
        _buildHeroBanner(
          context: context,
          title: 'Installation Complete!',
          subtitle: 'Ever Dialer PC was successfully set up and integrated with your desktop.',
          badgeIcon: Icons.check_circle_rounded,
          tag: 'Success',
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionCard(
                  context: context,
                  title: 'SUMMARY & RECEIPT',
                  subtitle: 'Configuration details for this installation',
                  icon: Icons.receipt_long_rounded,
                  children: [
                    _buildSummaryItem(
                      icon: Icons.folder_rounded,
                      title: 'Installation Folder',
                      value: targetDir,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryItem(
                      icon: Icons.apps_rounded,
                      title: 'Desktop Launcher',
                      value: _createMenuShortcut ? 'Configured in applications' : 'Skipped',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryItem(
                      icon: Icons.delete_outline_rounded,
                      title: 'In-App Uninstaller',
                      value: '$targetDir/uninstall.sh',
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Launch after finish checkbox container
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: CheckboxListTile(
                    value: _launchAfterFinish,
                    onChanged: (val) => setState(() => _launchAfterFinish = val ?? true),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: const Text(
                      'Launch Ever Dialer PC now',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Open the application immediately after closing this wizard',
                      style: TextStyle(fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: colorScheme.primary,
                    checkColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Button
        _buildBottomBar(
          context: context,
          buttonText: _launchAfterFinish ? 'Finish & Launch Ever Dialer' : 'Close Setup Wizard',
          icon: _launchAfterFinish ? Icons.rocket_launch_rounded : Icons.check_rounded,
          onPressed: _finishAndLaunch,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 4. EXPRESSIVE ERROR VIEW
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildExpressiveErrorView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const ValueKey('expressive_error_view'),
      children: [
        _buildHeroBanner(
          context: context,
          title: 'Installation Issue',
          subtitle: 'An unexpected error occurred while writing files or registering components.',
          badgeIcon: Icons.error_outline_rounded,
          tag: 'Error',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 40, color: colorScheme.onErrorContainer),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage ?? 'Unknown installation error occurred.',
                        style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          context: context,
          buttonText: 'Retry Setup',
          icon: Icons.refresh_rounded,
          onPressed: () => setState(() => _currentStep = _WizardStep.setup),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // REUSABLE EXPRESSIVE COMPONENTS (NO GRADIENTS)
  // ═════════════════════════════════════════════════════════════════════════

  /// Solid Hero Banner with Scallop Badge (Android 15/16 Clock & Widget Shape)
  Widget _buildHeroBanner({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData badgeIcon,
    required String tag,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Scallop Badge
          ScaleTransition(
            scale: _pulseAnimation,
            child: ClipPath(
              clipper: const ExpressiveScallopClipper(petals: 12, depth: 0.12),
              child: Container(
                width: 68,
                height: 68,
                color: colorScheme.primary,
                child: Center(
                  child: Icon(
                    badgeIcon,
                    size: 32,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),

          // Titles & Status Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Card (Directly inspired by Ever Haptics SectionCard.kt)
  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row (Ever Haptics style)
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content children
          ...children,
        ],
      ),
    );
  }

  /// Interactive Selection Row (For User vs System installation destination)
  Widget _buildSelectionRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.2)
                              : colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check_rounded, size: 12, color: colorScheme.onPrimary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isSelected ? 'Selected' : 'Choose',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle Row (Directly inspired by Ever Haptics HapticToggleRow.kt)
  Widget _buildToggleRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: value ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: colorScheme.primary,
              activeThumbColor: colorScheme.onPrimary,
              inactiveTrackColor: colorScheme.surfaceContainerHigh,
              inactiveThumbColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Existing Install Card (Directly inspired by Ever Haptics EnableServiceCard.kt)
  Widget _buildExistingInstallCard(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(Icons.info_outline_rounded, size: 22, color: colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing Installation Detected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      _detectedExistingPackage != null
                          ? '$_detectedExistingPackage installed at ${_installedPath ?? ''}'
                          : (_installedPath ?? 'System installation'),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                  label: const Text('Launch App'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _launchExistingApp,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Uninstall'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _uninstallExisting,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Summary item for completed view
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Elevated Bottom Bar with Stadium Button
  Widget _buildBottomBar({
    required BuildContext context,
    required String buttonText,
    required IconData? icon,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
            disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                buttonText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
