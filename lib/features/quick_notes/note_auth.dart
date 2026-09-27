import 'package:local_auth/local_auth.dart';

/// Pede digital/rosto (ou o PIN/padrão do aparelho como alternativa).
/// Retorna null se autenticou, ou a mensagem de erro para mostrar.
class NoteAuth {
  static final _auth = LocalAuthentication();

  static Future<String?> authenticate() async {
    try {
      final ok = await _auth.authenticate(localizedReason: 'Desbloquear notas ocultas');
      return ok ? null : 'Autenticação cancelada.';
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled =>
          'Autenticação cancelada.',
        LocalAuthExceptionCode.noCredentialsSet =>
          'Configure uma digital, rosto ou PIN no aparelho para usar notas ocultas.',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Muitas tentativas. Tente de novo mais tarde.',
        _ => 'Não foi possível autenticar (${e.code.name}).',
      };
    }
  }
}
