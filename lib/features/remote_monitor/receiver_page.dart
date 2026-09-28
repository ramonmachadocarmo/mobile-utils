import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'monitor_session.dart';
import 'monitor_source.dart';

/// Lado que assiste (celular do pai/mãe). Digita o código do transmissor,
/// mostra o vídeo recebido e alterna entre câmera frontal, traseira e tela.
class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key});

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage> {
  final _codeController = TextEditingController();
  bool _connecting = false;
  String? _error;
  MonitorSession? _session;

  Future<void> _connect() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Digite o código de 6 dígitos.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final session = MonitorSession.receiver(code);
      await session.start();
      if (!mounted) return;
      setState(() {
        _session = session;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _connecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _session?.dispose();
    if (mounted) setState(() => _session = null);
  }

  @override
  void dispose() {
    _session?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistir aparelho')),
      body: _session != null ? _viewer(_session!) : _codeForm(),
    );
  }

  Widget _codeForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Digite o código de 6 dígitos mostrado no aparelho transmissor.'),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _connecting ? null : _connect,
          icon: _connecting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(_connecting ? 'Conectando…' : 'Conectar'),
        ),
      ],
    );
  }

  Widget _viewer(MonitorSession session) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: ValueListenableBuilder(
              valueListenable: session.state,
              builder: (context, state, child) {
                if (state != MonitorState.live) {
                  return Center(
                    child: Text(
                      switch (state) {
                        MonitorState.waitingPeer => 'Aguardando o transmissor…',
                        MonitorState.connecting => 'Conectando…',
                        MonitorState.failed => 'Falha na conexão.',
                        MonitorState.ended => 'Transmissão encerrada.',
                        MonitorState.live => '',
                      },
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return RTCVideoView(session.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ValueListenableBuilder(
                valueListenable: session.source,
                builder: (context, current, child) => Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in MonitorSource.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: s == current,
                        onSelected: (_) => session.requestSource(s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.stop),
                label: const Text('Encerrar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
