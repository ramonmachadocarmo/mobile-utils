import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

/// Inicializa o Firebase sob demanda (só quando o monitoramento é aberto), para
/// o app não quebrar se a configuração ainda não tiver sido gerada. Usa o
/// `firebase_options.dart` do `flutterfire configure`, que funciona no Android e
/// no iOS sem depender dos arquivos nativos.
Future<bool> ensureFirebaseReady() async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return true;
  } catch (_) {
    return false;
  }
}
