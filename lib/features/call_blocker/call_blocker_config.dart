import 'phone_utils.dart';

enum BlockedSource { manual, contact }

class BlockedNumber {
  const BlockedNumber({
    required this.number,
    this.label,
    this.source = BlockedSource.manual,
  });

  final String number;
  final String? label;
  final BlockedSource source;

  String get digits => PhoneUtils.digits(number);

  factory BlockedNumber.fromJson(Map<String, dynamic> json) => BlockedNumber(
        number: json['number'] as String,
        label: json['label'] as String?,
        source: BlockedSource.values.byName(json['source'] as String? ?? 'manual'),
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'label': label,
        'source': source.name,
      };
}

/// Bloqueia todos os números que começam com [prefix] (ex.: 0303, telemarketing).
class BlockedPrefix {
  const BlockedPrefix({required this.prefix, this.label});

  final String prefix;
  final String? label;

  factory BlockedPrefix.fromJson(Map<String, dynamic> json) => BlockedPrefix(
        prefix: json['prefix'] as String,
        label: json['label'] as String?,
      );

  Map<String, dynamic> toJson() => {'prefix': prefix, 'label': label};
}

/// Horário de silêncio: rejeita chamadas num intervalo do dia, em dias escolhidos.
/// Mesma lógica de CallBlockerStore.isQuietTime (Android).
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.start = 22 * 60,
    this.end = 7 * 60,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.allowContacts = true,
    this.allowRepeated = true,
  });

  final bool enabled;

  /// Início e fim em minutos desde a meia-noite. Se [end] < [start], o
  /// intervalo atravessa a meia-noite; se forem iguais, vale o dia inteiro.
  final int start;
  final int end;

  /// Dias da semana em que o horário começa (1 = segunda ... 7 = domingo,
  /// como `DateTime.weekday`). Das 22h às 7h na sexta vai até sábado 7h.
  final List<int> days;

  /// Deixa passar quem está na agenda.
  final bool allowContacts;

  /// Deixa passar quem ligar de novo em até [repeatWindow] (urgências).
  final bool allowRepeated;

  static const repeatWindow = Duration(minutes: 3);

  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    final m = now.hour * 60 + now.minute;
    final today = now.weekday;
    final yesterday = today == 1 ? 7 : today - 1;
    if (start == end) return days.contains(today);
    if (start < end) return days.contains(today) && m >= start && m < end;
    return (m >= start && days.contains(today)) || (m < end && days.contains(yesterday));
  }

  QuietHours copyWith({
    bool? enabled,
    int? start,
    int? end,
    List<int>? days,
    bool? allowContacts,
    bool? allowRepeated,
  }) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
        days: days ?? this.days,
        allowContacts: allowContacts ?? this.allowContacts,
        allowRepeated: allowRepeated ?? this.allowRepeated,
      );

  factory QuietHours.fromJson(Map<String, dynamic> json) => QuietHours(
        enabled: json['enabled'] as bool? ?? false,
        start: (json['start'] as num?)?.toInt() ?? 22 * 60,
        end: (json['end'] as num?)?.toInt() ?? 7 * 60,
        days: (json['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4, 5, 6, 7],
        allowContacts: json['allowContacts'] as bool? ?? true,
        allowRepeated: json['allowRepeated'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'start': start,
        'end': end,
        'days': days,
        'allowContacts': allowContacts,
        'allowRepeated': allowRepeated,
      };
}

/// Resposta automática por SMS a quem foi bloqueado (só Android).
class SmsReply {
  const SmsReply({
    this.enabled = false,
    this.message = defaultMessage,
    this.onlyQuietHours = true,
  });

  static const defaultMessage = 'Não posso atender agora. Retorno assim que possível.';

  /// Cada número recebe no máximo uma resposta nesse intervalo.
  static const cooldown = Duration(hours: 12);

  final bool enabled;
  final String message;

  /// Responde só as chamadas rejeitadas pelo horário de silêncio. Desligado,
  /// responde também números da lista, prefixos e desconhecidos (não ocultos).
  final bool onlyQuietHours;

  SmsReply copyWith({bool? enabled, String? message, bool? onlyQuietHours}) => SmsReply(
        enabled: enabled ?? this.enabled,
        message: message ?? this.message,
        onlyQuietHours: onlyQuietHours ?? this.onlyQuietHours,
      );

  factory SmsReply.fromJson(Map<String, dynamic> json) => SmsReply(
        enabled: json['enabled'] as bool? ?? false,
        message: json['message'] as String? ?? defaultMessage,
        onlyQuietHours: json['onlyQuietHours'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'message': message,
        'onlyQuietHours': onlyQuietHours,
      };
}

class CallBlockerConfig {
  const CallBlockerConfig({
    this.enabled = false,
    this.blockUnknown = false,
    this.countryCode = '55',
    this.numbers = const [],
    this.prefixes = const [],
    this.quietHours = const QuietHours(),
    this.smsReply = const SmsReply(),
  });

  /// Liga/desliga o bloqueio como um todo.
  final bool enabled;

  /// Bloqueia números que não estão na agenda (e números ocultos/privados).
  /// Só funciona no Android.
  final bool blockUnknown;

  /// DDI usado para normalizar números sem código do país (ex.: 55 = Brasil).
  final String countryCode;

  /// Números bloqueados, digitados manualmente ou escolhidos dos contatos.
  final List<BlockedNumber> numbers;

  /// Prefixos bloqueados (só Android).
  final List<BlockedPrefix> prefixes;

  /// Horário de silêncio (só Android).
  final QuietHours quietHours;

  /// Resposta por SMS a quem foi bloqueado (só Android).
  final SmsReply smsReply;

  CallBlockerConfig copyWith({
    bool? enabled,
    bool? blockUnknown,
    String? countryCode,
    List<BlockedNumber>? numbers,
    List<BlockedPrefix>? prefixes,
    QuietHours? quietHours,
    SmsReply? smsReply,
  }) =>
      CallBlockerConfig(
        enabled: enabled ?? this.enabled,
        blockUnknown: blockUnknown ?? this.blockUnknown,
        countryCode: countryCode ?? this.countryCode,
        numbers: numbers ?? this.numbers,
        prefixes: prefixes ?? this.prefixes,
        quietHours: quietHours ?? this.quietHours,
        smsReply: smsReply ?? this.smsReply,
      );

  factory CallBlockerConfig.fromJson(Map<String, dynamic> json) => CallBlockerConfig(
        enabled: json['enabled'] as bool? ?? false,
        blockUnknown: json['blockUnknown'] as bool? ?? false,
        countryCode: json['countryCode'] as String? ?? '55',
        numbers: (json['numbers'] as List? ?? [])
            .map((e) => BlockedNumber.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        prefixes: (json['prefixes'] as List? ?? [])
            .map((e) => BlockedPrefix.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        quietHours: json['quietHours'] is Map
            ? QuietHours.fromJson(Map<String, dynamic>.from(json['quietHours'] as Map))
            : const QuietHours(),
        smsReply: json['smsReply'] is Map
            ? SmsReply.fromJson(Map<String, dynamic>.from(json['smsReply'] as Map))
            : const SmsReply(),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'blockUnknown': blockUnknown,
        'countryCode': countryCode,
        'numbers': numbers.map((n) => n.toJson()).toList(),
        'prefixes': prefixes.map((p) => p.toJson()).toList(),
        'quietHours': quietHours.toJson(),
        'smsReply': smsReply.toJson(),
      };
}

class BlockedCallLogEntry {
  const BlockedCallLogEntry({
    required this.number,
    required this.reason,
    required this.timestamp,
    this.smsSent = false,
  });

  final String number;
  final String reason;
  final DateTime timestamp;

  /// Foi respondida com o SMS automático.
  final bool smsSent;

  factory BlockedCallLogEntry.fromJson(Map<String, dynamic> json) => BlockedCallLogEntry(
        number: json['number'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt()),
        smsSent: json['sms'] as bool? ?? false,
      );
}
