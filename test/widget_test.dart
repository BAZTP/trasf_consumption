import 'package:flutter_test/flutter_test.dart';
import 'package:transf_consumption/services/notification_parser.dart';

void main() {
  group('NotificationParser Tests', () {
    test('Detecta transferencia enviada de Banco Pichincha con coma decimal', () {
      const text = r'Transferencia exitosa de $5,50 enviada a JUAN PEREZ';
      final result = NotificationParser.parse('com.pichincha.movil', 'Banco Pichincha', text);

      expect(result, isNotNull);
      expect(result!.amount, 5.50);
      expect(result.type, 'Transferencia');
    });

    test('Detecta consumo en comercio con punto decimal', () {
      const text = r'Consumo aprobado en SUPERMAXI por $45.20 con tarjeta';
      final result = NotificationParser.parse('com.pichincha.movil', 'Banco Pichincha', text);

      expect(result, isNotNull);
      expect(result!.amount, 45.20);
      expect(result.type, 'Consumo / Compra');
      expect(result.merchant, contains('SUPERMAXI'));
    });

    test('Ignora notificaciones de códigos de seguridad OTP', () {
      const text = 'Tu código de seguridad para transferir es 839201. No lo compartas.';
      final result = NotificationParser.parse('com.pichincha.movil', 'Banco Pichincha', text);

      expect(result, isNull);
    });
  });
}
