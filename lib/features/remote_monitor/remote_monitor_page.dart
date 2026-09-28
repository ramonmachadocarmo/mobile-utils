import 'package:flutter/material.dart';

import 'monitor_firebase.dart';
import 'receiver_page.dart';
import 'transmitter_page.dart';

/// Entrada do monitoramento remoto: explica o que será compartilhado e deixa
/// escolher o papel do aparelho. A transparência é proposital — o recurso é
/// para acompanhar os próprios filhos, com o celular em mãos e o consentimento
/// deles, nunca de forma oculta.
class RemoteMonitorPage extends StatelessWidget {
  const RemoteMonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoramento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como funciona',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Um aparelho transmite câmera, microfone e tela; o outro assiste. '
                    'Enquanto está transmitindo, o aparelho monitorado mostra um aviso '
                    'permanente na tela e na barra de notificações. Use apenas em '
                    'aparelhos seus e com quem está sendo monitorado sabendo.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: Icons.cast_connected,
            title: 'Este aparelho será transmitido',
            subtitle: 'Câmera, microfone e tela ficam visíveis para o outro celular',
            onTap: () => _open(context, const TransmitterPage()),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.monitor,
            title: 'Assistir a outro aparelho',
            subtitle: 'Digite o código mostrado no aparelho transmissor',
            onTap: () => _open(context, const ReceiverPage()),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ready = await ensureFirebaseReady();
    if (!ready) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Firebase não configurado. Veja a seção Monitoramento no README.'),
      ));
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
