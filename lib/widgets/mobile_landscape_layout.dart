import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class MobileLandscapeLayout extends StatefulWidget {
  final PcSyncService syncService;
  final VoidCallback onOpenSettings;

  const MobileLandscapeLayout({
    super.key,
    required this.syncService,
    required this.onOpenSettings,
  });

  @override
  State<MobileLandscapeLayout> createState() => _MobileLandscapeLayoutState();
}

class _MobileLandscapeLayoutState extends State<MobileLandscapeLayout> {
  int _selectedIndex = 0; // 0: Favourites, 1: Calls, 2: Contacts, 3: SMS, 4: Notes

  // Calls tab state
  String _callFilter = 'All'; // All, Missed, Incoming, Outgoing
  String _callSearchQuery = '';

  // Contacts tab state
  String _contactSearchQuery = '';

  // SMS tab state
  String? _selectedSmsThreadId;
  final TextEditingController _smsInputController = TextEditingController();

  // Notes tab state
  String _notesSearchQuery = '';

  @override
  void dispose() {
    _smsInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // ── Left Navigation Rail ──────────────────────────────────────────
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
                      _buildRailItem(
                        index: 0,
                        icon: Icons.favorite,
                        unselectedIcon: Icons.favorite_border,
                        label: 'Favourites',
                      ),
                      const SizedBox(height: 6),
                      _buildRailItem(
                        index: 1,
                        icon: Icons.history,
                        unselectedIcon: Icons.history_outlined,
                        label: 'Calls',
                      ),
                      const SizedBox(height: 6),
                      _buildRailItem(
                        index: 2,
                        icon: Icons.person,
                        unselectedIcon: Icons.person_outline,
                        label: 'Contacts',
                      ),
                      const SizedBox(height: 6),
                      _buildRailItem(
                        index: 3,
                        icon: Icons.chat,
                        unselectedIcon: Icons.chat_bubble_outline,
                        label: 'SMS',
                      ),
                      const SizedBox(height: 6),
                      _buildRailItem(
                        index: 4,
                        icon: Icons.note_alt,
                        unselectedIcon: Icons.note_alt_outlined,
                        label: 'Notes',
                      ),
                    ],
                  ),
                ),
              ),

              Divider(
                indent: 12,
                endIndent: 12,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),

              // Bluetooth Sync Status & trigger
              IconButton(
                icon: Icon(
                  widget.syncService.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_searching,
                  color: widget.syncService.isConnected
                      ? colorScheme.primary
                      : colorScheme.outline,
                  size: 20,
                ),
                tooltip: widget.syncService.isConnected
                    ? 'Synced with ${widget.syncService.connectedDeviceName ?? "Mobile"}. Click to refresh.'
                    : 'Searching for Ever Dialer Mobile... Click to refresh.',
                onPressed: () {
                  widget.syncService.requestSyncNow();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.syncService.isConnected
                            ? 'Requesting sync from ${widget.syncService.connectedDeviceName ?? "phone"}...'
                            : 'Listening for Bluetooth connection from Ever Dialer Mobile...',
                      ),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),

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

        // ── Right Main Content Area ───────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              Material(
                color: colorScheme.surface,
                child: ListenableBuilder(
                  listenable: widget.syncService,
                  builder: (context, _) {
                    switch (_selectedIndex) {
                      case 0:
                        return _buildFavouritesView();
                      case 1:
                        return _buildCallLogsView();
                      case 2:
                        return _buildContactsView();
                      case 3:
                        return _buildSmsView();
                      case 4:
                        return _buildNotesView();
                      default:
                        return _buildFavouritesView();
                    }
                  },
                ),
              ),
              if (_selectedIndex != 4)
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showDialDialog(context),
                    icon: const Icon(Icons.dialpad),
                    label: const Text('Dialpad'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openSmsForNumber(String num) {
    final clean = num.replaceAll(RegExp(r'[^\d+]'), '');
    final existingIndex = widget.syncService.smsThreads.indexWhere(
      (t) => t.phone.replaceAll(RegExp(r'[^\d+]'), '') == clean,
    );

    setState(() {
      _selectedIndex = 3; // Switch to SMS tab
      if (existingIndex != -1) {
        _selectedSmsThreadId = widget.syncService.smsThreads[existingIndex].id;
      }
    });
  }

  void _showDialDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String enteredNumber = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            void appendDigit(String digit) {
              setDialogState(() {
                enteredNumber += digit;
              });
            }

            void deleteDigit() {
              if (enteredNumber.isNotEmpty) {
                setDialogState(() {
                  enteredNumber = enteredNumber.substring(0, enteredNumber.length - 1);
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                enteredNumber.isEmpty ? 'Enter number' : enteredNumber,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: enteredNumber.isEmpty
                                      ? colorScheme.outline
                                      : colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (enteredNumber.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.backspace_outlined, size: 20),
                                onPressed: deleteDigit,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDialpadGrid(context, appendDigit),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.call),
                            label: const Text('Call'),
                            onPressed: enteredNumber.trim().isEmpty
                                ? null
                                : () {
                                    final num = enteredNumber.trim();
                                    Navigator.pop(context);
                                    widget.syncService.makeCall(num);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Placing call to $num through phone...'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text('SMS'),
                            onPressed: enteredNumber.trim().isEmpty
                                ? null
                                : () {
                                    final num = enteredNumber.trim();
                                    Navigator.pop(context);
                                    _openSmsForNumber(num);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialpadGrid(BuildContext context, void Function(String) onDigit) {
    const keys = [
      ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
      ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
      ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
      ['*', ''], ['0', '+'], ['#', ''],
    ];

    return Column(
      children: [
        for (int r = 0; r < 4; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int c = 0; c < 3; c++)
                  _buildDialKey(context, keys[r * 3 + c][0], keys[r * 3 + c][1], onDigit),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDialKey(BuildContext context, String main, String sub, void Function(String) onDigit) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => onDigit(main),
      onLongPress: main == '0' ? () => onDigit('+') : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              main,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  letterSpacing: 1.0,
                  color: colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
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
            FilledButton.icon(
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send'),
              onPressed: () {
                final phone = phoneCtrl.text.trim();
                final text = msgCtrl.text.trim();
                if (phone.isNotEmpty && text.isNotEmpty) {
                  Navigator.pop(context);
                  widget.syncService.sendSmsToNumber(phone, text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sending SMS to $phone...'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRailItem({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
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
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  isSelected ? icon : unselectedIcon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
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

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Favourites',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 16),
          if (favourites.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No favourites synced from Ever Dialer mobile yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  final contact = favourites[index];
                  return Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              contact.initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            contact.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            contact.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.call, size: 18),
                                color: colorScheme.primary,
                                tooltip: 'Call ${contact.name}',
                                onPressed: () {
                                  widget.syncService.makeCall(contact.phone);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Calling ${contact.name} (${contact.phone})...'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                color: colorScheme.primary,
                                tooltip: 'SMS ${contact.name}',
                                onPressed: () {
                                  _openSmsForNumber(contact.phone);
                                },
                              ),
                            ],
                          ),
                        ],
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

  // ═════════════════════════════════════════════════════════════════════════
  // 2. Call Logs View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCallLogsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allLogs = widget.syncService.callLogs;

    final filteredLogs = allLogs.where((log) {
      if (_callFilter == 'Missed' && log.type != CallType.missed) return false;
      if (_callFilter == 'Incoming' && log.type != CallType.incoming) return false;
      if (_callFilter == 'Outgoing' && log.type != CallType.outgoing) return false;
      if (_callSearchQuery.isNotEmpty) {
        final q = _callSearchQuery.toLowerCase();
        return log.name.toLowerCase().contains(q) ||
            log.number.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Call Logs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredLogs.length} calls',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search and Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search call logs...',
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
                      _callSearchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ...['All', 'Missed', 'Incoming', 'Outgoing'].map((f) {
                final isSelected = _callFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: FilterChip(
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
              }),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Text(
                      'No call logs match filter.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredLogs.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final isMissed = log.type == CallType.missed;
                      final hasContactName = log.name.isNotEmpty && log.name != log.number;
                      final displayTitle = hasContactName
                          ? log.name
                          : (log.number.isNotEmpty ? log.number : 'Unknown');

                      IconData typeIcon;
                      Color typeColor;

                      switch (log.type) {
                        case CallType.missed:
                          typeIcon = Icons.call_missed;
                          typeColor = colorScheme.error;
                          break;
                        case CallType.incoming:
                          typeIcon = Icons.call_received;
                          typeColor = colorScheme.onSurfaceVariant;
                          break;
                        case CallType.outgoing:
                          typeIcon = Icons.call_made;
                          typeColor = colorScheme.onSurfaceVariant;
                          break;
                      }

                      final durationFormatted = _formatCallDuration(log.duration);

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 21,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          child: hasContactName && log.name.trim().isNotEmpty
                              ? Text(
                                  log.name.trim()[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 22,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        title: Text(
                          displayTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isMissed ? colorScheme.error : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Icon(typeIcon, color: typeColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatCallDate(log.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!isMissed && durationFormatted.isNotEmpty) ...[
                              Text(
                                ' • $durationFormatted',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (isMissed) ...[
                              Text(
                                ' • Missed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                            if (log.simSlot > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SIM ${log.simSlot}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.call_rounded, size: 22),
                          color: colorScheme.primary,
                          tooltip: 'Call $displayTitle',
                          onPressed: () {
                            widget.syncService.makeCall(log.number);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Placing call to $displayTitle (${log.number})...'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          widget.syncService.makeCall(log.number);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Placing call to $displayTitle (${log.number})...'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 3. Contacts View
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildContactsView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allContacts = widget.syncService.contacts;

    final filtered = allContacts.where((c) {
      if (_contactSearchQuery.isEmpty) return true;
      final q = _contactSearchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contacts',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '${allContacts.length} total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
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
                _contactSearchQuery = val;
              });
            },
          ),
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
                          : 'No contacts synced yet.',
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
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final contact = filtered[index];
                  return ListTile(
                    onTap: () {
                      widget.syncService.makeCall(contact.phone);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Placing call to ${contact.name} (${contact.phone})...'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        contact.initials,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${contact.phone} • ${contact.account ?? "Default"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            contact.isFavorite
                                ? Icons.star
                                : Icons.star_border,
                            color: contact.isFavorite
                                ? Colors.amber
                                : colorScheme.outline,
                            size: 20,
                          ),
                          tooltip: contact.isFavorite
                              ? 'Unmark favorite'
                              : 'Mark favorite',
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
                        IconButton(
                          icon: const Icon(Icons.call_outlined, size: 20),
                          tooltip: 'Call',
                          onPressed: () {
                            widget.syncService.makeCall(contact.phone);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Placing call to ${contact.name} (${contact.phone})...'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
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
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
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

    _selectedSmsThreadId ??= threads.first.id;
    final activeThread = threads.firstWhere(
      (t) => t.id == _selectedSmsThreadId,
      orElse: () => threads.first,
    );

    return Row(
      children: [
        // Thread list
        SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Messages',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment_rounded),
                      tooltip: 'New Message',
                      onPressed: () => _showNewMessageDialog(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: threads.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final isSelected = thread.id == activeThread.id;
                    final isUnread = thread.unreadCount > 0;
                    final hasName = thread.contactName.isNotEmpty &&
                        thread.contactName != thread.phone;
                    final displayName = hasName ? thread.contactName : thread.phone;

                    final bgColor = isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                        : (isUnread
                            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                            : Colors.transparent);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedSmsThreadId = thread.id;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isUnread
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              child: hasName && thread.contactName.trim().isNotEmpty
                                  ? Text(
                                      thread.contactName.trim()[0].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isUnread
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSurface,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 22,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                            ),
                            const SizedBox(width: 12),
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
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatConversationDate(thread.timestamp),
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
                                      if (isUnread) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colorScheme.primary,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        VerticalDivider(
          width: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),

        // Conversation detail view
        Expanded(
          child: Column(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              activeThread.contactName.trim().isNotEmpty
                                  ? activeThread.contactName.trim()[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeThread.contactName.isNotEmpty
                                    ? activeThread.contactName
                                    : activeThread.phone,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (activeThread.contactName.isNotEmpty &&
                                  activeThread.contactName != activeThread.phone)
                                Text(
                                  activeThread.phone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.call_rounded),
                      color: colorScheme.primary,
                      tooltip: 'Call ${activeThread.contactName}',
                      onPressed: () {
                        widget.syncService.makeCall(activeThread.phone);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Placing call to ${activeThread.contactName} (${activeThread.phone})...'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Messages list with mobile date headers & bubble styling
              Expanded(
                child: activeThread.messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // Build grouped list with date headers
                          final List<Widget> chatWidgets = [];
                          DateTime? lastDate;

                          for (final msg in activeThread.messages) {
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
                            chatWidgets.add(
                              Align(
                                alignment: isOut
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 380),
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
                                      Text(
                                        msg.body,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isOut
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTime(msg.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isOut
                                              ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                              : colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            children: chatWidgets,
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
                            widget.syncService.sendMessage(activeThread.id, trimmed);
                            _smsInputController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sending SMS to ${activeThread.contactName}...'),
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
                            activeThread.id,
                            trimmed,
                          );
                          _smsInputController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sending SMS to ${activeThread.contactName}...'),
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notes',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Note'),
                onPressed: _showAddNoteDialog,
              ),
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
                      return Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
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
                                      widget.syncService.deleteNote(note.id);
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
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

  String _formatCallDate(DateTime dt) {
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
}
