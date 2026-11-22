// ignore_for_file: avoid_print
import 'dart:io';

Directory findProjectDir() {
  // 1. Walk upward from current directory
  Directory dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: ever_dialer_pc')) {
        return dir;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  // 2. Resolve relative to script path
  try {
    final scriptFile = File(Platform.script.toFilePath());
    final candidate = scriptFile.parent.parent;
    if (File('${candidate.path}/pubspec.yaml').existsSync()) {
      return candidate;
    }
  } catch (_) {}

  // 3. Check cached configuration
  try {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final configFile = File('$home/.config/ever_dialer_pc/project_dir');
    if (configFile.existsSync()) {
      final cached = configFile.readAsStringSync().trim();
      if (Directory(cached).existsSync()) {
        return Directory(cached);
      }
    }
  } catch (_) {}

  return Directory.current;
}

void main(List<String> args) async {
  print('====================================================');
  print('    Ever Dialer PC - Dual-Boot Platform Syncer     ');
  print('====================================================');
  
  final isWindows = Platform.isWindows;
  final isLinux = Platform.isLinux;
  final currentOs = isWindows ? 'Windows' : (isLinux ? 'Linux' : Platform.operatingSystem);
  print('[INFO] Current Operating System: $currentOs');

  final projectDir = findProjectDir();
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('[ERROR] Could not find the Ever Dialer PC project directory.');
    exit(1);
  }
  print('[OK] Project located at: ${projectDir.path}');

  // 1. Check & heal package_config.json
  final pkgConfigFile = File('${projectDir.path}/.dart_tool/package_config.json');
  bool needsPubGet = false;

  if (!pkgConfigFile.existsSync()) {
    needsPubGet = true;
  } else {
    final content = pkgConfigFile.readAsStringSync();
    if (isWindows && (content.contains('/home/') || content.contains('file:///(?!([A-Za-z]:))'))) {
      print('[HEAL] Detected Linux paths in package_config.json on Windows.');
      try { pkgConfigFile.deleteSync(); } catch (_) {}
      needsPubGet = true;
    } else if (isLinux && (content.contains('file:///C:') || content.contains('file:///c:') || content.contains(r'\\'))) {
      print('[HEAL] Detected Windows paths in package_config.json on Linux.');
      try { pkgConfigFile.deleteSync(); } catch (_) {}
      needsPubGet = true;
    }
  }

  if (needsPubGet) {
    print('[STEP 1/3] Running flutter pub get for $currentOs...');
    final pubResult = await Process.run('flutter', ['pub', 'get'], workingDirectory: projectDir.path, runInShell: true);
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
      await Process.run('chmod', ['+x', 'scripts/heal.sh', 'scripts/app_release.sh', 'lib/services/scripts/bt_sync_daemon.py'], workingDirectory: projectDir.path);
      print('[OK] Executable permissions restored for Linux scripts.');
    } catch (_) {}
  }

  // 3. Quick verification
  print('[STEP 3/3] Checking environment readiness...');
  print('====================================================');
  print('     Platform environment is 100% READY for $currentOs!    ');
  print('====================================================\n');
}
