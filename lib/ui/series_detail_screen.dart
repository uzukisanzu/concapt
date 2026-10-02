import 'package:flutter/material.dart';

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.title, required this.values});

  final String title;
  final List<int> values;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)));
}
