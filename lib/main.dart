import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'models/stream_settings.dart';
import 'services/permission_service.dart';
import 'services/screen_share_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LanScreenShareApp());
}

class LanScreenShareApp extends StatelessWidget {
  const LanScreenShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LAN Screen Share',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B6CFF), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0A1020),
        useMaterial3: true,
      ),
      home: const StreamHomePage(),
    );
  }
}

class StreamHomePage extends StatefulWidget {
  const StreamHomePage({super.key});

  @override
  State<StreamHomePage> createState() => _StreamHomePageState();
}

class _StreamHomePageState extends State<StreamHomePage> {
  final _permissionService = PermissionService();
  final _service = ScreenShareService();

  StreamSettings _settings = StreamSettings.defaults;
  bool _isStarting = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _startStreaming() async {
    setState(() => _isStarting = true);
    try {
      final hasPermissions = await _permissionService.requestBroadcastPermissions();
      if (!hasPermissions) {
        _showSnack('Permissions denied. Please allow microphone and nearby devices.');
        return;
      }
      if (!_settings.crop.isValid) {
        _showSnack('Invalid crop values. Keep combined opposite edges under 99%.');
        return;
      }
      await _service.start(_settings);
      setState(() => _isStreaming = true);
    } catch (e) {
      _showSnack('Failed to start stream: $e');
    } finally {
      setState(() => _isStarting = false);
    }
  }

  Future<void> _stopStreaming() async {
    await _service.stop();
    setState(() => _isStreaming = false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Screen Share Pro'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _glassCard(
                child: Column(
                  children: [
                    const Text('Live Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: _settings.aspectPreset.ratio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: RTCVideoView(
                          _service.localRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                          mirror: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsPanel(
                settings: _settings,
                onChanged: (updated) => setState(() => _settings = updated),
              ),
              const SizedBox(height: 16),
              _glassCard(
                child: ValueListenableBuilder<String>(
                  valueListenable: _service.status,
                  builder: (context, status, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: $status', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String?>(
                          valueListenable: _service.localUrl,
                          builder: (context, url, _) {
                            final hasUrl = url != null;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  hasUrl
                                      ? 'Viewer signaling URL (same Wi-Fi): $url'
                                      : 'Start streaming to generate a local signaling URL.',
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: hasUrl
                                      ? () {
                                          Clipboard.setData(ClipboardData(text: url));
                                          _showSnack('Signaling URL copied');
                                        }
                                      : null,
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy URL'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isStarting
                    ? null
                    : _isStreaming
                        ? _stopStreaming
                        : _startStreaming,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: Icon(_isStreaming ? Icons.stop_circle_outlined : Icons.wifi_tethering),
                label: Text(
                  _isStarting ? 'Starting...' : _isStreaming ? 'Stop Stream' : 'Start Ultra-Low-Latency Stream',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131C34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.settings, required this.onChanged});

  final StreamSettings settings;
  final ValueChanged<StreamSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131C34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stream Tuning', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SectionTitle('Bitrate: ${settings.bitrateKbps} kbps'),
          Slider(
            value: settings.bitrateKbps.toDouble(),
            min: 1000,
            max: 20000,
            divisions: 38,
            label: '${settings.bitrateKbps} kbps',
            onChanged: (value) => onChanged(settings.copyWith(bitrateKbps: value.round())),
          ),
          _SectionTitle('Resolution: ${settings.resolutionPercent}%'),
          Slider(
            value: settings.resolutionPercent.toDouble(),
            min: 25,
            max: 100,
            divisions: 15,
            label: '${settings.resolutionPercent}%',
            onChanged: (value) => onChanged(settings.copyWith(resolutionPercent: value.round())),
          ),
          _SectionTitle('Audio volume: ${(settings.audioVolume * 100).round()}%'),
          Slider(
            value: settings.audioVolume,
            min: 0,
            max: 1,
            divisions: 20,
            label: '${(settings.audioVolume * 100).round()}%',
            onChanged: (value) => onChanged(settings.copyWith(audioVolume: value)),
          ),
          _SectionTitle('Aspect ratio preset'),
          DropdownButtonFormField<AspectPreset>(
            value: settings.aspectPreset,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: AspectPreset.presets
                .map((preset) => DropdownMenuItem(value: preset, child: Text(preset.label)))
                .toList(),
            onChanged: (preset) {
              if (preset != null) {
                onChanged(settings.copyWith(aspectPreset: preset));
              }
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Crop before stream (for fitting into 16:9 without black bars)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _CropSlider(
            label: 'Top',
            value: settings.crop.topPercent,
            onChanged: (v) => onChanged(settings.copyWith(crop: settings.crop.copyWith(topPercent: v))),
          ),
          _CropSlider(
            label: 'Bottom',
            value: settings.crop.bottomPercent,
            onChanged: (v) => onChanged(settings.copyWith(crop: settings.crop.copyWith(bottomPercent: v))),
          ),
          _CropSlider(
            label: 'Left',
            value: settings.crop.leftPercent,
            onChanged: (v) => onChanged(settings.copyWith(crop: settings.crop.copyWith(leftPercent: v))),
          ),
          _CropSlider(
            label: 'Right',
            value: settings.crop.rightPercent,
            onChanged: (v) => onChanged(settings.copyWith(crop: settings.crop.copyWith(rightPercent: v))),
          ),
          const SizedBox(height: 6),
          Text('Crop summary: ${settings.crop}', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _CropSlider extends StatelessWidget {
  const _CropSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}%'),
        Slider(
          value: value,
          min: 0,
          max: 40,
          divisions: 80,
          label: '${value.toStringAsFixed(1)}%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
      ),
    );
  }
}
