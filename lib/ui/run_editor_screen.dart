import 'package:flutter/material.dart';

import '../core/models.dart';
import 'run_form.dart';

/// Edits a saved run; pops with the new [RunScores], or null when cancelled.
class RunEditorScreen extends StatelessWidget {
  const RunEditorScreen({super.key, required this.title, required this.initial});

  final String title;
  final RunDraft initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RunForm(
        initial: initial,
        onSave: (scores) => Navigator.pop(context, scores),
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
