import 'dart:convert';

import 'package:flutter/services.dart';

import 'call_blocker_config.dart';

/// Ponte com o código nativo. A configuração fica salva do lado nativo porque
/// quem bloqueia a chamada é um serviço do sistema (Android) ou uma extensão
/// (iOS), que rodam sem o app Flutter aberto.
class CallBlockerChannel {
  static const _channel = MethodChannel('mobile_utils/call_blocker');

  static Future<CallBlockerConfig> getConfig() async {
    final raw = await _channel.invokeMethod<String>('getConfig');
    if (raw == null || raw.isEmpty) return const CallBlockerConfig();
    return CallBlockerConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Salva a configuração. No iOS também recarrega a Call Directory Extension
  /// e retorna uma mensagem de erro se ela falhar.
  static Future<String?> saveConfig(CallBlockerConfig config) =>
      _channel.invokeMethod<String>('saveConfig', jsonEncode(config.toJson()));

  /// Android: o app é o serviço de triagem de chamadas padrão?
  /// iOS: a Call Directory Extension está habilitada nos Ajustes?
  static Future<bool> isServiceEnabled() async =>
      await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;

  /// Android: pede o papel de "app de identificação e spam".
  /// iOS: abre os Ajustes (a extensão tem que ser ligada manualmente).
  static Future<bool> requestServiceEnabled() async =>
      await _channel.invokeMethod<bool>('requestServiceEnabled') ?? false;

  static Future<List<BlockedCallLogEntry>> getLog() async {
    final raw = await _channel.invokeMethod<String>('getLog');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => BlockedCallLogEntry.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> clearLog() => _channel.invokeMethod('clearLog');
}
