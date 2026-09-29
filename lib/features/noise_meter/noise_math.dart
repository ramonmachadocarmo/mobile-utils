import 'dart:math' as math;
import 'dart:typed_data';

/// Cálculos do medidor de ruído, separados da tela para dar para testar.
class NoiseMath {
  NoiseMath._();

  /// Piso de leitura em dBFS (silêncio digital não vira -infinito).
  static const floorDbfs = -100.0;

  /// Nível em dBFS (0 = volume máximo do microfone) da média quadrática (RMS)
  /// de amostras PCM 16 bits little-endian. Um byte solto no fim é ignorado.
  static double dbfsFromPcm16(Uint8List bytes) {
    final samples = bytes.length ~/ 2;
    if (samples == 0) return floorDbfs;
    return dbfsFromMeanSquare(sumSquaresPcm16(bytes) / samples);
  }

  /// Soma dos quadrados das amostras normalizadas (-1..1), para acumular
  /// vários pedaços do stream antes de calcular o nível.
  static double sumSquaresPcm16(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final samples = bytes.length ~/ 2;
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    return sum;
  }

  static double dbfsFromMeanSquare(double meanSquare) {
    if (meanSquare <= 0) return floorDbfs;
    return math.max(floorDbfs, 10 * math.log(meanSquare) / math.ln10);
  }

  /// Média energética (Leq) de leituras em dB: 10·log10(média de 10^(L/10)).
  /// É como os decibelímetros calculam a média; a média aritmética dos dB
  /// subestimaria picos de barulho.
  static double energyAverage(Iterable<double> levels) {
    var sum = 0.0;
    var n = 0;
    for (final l in levels) {
      sum += math.pow(10, l / 10);
      n++;
    }
    if (n == 0) return 0;
    return 10 * math.log(sum / n) / math.ln10;
  }
}

/// Referências para leigos (valores aproximados, em dB SPL).
class NoiseReference {
  const NoiseReference(this.db, this.label);
  final double db;
  final String label;

  static const all = [
    NoiseReference(30, 'Sussurro, quarto silencioso'),
    NoiseReference(45, 'Biblioteca, geladeira'),
    NoiseReference(60, 'Conversa normal'),
    NoiseReference(70, 'Aspirador de pó, trânsito'),
    NoiseReference(85, 'Liquidificador; limite para 8 h de exposição'),
    NoiseReference(100, 'Show, moto acelerando'),
    NoiseReference(120, 'Sirene de perto, limiar da dor'),
  ];

  /// Descrição do nível [db] (a maior referência que não passa de [db]).
  static String describe(double db) {
    if (db < all.first.db) return 'Muito silencioso';
    return all.lastWhere((r) => r.db <= db).label;
  }
}
