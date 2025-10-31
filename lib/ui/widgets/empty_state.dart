import 'package:flutter/material.dart';

const double kFilterRowHeight = 44.0;

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String ctaText;
  final Color badgeColor;
  final VoidCallback onPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    required this.ctaText,
    required this.badgeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: badgeColor),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(ctaText),
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
