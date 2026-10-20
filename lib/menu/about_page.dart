import 'package:flutter/material.dart';

/// Placeholder for the about screen.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nh Reader', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Unofficial nhentai.net client.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
