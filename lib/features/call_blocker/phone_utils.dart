class PhoneUtils {
  PhoneUtils._();

  /// Mínimo de dígitos para considerar um casamento por sufixo
  /// (evita que "1234" bloqueie qualquer número terminado em 1234).
  static const minSuffixMatch = 8;

  /// Mínimo de dígitos de um prefixo nacional (sem zeros à esquerda), para
  /// que um prefixo como "9" não bloqueie quase todos os celulares.
  static const minPrefixDigits = 2;

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

  /// Número só com dígitos e com DDI, como o `toE164` da extensão do iOS:
  /// "+55 (11) 91234-5678" -> 5511912345678; "(11) 91234-5678" -> 55 + 11912345678.
  /// Números sem "+" que já começam com o DDI e têm 12+ dígitos ficam como estão.
  static String toInternational(String number, String countryCode) {
    final trimmed = number.trim();
    final d = digits(trimmed);
    if (trimmed.startsWith('+')) return d;
    final significant = d.replaceFirst(RegExp(r'^0+'), '');
    if (significant.isEmpty) return '';
    if (significant.startsWith(countryCode) && significant.length >= 12) return significant;
    return countryCode + significant;
  }

  /// Prefixo válido? Com "+" é internacional (ex.: "+1"); sem, é nacional e
  /// precisa de [minPrefixDigits] dígitos além dos zeros (ex.: "0303", "11").
  static bool isValidPrefix(String prefix) {
    final trimmed = prefix.trim();
    if (trimmed.startsWith('+')) return digits(trimmed).isNotEmpty;
    return _significant(trimmed).length >= minPrefixDigits;
  }

  /// Mesmo algoritmo de CallBlockerStore.matchesPrefix (Android).
  ///
  /// - Prefixo com "+" (ex.: "+1") compara com o número internacional.
  /// - Sem "+" (ex.: "0303", "11") compara com o número nacional, sem DDI e
  ///   sem zeros; números de outros países nunca batem com prefixo nacional.
  static bool matchesPrefix(String number, String prefix, String countryCode) {
    if (!isValidPrefix(prefix)) return false;
    final intl = toInternational(number, countryCode);
    if (intl.isEmpty) return false;
    final p = prefix.trim();
    if (p.startsWith('+')) return intl.startsWith(digits(p));
    if (!intl.startsWith(countryCode)) return false;
    return intl.substring(countryCode.length).startsWith(_significant(p));
  }
}
