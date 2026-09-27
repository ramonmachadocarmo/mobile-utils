import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'quick_note.dart';
import 'quick_notes_widget.dart';

class QuickNotesStore {
  static const _key = 'quick_notes';

  Future<List<QuickNote>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    final notes = (jsonDecode(raw) as List)
        .map((e) => QuickNote.fromJson(e as Map<String, dynamic>))
        .toList();
    return sort(notes);
  }

  Future<void> save(List<QuickNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(notes.map((n) => n.toJson()).toList()));
    await QuickNotesWidget.update(notes);
  }

  /// Fixadas primeiro; dentro de cada grupo, as usadas mais recentemente.
  static List<QuickNote> sort(List<QuickNote> notes) => [...notes]
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastUsed.compareTo(a.lastUsed);
    });
}
