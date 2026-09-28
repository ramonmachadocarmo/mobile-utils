import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'monitor_session.dart';
import 'monitor_source.dart';

/// Lado transmitido (celular dos filhos). Mostra um consentimento antes de
/// começar e, durante a transmissão, mantém um aviso permanente na tela e na
/// notificação — o sinal de que está sendo monitorado.
class TransmitterPage extends StatefulWidget {
  const TransmitterPage({super.key});

  @override
  State<TransmitterPage> createState() => _TransmitterPageState();
}

class _TransmitterPageState extends State<TransmitterPage> {
  bool _agreed = false;
  bool _starting = false;
  String? _error;
  MonitorSession? _session;
  late final String _code = _generateCode();

  static String _generateCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => rnd.nextInt(10)).join();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted) {
        throw 'Permita câmera e microfone para transmitir.';
      }
      // Android 13+: sem esta permissão o aviso permanente não aparece.
      await Permission.notification.request();
      await _startForegroundNotice();
      final session = MonitorSession.transmitter(_code, MonitorSource.frontCamera);
      await session.start();
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
      });
    } catch (e) {
      await FlutterForegroundTask.stopService();
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _starting = false;
      });
    }
  }

  /// Notificação permanente enquanto transmite (obrigatória no Android para
  /// capturar em segundo plano e, aqui, também o indicador de transparência).
  Future<void> _startForegroundNotice() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'monitor_transmit',
        channelName: 'Monitoramento ativo',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      notificationTitle: 'Monitoramento ativo',
      notificationText: 'Câmera, microfone e tela estão sendo transmitidos.',
    );
  }

  Future<void> _stop() async {
    await _session?.dispose();
    await FlutterForegroundTask.stopService();
    if (mounted) setState(() => _session = null);
  }

  @override
  void dispose() {
    _session?.dispose();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transmitir este aparelho')),
      body: _session != null ? _liveView() : _consentView(),
    );
  }

  Widget _consentView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ao iniciar, este aparelho passa a transmitir câmera, microfone e, se '
          'você permitir, a tela. Um aviso fica visível enquanto durar.',
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          title: const Text('A pessoa que usa este aparelho sabe e concorda com o monitoramento.'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _agreed && !_starting ? _start : null,
          icon: _starting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cast_connected),
          label: Text(_starting ? 'Iniciando…' : 'Iniciar transmissão'),
        ),
      ],
    );
  }

  Widget _liveView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.errorContainer,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: scheme.error, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TRANSMITINDO — câmera, microfone e tela visíveis para o outro aparelho',
                  style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: RTCVideoView(_session!.localRenderer, mirror: true)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Código: $_code', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Digite este código no aparelho que vai assistir.'),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: _session!.source,
                builder: (context, source, child) => Text('Enviando: ${source.label}'),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: _session!.micEnabled,
                builder: (context, on, child) => OutlinedButton.icon(
                  onPressed: _session!.toggleMic,
                  icon: Icon(on ? Icons.mic : Icons.mic_off),
                  label: Text(on ? 'Microfone ligado' : 'Microfone desligado'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: const Text('Parar transmissão'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
