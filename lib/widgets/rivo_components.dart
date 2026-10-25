import 'package:flutter/material.dart';

/// Material 3 Expressive Card with rounded corners matching mobile Rivo layout
class RivoExpressiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onClick;

  const RivoExpressiveCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.color,
    this.borderRadius = 22.0,
    this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.surfaceContainer;

    Widget content = Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClick,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }
}

/// Standard Rivo List Row matching mobile RivoListItem
class RivoListItem extends StatelessWidget {
  final String headline;
  final String? supporting;
  final IconData? leadingIcon;
  final Color? iconColor;
  final Color? iconContainerColor;
  final Widget? trailing;
  final VoidCallback? onClick;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const RivoListItem({
    super.key,
    required this.headline,
    this.supporting,
    this.leadingIcon,
    this.iconColor,
    this.iconContainerColor,
    this.trailing,
    this.onClick,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final containerColor = iconContainerColor ?? effectiveIconColor.withValues(alpha: 0.15);

    return InkWell(
      onTap: onClick,
      child: Padding(
        padding: compact ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0) : padding,
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  leadingIcon,
                  color: effectiveIconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  if (supporting != null && supporting!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      supporting!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onClick != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard Rivo Switch List Row
class RivoSwitchListItem extends StatelessWidget {
  final String headline;
  final String? supporting;
  final IconData? leadingIcon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const RivoSwitchListItem({
    super.key,
    required this.headline,
    this.supporting,
    this.leadingIcon,
    this.iconColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RivoListItem(
      headline: headline,
      supporting: supporting,
      leadingIcon: leadingIcon,
      iconColor: iconColor,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onClick: () => onChanged(!value),
    );
  }
}

/// Section label header matching mobile SectionLabel
class RivoSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const RivoSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(left: 14.0, bottom: 8.0, top: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Card divider matching mobile CardDivider
class RivoDivider extends StatelessWidget {
  const RivoDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }
}
