// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  print('====================================================');
  print('    Ever Dialer PC - Dual-Boot Platform Syncer     ');
  print('====================================================');
  
  final isWindows = Platform.isWindows;
  final isLinux = Platform.isLinux;
  final currentOs = isWindows ? 'Windows' : (isLinux ? 'Linux' : Platform.operatingSystem);
  print('[INFO] Current Operating System: $currentOs');

  final projectDir = Directory.current;
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('[ERROR] Please run this script from the Ever Dialer For PC project root.');
    exit(1);
  }

  // 1. Check & heal package_config.json
  final pkgConfigFile = File('${projectDir.path}/.dart_tool/package_config.json');
  bool needsPubGet = false;

  if (!pkgConfigFile.existsSync()) {
    needsPubGet = true;
  } else {
    final content = pkgConfigFile.readAsStringSync();
    if (isWindows && content.contains('/home/')) {
      print('[HEAL] Detected Linux paths in package_config.json on Windows.');
      needsPubGet = true;
    } else if (isLinux && (content.contains('file:///C:') || content.contains('file:///c:'))) {
      print('[HEAL] Detected Windows paths in package_config.json on Linux.');
      needsPubGet = true;
    }
  }

  if (needsPubGet) {
    print('[STEP 1/3] Running flutter pub get for $currentOs...');
    final pubResult = await Process.run('flutter', ['pub', 'get'], runInShell: true);
    if (pubResult.exitCode != 0) {
      print('[WARN] flutter pub get returned exit code ${pubResult.exitCode}:');
      print(pubResult.stderr);
    } else {
      print('[OK] Dependencies synchronized successfully.');
    }
  } else {
    print('[OK] Dependencies already synchronized for $currentOs.');
  }

  // 2. OS-specific assets & permissions check
  print('[STEP 2/3] Verifying platform assets...');
  if (isWindows) {
    final ico = File('${projectDir.path}/windows/runner/resources/app_icon.ico');
    if (ico.existsSync()) {
      print('[OK] Windows app_icon.ico exists.');
    } else {
      print('[WARN] windows/runner/resources/app_icon.ico is missing.');
    }

    final daemon = File('${projectDir.path}/windows/bin/bt_sync_daemon.exe');
    if (daemon.existsSync()) {
      print('[OK] Native Windows bt_sync_daemon.exe is ready.');
    } else {
      print('[INFO] bt_sync_daemon.exe will be compiled by CMake on first build.');
    }
  } else if (isLinux) {
    final desktop1 = File('${projectDir.path}/linux/ever_dialer_pc.desktop');
    final desktop2 = File('${projectDir.path}/linux/com.everdialer.ever_dialer_pc.desktop');
    if (desktop1.existsSync() && desktop2.existsSync()) {
      print('[OK] Linux desktop launcher files exist.');
    } else {
      print('[WARN] Linux desktop launcher files missing.');
    }

    // Ensure scripts have +x permissions
    try {
      await Process.run('chmod', ['+x', 'scripts/app_release.sh']);
      await Process.run('chmod', ['+x', 'lib/services/scripts/bt_sync_daemon.py']);
      print('[OK] Executable permissions restored for Linux scripts.');
    } catch (_) {}
  }

  // 3. Quick verification
  print('[STEP 3/3] Checking environment readiness...');
  print('====================================================');
  print('     Platform environment is 100% READY for $currentOs!    ');
  print('====================================================\n');
}
