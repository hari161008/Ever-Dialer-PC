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
          child: Material(
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
        ),
      ],
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Calling ${contact.name}...'),
                                      duration: const Duration(seconds: 1),
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
                                  setState(() {
                                    _selectedIndex = 3;
                                  });
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
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      IconData typeIcon;
                      Color typeColor;
                      String typeDesc;

                      switch (log.type) {
                        case CallType.missed:
                          typeIcon = Icons.call_missed;
                          typeColor = colorScheme.error;
                          typeDesc = 'Missed call';
                          break;
                        case CallType.incoming:
                          typeIcon = Icons.call_received;
                          typeColor = const Color(0xFF4CAF50);
                          typeDesc = 'Incoming';
                          break;
                        case CallType.outgoing:
                          typeIcon = Icons.call_made;
                          typeColor = const Color(0xFF2196F3);
                          typeDesc = 'Outgoing';
                          break;
                      }

                      final durationText = log.duration == Duration.zero
                          ? typeDesc
                          : '${log.duration.inMinutes}m ${log.duration.inSeconds % 60}s';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        title: Text(
                          log.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${log.number} • $durationText • SIM ${log.simSlot}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimestamp(log.timestamp),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.call_outlined, size: 20),
                              tooltip: 'Call back',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Calling ${log.number}...'),
                                    duration: const Duration(seconds: 1),
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
                          icon: const Icon(Icons.call_outlined, size: 20),
                          tooltip: 'Call',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Calling ${contact.name}...'),
                                duration: const Duration(seconds: 1),
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
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'Messages',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: threads.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final isSelected = thread.id == activeThread.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Text(
                          thread.contactName.isNotEmpty
                              ? thread.contactName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      title: Text(
                        thread.contactName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        thread.snippet,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatTimestamp(thread.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSmsThreadId = thread.id;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        VerticalDivider(
          width: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),

        // Conversation detail view
        Expanded(
          child: Column(
            children: [
              // Chat Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        activeThread.contactName.isNotEmpty
                            ? activeThread.contactName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeThread.contactName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            activeThread.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeThread.messages.length,
                  itemBuilder: (context, index) {
                    final msg = activeThread.messages[index];
                    final isOutgoing = msg.isOutgoing;

                    return Align(
                      alignment: isOutgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 360),
                        decoration: BoxDecoration(
                          color: isOutgoing
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                            bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isOutgoing
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.body,
                              style: TextStyle(
                                color: isOutgoing
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimestamp(msg.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isOutgoing
                                    ? colorScheme.onPrimary.withValues(alpha: 0.7)
                                    : colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
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
                          hintText: 'Type a message...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (text) {
                          widget.syncService.sendMessage(activeThread.id, text);
                          _smsInputController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () {
                        widget.syncService.sendMessage(
                          activeThread.id,
                          _smsInputController.text,
                        );
                        _smsInputController.clear();
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

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
