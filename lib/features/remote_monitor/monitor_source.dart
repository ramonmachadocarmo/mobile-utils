/// Fonte de vídeo que o transmissor envia. O microfone vai sempre junto; o
/// receptor troca entre estas fontes pelos comandos do canal de controle.
enum MonitorSource {
  frontCamera('front', 'Câmera frontal'),
  backCamera('back', 'Câmera traseira'),
  screen('screen', 'Tela');

  const MonitorSource(this.id, this.label);

  final String id;
  final String label;

  static MonitorSource fromId(String id) =>
      MonitorSource.values.firstWhere((s) => s.id == id, orElse: () => MonitorSource.frontCamera);
}
