import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ever_dialer_pc/main.dart';
import 'package:ever_dialer_pc/services/bluetooth_service.dart';
import 'package:ever_dialer_pc/services/sync_service.dart';
import 'package:ever_dialer_pc/widgets/bluetooth_container.dart';
import 'package:ever_dialer_pc/widgets/audio_status_card.dart';

void main() {
  testWidgets('EverDialerApp shows dashboard and opens Settings screen with unified Bluetooth Connection & Sync container', (WidgetTester tester) async {
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

    // Verify main screen header exists
    expect(find.text('Ever Dialer PC'), findsWidgets);
    expect(find.text('Material You'), findsNothing);

    // Verify Settings icon in top right AppBar actions is removed
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    // Verify default state is OFF
    expect(mockService.state.speakerModeEnabled, false);
    expect(mockSyncService.pcSyncEnabled, false);
    expect(find.text('Bluetooth connection & sync are currently OFF'), findsOneWidget);

    // Tap "Bluetooth & Sync Settings" button on the dashboard to open Settings screen
    final settingsButtonFinder = find.text('Bluetooth & Sync Settings');
    expect(settingsButtonFinder, findsOneWidget);
    await tester.tap(settingsButtonFinder);
    await tester.pumpAndSettle();

    // Verify that Settings screen has the single unified "Bluetooth Connection & Sync" container
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Bluetooth Connection & Sync'), findsOneWidget);
    // Verify "Bluetooth PC Sync" as a separate card is removed
    expect(find.text('Bluetooth PC Sync'), findsNothing);
    // Verify "Landscape view active" description is removed
    expect(find.textContaining('Landscape view active'), findsNothing);
    expect(find.text('Bluetooth & Sync Disabled'), findsOneWidget);

    // Verify single toggle exists and toggling it enables both features
    final toggleFinder = find.descendant(
      of: find.byType(BluetoothContainer),
      matching: find.byType(Switch),
    );
    expect(toggleFinder, findsOneWidget);
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(mockService.state.speakerModeEnabled, true);
    expect(mockSyncService.pcSyncEnabled, true);

    // Verify that Display scale and Font scale sliders exist in Appearance card
    expect(find.text('Display scale'), findsOneWidget);
    expect(find.text('UI and layout scaling'), findsOneWidget);
    expect(find.text('Font scale'), findsOneWidget);
    expect(find.text('Text size scaling'), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(2)); // Both default to 100%

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('EverDialerApp shows Mobile Ever Dialer landscape layout when Bluetooth Connection & Sync is ON', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_sync_enabled': true,
      'speaker_mode_enabled': true,
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
    expect(find.text('Bluetooth connection & sync are currently OFF'), findsNothing);
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

  testWidgets('EverDialerApp restores scale settings when persisted', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
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

    // Open Settings screen via button
    final settingsButtonFinder = find.text('Bluetooth & Sync Settings');
    expect(settingsButtonFinder, findsOneWidget);
    await tester.tap(settingsButtonFinder);
    await tester.pumpAndSettle();

    // Verify unified Bluetooth Connection & Sync container exists
    expect(find.text('Bluetooth Connection & Sync'), findsOneWidget);

    // Verify card order: Theme & Appearance is below Bluetooth container and above Audio card
    final btY = tester.getTopLeft(find.byType(BluetoothContainer)).dy;
    final themeY = tester.getTopLeft(find.text('Appearance Theme')).dy;
    final audioY = tester.getTopLeft(find.byType(AudioStatusCard)).dy;
    expect(btY < themeY, isTrue);
    expect(themeY < audioY, isTrue);

    // Verify persisted scale values are reflected
    expect(find.text('115%'), findsOneWidget);
    expect(find.text('125%'), findsOneWidget);

    // Verify display scale slider range is 0% to 200%
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('200%'), findsWidgets);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('SMS view marks active thread as read on open and supports message context menu', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_sync_enabled': true,
      'speaker_mode_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );
    final mockSyncService = PcSyncService(prefs: prefs);

    // Populate mock SMS thread with unread count
    mockSyncService.updateFromPayload({
      'smsThreads': [
        {
          'id': 'thread_101',
          'contactName': 'Alice Smith',
          'phone': '+15550199',
          'snippet': 'Hey, call me at +15550199 or visit https://google.com',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'unreadCount': 2,
          'messages': [
            {
              'id': 'msg_1',
              'body': 'First message',
              'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
              'isOutgoing': false,
            },
            {
              'id': 'msg_2',
              'body': 'Hey, call me at +15550199 or visit https://google.com',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'isOutgoing': false,
            },
          ],
        }
      ]
    });

    // Unread count should initially be 2
    expect(mockSyncService.smsThreads.first.unreadCount, 2);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Switch to SMS tab
    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();

    // Opening the thread should automatically mark it as read
    expect(mockSyncService.smsThreads.first.unreadCount, 0);

    // Verify reverse ListView exists inside SelectionArea
    final listViewFinder = find.byWidgetPredicate(
      (w) => w is ListView && w.reverse == true,
    );
    expect(listViewFinder, findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);

    // Right click (secondary tap) on msg_1 to open context menu
    final msgFinder = find.text('First message');
    expect(msgFinder, findsOneWidget);
    await tester.tap(msgFinder, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    // Verify context menu items match mobile version
    expect(find.text('Pin message'), findsOneWidget);
    expect(find.text('Star message'), findsOneWidget);
    expect(find.text('Select text'), findsOneWidget);
    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap "Star message"
    await tester.tap(find.text('Star message'));
    await tester.pumpAndSettle();
    expect(mockSyncService.isMessageStarred('msg_1'), true);

    // Open context menu again and verify it now says "Unstar message"
    await tester.tap(msgFinder, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Unstar message'), findsOneWidget);

    // Tap "Pin message"
    await tester.tap(find.text('Pin message'));
    await tester.pumpAndSettle();
    expect(mockSyncService.isMessagePinned('msg_1'), true);

    // Open context menu again and tap "Select text"
    await tester.tap(msgFinder, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select text'));
    await tester.pumpAndSettle();

    // Verify Select text dialog opens with "Copy all" and "Done"
    expect(find.text('Select text'), findsWidgets);
    expect(find.text('Copy all'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Now test phone number tap and URL recognizer inside message
    final textRichFinder = find.byWidgetPredicate(
      (w) => w is Text && w.textSpan != null && w.textSpan!.toPlainText().contains('+15550199'),
    );
    expect(textRichFinder, findsOneWidget);
    final textWidget = tester.widget<Text>(textRichFinder);
    final rootSpan = textWidget.textSpan as TextSpan;
    final phoneSpan = (rootSpan.children ?? []).cast<TextSpan>().firstWhere(
      (s) => s.text == '+15550199',
    );
    final urlSpan = (rootSpan.children ?? []).cast<TextSpan>().firstWhere(
      (s) => s.text == 'https://google.com',
    );
    expect(urlSpan.recognizer, isA<TapGestureRecognizer>());

    // Trigger phone tap
    (phoneSpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();

    // Verify Phone action popup with Call, Text, Copy Number options
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Copy Number'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('SMS view displays category chips and filters container-grouped threads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_sync_enabled': true,
      'speaker_mode_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final mockService = BluetoothService(
      autoStartTimer: false,
      autoRefresh: false,
      prefs: prefs,
    );
    final mockSyncService = PcSyncService(prefs: prefs);

    final now = DateTime.now().millisecondsSinceEpoch;
    mockSyncService.updateFromPayload({
      'pinnedSmsThreadIds': ['thread_fav'],
      'starredSmsMessageIds': ['msg_starred'],
      'smsThreads': [
        {
          'id': 'thread_fav',
          'contactName': 'Favorite Friend',
          'phone': '+1111111111',
          'snippet': 'Hello there!',
          'timestamp': now,
          'unreadCount': 0,
          'isPinned': true,
          'messages': [
            {
              'id': 'msg_fav_1',
              'body': 'Hello there!',
              'timestamp': now,
              'isOutgoing': false,
            }
          ],
        },
        {
          'id': 'thread_otp',
          'contactName': '+2222222222',
          'phone': '+2222222222',
          'snippet': 'Your OTP verification code is 482910',
          'timestamp': now - 1000,
          'unreadCount': 0,
          'messages': [
            {
              'id': 'msg_otp_1',
              'body': 'Your OTP verification code is 482910',
              'timestamp': now - 1000,
              'isOutgoing': false,
            }
          ],
        },
        {
          'id': 'thread_contact',
          'contactName': 'Charlie Colleague',
          'phone': '+3333333333',
          'snippet': 'Important document attached',
          'timestamp': now - 2000,
          'unreadCount': 0,
          'messages': [
            {
              'id': 'msg_starred',
              'body': 'Important document attached',
              'timestamp': now - 2000,
              'isOutgoing': false,
              'isStarred': true,
            }
          ],
        },
      ]
    });

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Switch to SMS tab
    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();

    // Verify category chips exist
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Favourites'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Starred'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Contacts'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Unknown'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'OTP'), findsOneWidget);

    // Verify Date header 'Today' exists above grouped threads
    expect(find.text('Today'), findsWidgets);

    // In 'All' category, all three threads are visible in sidebar
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsOneWidget);
    expect(find.widgetWithText(InkWell, '+2222222222'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Charlie Colleague'), findsOneWidget);

    // Tap 'Favourites' chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Favourites'));
    await tester.tap(find.widgetWithText(FilterChip, 'Favourites'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Charlie Colleague'), findsNothing);

    // Tap 'OTP' chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'OTP'));
    await tester.tap(find.widgetWithText(FilterChip, 'OTP'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsNothing);
    expect(find.widgetWithText(InkWell, '+2222222222'), findsOneWidget);

    // Tap 'Starred' chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Starred'));
    await tester.tap(find.widgetWithText(FilterChip, 'Starred'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Charlie Colleague'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsNothing);

    // Tap 'Contacts' chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Contacts'));
    await tester.tap(find.widgetWithText(FilterChip, 'Contacts'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Charlie Colleague'), findsOneWidget);

    // Tap 'All' chip
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'All'));
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Favorite Friend'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Charlie Colleague'), findsOneWidget);

    // Select Favorite Friend conversation
    await tester.tap(find.widgetWithText(InkWell, 'Favorite Friend'));
    await tester.pumpAndSettle();

    // Test Delete message context action on message bubble in chat
    final msgBubbleFinder = find.descendant(
      of: find.byType(ListView).last,
      matching: find.text('Hello there!'),
    );
    expect(msgBubbleFinder, findsOneWidget);
    await tester.tap(msgBubbleFinder, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify message was deleted from mockSyncService
    final threadFav = mockSyncService.smsThreads.firstWhere((t) => t.id == 'thread_fav');
    expect(threadFav.messages.any((m) => m.id == 'msg_fav_1'), isFalse);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('Settings screen provides Autostart and Show in system tray toggles defaulting to ON', (WidgetTester tester) async {
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

    // Verify no settings_outlined icon on dashboard
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    // Open Settings via Bluetooth & Sync Settings button
    final settingsButtonFinder = find.text('Bluetooth & Sync Settings');
    expect(settingsButtonFinder, findsOneWidget);
    await tester.tap(settingsButtonFinder);
    await tester.pumpAndSettle();

    // Verify settings_outlined is also not present in Settings screen
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    // Verify System & Startup card exists
    expect(find.text('System & Startup'), findsOneWidget);
    expect(find.text('Autostart'), findsOneWidget);
    expect(find.text('Show in system tray'), findsOneWidget);

    // Verify About Ever Dialer PC section with v1.0.0 exists
    expect(find.text('About Ever Dialer PC'), findsOneWidget);
    expect(find.text('v1.0.0'), findsWidgets);

    // Verify both default to ON (true)
    final autostartTile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Autostart'));
    final trayTile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Show in system tray'));
    expect(autostartTile.value, isTrue);
    expect(trayTile.value, isTrue);

    // Scroll and toggle autostart to OFF
    final autostartFinder = find.widgetWithText(SwitchListTile, 'Autostart');
    await tester.ensureVisible(autostartFinder);
    await tester.pumpAndSettle();
    await tester.tap(autostartFinder);
    await tester.pumpAndSettle();
    final updatedAutostartTile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Autostart'));
    expect(updatedAutostartTile.value, isFalse);

    // Scroll and toggle system tray to OFF
    final trayFinder = find.widgetWithText(SwitchListTile, 'Show in system tray');
    await tester.ensureVisible(trayFinder);
    await tester.pumpAndSettle();
    await tester.tap(trayFinder);
    await tester.pumpAndSettle();
    final updatedTrayTile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Show in system tray'));
    expect(updatedTrayTile.value, isFalse);

    // Verify Card backgrounds have no outline borders
    for (final card in tester.widgetList<Card>(find.byType(Card))) {
      final shape = card.shape;
      if (shape is RoundedRectangleBorder) {
        expect(shape.side, BorderSide.none);
      }
    }

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('App displays custom window controls and phone telemetry status indicators in the top right corner', (WidgetTester tester) async {
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

    // Verify window controls exist (minimize, maximize, close)
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Verify Bluetooth status icon in top right header
    expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);

    // Simulate incoming telemetry from phone
    mockSyncService.updateFromPayload({
      'deviceName': 'Pixel 9 Pro',
      'telemetry': {
        'batteryLevel': 85,
        'isCharging': false,
        'wifiLevel': 3,
        'isWifiConnected': true,
        'cellularLevel': 4,
      },
    });
    await tester.pumpAndSettle();

    // Verify telemetry indicators
    expect(find.text('85%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_6_bar_rounded), findsOneWidget);
    expect(find.byIcon(Icons.network_wifi_3_bar_rounded), findsOneWidget);
    expect(find.byIcon(Icons.signal_cellular_4_bar_rounded), findsOneWidget);

    mockService.dispose();
    mockSyncService.dispose();
  });
}

