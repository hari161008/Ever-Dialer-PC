import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/appearance_preferences.dart';
import '../services/sync_service.dart';
import 'smooth_contact_avatar.dart';

class MobileLandscapeLayout extends StatefulWidget {
  final PcSyncService syncService;
  final VoidCallback onOpenSettings;
  final AppearancePreferences? appearance;

  const MobileLandscapeLayout({
    super.key,
    required this.syncService,
    required this.onOpenSettings,
    this.appearance,
  });

  @override
  State<MobileLandscapeLayout> createState() => _MobileLandscapeLayoutState();
}

class _MobileLandscapeLayoutState extends State<MobileLandscapeLayout> {
  int _selectedIndex = 0; // 0: Favourites, 1: Calls, 2: Contacts, 3: SMS, 4: Notes
  int _previousIndex = 0;
  bool _isMobileView = false;

  void _changeTab(int newIndex) {
    if (newIndex == _selectedIndex) return;
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = newIndex;
    });
  }

  // Calls tab state
  String _callFilter = 'All'; // All, Missed, Incoming, Outgoing
  String _callSearchQuery = '';

  // Contacts tab state
  String _contactSearchQuery = '';
  SyncedContact? _selectedContactForDetails;
  String? _selectedContactGroupId; // null = All, '__ungrouped__' = Ungrouped, or group ID

  // SMS tab state
  String _selectedSmsCategory = 'all'; // all, favourites, starred, contacts, unknown, otp
  String? _selectedSmsThreadId;
  final TextEditingController _smsInputController = TextEditingController();
  bool _isNewMessageActive = false;
  String _newMessageSearchQuery = '';
  final TextEditingController _newMessageSearchController = TextEditingController();

  static final RegExp _otpRegex = RegExp(
    r'\b(otp|passcode|one[- ]time (?:password|passcode|code)|(?:verification|authentication|auth|security|secret|login|access|confirmation)[- ](?:code|pin|password)|your\s+(?:\w+\s+)?code\s+is|is\s+your\s+(?:\w+\s+)?(?:code|pin)|\d{4,8}\s+is\s+your|use\s+code\s+\d{4,8}|enter\s+(?:this\s+)?otp)\b|(?:\b(?:code|pin|otp)\s*[:=]\s*\d{4,8}\b)',
    caseSensitive: false,
  );

  // Notes tab state
  String _notesSearchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.appearance?.addListener(_onAppearanceChanged);
  }

  @override
  void didUpdateWidget(covariant MobileLandscapeLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance) {
      oldWidget.appearance?.removeListener(_onAppearanceChanged);
      widget.appearance?.addListener(_onAppearanceChanged);
    }
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.appearance?.removeListener(_onAppearanceChanged);
    _smsInputController.dispose();
    _newMessageSearchController.dispose();
    super.dispose();
  }

  void _initiateCall(String number, {String? displayName, String? photoBase64, int? simSlot}) {
    final cleanTarget = number.replaceAll(RegExp(r'\D'), '');
    SyncedContact? matchingContact;
    if (cleanTarget.isNotEmpty) {
      for (final c in widget.syncService.contacts) {
        final clean = c.phone.replaceAll(RegExp(r'\D'), '');
        if (clean == cleanTarget ||
            (clean.length >= 7 && cleanTarget.endsWith(clean)) ||
            (cleanTarget.length >= 7 && clean.endsWith(cleanTarget))) {
          matchingContact = c;
          break;
        }
      }
    }

    final resolvedName = displayName ?? (matchingContact?.name.isNotEmpty == true ? matchingContact!.name : number);
    final resolvedPhoto = photoBase64 ?? matchingContact?.photoBase64 ?? widget.syncService.getPhotoBase64ForNumber(number);

    if (widget.syncService.confirmPlacingCall) {
      _showConfirmCallDialog(
        number: number,
        displayName: resolvedName,
        photoBase64: resolvedPhoto,
        simSlot: simSlot,
      );
    } else {
      _executeCall(number, resolvedName, simSlot: simSlot);
    }
  }

  void _executeCall(String number, String displayName, {int? simSlot}) {
    widget.syncService.makeCall(number, simSlot: simSlot);
    final simText = simSlot != null && simSlot > 0 ? ' (SIM $simSlot)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Placing call to $displayName ($number)$simText...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfirmCallDialog({
    required String number,
    required String displayName,
    String? photoBase64,
    int? simSlot,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCustomName = displayName.trim().isNotEmpty && displayName.trim() != number.trim();

    final simCount = widget.syncService.simCount;
    final defaultSim = widget.syncService.defaultSim;
    int selectedSimSlot = simSlot ?? (defaultSim > 0 ? defaultSim : 1);
    if (simCount <= 1) {
      selectedSimSlot = 1;
    }

    final sim1Color = widget.syncService.sim1Color;
    final sim2Color = widget.syncService.sim2Color;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildSimBadge(int slot, Color color, {double width = 18, double height = 22, double fontSize = 11}) {
              return ClipPath(
                clipper: const _SimCardNotchClipper(),
                child: Container(
                  width: width,
                  height: height,
                  color: color,
                  alignment: Alignment.center,
                  child: Text(
                    '$slot',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              );
            }

            Widget buildSimChip({
              required int slot,
              required Color color,
              required bool isSelected,
              required VoidCallback onTap,
            }) {
              final chipBg = isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
              final borderColor = isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.6);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildSimBadge(slot, color, width: 20, height: 24, fontSize: 11),
                        const SizedBox(width: 8),
                        Text(
                          'SIM $slot',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.call,
                                size: 14,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Confirm placing call',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Contact Avatar
                        SmoothContactAvatar(
                          radius: 42,
                          photoBase64: photoBase64,
                          initials: hasCustomName
                              ? displayName.trim().substring(0, 1).toUpperCase()
                              : null,
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 16),

                        // Contact Name
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (hasCustomName) ...[
                          const SizedBox(height: 4),
                          Text(
                            number,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),

                        // SIM Selection row
                        if (simCount >= 2) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildSimChip(
                                slot: 1,
                                color: sim1Color,
                                isSelected: selectedSimSlot == 1,
                                onTap: () => setDialogState(() => selectedSimSlot = 1),
                              ),
                              const SizedBox(width: 12),
                              buildSimChip(
                                slot: 2,
                                color: sim2Color,
                                isSelected: selectedSimSlot == 2,
                                onTap: () => setDialogState(() => selectedSimSlot = 2),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Single SIM info pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildSimBadge(1, sim1Color, width: 17, height: 21, fontSize: 10),
                                const SizedBox(width: 8),
                                Text(
                                  'Calling via SIM 1',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    _executeCall(number, displayName, simSlot: selectedSimSlot);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          simCount >= 2 ? 'Call (SIM $selectedSimSlot)' : 'Call',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.syncService,
      builder: (context, _) {
        final sync = widget.syncService;
        final visibleIndices = <int>[];
        if (sync.syncFavouritesEnabled) visibleIndices.add(0);
        if (sync.syncCallLogsEnabled) visibleIndices.add(1);
        if (sync.syncContactsEnabled) visibleIndices.add(2);
        if (sync.syncSmsEnabled) visibleIndices.add(3);
        if (sync.syncNotesEnabled) visibleIndices.add(4);

        final activeIndex = visibleIndices.contains(_selectedIndex)
            ? _selectedIndex
            : (visibleIndices.isNotEmpty ? visibleIndices.first : -1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 640 || constraints.maxWidth < constraints.maxHeight;
            _isMobileView = isMobile;

            final direction = activeIndex >= _previousIndex ? 1 : -1;

            Widget pageWidget;
            switch (activeIndex) {
              case 0:
                pageWidget = _buildFavouritesView();
                break;
              case 1:
                pageWidget = _buildCallLogsView();
                break;
              case 2:
                pageWidget = _buildContactsView();
                break;
              case 3:
                pageWidget = _buildSmsView();
                break;
              case 4:
                pageWidget = _buildNotesView();
                break;
              default:
                pageWidget = Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_disabled, size: 48, color: colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'All sync categories are disabled',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enable categories in PC Connect settings on your phone.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
                break;
            }

            final blur = widget.appearance?.backgroundBlur ?? 0.0;
            Widget animatedPageContent = pageWidget;
            if (blur > 0.0) {
              animatedPageContent = Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  animatedPageContent,
                ],
              );
            }

            // Main Content Area with Slow, Smooth Section Switching Animation matching mobile TabTransitionStyle
            final contentArea = Expanded(
              child: Material(
                color: colorScheme.surface,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    switchInCurve: const Cubic(0.25, 1.0, 0.5, 1.0),
                    switchOutCurve: const Cubic(0.25, 1.0, 0.5, 1.0),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final isIncoming = child.key == ValueKey<int>(activeIndex);
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: const Cubic(0.25, 1.0, 0.5, 1.0),
                      );
                      final offsetTween = isIncoming
                          ? Tween<Offset>(
                              begin: Offset(direction * 0.25, 0.0),
                              end: Offset.zero,
                            )
                          : Tween<Offset>(
                              begin: Offset(-direction * 0.25, 0.0),
                              end: Offset.zero,
                            );
                      return SlideTransition(
                        position: offsetTween.animate(curved),
                        child: FadeTransition(
                          opacity: curved,
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(activeIndex),
                      child: animatedPageContent,
                    ),
                  ),
                ),
              ),
            );

            if (isMobile) {
              // Mobile View: Full-width content area with adaptive bottom navigation bar
              return Column(
                children: [
                  contentArea,
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      indicatorColor: colorScheme.primaryContainer,
                      selectedIndex: visibleIndices.indexOf(activeIndex).clamp(0, visibleIndices.isNotEmpty ? visibleIndices.length - 1 : 0),
                      onDestinationSelected: (vIdx) {
                        if (vIdx >= 0 && vIdx < visibleIndices.length) {
                          _changeTab(visibleIndices[vIdx]);
                        }
                      },
                      destinations: [
                        if (sync.syncFavouritesEnabled)
                          NavigationDestination(
                            icon: const Icon(Icons.favorite_border),
                            selectedIcon: Icon(Icons.favorite, color: colorScheme.onPrimaryContainer),
                            label: 'Favourites',
                          ),
                        if (sync.syncCallLogsEnabled)
                          NavigationDestination(
                            icon: const Icon(Icons.history_outlined),
                            selectedIcon: Icon(Icons.history, color: colorScheme.onPrimaryContainer),
                            label: 'Calls',
                          ),
                        if (sync.syncContactsEnabled)
                          NavigationDestination(
                            icon: const Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                            label: 'Contacts',
                          ),
                        if (sync.syncSmsEnabled)
                          NavigationDestination(
                            icon: const Icon(Icons.chat_bubble_outline),
                            selectedIcon: Icon(Icons.chat, color: colorScheme.onPrimaryContainer),
                            label: 'SMS',
                          ),
                        if (sync.syncNotesEnabled)
                          NavigationDestination(
                            icon: const Icon(Icons.note_alt_outlined),
                            selectedIcon: Icon(Icons.note_alt, color: colorScheme.onPrimaryContainer),
                            label: 'Notes',
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Desktop / Landscape View: Navigation Rail on left, full content area on right
            return Row(
              children: [
                Container(
                  width: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (sync.syncFavouritesEnabled) ...[
                                _buildRailItem(
                                  index: 0,
                                  icon: Icons.favorite,
                                  unselectedIcon: Icons.favorite_border,
                                  label: 'Favourites',
                                  isSelected: activeIndex == 0,
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (sync.syncCallLogsEnabled) ...[
                                _buildRailItem(
                                  index: 1,
                                  icon: Icons.history,
                                  unselectedIcon: Icons.history_outlined,
                                  label: 'Calls',
                                  isSelected: activeIndex == 1,
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (sync.syncContactsEnabled) ...[
                                _buildRailItem(
                                  index: 2,
                                  icon: Icons.person,
                                  unselectedIcon: Icons.person_outline,
                                  label: 'Contacts',
                                  isSelected: activeIndex == 2,
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (sync.syncSmsEnabled) ...[
                                _buildRailItem(
                                  index: 3,
                                  icon: Icons.chat,
                                  unselectedIcon: Icons.chat_bubble_outline,
                                  label: 'SMS',
                                  isSelected: activeIndex == 3,
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (sync.syncNotesEnabled) ...[
                                _buildRailItem(
                                  index: 4,
                                  icon: Icons.note_alt,
                                  unselectedIcon: Icons.note_alt_outlined,
                                  label: 'Notes',
                                  isSelected: activeIndex == 4,
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Settings button at bottom of rail
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: IconButton(
                          icon: const Icon(Icons.tune),
                          tooltip: 'Settings',
                          iconSize: 24,
                          color: colorScheme.onSurfaceVariant,
                          onPressed: widget.onOpenSettings,
                        ),
                      ),
                    ],
                  ),
                ),
                contentArea,
              ],
            );
          },
        );
      },
    );
  }

  void _openSmsForNumber(String num) {
    if (!widget.syncService.syncSmsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS sync is disabled in PC Connect settings on your phone.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final clean = num.replaceAll(RegExp(r'[^\d+]'), '');
    final existingIndex = widget.syncService.smsThreads.indexWhere(
      (t) => t.phone.replaceAll(RegExp(r'[^\d+]'), '') == clean,
    );

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = 3; // Switch to SMS tab
      if (existingIndex != -1) {
        _selectedSmsThreadId = widget.syncService.smsThreads[existingIndex].id;
      }
    });
  }

  void _showAddContactDialog(BuildContext context, {String initialPhone = ''}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: initialPhone);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_add_rounded, color: colorScheme.onPrimaryContainer, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Add Contact',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Contact Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isNotEmpty || phone.isNotEmpty) {
                              widget.syncService.addContact(name, phone);
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Contact added: ${name.isNotEmpty ? name : phone}'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Save'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDialDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dialpad',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: _MobileDialpadSheet(
            syncService: widget.syncService,
            onCall: (number) {
              Navigator.pop(dialogContext);
              _initiateCall(number);
            },
            onAddContact: (phone) {
              _showAddContactDialog(context, initialPhone: phone);
            },
            onOpenSms: (phone) {
              Navigator.pop(dialogContext);
              _openSmsForNumber(phone);
            },
            onDismiss: () => Navigator.pop(dialogContext),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
          reverseCurve: Curves.fastOutSlowIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }

  void _showNewMessageDialog(BuildContext context, {String? initialNumber}) {
    setState(() {
      _isNewMessageActive = true;
      _previousIndex = _selectedIndex;
      _selectedIndex = 3;
      _newMessageSearchQuery = initialNumber ?? '';
      _newMessageSearchController.text = initialNumber ?? '';
    });
  }

  void _openChatForNumber(String number, String? contactName) {
    final thread = widget.syncService.getOrCreateThreadForNumber(
      number,
      contactName: contactName,
    );
    setState(() {
      _selectedSmsThreadId = thread.id;
      _isNewMessageActive = false;
    });
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
    bool? isSelected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = isSelected ?? (_selectedIndex == index);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _changeTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  selected ? icon : unselectedIcon,
                  size: 22,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 1. Favourites View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildFavouritesView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final favourites = widget.syncService.favourites;
    final isListView = widget.syncService.favoritesInList;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobileView ? 14.0 : 20.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Favourites',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${favourites.length} contacts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      isListView
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isListView
                        ? 'Switch to grid view'
                        : 'Switch to list view',
                    onPressed: () {
                      widget.syncService.setFavoritesInList(!isListView);
                    },
                  ),
                  if (_isMobileView) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Settings',
                      color: colorScheme.onSurfaceVariant,
                      onPressed: widget.onOpenSettings,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (favourites.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_outline_rounded,
                      size: 48,
                      color: colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Star a contact to add them here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isListView)
            Expanded(
              child: ListView.separated(
                itemCount: favourites.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final contact = favourites[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapDown: (details) => _showFavouriteContextMenu(context, details.globalPosition, contact),
                    onLongPressStart: (details) => _showFavouriteContextMenu(context, details.globalPosition, contact),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _initiateCall(
                            contact.phone,
                            displayName: contact.name,
                            photoBase64: contact.photoBase64,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                          child: Row(
                            children: [
                              SmoothContactAvatar(
                                radius: 24,
                                photoBase64: contact.photoBase64,
                                initials: contact.initials,
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (contact.phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        contact.phone,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.call, size: 18),
                                  color: colorScheme.onPrimaryContainer,
                                  tooltip: 'Call ${contact.name}',
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _initiateCall(
                                      contact.phone,
                                      displayName: contact.name,
                                      photoBase64: contact.photoBase64,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 155,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  final contact = favourites[index];
                  final imageProvider = SmoothContactAvatar.getImageProvider(contact.photoBase64);
                  final hasPhoto = imageProvider != null;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapDown: (details) => _showFavouriteContextMenu(context, details.globalPosition, contact),
                    onLongPressStart: (details) => _showFavouriteContextMenu(context, details.globalPosition, contact),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          _initiateCall(
                            contact.phone,
                            displayName: contact.name,
                            photoBase64: contact.photoBase64,
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Banner / Avatar Container
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (hasPhoto)
                                    Image(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, _, _) => _buildFallbackBanner(contact, colorScheme),
                                    )
                                  else
                                    _buildFallbackBanner(contact, colorScheme),

                                  // Subtle bottom scrim on photo for contrast
                                  if (hasPhoto)
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.28),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Quick Call Action Badge
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Material(
                                      color: colorScheme.primary,
                                      shape: const CircleBorder(),
                                      elevation: 3,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          _initiateCall(
                                            contact.phone,
                                            displayName: contact.name,
                                            photoBase64: contact.photoBase64,
                                          );
                                        },
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Icon(
                                            Icons.call,
                                            size: 15,
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom Details Container
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    contact.name,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (contact.phone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      contact.phone,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10.5,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(SyncedContact contact, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.5),
            colorScheme.surfaceContainerHigh,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: SmoothContactAvatar(
        radius: 30,
        initials: contact.initials,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 2. Call Logs View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCallLogsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allLogs = widget.syncService.callLogs;

    final favoritePhoneNumbers = widget.syncService.contacts
        .where((c) => c.isFavorite)
        .expand((c) => [c.phone, ...c.phones.map((p) => p.number)])
        .map((n) => n.replaceAll(RegExp(r'[^\d+]'), ''))
        .where((n) => n.isNotEmpty)
        .toSet();

    final Map<String, SyncedContact> contactByCleanNumber = {};
    for (final contact in widget.syncService.contacts) {
      final cleanPrimary = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPrimary.isNotEmpty) {
        contactByCleanNumber[cleanPrimary] = contact;
      }
      for (final p in contact.phones) {
        final clean = p.number.replaceAll(RegExp(r'[^\d+]'), '');
        if (clean.isNotEmpty) {
          contactByCleanNumber[clean] = contact;
        }
      }
    }

    final syncedCallCategories = widget.syncService.callCategories.where((c) => c.isVisible).toList();

    final filteredLogs = allLogs.where((log) {
      final cleanNum = log.number.replaceAll(RegExp(r'[^\d+]'), '');
      final matchedContact = contactByCleanNumber[cleanNum];
      final isKnown = (log.name.isNotEmpty &&
              log.name.toLowerCase() != log.number.toLowerCase() &&
              log.name.toLowerCase() != 'unknown') ||
          matchedContact != null;
      final isFav = (matchedContact?.isFavorite == true) ||
          favoritePhoneNumbers.contains(cleanNum);

      final customCat = syncedCallCategories.firstWhere(
        (c) => c.isCustom && (c.id == _callFilter || c.name == _callFilter),
        orElse: () => const SyncedCallCategory(id: '', name: ''),
      );
      if (customCat.id.isNotEmpty) {
        final matchesCustom = customCat.contactPhones.any((p) {
          final cleanP = p.replaceAll(RegExp(r'[^\d+]'), '');
          return cleanP.isNotEmpty && (cleanP == cleanNum || cleanNum.endsWith(cleanP) || cleanP.endsWith(cleanNum));
        });
        if (!matchesCustom) return false;
      } else {
        if ((_callFilter == 'Known' || _callFilter == 'Contacts') && !isKnown) return false;
        if (_callFilter == 'Favourites' && !isFav) return false;
        if (_callFilter == 'Unknown' && isKnown) return false;
        if (_callFilter == 'Missed' && log.type != CallType.missed) return false;
        if (_callFilter == 'Incoming' && log.type != CallType.incoming) return false;
        if (_callFilter == 'Outgoing' && log.type != CallType.outgoing) return false;
      }
      if (_callSearchQuery.isNotEmpty) {
        final q = _callSearchQuery.toLowerCase();
        return log.name.toLowerCase().contains(q) ||
            log.number.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final groupedLogs = _groupLogsByDate(filteredLogs);

    final filterChips = (syncedCallCategories.isNotEmpty
        ? syncedCallCategories.map((c) => c.name).toList()
        : [
            'All',
            'Known',
            'Favourites',
            'Unknown',
            'Missed',
            'Incoming',
            'Outgoing',
          ]).map((f) {
      final isSelected = _callFilter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: FilterChip(
          showCheckmark: false,
          label: Text(f),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _callFilter = f;
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }).toList();

    final searchField = TextField(
      decoration: InputDecoration(
        hintText: 'Search call logs...',
        prefixIcon: Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
        suffixIcon: _callSearchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  setState(() {
                    _callSearchQuery = '';
                  });
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        setState(() {
          _callSearchQuery = val;
        });
      },
    );

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobileView ? 14.0 : 20.0,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Call Logs',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isMobileView)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: widget.onOpenSettings,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Search and Filters
              if (_isMobileView) ...[
                searchField,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filterChips,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: searchField,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filterChips,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_missed_outlined, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No call logs match filter.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: groupedLogs.length,
                    itemBuilder: (context, groupIndex) {
                      final dateHeader = groupedLogs.keys.elementAt(groupIndex);
                      final logsInGroup = groupedLogs[dateHeader]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                            child: Text(
                              dateHeader,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Material(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (int i = 0; i < logsInGroup.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      indent: 72,
                                      endIndent: 16,
                                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                    ),
                                  _buildCallLogTile(logsInGroup[i]),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    Positioned(
      right: _isMobileView ? 16 : 24,
      bottom: _isMobileView ? 16 : 24,
      child: _isMobileView
          ? FloatingActionButton(
              onPressed: () => _showDialDialog(context),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.dialpad),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showDialDialog(context),
              icon: const Icon(Icons.dialpad),
              label: const Text('Dialpad'),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
    ),
  ],
);
  }

  Widget _buildCallLogTile(SyncedCallLog log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMissed = log.type == CallType.missed;
    final hasContactName = log.name.isNotEmpty && log.name != log.number;
    final baseTitle = hasContactName
        ? log.name
        : (log.number.isNotEmpty ? log.number : 'Unknown');
    final displayTitle = log.count > 1 ? '$baseTitle (${log.count})' : baseTitle;

    IconData typeIcon;
    Color iconColor;
    Color containerColor;

    switch (log.type) {
      case CallType.missed:
        typeIcon = Icons.call_missed;
        iconColor = colorScheme.error;
        containerColor = colorScheme.errorContainer;
        break;
      case CallType.incoming:
        typeIcon = Icons.call_received;
        iconColor = colorScheme.onPrimaryContainer;
        containerColor = colorScheme.primaryContainer;
        break;
      case CallType.outgoing:
        typeIcon = Icons.call_made;
        iconColor = colorScheme.onPrimaryContainer;
        containerColor = colorScheme.primaryContainer;
        break;
    }

    final durationFormatted = _formatCallDuration(log.duration);
    final timeStr = _formatTime(log.timestamp);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _showCallLogContextMenu(context, details.globalPosition, log),
      onLongPressStart: (details) => _showCallLogContextMenu(context, details.globalPosition, log),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Builder(
          builder: (context) {
            final pfpBase64 = widget.syncService.getPhotoBase64ForNumber(log.number);
            return SmoothContactAvatar(
              radius: 22,
              photoBase64: pfpBase64,
              initials: hasContactName && log.name.trim().isNotEmpty
                  ? log.name.trim()[0].toUpperCase()
                  : null,
              fallbackChild: !hasContactName || log.name.trim().isEmpty
                  ? Icon(
                      Icons.person,
                      size: 22,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : null,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              foregroundColor: colorScheme.onSurface,
            );
          },
        ),
        title: Text(
          displayTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isMissed ? colorScheme.error : colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Row(
            children: [
              if (hasContactName && log.number.isNotEmpty) ...[
                Flexible(
                  child: Text(
                    log.number,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (log.simSlot > 0) ...[
                ClipPath(
                  clipper: const _SimCardNotchClipper(),
                  child: Container(
                    width: 17,
                    height: 20,
                    color: log.simSlot == 1
                        ? widget.syncService.sim1Color
                        : widget.syncService.sim2Color,
                    alignment: Alignment.center,
                    child: Text(
                      '${log.simSlot}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isMissed ? colorScheme.error : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!isMissed && durationFormatted.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    durationFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (isMissed) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Missed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: containerColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(typeIcon, size: 18, color: iconColor),
                tooltip: 'Call $displayTitle',
                onPressed: () {
                  _initiateCall(log.number, displayName: displayTitle, simSlot: log.simSlot > 0 ? log.simSlot : null);
                },
              ),
            ),
          ],
        ),
        onTap: () {
          _initiateCall(log.number, displayName: displayTitle, simSlot: log.simSlot > 0 ? log.simSlot : null);
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 3. Contacts View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildContactsView() {
    if (_selectedContactForDetails != null) {
      final currentContact = widget.syncService.contacts.firstWhere(
        (c) => c.id == _selectedContactForDetails!.id,
        orElse: () => _selectedContactForDetails!,
      );
      return _buildContactInfoView(currentContact);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final contactGroups = widget.syncService.contactGroups;
    final allContacts = widget.syncService.contacts;

    // Filter contacts by group
    final groupFilteredContacts = allContacts.where((c) {
      if (_selectedContactGroupId == null) return true;
      if (_selectedContactGroupId == '__ungrouped__') {
        final allGroupedIds = contactGroups.expand((g) => g.contactIds).toSet();
        return !allGroupedIds.contains(c.id);
      }
      final grp = contactGroups.cast<SyncedContactGroup?>().firstWhere(
        (g) => g?.id == _selectedContactGroupId,
        orElse: () => null,
      );
      if (grp == null) return true;
      return grp.contactIds.contains(c.id);
    }).toList();

    final filtered = groupFilteredContacts.where((c) {
      if (_contactSearchQuery.isEmpty) return true;
      final q = _contactSearchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();

    final groupedContacts = _groupContactsByLetter(filtered);

    final String contactsCountText;
    if (_selectedContactGroupId != null) {
      if (_selectedContactGroupId == '__ungrouped__') {
        contactsCountText = 'Ungrouped · ${filtered.length}';
      } else {
        final grp = contactGroups.cast<SyncedContactGroup?>().firstWhere(
          (g) => g?.id == _selectedContactGroupId,
          orElse: () => null,
        );
        contactsCountText = '${grp?.name ?? "Group"} · ${filtered.length}';
      }
    } else {
      contactsCountText = '${allContacts.length} contacts';
    }

    final searchTextField = TextField(
      decoration: InputDecoration(
        hintText: 'Search contacts...',
        prefixIcon: Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
        suffixIcon: _contactSearchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: colorScheme.onSurfaceVariant),
                onPressed: () {
                  setState(() {
                    _contactSearchQuery = '';
                  });
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (val) {
        setState(() {
          _contactSearchQuery = val;
        });
      },
    );

    final groupChips = [
      // "All" chip
      Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: FilterChip(
          showCheckmark: false,
          avatar: const Icon(Icons.people_outline_rounded, size: 16),
          label: const Text('All'),
          selected: _selectedContactGroupId == null,
          onSelected: (_) {
            setState(() {
              _selectedContactGroupId = null;
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      // Groups chips
      ...contactGroups.map((grp) {
        final isSelected = _selectedContactGroupId == grp.id;
        return Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: FilterChip(
            showCheckmark: false,
            avatar: const Icon(Icons.group_outlined, size: 16),
            label: Text(grp.name),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedContactGroupId = isSelected ? null : grp.id;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
      // "Ungrouped" chip
      Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: FilterChip(
          showCheckmark: false,
          avatar: const Icon(Icons.person_outline_rounded, size: 16),
          label: const Text('Ungrouped'),
          selected: _selectedContactGroupId == '__ungrouped__',
          onSelected: (_) {
            setState(() {
              _selectedContactGroupId =
                  _selectedContactGroupId == '__ungrouped__' ? null : '__ungrouped__';
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobileView ? 14.0 : 20.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Contacts',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        contactsCountText,
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
              if (_isMobileView)
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: widget.onOpenSettings,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Search and Groups Filter
          if (_isMobileView) ...[
            searchTextField,
            if (contactGroups.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: groupChips,
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                if (contactGroups.isNotEmpty)
                  SizedBox(
                    width: 250,
                    child: searchTextField,
                  )
                else
                  Expanded(
                    child: searchTextField,
                  ),
                if (contactGroups.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: groupChips,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      _contactSearchQuery.isNotEmpty
                          ? 'No contacts match "$_contactSearchQuery"'
                          : (_selectedContactGroupId != null
                              ? 'No contacts in this group'
                              : 'No contacts synced yet.'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Turn on Contacts in Ever Dialer mobile under PC Connect.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: groupedContacts.length,
                itemBuilder: (context, groupIndex) {
                  final letter = groupedContacts.keys.elementAt(groupIndex);
                  final contactsInGroup = groupedContacts[letter]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                        child: Text(
                          letter,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Material(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (int i = 0; i < contactsInGroup.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: 72,
                                  endIndent: 16,
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                              _buildContactTile(contactsInGroup[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactTile(SyncedContact contact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _showContactContextMenu(context, details.globalPosition, contact),
      onLongPressStart: (details) => _showContactContextMenu(context, details.globalPosition, contact),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        onTap: () {
          setState(() {
            _selectedContactForDetails = contact;
          });
        },
        leading: Builder(
          builder: (context) {
            return SmoothContactAvatar(
              radius: 22,
              photoBase64: contact.photoBase64,
              initials: contact.initials,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            );
          },
        ),
        title: Text(
          contact.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            contact.phone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite ? Colors.amber : colorScheme.outline,
                size: 20,
              ),
              tooltip: contact.isFavorite ? 'Unmark favorite' : 'Mark favorite',
              onPressed: () {
                widget.syncService.toggleFavorite(contact.id);
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              tooltip: 'SMS',
              onPressed: () {
                _openSmsForNumber(contact.phone);
              },
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.call, size: 18, color: colorScheme.primary),
                tooltip: 'Call ${contact.name}',
                onPressed: () {
                  _initiateCall(contact.phone, displayName: contact.name, photoBase64: contact.photoBase64);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _numbersMatch(String n1, String n2) {
    final c1 = n1.replaceAll(RegExp(r'\D'), '');
    final c2 = n2.replaceAll(RegExp(r'\D'), '');
    if (c1.isEmpty || c2.isEmpty) return false;
    if (c1 == c2) return true;
    if (c1.length >= 7 && c2.length >= 7) {
      return c1.endsWith(c2) || c2.endsWith(c1);
    }
    return false;
  }

  Widget _buildContactInfoView(SyncedContact contact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Matching call logs for Recent Activity
    final contactPhones = contact.phones.isNotEmpty
        ? contact.phones.map((p) => p.number).toSet()
        : {contact.phone};
    final matchingLogs = widget.syncService.callLogs.where((log) {
      return contactPhones.any((p) => _numbersMatch(log.number, p));
    }).toList();

    // Matching notes
    final matchingNotes = widget.syncService.notes.where((n) {
      final titleMatch = n.title.toLowerCase().contains(contact.name.toLowerCase());
      final phoneMatch = contactPhones.any((p) => n.content.contains(p) || n.title.contains(p));
      return titleMatch || phoneMatch;
    }).toList();

    // Matching groups
    final memberGroups = widget.syncService.contactGroups
        .where((g) => g.contactIds.contains(contact.id))
        .toList();

    return Column(
      children: [
        // Top App Bar / Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                tooltip: 'Back to contacts',
                onPressed: () {
                  setState(() {
                    _selectedContactForDetails = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Contact Info',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  contact.isFavorite ? Icons.star : Icons.star_border,
                  color: contact.isFavorite ? Colors.amber : colorScheme.onSurfaceVariant,
                ),
                tooltip: contact.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () {
                  widget.syncService.toggleFavorite(contact.id);
                  setState(() {});
                },
              ),
              IconButton(
                icon: Icon(Icons.share_outlined, color: colorScheme.onSurfaceVariant),
                tooltip: 'Copy details',
                onPressed: () {
                  final details = '${contact.name}\n${contact.phone}';
                  Clipboard.setData(ClipboardData(text: details));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact details copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: _isMobileView ? 16.0 : 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Large glowing avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: _isMobileView ? 140 : 200,
                      height: _isMobileView ? 140 : 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    SmoothContactAvatar(
                      radius: _isMobileView ? 55 : 80,
                      photoBase64: contact.photoBase64,
                      initials: contact.initials,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  contact.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Account / Storage badges
                if (contact.sourceAccounts.isNotEmpty) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: contact.sourceAccounts.map((acc) {
                      final isGoogle = acc.toLowerCase().contains('google') || acc.contains('@');
                      final isSim = acc.toLowerCase().contains('sim');
                      final icon = isGoogle
                          ? Icons.account_circle_outlined
                          : (isSim ? Icons.sim_card_outlined : Icons.phone_android_outlined);
                      return Chip(
                        avatar: Icon(icon, size: 16, color: colorScheme.primary),
                        label: Text(
                          acc,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                        ),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Quick Actions: Call & Text Pill Buttons
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _initiateCall(contact.phone, displayName: contact.name, photoBase64: contact.photoBase64);
                          },
                          icon: const Icon(Icons.call, size: 20),
                          label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openSmsForNumber(contact.phone);
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          label: const Text('Text', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.secondaryContainer,
                            foregroundColor: colorScheme.onSecondaryContainer,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Contact Info Card (Phone numbers, emails, addresses)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      _buildInfoSectionCard(
                        title: 'Contact Info',
                        icon: Icons.info_outline,
                        child: Column(
                          children: [
                            // Phones
                            if (contact.phones.isNotEmpty)
                              for (int i = 0; i < contact.phones.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    indent: 56,
                                    endIndent: 16,
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                  ),
                                _buildPhoneInfoItem(
                                  phone: contact.phones[i].number,
                                  label: contact.phones[i].label,
                                  isPrimary: i == 0,
                                ),
                              ]
                            else
                              _buildPhoneInfoItem(
                                phone: contact.phone,
                                label: 'Mobile',
                                isPrimary: true,
                              ),

                            // Emails
                            if (contact.emails.isNotEmpty)
                              for (final email in contact.emails) ...[
                                Divider(
                                  height: 1,
                                  indent: 56,
                                  endIndent: 16,
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.email_outlined, size: 18, color: colorScheme.primary),
                                  ),
                                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                  subtitle: const Text('Email', style: TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.content_copy, size: 18),
                                    tooltip: 'Copy email',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: email));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Email copied to clipboard'), duration: Duration(seconds: 2)),
                                      );
                                    },
                                  ),
                                ),
                              ],

                            // Addresses
                            if (contact.addresses.isNotEmpty)
                              for (final addr in contact.addresses) ...[
                                Divider(
                                  height: 1,
                                  indent: 56,
                                  endIndent: 16,
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                ),
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.location_on_outlined, size: 18, color: colorScheme.primary),
                                  ),
                                  title: Text(addr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                  subtitle: const Text('Address', style: TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.content_copy, size: 18),
                                    tooltip: 'Copy address',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: addr));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Groups Card
                      if (memberGroups.isNotEmpty) ...[
                        _buildInfoSectionCard(
                          title: 'Groups',
                          icon: Icons.group_outlined,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: memberGroups.map((g) {
                                return Chip(
                                  avatar: Icon(Icons.people_alt_outlined, size: 16, color: colorScheme.primary),
                                  label: Text(g.name, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                                  backgroundColor: colorScheme.surfaceContainerHigh,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. Description (Synced Notes) Card
                      _buildInfoSectionCard(
                        title: 'Description (Synced Notes)',
                        icon: Icons.description_outlined,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: (contact.note != null && contact.note!.trim().isNotEmpty)
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        contact.note!.trim(),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      color: colorScheme.onSurfaceVariant,
                                      tooltip: 'Copy description',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: contact.note!.trim()));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Description copied to clipboard'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : Text(
                                  'No synced description for this contact.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Notes (Phone Only) Card
                      _buildInfoSectionCard(
                        title: matchingNotes.isNotEmpty
                            ? 'Notes (${matchingNotes.length})'
                            : 'Notes',
                        icon: Icons.note_alt_outlined,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (matchingNotes.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Text(
                                    'No notes yet for this contact.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                )
                              else
                                for (int i = 0; i < matchingNotes.length; i++) ...[
                                  if (i > 0) const Divider(height: 20),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              matchingNotes[i].title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              matchingNotes[i].content,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: colorScheme.onSurface,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatCallDateHeader(matchingNotes[i].timestamp),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        color: colorScheme.onSurfaceVariant,
                                        tooltip: 'Edit note',
                                        onPressed: () => _showEditNoteDialog(matchingNotes[i]),
                                      ),
                                    ],
                                  ),
                                ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add note'),
                                  onPressed: () => _showAddNoteDialog(initialTitle: contact.name),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Recent Activity Card (Call history)
                      _buildInfoSectionCard(
                        title: matchingLogs.isNotEmpty
                            ? 'Recent Activity (${matchingLogs.length})'
                            : 'Recent Activity',
                        icon: Icons.history,
                        child: matchingLogs.isNotEmpty
                            ? Column(
                                children: [
                                  for (int i = 0; i < matchingLogs.take(8).length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        indent: 56,
                                        endIndent: 16,
                                        color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                                      ),
                                    _buildRecentActivityLogItem(matchingLogs[i]),
                                  ],
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.history_toggle_off, color: colorScheme.outline, size: 24),
                                    const SizedBox(width: 14),
                                    Text(
                                      'No recent call activity with this contact',
                                      style: TextStyle(color: colorScheme.outline, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // 6. Saved In Card
                      _buildInfoSectionCard(
                        title: 'Saved In',
                        icon: Icons.storage_outlined,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  contact.sourceAccounts.any((a) => a.toLowerCase().contains('google') || a.contains('@'))
                                      ? Icons.account_circle_outlined
                                      : (contact.sourceAccounts.any((a) => a.toLowerCase().contains('sim'))
                                          ? Icons.sim_card_outlined
                                          : Icons.phone_android_outlined),
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.sourceAccounts.isNotEmpty
                                        ? contact.sourceAccounts.join(', ')
                                        : (contact.account?.isNotEmpty == true ? contact.account! : 'Phone Storage'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Contact storage account',
                                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildPhoneInfoItem({
    required String phone,
    required String label,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.phone_outlined, size: 18, color: colorScheme.primary),
      ),
      title: Text(
        phone,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        isPrimary ? '$label • Primary' : label,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            tooltip: 'Copy number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $phone to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            tooltip: 'Send SMS',
            onPressed: () {
              _openSmsForNumber(phone);
            },
          ),
          const SizedBox(width: 4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.call, size: 18, color: colorScheme.onPrimaryContainer),
              tooltip: 'Call $phone',
              onPressed: () {
                _initiateCall(phone, displayName: _selectedContactForDetails?.name, photoBase64: _selectedContactForDetails?.photoBase64);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityLogItem(SyncedCallLog log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMissed = log.type == CallType.missed;
    final isIncoming = log.type == CallType.incoming;

    final IconData icon = isMissed
        ? Icons.call_missed
        : (isIncoming ? Icons.call_received : Icons.call_made);
    final Color iconColor = isMissed
        ? colorScheme.error
        : (isIncoming ? const Color(0xFF4CAF50) : const Color(0xFF2196F3));

    final String typeStr = isMissed
        ? 'Missed call'
        : (isIncoming ? 'Incoming call' : 'Outgoing call');

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      title: Text(
        typeStr,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isMissed ? colorScheme.error : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${_formatCallDateHeader(log.timestamp)} • ${_formatTime(log.timestamp)}${log.duration.inSeconds > 0 ? " • ${_formatCallDuration(log.duration)}" : ""}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, size: 18),
        tooltip: 'Call back',
        onPressed: () {
          _initiateCall(
            log.number,
            displayName: _selectedContactForDetails?.name ?? (log.name.isNotEmpty ? log.name : log.number),
            photoBase64: _selectedContactForDetails?.photoBase64,
            simSlot: log.simSlot > 0 ? log.simSlot : null,
          );
        },
      ),
    );
  }

  Widget _buildNewMessageView({bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final q = _newMessageSearchQuery.trim().toLowerCase();
    final trimmedNumber = _newMessageSearchQuery.trim();
    final hasDigits = RegExp(r'\d').hasMatch(trimmedNumber);

    final filteredContacts = widget.syncService.contacts.where((c) {
      if (q.isEmpty) return true;
      final matchName = c.name.toLowerCase().contains(q);
      final matchPhone = c.phone.replaceAll(RegExp(r'\D'), '').contains(q);
      return matchName || matchPhone;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top App Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                tooltip: 'Back',
                onPressed: () {
                  setState(() {
                    _isNewMessageActive = false;
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'New Message',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Search Input Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _newMessageSearchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type a name or phone number',
              hintStyle: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              suffixIcon: _newMessageSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _newMessageSearchController.clear();
                        setState(() => _newMessageSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (val) {
              setState(() => _newMessageSearchQuery = val);
            },
          ),
        ),

        // Direct send option if digits are entered
        if (hasDigits) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Material(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openChatForNumber(trimmedNumber, null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send to $trimmedNumber',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Start new SMS conversation',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Contacts List
        Expanded(
          child: filteredContacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      q.isNotEmpty
                          ? "No contacts match '$q'"
                          : "No contacts available",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = filteredContacts[index];
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openChatForNumber(contact.phone, contact.name),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              SmoothContactAvatar(
                                radius: 20,
                                photoBase64: contact.photoBase64,
                                initials: contact.initials,
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (contact.phone.isNotEmpty)
                                      Text(
                                        contact.phone,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 4. SMS View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildSmsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final threads = widget.syncService.smsThreads;

    if (threads.isEmpty) {
      if (_isNewMessageActive) {
        return _buildNewMessageView(isCompact: true);
      }
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Messages',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_comment_rounded, color: colorScheme.onSurface),
                  tooltip: 'New Message',
                  onPressed: () {
                    setState(() {
                      _isNewMessageActive = true;
                      _newMessageSearchQuery = '';
                      _newMessageSearchController.clear();
                    });
                  },
                ),
                if (_isMobileView)
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: widget.onOpenSettings,
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No SMS threads synced yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enable SMS under PC Connect > To sync in Ever Dialer mobile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filteredThreads = threads.where((t) {
      final customCat = widget.syncService.smsCategories
          .cast<SyncedSmsCategory?>()
          .firstWhere((c) => c?.id == _selectedSmsCategory, orElse: () => null);
      if (customCat != null && customCat.isCustom) {
        return customCat.contactPhones.any((p) => _numbersMatch(p, t.phone));
      }

      switch (_selectedSmsCategory) {
        case 'favourites':
          return t.isPinned ||
              widget.syncService.isThreadPinned(t.id) ||
              widget.syncService.favourites.any((c) =>
                  _numbersMatch(c.phone, t.phone) ||
                  (c.name.trim().isNotEmpty &&
                      c.name.trim().toLowerCase() == t.contactName.trim().toLowerCase()));
        case 'starred':
          return widget.syncService.isThreadStarred(t.id);
        case 'contacts':
          return t.contactName.isNotEmpty && t.contactName != t.phone;
        case 'unknown':
          return t.contactName.isEmpty || t.contactName == t.phone;
        case 'otp':
          return _otpRegex.hasMatch(t.snippet) || t.messages.any((m) => _otpRegex.hasMatch(m.body));
        case 'all':
        default:
          return true;
      }
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        SyncedSmsThread? activeThread;
        if (filteredThreads.isNotEmpty) {
          if (_selectedSmsThreadId != null) {
            activeThread = filteredThreads.cast<SyncedSmsThread?>().firstWhere(
              (t) => t?.id == _selectedSmsThreadId,
              orElse: () => null,
            );
          }

          // If on wide screens, default to first thread if nothing selected or not found
          if (!isCompact && activeThread == null) {
            activeThread = filteredThreads.first;
            _selectedSmsThreadId = activeThread.id;
          }

          if (activeThread != null && activeThread.unreadCount > 0) {
            final threadIdToMark = activeThread.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final currentThread = widget.syncService.smsThreads.cast<SyncedSmsThread?>().firstWhere(
                (t) => t?.id == threadIdToMark,
                orElse: () => null,
              );
              if (currentThread != null && currentThread.unreadCount > 0) {
                widget.syncService.markSmsAsRead(currentThread.id);
              }
            });
          }
        } else {
          activeThread = null;
        }

        // On smaller screens: when a chat is open, hide the SMS logs list and show only the chat
        if (isCompact && activeThread != null) {
          return Row(
            children: [
              Expanded(
                child: _buildSmsChatDetail(activeThread, isCompact: true),
              ),
            ],
          );
        }

    final pinnedThreads = filteredThreads.where((t) => widget.syncService.isThreadPinned(t.id)).toList();
    final unpinnedThreads = filteredThreads.where((t) => !widget.syncService.isThreadPinned(t.id)).toList();
    final groupedThreads = _groupSmsThreadsByDate(unpinnedThreads);

    final List<Widget> threadWidgets = [];
    if (pinnedThreads.isNotEmpty) {
      threadWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6, top: 4),
          child: Text(
            'Pinned',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontSize: 12.5,
            ),
          ),
        ),
      );
      threadWidgets.add(
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < pinnedThreads.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 64,
                    endIndent: 12,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                _buildSmsThreadTile(pinnedThreads[i], activeThread, showFullDate: true),
              ],
            ],
          ),
        ),
      );
      threadWidgets.add(const SizedBox(height: 12));
    }

    for (final dateHeader in groupedThreads.keys) {
      final threadsInGroup = groupedThreads[dateHeader]!;
      threadWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6, top: 4),
          child: Text(
            dateHeader,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontSize: 12.5,
            ),
          ),
        ),
      );
      threadWidgets.add(
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < threadsInGroup.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 64,
                    endIndent: 12,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                _buildSmsThreadTile(threadsInGroup[i], activeThread, showFullDate: false),
              ],
            ],
          ),
        ),
      );
      threadWidgets.add(const SizedBox(height: 12));
    }

        final threadListContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_comment_rounded, color: colorScheme.onSurface),
                    tooltip: 'New Message',
                    onPressed: () {
                      setState(() {
                        _isNewMessageActive = true;
                        _newMessageSearchQuery = '';
                        _newMessageSearchController.clear();
                      });
                    },
                  ),
                  if (_isMobileView)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                      onPressed: widget.onOpenSettings,
                    ),
                ],
              ),
            ),

            // Category Filter Pills
            Builder(
              builder: (context) {
                final categories = widget.syncService.smsCategories
                    .where((c) => c.isVisible)
                    .toList();
                final chips = categories.isNotEmpty
                    ? categories.map((c) => MapEntry(c.id, c.name)).toList()
                    : const [
                        MapEntry('all', 'All'),
                        MapEntry('favourites', 'Favourites'),
                        MapEntry('starred', 'Starred'),
                        MapEntry('contacts', 'Contacts'),
                        MapEntry('unknown', 'Unknown'),
                        MapEntry('otp', 'OTP'),
                      ];
                return SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (int i = 0; i < chips.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          _buildSmsCategoryChip(chips[i].key, chips[i].value),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            Expanded(
              child: filteredThreads.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No conversations found',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      children: threadWidgets,
                    ),
            ),
          ],
        );

        if (isCompact) {
          // On small screen, show full width New Message view if active, or thread list when no chat is open
          return Row(
            children: [
              Expanded(
                child: _isNewMessageActive
                    ? _buildNewMessageView(isCompact: true)
                    : threadListContent,
              ),
            ],
          );
        }

        // Wide desktop screen: side-by-side master-detail layout
        return Row(
          children: [
            SizedBox(
              width: 340,
              child: _isNewMessageActive
                  ? _buildNewMessageView(isCompact: false)
                  : threadListContent,
            ),
            VerticalDivider(
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            if (activeThread == null)
              Expanded(
                child: Center(
                  child: Text(
                    'Select a conversation to start messaging',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
              )
            else
              Expanded(
                child: _buildSmsChatDetail(activeThread, isCompact: false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSmsChatDetail(SyncedSmsThread thread, {bool isCompact = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Chat Header matching mobile SmsChatScreen top pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              if (isCompact) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                  tooltip: 'Back to messages',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _selectedSmsThreadId = null;
                    });
                  },
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              final pfpBase64 = widget.syncService.getPhotoBase64ForNumber(thread.phone);
                              return SmoothContactAvatar(
                                radius: 16,
                                photoBase64: pfpBase64,
                                initials: thread.contactName.trim().isNotEmpty
                                    ? thread.contactName.trim()[0].toUpperCase()
                                    : '?',
                                backgroundColor: colorScheme.primaryContainer,
                                foregroundColor: colorScheme.onPrimaryContainer,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  thread.contactName.isNotEmpty
                                      ? thread.contactName
                                      : thread.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (thread.contactName.isNotEmpty &&
                                    thread.contactName != thread.phone)
                                  Text(
                                    thread.phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call_rounded),
                  color: colorScheme.primary,
                  tooltip: 'Call ${thread.contactName}',
                  onPressed: () {
                    _initiateCall(thread.phone, displayName: thread.contactName);
                  },
                ),
              ],
            ),
          ),

          // Top Pinned Message Banner
          Builder(
            builder: (context) {
              final pinnedMsgs = thread.messages
                  .where((m) => widget.syncService.isMessagePinned(m.id))
                  .toList();
              if (pinnedMsgs.isEmpty) return const SizedBox.shrink();
              final latestPinned = pinnedMsgs.last;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pinnedMsgs.length > 1
                                ? 'Pinned message (${pinnedMsgs.length})'
                                : 'Pinned message',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            latestPinned.body.isNotEmpty
                                ? latestPinned.body
                                : 'MMS Message',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: colorScheme.onSurfaceVariant),
                      tooltip: 'Unpin message',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        widget.syncService.togglePinMessage(latestPinned.id);
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // Messages list with mobile date headers & bubble styling
          Expanded(
            child: thread.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      // Sort chronologically (oldest to newest)
                      final sortedMessages = List<SyncedSmsMessage>.from(thread.messages)
                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                      // Build grouped list with date headers
                      final List<Widget> chatWidgets = [];
                      DateTime? lastDate;

                      for (final msg in sortedMessages) {
                        final msgDate = DateTime(
                          msg.timestamp.year,
                          msg.timestamp.month,
                          msg.timestamp.day,
                        );

                        if (lastDate == null || msgDate != lastDate) {
                          lastDate = msgDate;
                          chatWidgets.add(
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _formatChatDateHeader(msg.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final isOut = msg.isOutgoing;
                        final isPinned = widget.syncService.isMessagePinned(msg.id);
                        final isStarred = widget.syncService.isMessageStarred(msg.id);
                        final footerColor = isOut
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.outline;

                        chatWidgets.add(
                          Align(
                            alignment: isOut
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onSecondaryTapDown: (details) => _showMessageContextMenu(
                                context,
                                details.globalPosition,
                                thread.id,
                                msg,
                              ),
                              onLongPressStart: (details) => _showMessageContextMenu(
                                context,
                                details.globalPosition,
                                thread.id,
                                msg,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                constraints: const BoxConstraints(maxWidth: 420),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isOut ? 16 : 4),
                                    bottomRight: Radius.circular(isOut ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isOut
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: _buildMessageSpans(
                                          context,
                                          msg.body,
                                          isOut,
                                          colorScheme,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: isOut
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPinned) ...[
                                          Icon(
                                            Icons.push_pin,
                                            size: 11,
                                            color: footerColor,
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        if (isStarred) ...[
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 13,
                                            color: Color(0xFFFFB300),
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          _formatTime(msg.timestamp),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: footerColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return SelectionArea(
                        child: ListView(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          children: chatWidgets.reversed.toList(),
                        ),
                      );
                    },
                  ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(12),
            color: colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _smsInputController,
                    decoration: InputDecoration(
                      hintText: 'Text message...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) {
                      final trimmed = text.trim();
                      if (trimmed.isNotEmpty) {
                        widget.syncService.sendMessage(thread.id, trimmed);
                        _smsInputController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sending SMS to ${thread.contactName}...'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  onPressed: () {
                    final trimmed = _smsInputController.text.trim();
                    if (trimmed.isNotEmpty) {
                      widget.syncService.sendMessage(
                        thread.id,
                        trimmed,
                      );
                      _smsInputController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sending SMS to ${thread.contactName}...'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 5. Notes View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildNotesView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allNotes = widget.syncService.notes;

    final filtered = allNotes.where((n) {
      if (_notesSearchQuery.isEmpty) return true;
      final q = _notesSearchQuery.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobileView ? 14.0 : 20.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notes',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Note'),
                onPressed: _showAddNoteDialog,
              ),
              if (_isMobileView) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: widget.onOpenSettings,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _notesSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 16),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No notes found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTapDown: (details) => _showNoteContextMenu(context, details.globalPosition, note),
                        onLongPressStart: (details) => _showNoteContextMenu(context, details.globalPosition, note),
                        child: Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      note.title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      tooltip: 'Delete note',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        _confirmDeleteNote(context, note);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  note.content,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _formatTimestamp(note.timestamp),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog({String? initialTitle}) {
    final titleController = TextEditingController(text: initialTitle ?? '');
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (contentController.text.trim().isNotEmpty) {
                  widget.syncService.addNote(
                    titleController.text,
                    contentController.text,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatConversationDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) {
      return _formatTime(dt);
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }

  String _formatPinnedConversationDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;
    final timeStr = _formatTime(dt);

    if (diffDays == 0) {
      return 'Today, $timeStr';
    } else if (diffDays == 1) {
      return 'Yesterday, $timeStr';
    } else if (diffDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dt.weekday - 1]}, $timeStr';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, $timeStr';
    }
  }


  String _formatCallDuration(Duration duration) {
    if (duration == Duration.zero) return '';
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatChatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays < 7) {
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      return weekdays[dt.weekday - 1];
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
  }

  String _formatTimestamp(DateTime dt) {
    return _formatConversationDate(dt);
  }

  String _formatCallDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      if (dt.year == now.year) {
        return '${months[dt.month - 1]} ${dt.day}';
      } else {
        return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    }
  }

  Map<String, List<SyncedCallLog>> _groupLogsByDate(List<SyncedCallLog> logs) {
    final map = <String, List<SyncedCallLog>>{};
    for (final log in logs) {
      final header = _formatCallDateHeader(log.timestamp);
      map.putIfAbsent(header, () => []).add(log);
    }
    return map;
  }

  Map<String, List<SyncedSmsThread>> _groupSmsThreadsByDate(List<SyncedSmsThread> threads) {
    final map = <String, List<SyncedSmsThread>>{};
    for (final thread in threads) {
      final header = _formatCallDateHeader(thread.timestamp);
      map.putIfAbsent(header, () => []).add(thread);
    }
    return map;
  }

  Map<String, List<SyncedContact>> _groupContactsByLetter(List<SyncedContact> contacts) {
    final map = <String, List<SyncedContact>>{};
    for (final contact in contacts) {
      final trimmed = contact.name.trim();
      final firstChar = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '#';
      final letter = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      map.putIfAbsent(letter, () => []).add(contact);
    }

    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    final sortedMap = <String, List<SyncedContact>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Context Menu Helpers & Actions
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _showItemContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required List<PopupMenuEntry<String>> items,
    required void Function(String action) onSelected,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      items: items,
    );
    if (action != null) {
      onSelected(action);
    }
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 19,
            color: isDestructive ? Colors.redAccent : iconColor,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFavouriteContextMenu(BuildContext context, Offset position, SyncedContact contact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        _buildMenuItem(
          value: 'view_contact',
          icon: Icons.person_outline,
          label: 'View Contact Info',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'call',
          icon: Icons.call,
          label: 'Call',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'sms',
          icon: Icons.chat_bubble_outline,
          label: 'Send SMS',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'copy_number',
          icon: Icons.copy,
          label: 'Copy Number',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'remove_favorite',
          icon: Icons.star_border,
          label: 'Remove Favorite',
          iconColor: Colors.amber,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'view_contact':
            setState(() {
              _previousIndex = _selectedIndex;
              _selectedIndex = 2;
              _selectedContactForDetails = contact;
            });
            break;
          case 'call':
            _initiateCall(contact.phone, displayName: contact.name, photoBase64: contact.photoBase64);
            break;
          case 'sms':
            _openSmsForNumber(contact.phone);
            break;
          case 'copy_number':
            Clipboard.setData(ClipboardData(text: contact.phone));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${contact.phone} to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'remove_favorite':
            widget.syncService.toggleFavorite(contact.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed ${contact.name} from favourites'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
        }
      },
    );
  }

  void _showCallLogContextMenu(BuildContext context, Offset position, SyncedCallLog log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = log.name.isNotEmpty && log.name != log.number ? log.name : log.number;
    final matchingContact = widget.syncService.contacts.cast<SyncedContact?>().firstWhere(
      (c) => c != null && c.phone.replaceAll(RegExp(r'[^\d+]'), '') == log.number.replaceAll(RegExp(r'[^\d+]'), ''),
      orElse: () => null,
    );

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        if (matchingContact != null)
          _buildMenuItem(
            value: 'view_contact',
            icon: Icons.person_outline,
            label: 'View Contact Info',
            iconColor: colorScheme.primary,
          ),
        _buildMenuItem(
          value: 'call',
          icon: Icons.call,
          label: 'Call Back',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'sms',
          icon: Icons.chat_bubble_outline,
          label: 'Send SMS',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'copy_number',
          icon: Icons.copy,
          label: 'Copy Number',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        if (matchingContact != null)
          _buildMenuItem(
            value: 'toggle_favorite',
            icon: matchingContact.isFavorite ? Icons.star : Icons.star_border,
            label: matchingContact.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
            iconColor: Colors.amber,
          ),
        _buildMenuItem(
          value: 'share',
          icon: Icons.share_outlined,
          label: 'Share',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'block_number',
          icon: Icons.block,
          label: 'Block Number',
          iconColor: colorScheme.error,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'delete_call_log',
          icon: Icons.delete_outline,
          label: 'Delete Call Log',
          isDestructive: true,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'view_contact':
            if (matchingContact != null) {
              setState(() {
                _previousIndex = _selectedIndex;
                _selectedIndex = 2;
                _selectedContactForDetails = matchingContact;
              });
            }
            break;
          case 'call':
            _initiateCall(log.number, displayName: displayName, simSlot: log.simSlot > 0 ? log.simSlot : null);
            break;
          case 'sms':
            _openSmsForNumber(log.number);
            break;
          case 'copy_number':
            Clipboard.setData(ClipboardData(text: log.number));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${log.number} to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'toggle_favorite':
            if (matchingContact != null) {
              widget.syncService.toggleFavorite(matchingContact.id);
            }
            break;
          case 'share':
            Clipboard.setData(ClipboardData(text: '$displayName: ${log.number}'));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied "$displayName: ${log.number}" to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'block_number':
            _confirmBlockNumber(context, log.number, displayName);
            break;
          case 'delete_call_log':
            widget.syncService.deleteCallLog(log.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call log deleted'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
        }
      },
    );
  }

  void _showContactContextMenu(BuildContext context, Offset position, SyncedContact contact) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        _buildMenuItem(
          value: 'view_contact',
          icon: Icons.person_outline,
          label: 'View Contact Info',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'call',
          icon: Icons.call,
          label: 'Call',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'sms',
          icon: Icons.chat_bubble_outline,
          label: 'Send SMS',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'copy_number',
          icon: Icons.copy,
          label: 'Copy Number',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'toggle_favorite',
          icon: contact.isFavorite ? Icons.star : Icons.star_border,
          label: contact.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
          iconColor: Colors.amber,
        ),
        _buildMenuItem(
          value: 'share',
          icon: Icons.share_outlined,
          label: 'Share Contact',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'block_contact',
          icon: Icons.block,
          label: 'Block Contact',
          iconColor: colorScheme.error,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'view_contact':
            setState(() {
              _previousIndex = _selectedIndex;
              _selectedIndex = 2;
              _selectedContactForDetails = contact;
            });
            break;
          case 'call':
            _initiateCall(contact.phone, displayName: contact.name, photoBase64: contact.photoBase64);
            break;
          case 'sms':
            _openSmsForNumber(contact.phone);
            break;
          case 'copy_number':
            Clipboard.setData(ClipboardData(text: contact.phone));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${contact.phone} to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'toggle_favorite':
            widget.syncService.toggleFavorite(contact.id);
            break;
          case 'share':
            Clipboard.setData(ClipboardData(text: '${contact.name}: ${contact.phone}'));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied "${contact.name}: ${contact.phone}" to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'block_contact':
            _confirmBlockNumber(context, contact.phone, contact.name);
            break;
        }
      },
    );
  }

  void _showSmsThreadContextMenu(BuildContext context, Offset position, SyncedSmsThread thread) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = thread.contactName.isNotEmpty && thread.contactName != thread.phone ? thread.contactName : thread.phone;
    final isUnread = thread.unreadCount > 0;

    final isPinned = widget.syncService.isThreadPinned(thread.id);

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        _buildMenuItem(
          value: 'pin_thread',
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: isPinned ? 'Unpin Chat' : 'Pin Chat',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'open',
          icon: Icons.chat_bubble_outline,
          label: 'Open Chat',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'call',
          icon: Icons.call,
          label: 'Call',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'copy_number',
          icon: Icons.copy,
          label: 'Copy Number',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'mark_read',
          icon: isUnread ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
          label: isUnread ? 'Mark as Read' : 'Mark as Unread',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'block_number',
          icon: Icons.block,
          label: 'Block Number',
          iconColor: colorScheme.error,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'delete_thread',
          icon: Icons.delete_outline,
          label: 'Delete Conversation',
          isDestructive: true,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'pin_thread':
            widget.syncService.togglePinThread(thread.id);
            break;
          case 'open':
            setState(() {
              _selectedSmsThreadId = thread.id;
            });
            if (thread.unreadCount > 0) {
              widget.syncService.markSmsAsRead(thread.id);
            }
            break;
          case 'call':
            _initiateCall(thread.phone, displayName: displayName);
            break;
          case 'copy_number':
            Clipboard.setData(ClipboardData(text: thread.phone));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${thread.phone} to clipboard'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'mark_read':
            widget.syncService.toggleSmsRead(thread.id);
            break;
          case 'block_number':
            _confirmBlockNumber(context, thread.phone, displayName);
            break;
          case 'delete_thread':
            _confirmDeleteSmsThread(context, thread);
            break;
        }
      },
    );
  }

  Widget _buildSmsCategoryChip(String key, String label) {
    final isSelected = _selectedSmsCategory == key;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
      ),
      backgroundColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      onSelected: (val) {
        setState(() {
          _selectedSmsCategory = key;
        });
      },
    );
  }

  Widget _buildSmsThreadTile(SyncedSmsThread thread, SyncedSmsThread? activeThread, {bool showFullDate = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = activeThread != null && thread.id == activeThread.id;
    final isUnread = thread.unreadCount > 0;
    final hasName = thread.contactName.isNotEmpty && thread.contactName != thread.phone;
    final displayName = hasName ? thread.contactName : thread.phone;

    final bgColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.45)
        : (isUnread
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.4)
            : Colors.transparent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) => _showSmsThreadContextMenu(context, details.globalPosition, thread),
      onLongPressStart: (details) => _showSmsThreadContextMenu(context, details.globalPosition, thread),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSmsThreadId = thread.id;
          });
          if (thread.unreadCount > 0) {
            widget.syncService.markSmsAsRead(thread.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: bgColor,
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final pfpBase64 = widget.syncService.getPhotoBase64ForNumber(thread.phone);
                  return SmoothContactAvatar(
                    radius: 20,
                    photoBase64: pfpBase64,
                    initials: hasName && thread.contactName.trim().isNotEmpty
                        ? thread.contactName.trim()[0].toUpperCase()
                        : null,
                    fallbackChild: !hasName || thread.contactName.trim().isEmpty
                        ? Icon(
                            Icons.person,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          )
                        : null,
                    backgroundColor: isUnread
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: isUnread
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: colorScheme.onSurface,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          showFullDate
                              ? _formatPinnedConversationDate(thread.timestamp)
                              : _formatConversationDate(thread.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isUnread
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.snippet.isNotEmpty
                                ? thread.snippet
                                : 'No message text',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isUnread
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.isPinned) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ],
                        if (widget.syncService.isThreadStarred(thread.id)) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFFB300),
                          ),
                        ],
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageContextMenu(BuildContext context, Offset position, String threadId, SyncedSmsMessage msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPinned = widget.syncService.isMessagePinned(msg.id);
    final isStarred = widget.syncService.isMessageStarred(msg.id);

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        _buildMenuItem(
          value: 'pin',
          icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          label: isPinned ? 'Unpin message' : 'Pin message',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'star',
          icon: isStarred ? Icons.star_outline_rounded : Icons.star_rounded,
          label: isStarred ? 'Unstar message' : 'Star message',
          iconColor: const Color(0xFFFFB300),
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'select',
          icon: Icons.select_all,
          label: 'Select text',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'copy',
          icon: Icons.copy,
          label: 'Copy text',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete',
          isDestructive: true,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'pin':
            widget.syncService.togglePinMessage(msg.id);
            break;
          case 'star':
            widget.syncService.toggleStarMessage(msg.id);
            break;
          case 'select':
            _showSelectTextDialog(context, msg.body);
            break;
          case 'copy':
            Clipboard.setData(ClipboardData(text: msg.body));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message copied to clipboard'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'delete':
            _confirmDeleteSmsMessage(context, threadId, msg.id);
            break;
        }
      },
    );
  }

  void _showSelectTextDialog(BuildContext context, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select text'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied all to clipboard'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Copy all'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSmsMessage(BuildContext context, String threadId, String messageId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'Delete this message? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogTheme.colorScheme.error,
                foregroundColor: dialogTheme.colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.syncService.deleteSmsMessage(threadId, messageId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showPhoneActionDialog(BuildContext context, String phoneNumber) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                phoneNumber,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.call, color: colorScheme.primary),
              title: const Text('Call'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _initiateCall(phoneNumber, displayName: phoneNumber);
              },
            ),
            ListTile(
              leading: Icon(Icons.message_outlined, color: colorScheme.primary),
              title: const Text('Text'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                _showNewMessageDialog(context, initialNumber: phoneNumber);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: colorScheme.onSurfaceVariant),
              title: const Text('Copy Number'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: phoneNumber));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $phoneNumber to clipboard'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openBrowserUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    try {
      Process.run('xdg-open', [url]);
    } catch (e) {
      debugPrint('Failed to open URL $url: $e');
    }
  }

  List<InlineSpan> _buildMessageSpans(
    BuildContext context,
    String text,
    bool isOutgoing,
    ColorScheme colorScheme,
  ) {
    final textColor = isOutgoing
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final linkColor = colorScheme.primary;

    final List<InlineSpan> spans = [];

    final urlRegex = RegExp(
      r'(https?:\/\/[^\s<>"\)]+|www\.[^\s<>"\)]+)',
      caseSensitive: false,
    );

    int lastIdx = 0;
    for (final match in urlRegex.allMatches(text)) {
      if (match.start > lastIdx) {
        final sub = text.substring(lastIdx, match.start);
        _appendPhoneAndTextSpans(context, spans, sub, textColor, linkColor);
      }
      var url = match.group(0)!;
      String trailing = '';
      while (url.isNotEmpty &&
          (url.endsWith('.') ||
              url.endsWith(',') ||
              url.endsWith(';') ||
              url.endsWith(')') ||
              url.endsWith(']'))) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }

      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _openBrowserUrl(url),
        ),
      );

      if (trailing.isNotEmpty) {
        _appendPhoneAndTextSpans(context, spans, trailing, textColor, linkColor);
      }

      lastIdx = match.end;
    }

    if (lastIdx < text.length) {
      final sub = text.substring(lastIdx);
      _appendPhoneAndTextSpans(context, spans, sub, textColor, linkColor);
    }

    return spans;
  }

  void _appendPhoneAndTextSpans(
    BuildContext context,
    List<InlineSpan> spans,
    String text,
    Color textColor,
    Color linkColor,
  ) {
    final phoneRegex = RegExp(r'(\+?\d[\d\s\-\(\)]{5,}\d)');
    int lastIdx = 0;
    for (final match in phoneRegex.allMatches(text)) {
      final candidate = match.group(0)!;
      final digits = candidate.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 7 && digits.length <= 15) {
        if (match.start > lastIdx) {
          spans.add(TextSpan(
            text: text.substring(lastIdx, match.start),
            style: TextStyle(color: textColor),
          ));
        }
        spans.add(
          TextSpan(
            text: candidate,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _showPhoneActionDialog(context, candidate),
          ),
        );
        lastIdx = match.end;
      }
    }
    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: TextStyle(color: textColor),
      ));
    }
  }

  void _showNoteContextMenu(BuildContext context, Offset position, SyncedNote note) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _showItemContextMenu(
      context: context,
      globalPosition: position,
      items: [
        _buildMenuItem(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Edit Note',
          iconColor: colorScheme.primary,
        ),
        _buildMenuItem(
          value: 'copy',
          icon: Icons.copy,
          label: 'Copy Content',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        _buildMenuItem(
          value: 'share',
          icon: Icons.share_outlined,
          label: 'Share Note',
          iconColor: colorScheme.onSurfaceVariant,
        ),
        const PopupMenuDivider(height: 8),
        _buildMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete Note',
          isDestructive: true,
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _showEditNoteDialog(note);
            break;
          case 'copy':
            Clipboard.setData(ClipboardData(text: '${note.title}\n\n${note.content}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied note to clipboard'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'share':
            Clipboard.setData(ClipboardData(text: '${note.title}\n\n${note.content}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note content copied to clipboard for sharing'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'delete':
            _confirmDeleteNote(context, note);
            break;
        }
      },
    );
  }

  void _showEditNoteDialog(SyncedNote note) {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.syncService.editNote(
                note.id,
                titleController.text,
                contentController.text,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNote(BuildContext context, SyncedNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              widget.syncService.deleteNote(note.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note deleted'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSmsThread(BuildContext context, SyncedSmsThread thread) {
    final displayName = thread.contactName.isNotEmpty && thread.contactName != thread.phone ? thread.contactName : thread.phone;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete the entire conversation with $displayName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              widget.syncService.deleteSmsThread(thread.id);
              if (_selectedSmsThreadId == thread.id) {
                setState(() {
                  _selectedSmsThreadId = null;
                });
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation deleted'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockNumber(BuildContext context, String number, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Number'),
        content: Text('Block incoming calls and messages from $name ($number)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              widget.syncService.blockNumber(number);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Blocked $name ($number)'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}

class _SimCardNotchClipper extends CustomClipper<Path> {
  const _SimCardNotchClipper();

  @override
  Path getClip(Size size) {
    final notch = (size.width < size.height ? size.width : size.height) * 0.42;
    return Path()
      ..moveTo(notch, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, notch)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ═════════════════════════════════════════════════════════════════════════
// Mobile Dialpad Bottom Sheet & Animations
// ═════════════════════════════════════════════════════════════════════════

class _DialDigitItem {
  final int id;
  final String char;
  const _DialDigitItem(this.id, this.char);
}

class _AnimatedDialDigit extends StatefulWidget {
  final String char;
  final double fontSize;
  final Color color;

  const _AnimatedDialDigit({
    super.key,
    required this.char,
    required this.fontSize,
    required this.color,
  });

  @override
  State<_AnimatedDialDigit> createState() => _AnimatedDialDigitState();
}

class _AnimatedDialDigitState extends State<_AnimatedDialDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetYAnim;
  late final Animation<double> _alphaAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offsetYAnim = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _alphaAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offsetYAnim.value),
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _alphaAnim.value,
              child: Text(
                widget.char,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w400,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBackspaceButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final ColorScheme colorScheme;

  const _AnimatedBackspaceButton({
    required this.visible,
    required this.onBackspace,
    required this.onClear,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.fastOutSlowIn,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.7,
        duration: const Duration(milliseconds: 180),
        curve: Curves.fastOutSlowIn,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: visible ? onBackspace : null,
            onLongPress: visible ? onClear : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.backspace_outlined,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPadKeyWidget extends StatefulWidget {
  final String main;
  final String sub;
  final void Function(String) onDigit;
  final VoidCallback? onLongPress;

  const _DialPadKeyWidget({
    required this.main,
    required this.sub,
    required this.onDigit,
    this.onLongPress,
  });

  @override
  State<_DialPadKeyWidget> createState() => _DialPadKeyWidgetState();
}

class _DialPadKeyWidgetState extends State<_DialPadKeyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerTapPulse() {
    _controller.forward().then((_) {
      if (!_isPressed && mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isStar = widget.main == '*';
    final isPlus = widget.sub.trim() == '+';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final cornerRadius = ui.lerpDouble(24.0, 10.0, progress)!;
        final scale = ui.lerpDouble(1.0, 0.88, progress)!;
        final bgColor = Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.primary,
          progress,
        )!;
        final textColor = Color.lerp(
          colorScheme.onPrimaryContainer,
          colorScheme.onPrimary,
          progress,
        )!;
        final subTextColor = Color.lerp(
          colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
          colorScheme.onPrimary.withValues(alpha: 0.85),
          progress,
        )!;

        return Transform.scale(
          scale: scale,
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(cornerRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTapDown: (_) {
                _isPressed = true;
                _controller.forward();
              },
              onTapUp: (_) {
                _isPressed = false;
                _triggerTapPulse();
              },
              onTapCancel: () {
                _isPressed = false;
                _controller.reverse();
              },
              onTap: () => widget.onDigit(widget.main),
              onLongPress: widget.onLongPress,
              child: SizedBox(
                width: 90,
                height: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.main,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: isStar ? 26 : 21,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    if (widget.sub.trim().isNotEmpty)
                      Text(
                        widget.sub,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: isPlus ? 12 : 9.5,
                          fontWeight: isPlus ? FontWeight.bold : FontWeight.w500,
                          letterSpacing: isPlus ? 0 : 1.2,
                          color: subTextColor,
                          height: 1.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialerActionExpressive extends StatefulWidget {
  final VoidCallback onClick;
  final IconData icon;
  final Color containerColor;
  final Color? contentColor;
  final double width;
  final double height;
  final bool isCallButton;

  const _DialerActionExpressive({
    required this.onClick,
    required this.icon,
    required this.containerColor,
    this.contentColor,
    required this.width,
    required this.height,
    this.isCallButton = false,
  });

  @override
  State<_DialerActionExpressive> createState() => _DialerActionExpressiveState();
}

class _DialerActionExpressiveState extends State<_DialerActionExpressive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerTapPulse() {
    _controller.forward().then((_) {
      if (!_isPressed && mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final baseRadius = widget.isCallButton ? 26.0 : 24.0;
        final pressedRadius = widget.isCallButton ? 14.0 : 10.0;
        final cornerRadius = ui.lerpDouble(baseRadius, pressedRadius, progress)!;
        final scale = ui.lerpDouble(1.0, 0.88, progress)!;
        final bgColor = Color.lerp(
          widget.containerColor,
          widget.isCallButton
              ? widget.containerColor.withValues(alpha: 0.85)
              : colorScheme.primary,
          progress,
        )!;
        final contentColor = widget.contentColor ?? colorScheme.onSurface;

        return Transform.scale(
          scale: scale,
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(cornerRadius),
            clipBehavior: Clip.antiAlias,
            elevation: widget.isCallButton ? 3 : 0,
            child: InkWell(
              onTapDown: (_) {
                _isPressed = true;
                _controller.forward();
              },
              onTapUp: (_) {
                _isPressed = false;
                _triggerTapPulse();
              },
              onTapCancel: () {
                _isPressed = false;
                _controller.reverse();
              },
              onTap: widget.onClick,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: widget.isCallButton ? 28 : 22,
                    color: contentColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileDialpadSheet extends StatefulWidget {
  final PcSyncService syncService;
  final void Function(String) onCall;
  final void Function(String) onAddContact;
  final void Function(String) onOpenSms;
  final VoidCallback onDismiss;

  const _MobileDialpadSheet({
    required this.syncService,
    required this.onCall,
    required this.onAddContact,
    required this.onOpenSms,
    required this.onDismiss,
  });

  @override
  State<_MobileDialpadSheet> createState() => _MobileDialpadSheetState();
}

class _MobileDialpadSheetState extends State<_MobileDialpadSheet>
    with SingleTickerProviderStateMixin {
  String _enteredNumber = '';
  int _cursorPosition = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _idCounter = 0;
  final List<_DialDigitItem> _stableDigits = [];
  late final AnimationController _cursorBlinkController;

  static const _keys = [
    ['1', ' '], ['2', 'ABC'], ['3', 'DEF'],
    ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
    ['*', ' '], ['0', '+'], ['#', ' '],
  ];

  @override
  void initState() {
    super.initState();
    _cursorBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _cursorBlinkController.dispose();
    super.dispose();
  }

  String _convertNameToT9(String name) {
    final buffer = StringBuffer();
    for (final rune in name.toUpperCase().runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case 'A': case 'B': case 'C': buffer.write('2'); break;
        case 'D': case 'E': case 'F': buffer.write('3'); break;
        case 'G': case 'H': case 'I': buffer.write('4'); break;
        case 'J': case 'K': case 'L': buffer.write('5'); break;
        case 'M': case 'N': case 'O': buffer.write('6'); break;
        case 'P': case 'Q': case 'R': case 'S': buffer.write('7'); break;
        case 'T': case 'U': case 'V': buffer.write('8'); break;
        case 'W': case 'X': case 'Y': case 'Z': buffer.write('9'); break;
        default: buffer.write('0'); break;
      }
    }
    return buffer.toString();
  }

  void _insertAtCursor(String text) {
    setState(() {
      final at = _cursorPosition.clamp(0, _enteredNumber.length);
      _enteredNumber = _enteredNumber.substring(0, at) + text + _enteredNumber.substring(at);
      for (int i = 0; i < text.length; i++) {
        _stableDigits.insert(at + i, _DialDigitItem(_idCounter++, text[i]));
      }
      _cursorPosition = at + text.length;
    });
  }

  void _deleteAtCursor() {
    if (_enteredNumber.isNotEmpty && _cursorPosition > 0) {
      setState(() {
        final at = _cursorPosition.clamp(0, _enteredNumber.length);
        _enteredNumber = _enteredNumber.substring(0, at - 1) + _enteredNumber.substring(at);
        if (at - 1 < _stableDigits.length) {
          _stableDigits.removeAt(at - 1);
        }
        _cursorPosition = at - 1;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _enteredNumber = '';
      _cursorPosition = 0;
      _stableDigits.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Real-time contact matching (T9 + digits + search query)
    final q = _searchQuery.trim().toLowerCase();
    final numDigits = _enteredNumber.replaceAll(RegExp(r'[^\d+*#]'), '');
    List<SyncedContact> matchedContacts = [];
    if (q.isNotEmpty) {
      matchedContacts = widget.syncService.contacts.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.replaceAll(RegExp(r'[^\d+]'), '').contains(q);
      }).take(3).toList();
    } else if (numDigits.isNotEmpty) {
      matchedContacts = widget.syncService.contacts.where((c) {
        final cleanPhone = c.phone.replaceAll(RegExp(r'[^\d+]'), '');
        final matchesPhone = cleanPhone.contains(numDigits);
        final t9Name = _convertNameToT9(c.name);
        final matchesT9 = t9Name.contains(numDigits);
        return matchesPhone || matchesT9;
      }).take(3).toList();
    }

    // Dynamic progressive font scaling
    final step = (_enteredNumber.length - 6).clamp(0, 100);
    final factor = step == 0
        ? 1.0
        : (step <= 7 ? 1.0 - step * 0.06 : (0.58 - (step - 7) * 0.025).clamp(0.35, 1.0));
    final numFontSize = (36.0 * factor).clamp(16.0, 36.0);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _deleteAtCursor();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (_enteredNumber.isNotEmpty) {
              widget.onCall(_enteredNumber);
            } else {
              final latest = widget.syncService.callLogs.firstOrNull;
              if (latest != null && latest.number.isNotEmpty) {
                setState(() {
                  _enteredNumber = latest.number;
                  _stableDigits.clear();
                  for (final ch in _enteredNumber.split('')) {
                    _stableDigits.add(_DialDigitItem(_idCounter++, ch));
                  }
                  _cursorPosition = _enteredNumber.length;
                });
              }
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onDismiss();
            return KeyEventResult.handled;
          } else {
            final keyLabel = event.logicalKey.keyLabel;
            if (RegExp(r'^[0-9*#+]$').hasMatch(keyLabel)) {
              _insertAtCursor(keyLabel);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Material(
          color: colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          elevation: 16,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Search Bar with X button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search contacts...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        foregroundColor: colorScheme.onSurfaceVariant,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),

                // Matching contacts preview
                if (matchedContacts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 125),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: matchedContacts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 4),
                      itemBuilder: (context, idx) {
                        final contact = matchedContacts[idx];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _enteredNumber = contact.phone;
                              _stableDigits.clear();
                              for (final ch in _enteredNumber.split('')) {
                                _stableDigits.add(_DialDigitItem(_idCounter++, ch));
                              }
                              _cursorPosition = _enteredNumber.length;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                SmoothContactAvatar(
                                  radius: 16,
                                  photoBase64: contact.photoBase64,
                                  initials: contact.initials,
                                  backgroundColor: colorScheme.primaryContainer,
                                  foregroundColor: colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        contact.phone,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.call, size: 18),
                                  color: Colors.green.shade600,
                                  onPressed: () => widget.onCall(contact.phone),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Number Display Area with Animated Digits & Backspace
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered Digits Row with blinking cursor
                      Center(
                        child: _enteredNumber.isEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _cursorBlinkController,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _cursorBlinkController.value > 0.5 ? 1.0 : 0.0,
                                        child: Container(
                                          width: 2.5,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Dial a number',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.outline.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 48),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (int i = 0; i <= _stableDigits.length; i++) ...[
                                      if (i == _cursorPosition)
                                        AnimatedBuilder(
                                          animation: _cursorBlinkController,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: _cursorBlinkController.value > 0.5 ? 1.0 : 0.0,
                                              child: Container(
                                                width: 2.5,
                                                height: numFontSize * 0.95,
                                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary,
                                                  borderRadius: BorderRadius.circular(1),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      if (i < _stableDigits.length)
                                        GestureDetector(
                                          onTap: () => setState(() => _cursorPosition = i + 1),
                                          child: _AnimatedDialDigit(
                                            key: ValueKey(_stableDigits[i].id),
                                            char: _stableDigits[i].char,
                                            fontSize: numFontSize,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                      ),

                      // Backspace Button placed on the right
                      Positioned(
                        right: 0,
                        child: _AnimatedBackspaceButton(
                          visible: _enteredNumber.isNotEmpty,
                          onBackspace: _deleteAtCursor,
                          onClear: _clearAll,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Action Chips (Copy, SMS)
                if (_enteredNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.person_add_outlined, size: 16),
                        label: const Text('Add Contact', style: TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () => widget.onAddContact(_enteredNumber),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.copy_outlined, size: 16),
                        label: const Text('Copy', style: TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _enteredNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Number copied to clipboard'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('SMS', style: TextStyle(fontSize: 12)),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onPressed: () => widget.onOpenSms(_enteredNumber.trim()),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Dialpad Keys Grid (Mobile M3 Parity)
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      for (int r = 0; r < 4; r++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int c = 0; c < 3; c++)
                                _DialPadKeyWidget(
                                  main: _keys[r * 3 + c][0],
                                  sub: _keys[r * 3 + c][1],
                                  onDigit: _insertAtCursor,
                                  onLongPress: _keys[r * 3 + c][0] == '0'
                                      ? () => _insertAtCursor('+')
                                      : null,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Action Row (Add Contact | Call Button | Spacer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Add Contact Expressive Action Button
                      _DialerActionExpressive(
                        icon: Icons.person_add_rounded,
                        containerColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        contentColor: colorScheme.onSurface,
                        width: 72,
                        height: 56,
                        onClick: () => widget.onAddContact(_enteredNumber),
                      ),

                      // Centered Green Call Button
                      _DialerActionExpressive(
                        icon: Icons.call,
                        containerColor: const Color(0xFF34A853),
                        contentColor: Colors.white,
                        width: 96,
                        height: 56,
                        isCallButton: true,
                        onClick: () {
                          if (_enteredNumber.trim().isNotEmpty) {
                            widget.onCall(_enteredNumber.trim());
                          } else {
                            final latest = widget.syncService.callLogs.firstOrNull;
                            if (latest != null && latest.number.isNotEmpty) {
                              setState(() {
                                _enteredNumber = latest.number;
                                _stableDigits.clear();
                                for (final ch in _enteredNumber.split('')) {
                                  _stableDigits.add(_DialDigitItem(_idCounter++, ch));
                                }
                                _cursorPosition = _enteredNumber.length;
                              });
                            }
                          }
                        },
                      ),

                      // Right Balanced Spacer matching mobile
                      const SizedBox(width: 72, height: 56),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

