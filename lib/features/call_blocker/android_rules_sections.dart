import 'package:flutter/material.dart';

import 'call_blocker_config.dart';

const _dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String describeDays(List<int> days) {
  final sorted = [...days]..sort();
  if (sorted.length == 7) return 'todos os dias';
  if (sorted.isEmpty) return 'nenhum dia';
  if (sorted.join() == '12345') return 'seg a sex';
  if (sorted.join() == '67') return 'fins de semana';
  return sorted.map((d) => _dayNames[d - 1].toLowerCase()).join(', ');
}

/// Horário de silêncio: rejeita chamadas num intervalo do dia (só Android).
class QuietHoursSection extends StatelessWidget {
  const QuietHoursSection({
    super.key,
    required this.quietHours,
    required this.enabled,
    required this.onChanged,
    required this.onAllowContacts,
  });

  final QuietHours quietHours;

  /// Falso quando o bloqueio como um todo está desligado.
  final bool enabled;
  final ValueChanged<QuietHours> onChanged;

  /// Ligar "permitir contatos" precisa da permissão de contatos.
  final ValueChanged<bool> onAllowContacts;

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final current = start ? quietHours.start : quietHours.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: start ? 'Início do silêncio' : 'Fim do silêncio',
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    onChanged(start ? quietHours.copyWith(start: minutes) : quietHours.copyWith(end: minutes));
  }

  @override
  Widget build(BuildContext context) {
    final q = quietHours;
    final activeNow = q.isActiveAt(DateTime.now());
    final range = q.start == q.end ? 'O dia inteiro' : '${formatMinutes(q.start)} às ${formatMinutes(q.end)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.bedtime_outlined),
          title: const Text('Horário de silêncio'),
          subtitle: Text(
            q.enabled
                ? '$range · ${describeDays(q.days)}${enabled && activeNow ? ' · ativo agora' : ''}'
                : 'Rejeita chamadas num horário, como um "não perturbe"',
          ),
          value: q.enabled,
          onChanged: enabled ? (v) => onChanged(q.copyWith(enabled: v)) : null,
        ),
        if (q.enabled) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Início ${formatMinutes(q.start)}'),
                    onPressed: enabled ? () => _pickTime(context, start: true) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alarm),
                    label: Text('Fim ${formatMinutes(q.end)}'),
                    onPressed: enabled ? () => _pickTime(context, start: false) : null,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_dayNames[d - 1]),
                    selected: q.days.contains(d),
                    onSelected: enabled
                        ? (on) => onChanged(
                            q.copyWith(days: on ? ([...q.days, d]..sort()) : q.days.where((x) => x != d).toList()),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (q.start > q.end)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Atravessa a meia-noite: os dias marcados são os do início.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SwitchListTile(
            title: const Text('Permitir contatos'),
            subtitle: const Text('Quem está na agenda consegue ligar'),
            value: q.allowContacts,
            onChanged: enabled ? onAllowContacts : null,
          ),
          SwitchListTile(
            title: const Text('Permitir ligações repetidas'),
            subtitle: Text(
              'Se a mesma pessoa ligar de novo em até ${QuietHours.repeatWindow.inMinutes} minutos, '
              'a chamada passa (para urgências)',
            ),
            value: q.allowRepeated,
            onChanged: enabled ? (v) => onChanged(q.copyWith(allowRepeated: v)) : null,
          ),
        ],
      ],
    );
  }
}

/// Resposta automática por SMS a quem foi bloqueado (só Android).
class SmsReplySection extends StatelessWidget {
  const SmsReplySection({
    super.key,
    required this.smsReply,
    required this.enabled,
    required this.onChanged,
    required this.onToggle,
  });

  final SmsReply smsReply;
  final bool enabled;
  final ValueChanged<SmsReply> onChanged;

  /// Ligar a resposta precisa da permissão de SMS.
  final ValueChanged<bool> onToggle;

  Future<void> _editMessage(BuildContext context) async {
    final ctrl = TextEditingController(text: smsReply.message);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mensagem do SMS'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 4, minLines: 2, maxLength: 300),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onChanged(smsReply.copyWith(message: result));
  }

  @override
  Widget build(BuildContext context) {
    final s = smsReply;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.sms_outlined),
          title: const Text('Responder por SMS'),
          subtitle: Text(
            'Envia uma mensagem a quem foi bloqueado (no máximo uma a cada '
            '${SmsReply.cooldown.inHours} h por número). Pode ter custo da operadora.',
          ),
          value: s.enabled,
          onChanged: enabled ? onToggle : null,
        ),
        if (s.enabled) ...[
          ListTile(
            title: const Text('Mensagem'),
            subtitle: Text(s.message),
            trailing: const Icon(Icons.edit),
            enabled: enabled,
            onTap: () => _editMessage(context),
          ),
          SwitchListTile(
            title: const Text('Só no horário de silêncio'),
            subtitle: Text(
              s.onlyQuietHours
                  ? 'Números da lista, prefixos e desconhecidos não recebem resposta'
                  : 'Responde qualquer chamada bloqueada, exceto números ocultos',
            ),
            value: s.onlyQuietHours,
            onChanged: enabled ? (v) => onChanged(s.copyWith(onlyQuietHours: v)) : null,
          ),
        ],
      ],
    );
  }
}
