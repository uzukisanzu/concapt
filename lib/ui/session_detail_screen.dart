import 'package:flutter/material.dart';

import '../data/repository.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.repository, required this.sessionId});

  final Repository repository;
  final int sessionId;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
