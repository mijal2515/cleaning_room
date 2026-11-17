import 'package:flutter/material.dart';

/// A quiet editorial heading with room for the text to breathe.
class GentleHeading extends StatelessWidget {
  const GentleHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
  });
  final String eyebrow;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
              letterSpacing: -.7,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(description!, style: text.bodySmall?.copyWith(height: 1.7)),
          ],
        ],
      ),
    );
  }
}
