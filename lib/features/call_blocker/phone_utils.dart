class PhoneUtils {
  PhoneUtils._();

  /// Mínimo de dígitos para considerar um casamento por sufixo
  /// (evita que "1234" bloqueie qualquer número terminado em 1234).
  static const minSuffixMatch = 8;

  static String digits(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// Mesmo algoritmo usado no Android (CallBlockerStore.kt): números batem se
  /// forem iguais ou se os últimos N dígitos coincidirem (N >= 8), o que cobre
  /// variações como "+55 11 91234-5678" x "(11) 91234-5678" x "011912345678".
  /// Zeros à esquerda (prefixo de discagem) são ignorados.
  static bool matches(String a, String b) {
    final da = _significant(a);
    final db = _significant(b);
    if (da.isEmpty || db.isEmpty) return false;
    if (da == db) return true;
    final n = da.length < db.length ? da.length : db.length;
    if (n < minSuffixMatch) return false;
    return da.substring(da.length - n) == db.substring(db.length - n);
  }

  static String _significant(String input) => digits(input).replaceFirst(RegExp(r'^0+'), '');
}
