import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ever_dialer_pc/main.dart';
import 'package:ever_dialer_pc/services/bluetooth_service.dart';

void main() {
  testWidgets('EverDialerApp shows Settings icon and opens Settings screen with Bluetooth Connection container', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );

    await tester.pumpWidget(EverDialerApp(bluetoothService: mockService, prefs: prefs));
    await tester.pump();

    // Verify main screen header and Material You indicator
    expect(find.text('Ever Dialer PC'), findsWidgets);
    expect(find.text('Material You'), findsOneWidget);

    // Verify Settings icon in top right AppBar actions
    final settingsIconFinder = find.byIcon(Icons.settings_outlined);
    expect(settingsIconFinder, findsOneWidget);

    // Verify default state is OFF
    expect(mockService.state.speakerModeEnabled, false);
    expect(find.text('Speaker mode is currently OFF'), findsOneWidget);

    // Tap the Settings icon to open Settings screen
    await tester.tap(settingsIconFinder);
    await tester.pumpAndSettle();

    // Verify that Settings screen is open and contains "Bluetooth Connection" container
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Media Speaker Mode Disabled'), findsOneWidget);

    mockService.dispose();
  });

  testWidgets('EverDialerApp restores ON state when persisted and reflects on Settings screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'speaker_mode_enabled': true});
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );

    await tester.pumpWidget(EverDialerApp(bluetoothService: mockService, prefs: prefs));
    await tester.pump();

    // Verify persisted state is ON
    expect(mockService.state.speakerModeEnabled, true);

    // Open Settings screen via button
    final settingsButtonFinder = find.text('Bluetooth & Speaker Settings');
    expect(settingsButtonFinder, findsOneWidget);
    await tester.tap(settingsButtonFinder);
    await tester.pumpAndSettle();

    // Verify Bluetooth Connection container shows enabled status
    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Media Speaker Mode Disabled'), findsNothing);

    mockService.dispose();
  });
}
