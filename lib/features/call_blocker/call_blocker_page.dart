import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'android_rules_sections.dart';
import 'blocked_log_page.dart';
import 'call_blocker_channel.dart';
import 'call_blocker_config.dart';
import 'contact_picker_page.dart';
import 'phone_utils.dart';

class CallBlockerPage extends StatefulWidget {
  const CallBlockerPage({super.key});

  @override
  State<CallBlockerPage> createState() => _CallBlockerPageState();
}

class _CallBlockerPageState extends State<CallBlockerPage> with WidgetsBindingObserver {
  CallBlockerConfig? _config;
  bool _serviceEnabled = false;

  /// Sem acesso aos contatos o serviço não sabe quem é desconhecido e deixa
  /// todas as chamadas passarem (Android).
  bool _hasContactsPermission = true;

  /// Sem a permissão de SMS a resposta automática não é enviada (Android).
  bool _hasSmsPermission = true;

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

  // Ao voltar dos Ajustes, atualiza o status do serviço e da permissão.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshServiceStatus();
  }

  Future<void> _load() async {
    final config = await CallBlockerChannel.getConfig();
    setState(() => _config = config);
    await _refreshServiceStatus();
  }

  Future<void> _refreshServiceStatus() async {
    final enabled = await CallBlockerChannel.isServiceEnabled();
    final contacts = !Platform.isAndroid || await FlutterContacts.permissions.has(PermissionType.read);
    final sms = !Platform.isAndroid || await ph.Permission.sms.isGranted;
    if (mounted) {
      setState(() {
        _serviceEnabled = enabled;
        _hasContactsPermission = contacts;
        _hasSmsPermission = sms;
      });
    }
  }

  /// Pede a permissão de contatos; se já foi negada de vez, abre os Ajustes.
  Future<bool> _requestContactsPermission() async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    if (mounted) setState(() => _hasContactsPermission = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sem acesso aos contatos não dá para saber quem é desconhecido.'),
        action: status == PermissionStatus.permanentlyDenied
            ? SnackBarAction(label: 'Ajustes', onPressed: FlutterContacts.permissions.openSettings)
            : null,
      ));
    }
    return granted;
  }

  Future<void> _setBlockUnknown(bool value) async {
    if (value && !await _requestContactsPermission()) return;
    await _update(_config!.copyWith(blockUnknown: value));
  }

  Future<void> _setAllowContacts(bool value) async {
    if (value && !await _requestContactsPermission()) return;
    await _update(_config!.copyWith(quietHours: _config!.quietHours.copyWith(allowContacts: value)));
  }

  /// Pede a permissão de enviar SMS; se já foi negada de vez, abre os Ajustes.
  Future<bool> _requestSmsPermission() async {
    final status = await ph.Permission.sms.request();
    final granted = status.isGranted;
    if (mounted) setState(() => _hasSmsPermission = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sem a permissão de SMS a resposta automática não é enviada.'),
        action: status.isPermanentlyDenied
            ? SnackBarAction(label: 'Ajustes', onPressed: ph.openAppSettings)
            : null,
      ));
    }
    return granted;
  }

  Future<void> _setSmsReply(bool value) async {
    if (value && !await _requestSmsPermission()) return;
    await _update(_config!.copyWith(smsReply: _config!.smsReply.copyWith(enabled: value)));
  }

  Future<void> _update(CallBlockerConfig config) async {
    setState(() => _config = config);
    final error = await CallBlockerChannel.saveConfig(config);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _addNumbers(List<BlockedNumber> added) async {
    final current = _config!.numbers;
    final fresh = added.where((n) => !current.any((c) => PhoneUtils.matches(c.number, n.number)));
    await _update(_config!.copyWith(numbers: [...current, ...fresh]));
  }

  Future<void> _typeNumber() async {
    final numberCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final result = await showDialog<BlockedNumber>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquear número'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\- ]'))],
              decoration: const InputDecoration(labelText: 'Número', hintText: '(11) 91234-5678'),
            ),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final number = numberCtrl.text.trim();
              if (PhoneUtils.digits(number).length < 3) return;
              final label = labelCtrl.text.trim();
              Navigator.pop(context, BlockedNumber(number: number, label: label.isEmpty ? null : label));
            },
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (result != null) await _addNumbers([result]);
  }

  Future<void> _typePrefix() async {
    final prefixCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String? error;
    final result = await showDialog<BlockedPrefix>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bloquear prefixo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: prefixCtrl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                decoration: InputDecoration(
                  labelText: 'Prefixo',
                  hintText: '0303',
                  helperText: 'Ex.: 0303 (telemarketing), um DDD, ou +1 para outro país',
                  helperMaxLines: 2,
                  errorText: error,
                ),
              ),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final prefix = prefixCtrl.text.trim();
                if (!PhoneUtils.isValidPrefix(prefix)) {
                  setDialogState(() => error = 'Use ao menos ${PhoneUtils.minPrefixDigits} dígitos (sem contar zeros)');
                  return;
                }
                final label = labelCtrl.text.trim();
                Navigator.pop(context, BlockedPrefix(prefix: prefix, label: label.isEmpty ? null : label));
              },
              child: const Text('Bloquear'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final current = _config!.prefixes;
    if (current.any((p) => p.prefix == result.prefix)) return;
    await _update(_config!.copyWith(prefixes: [...current, result]));
  }

  Future<void> _pickContacts() async {
    final result = await Navigator.push<List<BlockedNumber>>(
      context,
      MaterialPageRoute(builder: (_) => ContactPickerPage(alreadyBlocked: _config!.numbers)),
    );
    if (result != null && result.isNotEmpty) await _addNumbers(result);
  }

  Future<void> _editCountryCode() async {
    final ctrl = TextEditingController(text: _config!.countryCode);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código do país (DDI)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '+'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await _update(_config!.copyWith(countryCode: result));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloqueio de chamadas'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              tooltip: 'Histórico',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedLogPage()),
              ),
            ),
        ],
      ),
      floatingActionButton: config == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dialpad),
                        title: const Text('Digitar número'),
                        onTap: () {
                          Navigator.pop(context);
                          _typeNumber();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.contacts),
                        title: const Text('Escolher dos contatos'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickContacts();
                        },
                      ),
                      if (Platform.isAndroid)
                        ListTile(
                          leading: const Icon(Icons.pin_outlined),
                          title: const Text('Bloquear prefixo'),
                          subtitle: const Text('Todos os números que começam com, ex.: 0303'),
                          onTap: () {
                            Navigator.pop(context);
                            _typePrefix();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (!_serviceEnabled)
                  _WarningCard(
                    title: 'Bloqueador desativado no sistema',
                    message: Platform.isAndroid
                        ? 'Defina este app como "app de identificação de chamadas e spam".'
                        : 'Ative em Ajustes › Apps › Telefone › Bloqueio e Identificação de Chamadas.',
                    action: 'Ativar',
                    onTap: () async {
                      await CallBlockerChannel.requestServiceEnabled();
                      await _refreshServiceStatus();
                    },
                  ),
                if (Platform.isAndroid && config.blockUnknown && !_hasContactsPermission)
                  _WarningCard(
                    title: 'Desconhecidos não estão sendo bloqueados',
                    message: 'O app precisa de acesso aos contatos para saber quem está na agenda.',
                    action: 'Permitir',
                    onTap: _requestContactsPermission,
                  ),
                if (Platform.isAndroid &&
                    config.quietHours.enabled &&
                    config.quietHours.allowContacts &&
                    !_hasContactsPermission)
                  _WarningCard(
                    title: 'Horário de silêncio não está bloqueando',
                    message: 'Sem acesso aos contatos, todas as chamadas passam para não barrar quem está na agenda.',
                    action: 'Permitir',
                    onTap: _requestContactsPermission,
                  ),
                if (Platform.isAndroid && config.smsReply.enabled && !_hasSmsPermission)
                  _WarningCard(
                    title: 'Respostas por SMS não estão sendo enviadas',
                    message: 'O app precisa da permissão de SMS.',
                    action: 'Permitir',
                    onTap: _requestSmsPermission,
                  ),
                SwitchListTile(
                  title: const Text('Bloqueio ativo'),
                  subtitle: const Text('Rejeita as chamadas que se encaixam nas regras abaixo'),
                  value: config.enabled,
                  onChanged: (v) => _update(config.copyWith(enabled: v)),
                ),
                const Divider(),
                if (Platform.isAndroid)
                  SwitchListTile(
                    title: const Text('Bloquear desconhecidos'),
                    subtitle: const Text('Números fora da agenda e números ocultos/privados'),
                    value: config.blockUnknown,
                    onChanged: config.enabled ? _setBlockUnknown : null,
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Bloquear desconhecidos'),
                    subtitle: Text(
                      'O iOS não permite que apps façam isso. Use Ajustes › Telefone › '
                      'Silenciar Desconhecidos.',
                    ),
                  ),
                ListTile(
                  title: const Text('Código do país padrão'),
                  subtitle: Text('+${config.countryCode} — usado em números digitados sem DDI'),
                  trailing: const Icon(Icons.edit),
                  onTap: _editCountryCode,
                ),
                if (Platform.isAndroid) ...[
                  const Divider(),
                  QuietHoursSection(
                    quietHours: config.quietHours,
                    enabled: config.enabled,
                    onChanged: (q) => _update(config.copyWith(quietHours: q)),
                    onAllowContacts: _setAllowContacts,
                  ),
                  const Divider(),
                  SmsReplySection(
                    smsReply: config.smsReply,
                    enabled: config.enabled,
                    onChanged: (r) => _update(config.copyWith(smsReply: r)),
                    onToggle: _setSmsReply,
                  ),
                ],
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Números bloqueados (${config.numbers.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (config.numbers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum número. Toque em "Adicionar" para digitar ou escolher dos contatos.'),
                  ),
                for (final n in config.numbers)
                  ListTile(
                    enabled: config.enabled,
                    leading: Icon(n.source == BlockedSource.contact ? Icons.person : Icons.dialpad),
                    title: Text(n.label ?? n.number),
                    subtitle: n.label != null ? Text(n.number) : null,
                    trailing: IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _update(
                        config.copyWith(numbers: config.numbers.where((x) => x != n).toList()),
                      ),
                    ),
                  ),
                if (Platform.isAndroid && config.prefixes.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Prefixos bloqueados (${config.prefixes.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final p in config.prefixes)
                    ListTile(
                      enabled: config.enabled,
                      leading: const Icon(Icons.pin_outlined),
                      title: Text(p.label == null ? '${p.prefix}…' : p.label!),
                      subtitle: Text(p.label == null ? 'Começa com ${p.prefix}' : '${p.prefix}…'),
                      trailing: IconButton(
                        tooltip: 'Remover',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _update(config.copyWith(prefixes: config.prefixes.where((x) => x != p).toList())),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: scheme.onErrorContainer),
        title: Text(title, style: TextStyle(color: scheme.onErrorContainer)),
        subtitle: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        trailing: FilledButton(onPressed: onTap, child: Text(action)),
      ),
    );
  }
}
