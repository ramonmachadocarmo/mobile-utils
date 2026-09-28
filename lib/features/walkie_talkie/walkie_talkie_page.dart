import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../remote_monitor/monitor_firebase.dart';
import 'walkie_session.dart';

/// Walkie-talkie: chamada de duas vias com câmera e microfone. Um aparelho cria
/// a sala e mostra um código; o outro entra com o código.
class WalkieTalkiePage extends StatefulWidget {
  const WalkieTalkiePage({super.key});

  @override
  State<WalkieTalkiePage> createState() => _WalkieTalkiePageState();
}

class _WalkieTalkiePageState extends State<WalkieTalkiePage> {
  final _codeController = TextEditingController();
  bool _busy = false;
  bool _pushToTalk = true;
  String? _error;
  String? _code;
  WalkieSession? _session;

  static String _generateCode() {
    final rnd = Random.secure();
    return List.generate(6, (_) => rnd.nextInt(10)).join();
  }

  Future<bool> _ensurePermissions() async {
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      setState(() => _error = 'Permita câmera e microfone.');
      return false;
    }
    return true;
  }

  Future<void> _start(WalkieSession session, String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _ensurePermissions()) {
        setState(() => _busy = false);
        return;
      }
      if (!await ensureFirebaseReady()) throw 'Firebase não configurado.';
      await session.start(pushToTalk: _pushToTalk);
      if (!mounted) return;
      setState(() {
        _session = session;
        _code = code;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  void _createRoom() {
    final code = _generateCode();
    _start(WalkieSession.create(code), code);
  }

  Future<void> _hangUp() async {
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
      appBar: AppBar(title: const Text('Walkie-talkie')),
      body: _session != null ? _callView(_session!) : _lobby(),
    );
  }

  Widget _lobby() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Chamada de duas vias com câmera e microfone entre dois aparelhos.'),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pushToTalk,
          onChanged: (v) => setState(() => _pushToTalk = v),
          title: const Text('Modo walkie-talkie (segure para falar)'),
          subtitle: const Text('Desligado, o microfone fica sempre aberto, como uma chamada.'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _createRoom,
          icon: const Icon(Icons.add_call),
          label: const Text('Criar sala'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Ou entre numa sala existente:'),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _busy
              ? null
              : () {
                  final code = _codeController.text.trim();
                  if (code.length != 6) {
                    setState(() => _error = 'Digite o código de 6 dígitos.');
                    return;
                  }
                  _start(WalkieSession.join(code), code);
                },
          icon: const Icon(Icons.login),
          label: const Text('Entrar'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _callView(WalkieSession session) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: ValueListenableBuilder(
                    valueListenable: session.state,
                    builder: (context, state, child) {
                      if (state != CallState.live) {
                        return Center(
                          child: Text(
                            switch (state) {
                              CallState.waitingPeer => _code != null
                                  ? 'Aguardando alguém entrar…\nCódigo: $_code'
                                  : 'Aguardando…',
                              CallState.connecting => 'Conectando…',
                              CallState.failed => 'Falha na conexão.',
                              CallState.ended => 'Chamada encerrada.',
                              CallState.live => '',
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                        );
                      }
                      return RTCVideoView(
                        session.remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      );
                    },
                  ),
                ),
              ),
              // Preview da própria câmera no canto.
              Positioned(
                right: 12,
                top: 12,
                width: 110,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(session.localRenderer, mirror: true),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_code != null) Text('Código da sala: $_code'),
              const SizedBox(height: 12),
              _micControl(session),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: session.switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                    label: const Text('Virar câmera'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: _hangUp,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Encerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _micControl(WalkieSession session) {
    if (_pushToTalk) {
      return ValueListenableBuilder(
        valueListenable: session.micEnabled,
        builder: (context, talking, child) => GestureDetector(
          onTapDown: (_) => session.setMic(true),
          onTapUp: (_) => session.setMic(false),
          onTapCancel: () => session.setMic(false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: talking
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                talking ? 'Falando…' : 'Segure para falar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: talking ? Theme.of(context).colorScheme.onPrimary : null,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ValueListenableBuilder(
      valueListenable: session.micEnabled,
      builder: (context, on, child) => OutlinedButton.icon(
        onPressed: session.toggleMic,
        icon: Icon(on ? Icons.mic : Icons.mic_off),
        label: Text(on ? 'Microfone ligado' : 'Microfone desligado'),
      ),
    );
  }
}
