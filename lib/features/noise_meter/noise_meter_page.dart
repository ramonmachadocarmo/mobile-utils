import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noise_math.dart';

/// Medidor de ruído pelo microfone. Mede em dBFS e soma um ajuste
/// (calibração) para aproximar dB SPL; celulares não são decibelímetros
/// certificados, então os valores são uma estimativa.
class NoiseMeterPage extends StatefulWidget {
  const NoiseMeterPage({super.key});

  @override
  State<NoiseMeterPage> createState() => _NoiseMeterPageState();
}

enum _Status { starting, measuring, paused, denied, error }

class _NoiseMeterPageState extends State<NoiseMeterPage> with WidgetsBindingObserver {
  static const _sampleRate = 44100;

  /// Uma leitura a cada 100 ms (parecido com a ponderação "fast" de 125 ms).
  static const _samplesPerReading = _sampleRate ~/ 10;

  /// 30 s de histórico no gráfico.
  static const _historyLength = 300;

  /// Primeiras leituras descartadas (o microfone costuma começar mudo).
  static const _warmupReadings = 3;

  /// dBFS + [_defaultOffset] ≈ dB SPL num celular típico.
  static const _defaultOffset = 90.0;
  static const _offsetKey = 'noise_meter_offset';

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  _Status _status = _Status.starting;
  double _offset = _defaultOffset;

  double _sumSquares = 0;
  int _samples = 0;
  int _readingsSinceStart = 0;

  double? _current;
  double? _min;
  double? _max;
  final List<double> _history = [];
  final List<double> _session = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // Solta o microfone em segundo plano e retoma ao voltar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _status == _Status.measuring) {
      _stop(_Status.starting);
    } else if (state == AppLifecycleState.resumed && (_status == _Status.starting || _status == _Status.denied)) {
      _start();
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _offset = prefs.getDouble(_offsetKey) ?? _defaultOffset;
    await _start();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) setState(() => _status = _Status.denied);
      return;
    }
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          // Sem processamento: ganho automático e supressão de ruído distorcem a medida.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
        ),
      );
      _sumSquares = 0;
      _samples = 0;
      _readingsSinceStart = 0;
      _sub = stream.listen(_onAudio, onError: (_) => _stop(_Status.error));
      if (mounted) setState(() => _status = _Status.measuring);
    } catch (_) {
      if (mounted) setState(() => _status = _Status.error);
    }
  }

  Future<void> _stop(_Status next) async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    if (mounted) setState(() => _status = next);
  }

  void _onAudio(Uint8List chunk) {
    _sumSquares += NoiseMath.sumSquaresPcm16(chunk);
    _samples += chunk.length ~/ 2;
    if (_samples < _samplesPerReading) return;

    final dbfs = NoiseMath.dbfsFromMeanSquare(_sumSquares / _samples);
    _sumSquares = 0;
    _samples = 0;
    if (++_readingsSinceStart <= _warmupReadings) return;

    final db = math.max(0.0, dbfs + _offset);
    if (!mounted) return;
    setState(() {
      _current = db;
      _min = _min == null ? db : math.min(_min!, db);
      _max = _max == null ? db : math.max(_max!, db);
      _history.add(db);
      if (_history.length > _historyLength) _history.removeAt(0);
      _session.add(db);
    });
  }

  void _reset() => setState(() {
    _current = null;
    _min = null;
    _max = null;
    _history.clear();
    _session.clear();
  });

  Future<void> _calibrate() async {
    var value = _offset - _defaultOffset;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calibração'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cada microfone capta de um jeito. Se tiver um decibelímetro de referência, '
                'ajuste até as leituras baterem.',
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)} dB',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Slider(value: value, min: -20, max: 20, divisions: 40, onChanged: (v) => setDialogState(() => value = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 0.0), child: const Text('Padrão')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _offset = _defaultOffset + result);
    _reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_offsetKey, _offset);
  }

  static Color levelColor(double db, ColorScheme scheme) {
    if (db >= 85) return scheme.error;
    if (db >= 70) return const Color(0xFFFD9704); // laranja da marca
    return Colors.green.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medidor de ruído'),
        actions: [IconButton(tooltip: 'Calibrar', icon: const Icon(Icons.tune), onPressed: _calibrate)],
      ),
      body: switch (_status) {
        _Status.denied => _Message(
          icon: Icons.mic_off,
          text: 'O medidor precisa do microfone. O áudio não é gravado nem enviado.',
          action: 'Abrir ajustes',
          onTap: openAppSettings,
        ),
        _Status.error => _Message(
          icon: Icons.error_outline,
          text: 'Não foi possível usar o microfone. Ele pode estar em uso por outro app.',
          action: 'Tentar de novo',
          onTap: _start,
        ),
        _ => _buildMeter(context),
      },
      floatingActionButton: _status == _Status.measuring || _status == _Status.paused
          ? FloatingActionButton(
              tooltip: _status == _Status.measuring ? 'Pausar' : 'Continuar',
              onPressed: _status == _Status.measuring ? () => _stop(_Status.paused) : _start,
              child: Icon(_status == _Status.measuring ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildMeter(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = _current;
    final color = current == null ? scheme.outline : levelColor(current, scheme);
    String fmt(double? v) => v == null ? '--' : v.toStringAsFixed(0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
      children: [
        Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: fmt(current),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 96,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' dB',
                  style: theme.textTheme.headlineSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Text(
            _status == _Status.paused
                ? 'Pausado'
                : current == null
                ? 'Medindo…'
                : NoiseReference.describe(current),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: current == null ? 0 : (current / 120).clamp(0.0, 1.0),
            minHeight: 12,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Stat(label: 'Mín.', value: fmt(_min)),
            _Stat(
              label: 'Média',
              value: _session.isEmpty ? '--' : NoiseMath.energyAverage(_session).toStringAsFixed(0),
            ),
            _Stat(label: 'Máx.', value: fmt(_max)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _HistoryPainter(
              history: _history,
              capacity: _historyLength,
              lineColor: scheme.primary,
              gridColor: scheme.outlineVariant,
              limitColor: scheme.error,
              labelStyle: theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('últimos 30 s', style: theme.textTheme.bodySmall),
            TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt), label: const Text('Zerar')),
          ],
        ),
        const Divider(),
        for (final r in NoiseReference.all.reversed)
          ListTile(
            dense: true,
            leading: SizedBox(
              width: 48,
              child: Text(
                '${r.db.toStringAsFixed(0)} dB',
                style: TextStyle(color: levelColor(r.db, scheme), fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(r.label),
            selected: current != null && NoiseReference.describe(current) == r.label,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Valores aproximados: o microfone do celular não é um decibelímetro certificado. '
            'Use "Calibrar" para ajustar. O áudio não é gravado.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.action, required this.onTap});
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de linha do histórico (0–120 dB), com a linha de 85 dB destacada.
class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.history,
    required this.capacity,
    required this.lineColor,
    required this.gridColor,
    required this.limitColor,
    required this.labelStyle,
  });

  final List<double> history;
  final int capacity;
  final Color lineColor;
  final Color gridColor;
  final Color limitColor;
  final TextStyle labelStyle;

  static const _maxDb = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double db) => size.height * (1 - (db / _maxDb).clamp(0.0, 1.0));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final db in [30.0, 60.0, 85.0, 120.0]) {
      final paint = db == 85
          ? (Paint()
              ..color = limitColor.withValues(alpha: 0.6)
              ..strokeWidth = 1)
          : grid;
      canvas.drawLine(Offset(0, y(db)), Offset(size.width, y(db)), paint);
      final tp = TextPainter(
        text: TextSpan(text: db.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, math.max(0, y(db) - tp.height)));
    }

    if (history.length < 2) return;
    final dx = size.width / (capacity - 1);
    final start = size.width - dx * (history.length - 1);
    final path = Path()..moveTo(start, y(history.first));
    for (var i = 1; i < history.length; i++) {
      path.lineTo(start + dx * i, y(history[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // A lista é mutada no lugar, então não dá para comparar com a anterior.
  @override
  bool shouldRepaint(_HistoryPainter old) => true;
}
