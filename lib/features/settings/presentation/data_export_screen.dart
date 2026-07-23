import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DataExportScreen extends StatelessWidget {
  const DataExportScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Data'),
        actions: [
          IconButton(
            tooltip: 'Copy to clipboard',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pretty));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard.')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          pretty,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
