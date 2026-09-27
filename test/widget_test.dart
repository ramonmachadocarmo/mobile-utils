import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_utils/features/call_blocker/phone_utils.dart';
import 'package:mobile_utils/main.dart';

void main() {
  testWidgets('home lista o bloqueio de chamadas', (tester) async {
    await tester.pumpWidget(const MobileUtilsApp());
    expect(find.text('OmniTool'), findsWidgets); // splash + app bar
    // Espera a splash sumir (o timer começa após o primeiro quadro).
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('All-In-One Mobile Utilities'), findsNothing);
    expect(find.text('Bloqueio de chamadas'), findsOneWidget);
  });

  group('PhoneUtils.matches', () {
    test('mesmo número em formatos diferentes', () {
      expect(PhoneUtils.matches('+55 (11) 91234-5678', '11912345678'), isTrue);
      expect(PhoneUtils.matches('011 91234-5678', '+5511912345678'), isTrue);
      expect(PhoneUtils.matches('91234-5678', '+55 11 91234-5678'), isTrue);
    });

    test('números diferentes ou curtos demais', () {
      expect(PhoneUtils.matches('11912345678', '11912345679'), isFalse);
      expect(PhoneUtils.matches('5678', '11912345678'), isFalse);
      expect(PhoneUtils.matches('', '11912345678'), isFalse);
    });
  });
}
