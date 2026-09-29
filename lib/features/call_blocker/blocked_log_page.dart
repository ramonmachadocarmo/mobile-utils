import 'package:flutter/material.dart';

import 'call_blocker_channel.dart';
import 'call_blocker_config.dart';

class BlockedLogPage extends StatefulWidget {
  const BlockedLogPage({super.key});

  @override
  State<BlockedLogPage> createState() => _BlockedLogPageState();
}

class _BlockedLogPageState extends State<BlockedLogPage> {
  List<BlockedCallLogEntry>? _log;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await CallBlockerChannel.getLog();
    setState(() => _log = log);
  }

  String _format(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloqueadas (últimos 7 dias)'),
        actions: [
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: log == null || log.isEmpty
                ? null
                : () async {
                    await CallBlockerChannel.clearLog();
                    await _load();
                  },
          ),
        ],
      ),
      body: log == null
          ? const Center(child: CircularProgressIndicator())
          : log.isEmpty
              ? const Center(child: Text('Nenhuma chamada bloqueada nos últimos 7 dias.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: log.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = log[i];
                      return ListTile(
                        leading: const Icon(Icons.call_end, color: Colors.red),
                        title: Text(e.number.isEmpty ? 'Número oculto' : e.number),
                        subtitle: Text(e.smsSent ? '${e.reason} · respondida por SMS' : e.reason),
                        trailing: Text(_format(e.timestamp)),
                      );
                    },
                  ),
                ),
    );
  }
}
