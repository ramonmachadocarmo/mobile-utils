import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_utils/features/quick_notes/quick_note.dart';
import 'package:mobile_utils/features/quick_notes/quick_notes_store.dart';
import 'package:mobile_utils/features/quick_notes/quick_notes_widget.dart';

QuickNote _note(String id, {bool pinned = false, int updated = 0, int? copied}) => QuickNote(
      id: id,
      title: id,
      content: 'conteúdo $id',
      pinned: pinned,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated),
      lastCopiedAt: copied == null ? null : DateTime.fromMillisecondsSinceEpoch(copied),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ordena fixadas primeiro e depois pelo uso mais recente', () {
    final sorted = QuickNotesStore.sort([
      _note('antiga', updated: 1),
      _note('copiada', updated: 1, copied: 50),
      _note('fixada', pinned: true, updated: 0),
      _note('editada', updated: 10),
    ]);
    expect(sorted.map((n) => n.id), ['fixada', 'copiada', 'editada', 'antiga']);
  });

  test('salva e carrega as notas', () async {
    SharedPreferences.setMockInitialValues({});
    final store = QuickNotesStore();
    await store.save([_note('a', copied: 5), _note('b', pinned: true)]);
    final loaded = await store.load();
    expect(loaded.map((n) => n.id), ['b', 'a']);
    expect(loaded.last.lastCopiedAt, DateTime.fromMillisecondsSinceEpoch(5));
    expect(loaded.last.content, 'conteúdo a');
  });

  test('widget recebe só notas fixadas e não ocultas', () {
    final notes = [
      _note('fixada', pinned: true),
      _note('solta'),
      _note('fixada-oculta', pinned: true).copyWith(hidden: true),
    ];
    expect(QuickNotesWidget.widgetNotes(notes).map((n) => n.id), ['fixada']);
  });
}
