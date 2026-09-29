import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_utils/features/call_blocker/call_blocker_config.dart';
import 'package:mobile_utils/features/call_blocker/phone_utils.dart';

void main() {
  group('PhoneUtils.toInternational', () {
    test('adiciona o DDI quando falta', () {
      expect(PhoneUtils.toInternational('(11) 91234-5678', '55'), '5511912345678');
      expect(PhoneUtils.toInternational('011 91234-5678', '55'), '5511912345678');
    });

    test('mantém números que já têm DDI', () {
      expect(PhoneUtils.toInternational('+55 (11) 91234-5678', '55'), '5511912345678');
      expect(PhoneUtils.toInternational('5511912345678', '55'), '5511912345678');
      expect(PhoneUtils.toInternational('+1 212 555 0100', '55'), '12125550100');
    });

    test('vazio continua vazio', () {
      expect(PhoneUtils.toInternational('', '55'), '');
      expect(PhoneUtils.toInternational('000', '55'), '');
    });
  });

  group('PhoneUtils.matchesPrefix', () {
    test('0303 (telemarketing) em qualquer formato', () {
      for (final n in ['03031234567', '3031234567', '+553031234567', '0303 123 4567']) {
        expect(PhoneUtils.matchesPrefix(n, '0303', '55'), isTrue, reason: n);
      }
      expect(PhoneUtils.matchesPrefix('11912345678', '0303', '55'), isFalse);
    });

    test('DDD', () {
      expect(PhoneUtils.matchesPrefix('+5511912345678', '11', '55'), isTrue);
      expect(PhoneUtils.matchesPrefix('(11) 91234-5678', '11', '55'), isTrue);
      expect(PhoneUtils.matchesPrefix('(21) 91234-5678', '11', '55'), isFalse);
    });

    test('prefixo nacional não bate com número de outro país', () {
      expect(PhoneUtils.matchesPrefix('+1 303 555 0100', '303', '55'), isFalse);
    });

    test('prefixo internacional', () {
      expect(PhoneUtils.matchesPrefix('+1 212 555 0100', '+1', '55'), isTrue);
      expect(PhoneUtils.matchesPrefix('(11) 91234-5678', '+1', '55'), isFalse);
      expect(PhoneUtils.matchesPrefix('(11) 91234-5678', '+55', '55'), isTrue);
    });

    test('prefixos curtos demais são ignorados', () {
      expect(PhoneUtils.isValidPrefix('9'), isFalse);
      expect(PhoneUtils.isValidPrefix('009'), isFalse);
      expect(PhoneUtils.isValidPrefix('+'), isFalse);
      expect(PhoneUtils.matchesPrefix('11912345678', '1', '55'), isFalse);
      expect(PhoneUtils.matchesPrefix('', '0303', '55'), isFalse);
    });
  });

  group('QuietHours.isActiveAt', () {
    // 2026-09-28 é segunda-feira.
    DateTime at(int day, int hour, [int minute = 0]) => DateTime(2026, 9, 27 + day, hour, minute);

    test('intervalo que atravessa a meia-noite', () {
      const q = QuietHours(enabled: true, start: 22 * 60, end: 7 * 60, days: [1, 2, 3, 4, 5]);
      expect(q.isActiveAt(at(1, 23)), isTrue); // seg 23h
      expect(q.isActiveAt(at(2, 6, 59)), isTrue); // ter 6h59, começou seg
      expect(q.isActiveAt(at(2, 7)), isFalse); // ter 7h
      expect(q.isActiveAt(at(1, 21, 59)), isFalse);
      expect(q.isActiveAt(at(6, 3)), isTrue); // sáb 3h, começou sex
      expect(q.isActiveAt(at(6, 23)), isFalse); // sáb não está marcado
      expect(q.isActiveAt(at(1, 3)), isFalse); // seg 3h, começaria dom
    });

    test('intervalo no mesmo dia', () {
      const q = QuietHours(enabled: true, start: 13 * 60, end: 14 * 60, days: [1]);
      expect(q.isActiveAt(at(1, 13, 30)), isTrue);
      expect(q.isActiveAt(at(1, 14)), isFalse);
      expect(q.isActiveAt(at(2, 13, 30)), isFalse);
    });

    test('início igual ao fim = dia inteiro; desligado nunca', () {
      const q = QuietHours(enabled: true, start: 0, end: 0, days: [7]);
      expect(q.isActiveAt(at(7, 12)), isTrue);
      expect(q.isActiveAt(at(1, 12)), isFalse);
      expect(const QuietHours(enabled: false).isActiveAt(at(1, 23)), isFalse);
    });
  });

  test('config antiga (sem os campos novos) continua carregando', () {
    final c = CallBlockerConfig.fromJson({'enabled': true, 'numbers': []});
    expect(c.prefixes, isEmpty);
    expect(c.quietHours.enabled, isFalse);
    expect(c.smsReply.enabled, isFalse);
  });

  test('config ida e volta pelo JSON', () {
    const c = CallBlockerConfig(
      enabled: true,
      prefixes: [BlockedPrefix(prefix: '0303', label: 'Telemarketing')],
      quietHours: QuietHours(enabled: true, start: 60, end: 120, days: [6, 7], allowContacts: false),
      smsReply: SmsReply(enabled: true, message: 'Ocupado', onlyQuietHours: false),
    );
    final back = CallBlockerConfig.fromJson(c.toJson());
    expect(back.prefixes.single.prefix, '0303');
    expect(back.prefixes.single.label, 'Telemarketing');
    expect(back.quietHours.toJson(), c.quietHours.toJson());
    expect(back.smsReply.toJson(), c.smsReply.toJson());
  });
}
