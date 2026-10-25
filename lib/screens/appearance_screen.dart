import 'package:flutter/material.dart';
import '../services/appearance_preferences.dart';
import '../services/system_service.dart';
import '../services/sync_service.dart';
import '../widgets/rivo_components.dart';
import '../widgets/window_header_actions.dart';

class AppearanceScreen extends StatefulWidget {
  final AppearancePreferences appearance;
  final bool isPane;
  final SystemService? systemService;
  final PcSyncService? syncService;

  const AppearanceScreen({
    super.key,
    required this.appearance,
    this.isPane = false,
    this.systemService,
    this.syncService,
  });

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late TextEditingController _hexController;
  bool _hexError = false;

  static const List<Color> _presetColors = [
    Color(0xFF6750A4), Color(0xFF0061A4), Color(0xFF006A60), Color(0xFF436916),
    Color(0xFF984061), Color(0xFF006874), Color(0xFF705D00), Color(0xFFBF0031),
    Color(0xFFE91E63), Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFFFFC107), Color(0xFF009688), Color(0xFF2196F3), Color(0xFF4CAF50),
    Color(0xFF3F51B5), Color(0xFFE53935),
  ];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _colorToHex(widget.appearance.customPrimaryColor));
  }

  @override
  void didUpdateWidget(covariant AppearanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final curHex = _colorToHex(widget.appearance.customPrimaryColor);
    if (_hexController.text != curHex) {
      _hexController.text = curHex;
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  Color? _parseHex(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  void _applyHex() {
    final parsed = _parseHex(_hexController.text);
    if (parsed != null) {
      setState(() => _hexError = false);
      widget.appearance.setCustomPrimaryColor(parsed);
    } else {
      setState(() => _hexError = true);
    }
  }

  void _showColorPickerDialog() {
    Color selectedColor = widget.appearance.customPrimaryColor;
    HSVColor hsv = HSVColor.fromColor(selectedColor);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentColor = hsv.toColor();
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Text('Pick Custom Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '#${_colorToHex(currentColor)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Hue Slider
                    Row(
                      children: [
                        const Text('Hue', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: hsv.hue,
                            min: 0,
                            max: 360,
                            onChanged: (val) {
                              setDialogState(() {
                                hsv = hsv.withHue(val);
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Saturation Slider
                    Row(
                      children: [
                        const Text('Sat', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Slider(
                            value: hsv.saturation,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (val) {
                              setDialogState(() {
                                hsv = hsv.withSaturation(val);
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Brightness Slider
                    Row(
                      children: [
                        const Text('Val', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Slider(
                            value: hsv.value,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (val) {
                              setDialogState(() {
                                hsv = hsv.withValue(val);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.appearance.setCustomPrimaryColor(hsv.toColor());
                    _hexController.text = _colorToHex(hsv.toColor());
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFontPickerDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Select Font'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppearancePreferences.availableFonts.length,
              itemBuilder: (context, index) {
                final font = AppearancePreferences.availableFonts[index];
                final family = font['family']!.isEmpty ? null : font['family']!;
                final isSelected = widget.appearance.customFontFamily == family;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    widget.appearance.setCustomFontFamily(family);
                    Navigator.pop(dialogCtx);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                font['name']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: family,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'The quick brown fox jumps over the lazy dog',
                                style: TextStyle(
                                  fontFamily: family,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appearance,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final app = widget.appearance;

        final content = SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. App Theme ────────────────────────────
              const RivoSectionHeader(title: 'App Theme'),
              RivoExpressiveCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildModePill('auto', 'Auto', app),
                        _buildModePill('light', 'Light', app),
                        _buildModePill('dark', 'Dark', app),
                        _buildModePill('white', 'White', app),
                        _buildModePill('black', 'Black', app),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Display & Font Size Card ─────────────────
              RivoExpressiveCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Display & Font Size',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Reset scale',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            app.resetDisplayScale();
                            app.resetFontScale();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Display Scaling Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Display Scaling',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(app.displayScale * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: app.displayScale,
                      min: 0.70,
                      max: 1.40,
                      divisions: 14,
                      onChanged: (val) => app.setDisplayScale(val),
                    ),

                    const SizedBox(height: 8),

                    // Font Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Font Size',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(app.fontScale * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: app.fontScale,
                      min: 0.70,
                      max: 1.40,
                      divisions: 14,
                      onChanged: (val) => app.setFontScale(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Background Container (Blur & Dimness) ───
              RivoExpressiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Background',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Reset background',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            app.resetBackgroundSettings();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Blur for all pages Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Blur for all pages',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          app.backgroundBlur == 0
                              ? 'No blur'
                              : '${app.backgroundBlur.toStringAsFixed(1)} px',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: app.backgroundBlur,
                      min: 0.0,
                      max: 30.0,
                      divisions: 30,
                      onChanged: (val) => app.setBackgroundBlur(val),
                    ),

                    const SizedBox(height: 8),

                    // Window Transparency Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Window Transparency',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(app.windowTransparency * 100).round()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: app.windowTransparency,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (val) => app.setWindowTransparency(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Theme Colors ─────────────────────────
              const RivoSectionHeader(title: 'Theme Colors'),
              RivoExpressiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RivoSwitchListItem(
                      headline: 'Dynamic Colors',
                      supporting: 'Sync colors from connected phone or system wallpaper',
                      leadingIcon: Icons.auto_awesome_outlined,
                      iconColor: const Color(0xFFE91E63),
                      value: app.dynamicColors,
                      onChanged: (val) => app.setDynamicColors(val),
                    ),

                    if (!app.dynamicColors) ...[
                      const RivoDivider(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Color',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Preset colors
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _presetColors.map((color) {
                                final isSelected = app.customPrimaryColor.toARGB32() == color.toARGB32();
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    app.setCustomPrimaryColor(color);
                                    _hexController.text = _colorToHex(color);
                                  },
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: colorScheme.onSurface,
                                              width: 3,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 14),

                            // Interactive picker button
                            OutlinedButton.icon(
                              onPressed: _showColorPickerDialog,
                              icon: const Icon(Icons.colorize_outlined, size: 18),
                              label: Row(
                                children: [
                                  const Text('Pick Custom Color (Interactive)'),
                                  const Spacer(),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: app.customPrimaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.outline,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Hex Input
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _parseHex(_hexController.text) ?? Colors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.outlineVariant),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _hexController,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      prefixText: '#',
                                      labelText: 'Hex Color',
                                      counterText: '',
                                      errorText: _hexError ? 'Invalid hex code' : null,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_hexError) setState(() => _hexError = false);
                                    },
                                    onSubmitted: (_) => _applyHex(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _applyHex,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const RivoDivider(),

                    // Saturated Colors Switch
                    RivoSwitchListItem(
                      headline: 'Saturated Colors',
                      supporting: 'Apply rich saturated colors behind containers',
                      leadingIcon: Icons.invert_colors_outlined,
                      iconColor: const Color(0xFFFF9800),
                      value: app.saturatedColors,
                      onChanged: (val) => app.setSaturatedColors(val),
                    ),

                    if (app.saturatedColors) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTargetOption('container', 'Container', app),
                              ),
                              Expanded(
                                child: _buildTargetOption('background', 'Background', app),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Fonts ────────────────────────────────
              const RivoSectionHeader(title: 'Fonts'),
              RivoExpressiveCard(
                child: RivoListItem(
                  headline: 'Fonts',
                  supporting: app.currentFontDisplayName,
                  leadingIcon: Icons.text_format_outlined,
                  iconColor: const Color(0xFF9C27B0),
                  onClick: _showFontPickerDialog,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );

        if (widget.isPane) {
          return content;
        }

        return Scaffold(
          appBar: AppBar(
            flexibleSpace: WindowDragArea(
              onStartDrag: () => widget.systemService?.startWindowDrag(),
              onDoubleTap: () => widget.systemService?.toggleMaximizeWindow(),
              child: const SizedBox.expand(),
            ),
            title: const Text('Interface'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              WindowHeaderActions(
                syncService: widget.syncService,
                systemService: widget.systemService,
              ),
            ],
          ),
          body: content,
        );
      },
    );
  }

  Widget _buildModePill(String key, String label, AppearancePreferences app) {
    final selected = app.colorMode == key;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(50),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => app.setColorMode(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetOption(String key, String label, AppearancePreferences app) {
    final isSelected = app.saturatedTarget == key;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () => app.setSaturatedTarget(key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
