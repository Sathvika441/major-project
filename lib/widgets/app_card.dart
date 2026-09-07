import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    return Container(
      margin: margin,
      child: Card(
        margin: EdgeInsets.zero,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: cardContent,
              )
            : cardContent,
      ),
    );
  }
}
