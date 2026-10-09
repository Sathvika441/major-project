import 'package:flutter/material.dart';

class AssetGlassPanel extends StatelessWidget {
  final String imagePath;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Alignment imageAlignment;

  const AssetGlassPanel({
    super.key,
    required this.imagePath,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.imageAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: primary.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.13),
            blurRadius: 26,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                alignment: imageAlignment,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE6000805),
                      Color(0xA6000805),
                      Color(0x50000805),
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
