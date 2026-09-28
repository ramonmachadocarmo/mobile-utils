import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Troca de ofertas WebRTC entre os dois celulares pelo Firestore. Depois que a
/// conexão fecha, o vídeo/áudio vai direto de um aparelho para o outro; o
/// Firestore só serve para eles se acharem.
///
/// Estrutura: `monitor_sessions/{code}` com `offer`/`answer`, e as subcoleções
/// `offerCandidates` (ICE do transmissor) e `answerCandidates` (ICE do receptor).
///
/// O transmissor é o "caller" (tem as tracks e cria a oferta); o receptor é o
/// "callee" (cria a resposta).
class MonitorSignaling {
  MonitorSignaling(
    this.code, {
    required this.isTransmitter,
    String collection = 'monitor_sessions',
  }) : _doc = FirebaseFirestore.instance.collection(collection).doc(code);

  final String code;
  final bool isTransmitter;
  final DocumentReference<Map<String, dynamic>> _doc;

  CollectionReference<Map<String, dynamic>> get _localCandidates =>
      _doc.collection(isTransmitter ? 'offerCandidates' : 'answerCandidates');
  CollectionReference<Map<String, dynamic>> get _remoteCandidates =>
      _doc.collection(isTransmitter ? 'answerCandidates' : 'offerCandidates');

  Future<void> sendOffer(RTCSessionDescription offer) =>
      _doc.set({'offer': offer.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> sendAnswer(RTCSessionDescription answer) => _doc.update({'answer': answer.toMap()});

  Future<void> sendCandidate(RTCIceCandidate candidate) =>
      _localCandidates.add(candidate.toMap());

  /// Aguarda a oferta do transmissor (usado pelo receptor).
  Future<RTCSessionDescription> waitForOffer() async {
    final snap = await _doc.snapshots().firstWhere((s) => s.data()?['offer'] != null);
    final offer = snap.data()!['offer'] as Map<String, dynamic>;
    return RTCSessionDescription(offer['sdp'] as String, offer['type'] as String);
  }

  /// Observa a resposta do receptor (usado pelo transmissor). Emite uma vez.
  Stream<RTCSessionDescription> watchAnswer() => _doc
      .snapshots()
      .where((s) => s.data()?['answer'] != null)
      .map((s) => s.data()!['answer'] as Map<String, dynamic>)
      .map((a) => RTCSessionDescription(a['sdp'] as String, a['type'] as String));

  /// Observa os ICE candidates do outro lado.
  Stream<RTCIceCandidate> watchRemoteCandidates() =>
      _remoteCandidates.snapshots().expand((snap) => snap.docChanges
          .where((c) => c.type == DocumentChangeType.added)
          .map((c) => c.doc.data()!)
          .map((d) => RTCIceCandidate(
                d['candidate'] as String?,
                d['sdpMid'] as String?,
                d['sdpMLineIndex'] as int?,
              )));

  /// O transmissor limpa a sessão ao encerrar, para o código não ser reusado.
  Future<void> dispose() async {
    if (!isTransmitter) return;
    for (final sub in ['offerCandidates', 'answerCandidates']) {
      final docs = await _doc.collection(sub).get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }
    await _doc.delete();
  }
}
