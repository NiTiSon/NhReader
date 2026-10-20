import 'package:flutter/material.dart';

/// Placeholder for the options screen.
class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: const Center(child: Text('No options yet')),
    );
  }
}
