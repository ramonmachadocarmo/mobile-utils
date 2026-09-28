import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../remote_monitor/monitor_signaling.dart';

/// Estado da chamada, para a UI.
enum CallState { connecting, waitingPeer, live, ended, failed }

/// Chamada de duas vias (câmera + microfone) entre dois aparelhos. É simétrica:
/// cada lado envia a própria câmera/mic e recebe a do outro. Reaproveita a
/// sinalização do monitoramento, numa coleção separada (`walkie_sessions`).
///
/// Quem cria a sala é o "caller" (faz a oferta); quem entra é o "callee".
class WalkieSession {
  WalkieSession._({required this.code, required this.isCaller})
    : _signaling = MonitorSignaling(
        code,
        isTransmitter: isCaller,
        collection: 'walkie_sessions',
      );

  factory WalkieSession.create(String code) => WalkieSession._(code: code, isCaller: true);
  factory WalkieSession.join(String code) => WalkieSession._(code: code, isCaller: false);

  final String code;
  final bool isCaller;
  final MonitorSignaling _signaling;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStreamTrack? _audioTrack;
  MediaStreamTrack? _videoTrack;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  final state = ValueNotifier<CallState>(CallState.connecting);
  final micEnabled = ValueNotifier<bool>(true);
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  Future<void> start({required bool pushToTalk}) async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _pc = await createPeerConnection(_iceServers);

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    localRenderer.srcObject = _localStream;
    final audio = _localStream!.getAudioTracks();
    final video = _localStream!.getVideoTracks();
    if (audio.isNotEmpty) _audioTrack = audio.first;
    if (video.isNotEmpty) _videoTrack = video.first;

    // No modo walkie-talkie o microfone começa mudo (só fala segurando o botão).
    if (pushToTalk) setMic(false);

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null) _signaling.sendCandidate(c);
    };
    _pc!.onTrack = (event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };
    _pc!.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          state.value = CallState.live;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          state.value = CallState.failed;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          if (state.value != CallState.ended) state.value = CallState.ended;
        default:
          break;
      }
    };

    if (isCaller) {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _signaling.sendOffer(offer);
      state.value = CallState.waitingPeer;
      _subscriptions.add(_signaling.watchAnswer().listen((answer) async {
        await _pc!.setRemoteDescription(answer);
      }));
    } else {
      state.value = CallState.waitingPeer;
      final offer = await _signaling.waitForOffer();
      await _pc!.setRemoteDescription(offer);
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _signaling.sendAnswer(answer);
      state.value = CallState.connecting;
    }

    _subscriptions.add(_signaling.watchRemoteCandidates().listen(_pc!.addCandidate));
  }

  void setMic(bool on) {
    _audioTrack?.enabled = on;
    micEnabled.value = on;
  }

  void toggleMic() => setMic(!micEnabled.value);

  Future<void> switchCamera() async {
    if (_videoTrack != null) await Helper.switchCamera(_videoTrack!);
  }

  Future<void> dispose() async {
    state.value = CallState.ended;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
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
