import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'overlay/overlay_app.dart';

void main() => runApp(const MaterialApp(home: SpikeHome()));

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

class SpikeHome extends StatelessWidget {
  const SpikeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay spike')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => FlutterOverlayWindow.requestPermission(),
            child: const Text('1. Grant overlay permission'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await SharedPreferencesAsync()
                  .setString('spike', 'written by main at ${DateTime.now()}');
              await FlutterOverlayWindow.showOverlay(
                width: 56,
                height: 56,
                enableDrag: true,
                alignment: OverlayAlignment.centerRight,
                overlayTitle: 'concapt spike',
                overlayContent: 'Bubble active',
              );
            },
            child: const Text('2. Show bubble'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => FlutterOverlayWindow.closeOverlay(),
            child: const Text('3. Close bubble'),
          ),
        ],
      ),
    );
  }
}
