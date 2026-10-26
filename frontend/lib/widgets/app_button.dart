import 'package:flutter/material.dart';

enum AppButtonType { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor =
        type == AppButtonType.outline || type == AppButtonType.text
        ? theme.colorScheme.primary
        : type == AppButtonType.secondary
        ? Colors.white
        : theme.colorScheme.onPrimary;

    final childContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );

    final buttonWidth = width ?? double.infinity;
    switch (type) {
      case AppButtonType.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(buttonWidth, height),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: childContent,
        );
      case AppButtonType.secondary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            minimumSize: Size(buttonWidth, height),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: childContent,
        );
      case AppButtonType.outline:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(buttonWidth, height),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: childContent,
        );
      case AppButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(buttonWidth, height),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: childContent,
        );
    }
  }
}
