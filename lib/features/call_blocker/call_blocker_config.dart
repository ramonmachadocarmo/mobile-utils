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

class CallBlockerConfig {
  const CallBlockerConfig({
    this.enabled = false,
    this.blockUnknown = false,
    this.countryCode = '55',
    this.numbers = const [],
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

  CallBlockerConfig copyWith({
    bool? enabled,
    bool? blockUnknown,
    String? countryCode,
    List<BlockedNumber>? numbers,
  }) =>
      CallBlockerConfig(
        enabled: enabled ?? this.enabled,
        blockUnknown: blockUnknown ?? this.blockUnknown,
        countryCode: countryCode ?? this.countryCode,
        numbers: numbers ?? this.numbers,
      );

  factory CallBlockerConfig.fromJson(Map<String, dynamic> json) => CallBlockerConfig(
        enabled: json['enabled'] as bool? ?? false,
        blockUnknown: json['blockUnknown'] as bool? ?? false,
        countryCode: json['countryCode'] as String? ?? '55',
        numbers: (json['numbers'] as List? ?? [])
            .map((e) => BlockedNumber.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'blockUnknown': blockUnknown,
        'countryCode': countryCode,
        'numbers': numbers.map((n) => n.toJson()).toList(),
      };
}

class BlockedCallLogEntry {
  const BlockedCallLogEntry({required this.number, required this.reason, required this.timestamp});

  final String number;
  final String reason;
  final DateTime timestamp;

  factory BlockedCallLogEntry.fromJson(Map<String, dynamic> json) => BlockedCallLogEntry(
        number: json['number'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt()),
      );
}
