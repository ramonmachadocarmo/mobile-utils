import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_utils/features/noise_meter/noise_math.dart';
import 'package:mobile_utils/features/quick_whatsapp/whatsapp_link.dart';

Uint8List _pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('NoiseMath', () {
    test('silêncio vai para o piso', () {
      expect(NoiseMath.dbfsFromPcm16(_pcm(List.filled(100, 0))), NoiseMath.floorDbfs);
      expect(NoiseMath.dbfsFromPcm16(Uint8List(0)), NoiseMath.floorDbfs);
    });

    test('onda quadrada no máximo ≈ 0 dBFS; metade ≈ -6 dBFS', () {
      final full = _pcm([for (var i = 0; i < 100; i++) i.isEven ? 32767 : -32768]);
      expect(NoiseMath.dbfsFromPcm16(full), closeTo(0, 0.01));
      final half = _pcm([for (var i = 0; i < 100; i++) i.isEven ? 16384 : -16384]);
      expect(NoiseMath.dbfsFromPcm16(half), closeTo(-6.02, 0.01));
    });

    test('senoide cheia ≈ -3 dBFS', () {
      final sine = _pcm([for (var i = 0; i < 4410; i++) (32767 * math.sin(2 * math.pi * 441 * i / 44100)).round()]);
      expect(NoiseMath.dbfsFromPcm16(sine), closeTo(-3.01, 0.05));
    });

    test('byte solto no fim é ignorado', () {
      final bytes = Uint8List.fromList([
        ..._pcm([16384, -16384]),
        7,
      ]);
      expect(NoiseMath.dbfsFromPcm16(bytes), closeTo(-6.02, 0.01));
    });

    test('média energética pesa mais os picos', () {
      expect(NoiseMath.energyAverage([60, 60]), closeTo(60, 0.001));
      expect(NoiseMath.energyAverage([40, 80]), closeTo(77, 0.1));
      expect(NoiseMath.energyAverage([]), 0);
    });

    test('descrição por faixa', () {
      expect(NoiseReference.describe(10), 'Muito silencioso');
      expect(NoiseReference.describe(62), 'Conversa normal');
      expect(NoiseReference.describe(130), NoiseReference.all.last.label);
    });
  });

  group('WhatsappLink', () {
    test('normaliza números brasileiros e estrangeiros', () {
      expect(WhatsappLink.normalize('(11) 91234-5678', '55'), '5511912345678');
      expect(WhatsappLink.normalize('+55 11 91234-5678', '55'), '5511912345678');
      expect(WhatsappLink.normalize('+1 212 555 0100', '55'), '12125550100');
      expect(WhatsappLink.normalize('91234-5678', '55'), isNull); // sem DDD
      expect(WhatsappLink.normalize('', '55'), isNull);
    });

    test('link com mensagem codificada', () {
      expect(WhatsappLink.build('5511912345678').toString(), 'https://wa.me/5511912345678');
      expect(
        WhatsappLink.build('5511912345678', message: ' Olá, tudo bem? ').toString(),
        'https://wa.me/5511912345678?text=Ol%C3%A1%2C%20tudo%20bem%3F',
      );
    });

    test('formata para exibição', () {
      expect(WhatsappLink.format('5511912345678'), '+55 (11) 91234-5678');
      expect(WhatsappLink.format('551132345678'), '+55 (11) 3234-5678');
      expect(WhatsappLink.format('12125550100'), '+12125550100');
    });
  });
}
