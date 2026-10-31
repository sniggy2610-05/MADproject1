import 'package:flutter/material.dart';

import '../theme/manor_theme.dart';

class ManorButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const ManorButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward),
        label: Text(
          text,
          style: const TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ManorColors.burgundy,
          foregroundColor: ManorColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class ManorSectionTitle extends StatelessWidget {
  final String title;

  const ManorSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: ManorColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}
