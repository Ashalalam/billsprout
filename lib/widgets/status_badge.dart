import 'package:flutter/material.dart';

/// A simple colored badge widget for displaying status labels.
/// Used across the app for subscription status, license status, access status, etc.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
