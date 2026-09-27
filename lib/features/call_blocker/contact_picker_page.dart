import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'call_blocker_config.dart';
import 'phone_utils.dart';

class _Entry {
  _Entry(this.name, this.number);
  final String name;
  final String number;
}

/// Lista os contatos (um item por telefone) com busca e seleção múltipla.
/// Retorna os números escolhidos como [BlockedNumber].
class ContactPickerPage extends StatefulWidget {
  const ContactPickerPage({super.key, required this.alreadyBlocked});

  final List<BlockedNumber> alreadyBlocked;

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  List<_Entry>? _entries;
  String? _error;
  String _query = '';
  final _selected = <_Entry>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      setState(() => _error = 'Permissão de contatos negada.');
      return;
    }
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    final entries = <_Entry>[];
    for (final c in contacts) {
      final seen = <String>{};
      for (final p in c.phones) {
        final d = PhoneUtils.digits(p.number);
        if (d.isEmpty || !seen.add(d)) continue;
        if (widget.alreadyBlocked.any((b) => PhoneUtils.matches(b.number, p.number))) continue;
        entries.add(_Entry(c.displayName ?? p.number, p.number));
      }
    }
    entries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final qDigits = PhoneUtils.digits(_query);
    final visible = _entries
        ?.where((e) =>
            q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            (qDigits.isNotEmpty && PhoneUtils.digits(e.number).contains(qDigits)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty ? 'Escolher contatos' : '${_selected.length} selecionado(s)'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _selected
                          .map((e) => BlockedNumber(
                                number: e.number,
                                label: e.name,
                                source: BlockedSource.contact,
                              ))
                          .toList(),
                    ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : visible == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por nome ou número',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(child: Text('Nenhum contato encontrado.'))
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final e = visible[i];
                                return CheckboxListTile(
                                  value: _selected.contains(e),
                                  title: Text(e.name),
                                  subtitle: Text(e.number),
                                  onChanged: (v) => setState(
                                    () => v! ? _selected.add(e) : _selected.remove(e),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
