import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'note_auth.dart';
import 'quick_note.dart';
import 'quick_note_edit_page.dart';
import 'quick_notes_store.dart';

enum _Action { edit, pin, hide, delete }

/// Textos que você cola com frequência (chave Pix, endereço, dados bancários...).
/// Toque para copiar para a área de transferência. Notas ocultas pedem
/// digital/rosto/PIN uma vez por visita à tela.
class QuickNotesPage extends StatefulWidget {
  const QuickNotesPage({super.key, this.copyId});

  /// Copia esta nota ao abrir (link do widget no iOS).
  final String? copyId;

  @override
  State<QuickNotesPage> createState() => _QuickNotesPageState();
}

class _QuickNotesPageState extends State<QuickNotesPage> with WidgetsBindingObserver {
  final _store = QuickNotesStore();
  List<QuickNote>? _notes;
  String _query = '';

  /// Passou pela autenticação; liberado até o app ir para segundo plano.
  bool _unlocked = false;

  /// Notas ocultas que o usuário revelou temporariamente nesta tela.
  final _revealed = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() {
        _unlocked = false;
        _revealed.clear();
      });
    }
  }

  Future<void> _load() async {
    final notes = await _store.load();
    setState(() => _notes = notes);
    final toCopy = notes.where((n) => n.id == widget.copyId).firstOrNull;
    if (toCopy != null) await _copy(toCopy);
  }

  /// Exige autenticação antes de mostrar/copiar/editar uma nota oculta.
  Future<bool> _unlockFor(QuickNote note) async {
    if (!note.hidden || _unlocked) return true;
    final error = await NoteAuth.authenticate();
    if (!mounted) return false;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    setState(() => _unlocked = true);
    return true;
  }

  Future<void> _setNotes(List<QuickNote> notes) async {
    final sorted = QuickNotesStore.sort(notes);
    setState(() => _notes = sorted);
    await _store.save(sorted);
  }

  Future<void> _upsert(QuickNote note) =>
      _setNotes([..._notes!.where((n) => n.id != note.id), note]);

  Future<void> _copy(QuickNote note) async {
    if (!await _unlockFor(note)) return;
    await Clipboard.setData(ClipboardData(text: note.content));
    await _upsert(note.copyWith(lastCopiedAt: DateTime.now()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('"${note.title}" copiado')));
  }

  Future<void> _openEditor({QuickNote? note, String? initialContent}) async {
    final saved = await Navigator.push<QuickNote>(
      context,
      MaterialPageRoute(builder: (_) => QuickNoteEditPage(note: note, initialContent: initialContent)),
    );
    if (saved != null) await _upsert(saved);
  }

  Future<void> _newFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A área de transferência está vazia.')),
      );
      return;
    }
    await _openEditor(initialContent: text);
  }

  Future<void> _delete(QuickNote note) async {
    await _setNotes(_notes!.where((n) => n.id != note.id).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('"${note.title}" excluída'),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => _upsert(note)),
      ));
  }

  Future<void> _onAction(QuickNote note, _Action action) async {
    switch (action) {
      case _Action.edit:
        if (await _unlockFor(note)) await _openEditor(note: note);
      case _Action.pin:
        await _upsert(note.copyWith(pinned: !note.pinned));
      case _Action.hide:
        if (!await _unlockFor(note)) return;
        _revealed.remove(note.id);
        await _upsert(note.copyWith(hidden: !note.hidden));
      case _Action.delete:
        await _delete(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final visible = _notes
        ?.where((n) =>
            q.isEmpty ||
            n.title.toLowerCase().contains(q) ||
            (!n.hidden && n.content.toLowerCase().contains(q)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas rápidas'),
        actions: [
          IconButton(
            tooltip: 'Nova nota com o que está copiado',
            icon: const Icon(Icons.content_paste),
            onPressed: _newFromClipboard,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova nota',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: visible == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                Expanded(
                  child: _notes!.isEmpty
                      ? const _EmptyState()
                      : visible.isEmpty
                          ? const Center(child: Text('Nada encontrado.'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: visible.length,
                              itemBuilder: (context, i) => _NoteTile(
                                note: visible[i],
                                revealed: _revealed.contains(visible[i].id),
                                onCopy: () => _copy(visible[i]),
                                onToggleReveal: () async {
                                  final note = visible[i];
                                  if (_revealed.contains(note.id)) {
                                    setState(() => _revealed.remove(note.id));
                                  } else if (await _unlockFor(note)) {
                                    setState(() => _revealed.add(note.id));
                                  }
                                },
                                onAction: (a) => _onAction(visible[i], a),
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.revealed,
    required this.onCopy,
    required this.onToggleReveal,
    required this.onAction,
  });

  final QuickNote note;
  final bool revealed;
  final VoidCallback onCopy;
  final VoidCallback onToggleReveal;
  final ValueChanged<_Action> onAction;

  @override
  Widget build(BuildContext context) {
    final masked = note.hidden && !revealed;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onCopy,
        leading: Icon(note.pinned ? Icons.push_pin : Icons.notes),
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          masked ? '••••••••' : note.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.hidden)
              IconButton(
                // Sem desbloqueio, o olho pede a digital.
                tooltip: masked ? 'Mostrar' : 'Esconder',
                icon: Icon(masked ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleReveal,
              ),
            PopupMenuButton<_Action>(
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(value: _Action.edit, child: Text('Editar')),
                PopupMenuItem(value: _Action.pin, child: Text(note.pinned ? 'Desafixar' : 'Fixar')),
                PopupMenuItem(value: _Action.hide, child: Text(note.hidden ? 'Não ocultar' : 'Ocultar')),
                const PopupMenuItem(value: _Action.delete, child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Guarde aqui textos que você cola com frequência: chave Pix, endereço, '
          'dados bancários...\n\nToque numa nota para copiar.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
