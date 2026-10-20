// =============================================================================
// STAGE 0A SPIKE — THROWAWAY UI
//
// Not architecture. This screen exists only to prove the Swift -> Dart handoff
// works and to read back what the App Intent wrote. Stage 0B creates the real
// four-layer skeleton; this file is deleted then.
// =============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SpikeApp());

const _channel = MethodChannel('soreva/spike');

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Soreva Spike',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const SpikeHome(),
      );
}

class SpikeHome extends StatefulWidget {
  const SpikeHome({super.key});

  @override
  State<SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<SpikeHome> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _captures = [];
  String _inboxPath = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Drain on resume — captures happen while the app is backgrounded.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _channel.invokeListMethod<String>('listCaptures') ?? [];
      final path = await _channel.invokeMethod<String>('inboxPath') ?? '';
      setState(() {
        _captures = raw
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList(growable: false);
        _inboxPath = path;
        _error = null;
      });
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    }
  }

  Future<void> _clear() async {
    await _channel.invokeMethod('clearCaptures');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage 0A — Capture Spike'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload inbox',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _captures.isEmpty ? null : _clear,
            tooltip: 'Clear inbox',
          ),
        ],
      ),
      body: _error != null
          ? _Message(
              icon: Icons.error_outline,
              title: 'Channel error',
              body: _error!,
            )
          : _captures.isEmpty
              ? _Message(
                  icon: Icons.inbox_outlined,
                  title: 'Inbox empty',
                  body: 'Double-tap the back of the phone over a receipt '
                      'screen, then return here and pull to refresh.\n\n'
                      '$_inboxPath',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _captures.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CaptureCard(_captures[i]),
                  ),
                ),
    );
  }
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard(this.c);
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final app = c['foreground_app_name'];
    final attribution = c['attribution_source'] ?? 'unavailable';
    final text = (c['raw_text'] as String?) ?? '';
    final err = c['spike_error'];
    final langs =
        (c['spike_vision_supported_languages'] as List?)?.cast<String>() ?? [];
    final hasIndonesian = langs.any((l) => l.toLowerCase().startsWith('id'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  err == null ? Icons.check_circle : Icons.error,
                  size: 18,
                  color: err == null ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app == null ? 'app: NOT REPORTED' : 'app: $app',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Row('attribution', attribution.toString()),
            _Row('ocr', '${text.length} chars · '
                '${c['ocr_block_count']} blocks · '
                'conf ${(c['ocr_mean_confidence'] as num?)?.toStringAsFixed(2)}'),
            _Row('timing', '${c['spike_elapsed_ms']}ms · '
                '${((c['spike_image_bytes'] as num?) ?? 0) ~/ 1024}KB'),
            _Row('vision id-ID', hasIndonesian ? 'SUPPORTED' : 'not supported'),
            if (err != null) _Row('error', err.toString()),
            if (text.isNotEmpty) ...[
              const Divider(height: 20),
              SelectableText(
                text,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(k,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
}
