import 'dart:convert';

import 'package:flutter/services.dart';

import 'quick_note.dart';

/// Envia as notas para o widget da tela inicial (Android: QuickNotesWidget.kt,
/// iOS: QuickNotesWidget extension). Só as fixadas e não ocultas vão para o
/// widget, porque lá não dá para pedir a digital.
class QuickNotesWidget {
  static const _channel = MethodChannel('mobile_utils/widgets');

  static List<QuickNote> widgetNotes(List<QuickNote> notes) =>
      notes.where((n) => n.pinned && !n.hidden).toList();

  static Future<void> update(List<QuickNote> notes) async {
    final data = widgetNotes(notes)
        .map((n) => {'id': n.id, 'title': n.title, 'content': n.content})
        .toList();
    try {
      await _channel.invokeMethod('updateQuickNotes', jsonEncode(data));
    } on MissingPluginException {
      // Testes e plataformas sem widget.
    }
  }
}
