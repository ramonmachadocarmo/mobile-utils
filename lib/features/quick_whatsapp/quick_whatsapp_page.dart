import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'whatsapp_link.dart';

/// Abre uma conversa no WhatsApp com qualquer número, sem salvar o contato.
class QuickWhatsappPage extends StatefulWidget {
  const QuickWhatsappPage({super.key});

  @override
  State<QuickWhatsappPage> createState() => _QuickWhatsappPageState();
}

class _QuickWhatsappPageState extends State<QuickWhatsappPage> {
  static const _recentKey = 'quick_whatsapp_recent';
  static const _countryKey = 'quick_whatsapp_country_code';
  static const _maxRecent = 10;

  final _numberCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _countryCode = '55';
  List<String> _recent = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _countryCode = prefs.getString(_countryKey) ?? '55';
      _recent = prefs.getStringList(_recentKey) ?? [];
    });
  }

  Future<void> _saveRecent(List<String> recent) async {
    setState(() => _recent = recent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, recent);
  }

  // Colar só ao tocar: no iOS, ler a área de transferência sozinho mostra um aviso.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _numberCtrl.text = text.replaceAll(RegExp(r'[^0-9+()\- ]'), '').trim();
      _error = null;
    });
  }

  Future<void> _open([String? number]) async {
    final digits = WhatsappLink.normalize(number ?? _numberCtrl.text, _countryCode);
    if (digits == null) {
      setState(() => _error = 'Número inválido. Inclua o DDD (ex.: 11 91234-5678).');
      return;
    }
    setState(() => _error = null);
    final ok = await launchUrl(
      WhatsappLink.build(digits, message: _messageCtrl.text),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')));
      }
      return;
    }
    await _saveRecent([digits, ..._recent.where((r) => r != digits)].take(_maxRecent).toList());
  }

  Future<void> _editCountryCode() async {
    final ctrl = TextEditingController(text: _countryCode);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código do país (DDI)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '+', helperText: 'Usado quando o número é digitado sem "+"'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _countryCode = result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKey, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp rápido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Converse com um número sem salvá-lo nos contatos.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _numberCtrl,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\- ]'))],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Número',
              hintText: '(11) 91234-5678',
              border: const OutlineInputBorder(),
              errorText: _error,
              prefixIcon: TextButton(onPressed: _editCountryCode, child: Text('+$_countryCode')),
              suffixIcon: IconButton(tooltip: 'Colar', icon: const Icon(Icons.content_paste), onPressed: _paste),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Mensagem (opcional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(icon: const Icon(Icons.chat), label: const Text('Abrir conversa'), onPressed: _open),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Recentes', style: theme.textTheme.titleSmall)),
                TextButton(onPressed: () => _saveRecent([]), child: const Text('Limpar')),
              ],
            ),
            for (final r in _recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(WhatsappLink.format(r)),
                onTap: () => _open('+$r'),
                trailing: IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close),
                  onPressed: () => _saveRecent(_recent.where((x) => x != r).toList()),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
