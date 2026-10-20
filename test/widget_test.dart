import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ever_dialer_pc/main.dart';
import 'package:ever_dialer_pc/services/bluetooth_service.dart';
import 'package:ever_dialer_pc/services/sync_service.dart';

void main() {
  testWidgets('EverDialerApp shows header without Material You pill and opens Settings screen with Appearance sliders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );
    final mockSyncService = PcSyncService(prefs: prefs);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Verify main screen header exists and Material You indicator is REMOVED
    expect(find.text('Ever Dialer PC'), findsWidgets);
    expect(find.text('Material You'), findsNothing);

    // Verify Settings icon in top right AppBar actions
    final settingsIconFinder = find.byIcon(Icons.settings_outlined);
    expect(settingsIconFinder, findsOneWidget);

    // Verify default state is OFF
    expect(mockService.state.speakerModeEnabled, false);
    expect(find.text('Speaker mode is currently OFF'), findsOneWidget);

    // Tap the Settings icon to open Settings screen
    await tester.tap(settingsIconFinder);
    await tester.pumpAndSettle();

    // Verify that Settings screen is open and contains "Bluetooth PC Sync" and "Bluetooth Connection" containers
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Bluetooth PC Sync'), findsOneWidget);
    expect(find.text('Bluetooth Connection'), findsOneWidget);
    expect(find.text('Media Speaker Mode Disabled'), findsOneWidget);

    // Verify that Display scale and Font scale sliders exist in Appearance card
    expect(find.text('Display scale'), findsOneWidget);
    expect(find.text('UI and layout scaling'), findsOneWidget);
    expect(find.text('Font scale'), findsOneWidget);
    expect(find.text('Text size scaling'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(2)); // Both default to 100%

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('EverDialerApp shows Mobile Ever Dialer landscape layout when Bluetooth PC Sync is ON', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_sync_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );
    final mockSyncService = PcSyncService(prefs: prefs);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // In sync mode, old speaker status and about are REMOVED from the main screen
    expect(find.text('Media Speaker Status'), findsNothing);
    expect(find.text('About Ever Dialer PC'), findsNothing);

    // The mobile landscape navigation rail tabs are visible
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Calls'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    // Tap on Calls tab
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.text('Call Logs'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);

    // Tap on Contacts tab
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Search contacts...'), findsOneWidget);

    // Tap on SMS tab
    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsOneWidget);

    // Tap on Notes tab
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Add Note'), findsOneWidget);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('EverDialerApp restores ON state and scale settings when persisted', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'speaker_mode_enabled': true,
      'display_scale': 1.15,
      'font_scale': 1.25,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );
    final mockSyncService = PcSyncService(prefs: prefs);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
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

    // Verify persisted scale values are reflected
    expect(find.text('115%'), findsOneWidget);
    expect(find.text('125%'), findsOneWidget);

    mockService.dispose();
    mockSyncService.dispose();
  });
}
