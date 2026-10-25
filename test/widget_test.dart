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
    expect(find.text('Pinned message'), findsOneWidget);

    // Open context menu again on message bubble and tap "Select text"
    await tester.tap(find.text('First message').last, buttons: kSecondaryButton);
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
        'isHotspotOn': true,
        'dataNetworkType': '5G',
      },
    });
    await tester.pumpAndSettle();

    // Verify telemetry indicators
    expect(find.text('85%'), findsOneWidget);
    expect(find.byIcon(Icons.battery_6_bar_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_rounded), findsWidgets);
    expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget); // Hotspot icon
    expect(find.byIcon(Icons.signal_cellular_4_bar_rounded), findsWidgets);
    expect(find.text('5G'), findsOneWidget); // Data network badge
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget); // Volume icon

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('SMS view displays dedicated Pinned container above date containers, supports dynamic categories, and unpins via top banner', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pc_sync_enabled', true);

    final mockService = BluetoothService(autoStartTimer: false, autoRefresh: false, prefs: prefs);
    final mockSyncService = PcSyncService(prefs: prefs);

    final now = DateTime.now().millisecondsSinceEpoch;
    mockSyncService.updateFromPayload({
      'pinnedSmsThreadIds': ['thread_pinned_1'],
      'pinnedSmsMessageIds': ['msg_pinned_content'],
      'smsCategories': [
        {'id': 'all', 'name': 'All', 'isCustom': false, 'isVisible': true},
        {'id': 'work', 'name': 'Work', 'isCustom': true, 'isVisible': true, 'contactPhones': ['+9999999999']},
      ],
      'smsThreads': [
        {
          'id': 'thread_pinned_1',
          'contactName': 'Boss',
          'phone': '+9999999999',
          'snippet': 'Urgent project task',
          'timestamp': now,
          'unreadCount': 0,
          'isPinned': true,
          'messages': [
            {
              'id': 'msg_pinned_content',
              'body': 'Urgent project task',
              'timestamp': now,
              'isOutgoing': false,
              'isPinned': true,
            }
          ],
        },
        {
          'id': 'thread_normal_2',
          'contactName': 'Friend',
          'phone': '+8888888888',
          'snippet': 'See you tomorrow',
          'timestamp': now - 5000,
          'unreadCount': 0,
          'isPinned': false,
          'messages': [
            {
              'id': 'msg_normal_content',
              'body': 'See you tomorrow',
              'timestamp': now - 5000,
              'isOutgoing': false,
            }
          ],
        },
      ],
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

    // Verify "Pinned" heading exists above "Boss"
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Boss'), findsWidgets);

    // Verify dynamic category "Work" chip exists
    expect(find.widgetWithText(FilterChip, 'Work'), findsOneWidget);

    // Verify top pinned message banner is displayed with unpin button
    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.byTooltip('Unpin message'), findsOneWidget);

    // Tap Unpin message button in top banner
    await tester.tap(find.byTooltip('Unpin message'));
    await tester.pumpAndSettle();
    expect(mockSyncService.isMessagePinned('msg_pinned_content'), false);
    expect(find.text('Pinned message'), findsNothing);

    // Select custom category "Work"
    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();
    expect(find.text('Boss'), findsWidgets);
    expect(find.text('Friend'), findsNothing);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('Call logs view displays dialpad button only in Call Logs screen, shows call count for repeated calls, and displays SIM notch badge', (WidgetTester tester) async {
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
      'callLogs': [
        {
          'id': 'log_1',
          'name': 'Mom',
          'number': '+1999888777',
          'type': 'incoming',
          'timestamp': now,
          'duration': 120,
          'simSlot': 0, // slot 0 -> 1-based SIM 1
          'count': 3,
        },
        {
          'id': 'log_2',
          'name': 'Doctor',
          'number': '+1222333444',
          'type': 'outgoing',
          'timestamp': now - 100000,
          'duration': 45,
          'simSlot': 1, // slot 1 -> 1-based SIM 2
          'count': 1,
        },
      ],
      'contacts': [
        {
          'id': 'c1',
          'name': 'Mom',
          'phone': '+1999888777',
          'isFavorite': true,
        }
      ],
      'sms': [],
      'notes': [],
    });

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Default tab is Favourites (index 0) - Dialpad FAB must NOT be visible
    expect(find.widgetWithText(FloatingActionButton, 'Dialpad'), findsNothing);

    // Switch to Calls tab (index 1) - Dialpad FAB MUST be visible
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FloatingActionButton, 'Dialpad'), findsOneWidget);

    // Verify call count "Mom (3)" is displayed
    expect(find.text('Mom (3)'), findsOneWidget);

    // Verify single call "Doctor" does not show count
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Doctor (1)'), findsNothing);

    // Verify SIM notch badges show "1" and "2" and no longer text "SIM 1"
    expect(find.text('SIM 1'), findsNothing);
    expect(find.text('SIM 2'), findsNothing);
    expect(find.byType(ClipPath), findsWidgets);

    // Switch to Contacts tab (index 2) - Dialpad FAB must NOT be visible
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FloatingActionButton, 'Dialpad'), findsNothing);

    // Switch to SMS tab (index 3) - Dialpad FAB must NOT be visible
    await tester.tap(find.text('SMS'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FloatingActionButton, 'Dialpad'), findsNothing);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('Confirm call dialog displays Material You SIM selector and allows SIM switching', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_sync_enabled': true,
      'speaker_mode_enabled': true,
      'confirm_placing_call': true,
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
      'confirmPlacingCall': true,
      'simCount': 2,
      'defaultSim': 1,
      'sim1Color': '#2E7D32',
      'sim2Color': '#C62828',
      'callLogs': [
        {
          'id': 'log_sim_test',
          'name': 'Test Contact',
          'number': '+15550001',
          'type': 'incoming',
          'timestamp': now,
          'duration': 45,
          'simSlot': 0,
        },
      ],
    });

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Switch to Calls tab
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();

    expect(find.text('Test Contact'), findsOneWidget);

    // Tap call log entry to trigger confirm call dialog
    await tester.tap(find.text('Test Contact'));
    await tester.pumpAndSettle();

    // Confirm dialog is displayed
    expect(find.text('Confirm placing call'), findsOneWidget);
    expect(find.text('Test Contact'), findsWidgets);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('+15550001')), findsOneWidget);

    // Both SIM 1 and SIM 2 selection chips are visible
    expect(find.text('SIM 1'), findsOneWidget);
    expect(find.text('SIM 2'), findsOneWidget);
    expect(find.text('Call (SIM 1)'), findsOneWidget);

    // Switch to SIM 2
    await tester.tap(find.text('SIM 2'));
    await tester.pumpAndSettle();

    expect(find.text('Call (SIM 2)'), findsOneWidget);

    // Tap Call
    await tester.tap(find.text('Call (SIM 2)'));
    await tester.pumpAndSettle();

    // Dialog is dismissed
    expect(find.text('Confirm placing call'), findsNothing);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('Call logs header does not display "-calls" pill badge and caps sync to 50 call logs', (WidgetTester tester) async {
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

    // Create 60 call logs
    final logsJson = List.generate(60, (index) => {
      'id': 'log_$index',
      'name': 'Contact $index',
      'number': '+1555${1000 + index}',
      'type': 'incoming',
      'timestamp': DateTime.now().millisecondsSinceEpoch - index * 60000,
      'duration': 10,
      'simSlot': 1,
      'count': 1,
    });

    mockSyncService.updateFromPayload({
      'callLogs': logsJson,
    });

    // Verify capped to 50
    expect(mockSyncService.callLogs.length, 50);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Switch to Calls tab
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();

    // Header says 'Call Logs' but does NOT display the '-calls' pill badge
    expect(find.text('Call Logs'), findsOneWidget);
    expect(find.textContaining('calls'), findsNothing);

    mockService.dispose();
    mockSyncService.dispose();
  });

  testWidgets('Contacts tab displays contact groups filter chips, filters contacts by group, and updates badge text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    mockSyncService.updateFromPayload({
      'contacts': [
        {'id': 'c_1', 'name': 'Alice Smith', 'phone': '+15550001'},
        {'id': 'c_2', 'name': 'Bob Jones', 'phone': '+15550002'},
        {'id': 'c_3', 'name': 'Charlie Brown', 'phone': '+15550003'},
      ],
      'contactGroups': [
        {
          'id': 'grp_friends',
          'name': 'Friends',
          'contactIds': ['c_1'],
        },
        {
          'id': 'grp_work',
          'name': 'Work',
          'contactIds': ['c_2'],
        },
      ],
    });

    expect(mockSyncService.contactGroups.length, 2);

    await tester.pumpWidget(EverDialerApp(
      bluetoothService: mockService,
      syncService: mockSyncService,
      prefs: prefs,
    ));
    await tester.pump();

    // Switch to Contacts tab
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    // Verify chips are present
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Ungrouped'), findsOneWidget);

    // Initial state: All contacts shown
    expect(find.text('3 contacts'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Charlie Brown'), findsOneWidget);

    // Select Friends group
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();

    expect(find.text('Friends · 1'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);
    expect(find.text('Charlie Brown'), findsNothing);

    // Select Ungrouped
    await tester.tap(find.text('Ungrouped'));
    await tester.pumpAndSettle();

    expect(find.text('Ungrouped · 1'), findsOneWidget);
    expect(find.text('Charlie Brown'), findsOneWidget);
    expect(find.text('Alice Smith'), findsNothing);
    expect(find.text('Bob Jones'), findsNothing);

    // Select All
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('3 contacts'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Charlie Brown'), findsOneWidget);

    mockService.dispose();
    mockSyncService.dispose();
  });
}


