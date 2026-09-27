import 'package:flutter/material.dart';

import 'quick_note.dart';

/// Cria ou edita uma nota. Retorna a nota salva, ou null se cancelar.
class QuickNoteEditPage extends StatefulWidget {
  const QuickNoteEditPage({super.key, this.note, this.initialContent});

  final QuickNote? note;

  /// Conteúdo inicial de uma nota nova (ex.: vindo da área de transferência).
  final String? initialContent;

  @override
  State<QuickNoteEditPage> createState() => _QuickNoteEditPageState();
}

class _QuickNoteEditPageState extends State<QuickNoteEditPage> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _content = TextEditingController(text: widget.note?.content ?? widget.initialContent);
  late bool _pinned = widget.note?.pinned ?? false;
  late bool _hidden = widget.note?.hidden ?? false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    final content = _content.text;
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O conteúdo está vazio.')));
      return;
    }
    // Sem título, usa a primeira linha do conteúdo.
    var title = _title.text.trim();
    if (title.isEmpty) {
      title = content.trim().split('\n').first;
      if (title.length > 40) title = '${title.substring(0, 40)}…';
    }
    final now = DateTime.now();
    final note = widget.note?.copyWith(
          title: title,
          content: content,
          pinned: _pinned,
          hidden: _hidden,
          updatedAt: now,
        ) ??
        QuickNote(
          id: now.microsecondsSinceEpoch.toString(),
          title: title,
          content: content,
          pinned: _pinned,
          hidden: _hidden,
          updatedAt: now,
        );
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nova nota' : 'Editar nota'),
        actions: [
          IconButton(tooltip: 'Salvar', icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título (opcional)',
              hintText: 'Ex.: Chave Pix',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            autofocus: widget.note == null && widget.initialContent == null,
            minLines: 4,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Conteúdo',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fixar no topo'),
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ocultar conteúdo na lista'),
            subtitle: const Text('Para dados sensíveis. Continua copiando normalmente.'),
            value: _hidden,
            onChanged: (v) => setState(() => _hidden = v),
          ),
        ],
      ),
    );
  }
}
