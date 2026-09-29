import '../call_blocker/phone_utils.dart';

/// Monta links wa.me para conversar sem salvar o contato.
class WhatsappLink {
  WhatsappLink._();

  /// Números internacionais têm de 8 a 15 dígitos (E.164), mas qualquer
  /// número real com DDI passa de 10.
  static const minDigits = 10;
  static const maxDigits = 15;

  /// Número com DDI só com dígitos, ou null se não parecer um telefone válido.
  static String? normalize(String number, String countryCode) {
    final intl = PhoneUtils.toInternational(number, countryCode);
    if (intl.length < minDigits || intl.length > maxDigits) return null;
    // Brasil: DDI + DDD + 8 ou 9 dígitos. Pega quem esqueceu o DDD.
    if (intl.startsWith('55') && intl.length != 12 && intl.length != 13) return null;
    return intl;
  }

  /// https://wa.me/5511912345678?text=Ol%C3%A1 (espaços viram %20, não "+").
  static Uri build(String internationalDigits, {String message = ''}) {
    final text = message.trim();
    return Uri.parse('https://wa.me/$internationalDigits${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
  }

  /// "5511912345678" -> "+55 (11) 91234-5678"; outros países ficam "+" e os dígitos.
  static String format(String internationalDigits) {
    final d = internationalDigits;
    if (d.startsWith('55') && (d.length == 12 || d.length == 13)) {
      final ddd = d.substring(2, 4);
      final local = d.substring(4);
      final split = local.length - 4;
      return '+55 ($ddd) ${local.substring(0, split)}-${local.substring(split)}';
    }
    return '+$d';
  }
}
