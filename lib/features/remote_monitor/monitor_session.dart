import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'monitor_signaling.dart';
import 'monitor_source.dart';

/// Estado de alto nível da conexão, para a UI mostrar.
enum MonitorState { connecting, waitingPeer, live, ended, failed }

/// Sessão WebRTC de um dos lados do monitoramento.
///
/// O transmissor envia sempre o microfone e uma track de vídeo, que o receptor
/// alterna entre câmera frontal, traseira e tela por comandos no canal de dados.
/// A conexão é ponto a ponto; o Firestore só faz a sinalização inicial.
class MonitorSession {
  MonitorSession._({required this.code, required this.isTransmitter, MonitorSource? source})
    : _signaling = MonitorSignaling(code, isTransmitter: isTransmitter),
      source = ValueNotifier(source ?? MonitorSource.frontCamera);

  factory MonitorSession.transmitter(String code, MonitorSource initial) =>
      MonitorSession._(code: code, isTransmitter: true, source: initial);

  factory MonitorSession.receiver(String code) =>
      MonitorSession._(code: code, isTransmitter: false);

  final String code;
  final bool isTransmitter;
  final MonitorSignaling _signaling;

  /// Servidores STUN públicos do Google. Para casos de NAT mais fechado é
  /// preciso somar um servidor TURN (veja o README).
  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? _pc;
  RTCDataChannel? _control;
  RTCRtpSender? _videoSender;
  MediaStream? _localStream; // mic + vídeo atual (transmissor)
  MediaStreamTrack? _audioTrack;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  /// Microfone ligado (transmissor). Desligar mantém a track, só silencia.
  final micEnabled = ValueNotifier<bool>(true);

  /// Fonte de vídeo em uso. No transmissor, muda ao receber um comando; no
  /// receptor, reflete o que o transmissor confirmou.
  final ValueNotifier<MonitorSource> source;
  final state = ValueNotifier<MonitorState>(MonitorState.connecting);

  final localRenderer = RTCVideoRenderer(); // preview no transmissor
  final remoteRenderer = RTCVideoRenderer(); // vídeo recebido no receptor

  Future<void> start() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _pc = await createPeerConnection(_iceServers);

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) _signaling.sendCandidate(c);
    };
    _pc!.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        state.value = MonitorState.live;
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        state.value = MonitorState.failed;
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (state.value != MonitorState.ended) state.value = MonitorState.ended;
      }
    };
    _pc!.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    if (isTransmitter) {
      await _startTransmitter();
    } else {
      await _startReceiver();
    }

    _subscriptions.add(_signaling.watchRemoteCandidates().listen(_pc!.addCandidate));
  }

  // ---- Transmissor ----

  Future<void> _startTransmitter() async {
    _control = await _pc!.createDataChannel('control', RTCDataChannelInit());
    _control!.onMessage = _onControlMessage;

    _localStream = await _captureFor(source.value, withAudio: true);
    localRenderer.srcObject = _localStream;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) _audioTrack = audioTracks.first;
    for (final track in audioTracks) {
      await _pc!.addTrack(track, _localStream!);
    }
    final videoTrack = _localStream!.getVideoTracks().first;
    _videoSender = await _pc!.addTrack(videoTrack, _localStream!);

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _signaling.sendOffer(offer);
    state.value = MonitorState.waitingPeer;

    _subscriptions.add(_signaling.watchAnswer().listen((answer) async {
      await _pc!.setRemoteDescription(answer);
    }));
  }

  /// Troca a track de vídeo enviada sem refazer a negociação.
  Future<void> _switchSource(MonitorSource next) async {
    if (next == source.value || _videoSender == null) return;
    final current = source.value;
    final videoTracks = _localStream!.getVideoTracks();

    // Câmera → câmera: gira a câmera na própria track (não recaptura, o que
    // evitava o travamento ao ir para a traseira).
    if (current != MonitorSource.screen &&
        next != MonitorSource.screen &&
        videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
      source.value = next;
      _sendControl({'ack': next.id});
      return;
    }

    // Envolvendo a tela: precisa de uma captura nova (getDisplayMedia/getUserMedia).
    final newStream = await _captureFor(next, withAudio: false);
    final newVideo = newStream.getVideoTracks().first;
    await _videoSender!.replaceTrack(newVideo);

    for (final old in videoTracks) {
      await old.stop();
      _localStream!.removeTrack(old);
    }
    _localStream!.addTrack(newVideo);
    localRenderer.srcObject = _localStream;
    source.value = next;
    _sendControl({'ack': next.id});
  }

  /// Liga/desliga o microfone (transmissor). Só silencia; a track continua.
  void toggleMic() {
    final track = _audioTrack;
    if (track == null) return;
    final on = !micEnabled.value;
    track.enabled = on;
    micEnabled.value = on;
  }

  Future<MediaStream> _captureFor(MonitorSource s, {required bool withAudio}) {
    if (s == MonitorSource.screen) {
      return navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
    }
    return navigator.mediaDevices.getUserMedia({
      'audio': withAudio,
      'video': {'facingMode': s == MonitorSource.frontCamera ? 'user' : 'environment'},
    });
  }

  // ---- Receptor ----

  Future<void> _startReceiver() async {
    _pc!.onDataChannel = (channel) {
      _control = channel;
      channel.onMessage = _onControlMessage;
    };

    state.value = MonitorState.waitingPeer;
    final offer = await _signaling.waitForOffer();
    await _pc!.setRemoteDescription(offer);
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await _signaling.sendAnswer(answer);
    state.value = MonitorState.connecting;
  }

  /// Receptor pede a troca de fonte ao transmissor.
  void requestSource(MonitorSource next) => _sendControl({'source': next.id});

  // ---- Canal de controle ----

  void _sendControl(Map<String, dynamic> msg) =>
      _control?.send(RTCDataChannelMessage(jsonEncode(msg)));

  void _onControlMessage(RTCDataChannelMessage message) {
    final data = jsonDecode(message.text) as Map<String, dynamic>;
    if (isTransmitter && data['source'] != null) {
      _switchSource(MonitorSource.fromId(data['source'] as String));
    } else if (!isTransmitter && data['ack'] != null) {
      source.value = MonitorSource.fromId(data['ack'] as String);
    }
  }

  Future<void> dispose() async {
    state.value = MonitorState.ended;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _control?.close();
    for (final track in _localStream?.getTracks() ?? const []) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    await _signaling.dispose();
  }
}
