import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(home: SpikeHome()));

@pragma('vm:entry-point')
void overlayMain() => runApp(
      const MaterialApp(debugShowCheckedModeBanner: false, home: SpikeOverlay()),
    );

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

class SpikeOverlay extends StatefulWidget {
  const SpikeOverlay({super.key});

  @override
  State<SpikeOverlay> createState() => _SpikeOverlayState();
}

class _SpikeOverlayState extends State<SpikeOverlay> {
  bool _expanded = false;
  String _prefs = '(loading)';

  @override
  void initState() {
    super.initState();
    SharedPreferencesAsync().getString('spike').then((value) {
      if (mounted) setState(() => _prefs = value ?? '(null)');
    });
  }

  Future<void> _expand() async {
    await FlutterOverlayWindow.resizeOverlay(340, 400, true);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    setState(() => _expanded = true);
  }

  Future<void> _collapse() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(56, 56, true);
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Material(
      type: MaterialType.transparency,
      child: _expanded
          ? Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('prefs: $_prefs'),
                    Text(
                      'logical size: ${size.width.toStringAsFixed(0)} x '
                      '${size.height.toStringAsFixed(0)}, dpr ${dpr.toStringAsFixed(2)}',
                    ),
                    const TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Type a number'),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: _collapse, child: const Text('Collapse')),
                        TextButton(
                          onPressed: () => FlutterOverlayWindow.closeOverlay(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : GestureDetector(
              onTap: _expand,
              child: const CircleAvatar(radius: 28, child: Icon(Icons.camera_alt)),
            ),
    );
  }
}
