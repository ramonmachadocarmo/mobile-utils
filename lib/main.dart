import 'package:flutter/material.dart';

import 'features/call_blocker/call_blocker_page.dart';
import 'features/quick_notes/quick_notes_page.dart';
import 'features/remote_monitor/remote_monitor_page.dart';
import 'features/walkie_talkie/walkie_talkie_page.dart';
import 'features/quick_notes/quick_notes_store.dart';
import 'features/quick_notes/quick_notes_widget.dart';
import 'splash_overlay.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobileUtilsApp());
  // Mantém o widget da tela inicial em dia mesmo sem abrir as notas.
  QuickNotesStore().load().then(QuickNotesWidget.update);
}

class MobileUtilsApp extends StatelessWidget {
  const MobileUtilsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniTool',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      builder: (context, child) => SplashOverlay(child: child!),
      // Deep links: mobileutils://app/quick_notes?copy=<id> (widget do iOS e
      // cabeçalho do widget do Android).
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');
        final page = switch (uri.path) {
          '/quick_notes' => QuickNotesPage(copyId: uri.queryParameters['copy']),
          '/call_blocker' => const CallBlockerPage(),
          _ => const HomePage(),
        };
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}

class _Utility {
  const _Utility(this.title, this.description, this.icon, this.builder);
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Lista de utilitários do app. Novas funções entram aqui.
final _utilities = <_Utility>[
  _Utility(
    'Bloqueio de chamadas',
    'Rejeita desconhecidos e números escolhidos',
    Icons.phone_disabled,
    (_) => const CallBlockerPage(),
  ),
  _Utility(
    'Notas rápidas',
    'Textos para copiar com um toque',
    Icons.content_paste,
    (_) => const QuickNotesPage(),
  ),
  _Utility(
    'Monitoramento',
    'Transmite câmera, microfone e tela para outro aparelho',
    Icons.monitor,
    (_) => const RemoteMonitorPage(),
  ),
  _Utility(
    'Walkie-talkie',
    'Chamada de duas vias com câmera e microfone',
    Icons.record_voice_over,
    (_) => const WalkieTalkiePage(),
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OmniTool')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final u in _utilities)
            Card(
              child: ListTile(
                leading: Icon(u.icon, size: 32),
                title: Text(u.title),
                subtitle: Text(u.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: u.builder)),
              ),
            ),
        ],
      ),
    );
  }
}
