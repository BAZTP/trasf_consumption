import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:transf_consumption/services/notification_parser.dart';

export 'package:transf_consumption/services/notification_parser.dart';

/// Servicio encargado de la comunicación con el NotificationListenerService nativo de Android
class NotificationService {
  static const MethodChannel _channel =
      MethodChannel('com.baztp.transf_consumption/notifications');

  static final StreamController<TransactionData> _controller =
      StreamController<TransactionData>.broadcast();

  /// Stream de eventos de transacciones detectadas en tiempo real
  static Stream<TransactionData> get onTransactionDetected => _controller.stream;

  /// Inicializa los escuchadores del MethodChannel
  static Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotificationReceived':
          final Map<dynamic, dynamic>? args = call.arguments;
          if (args != null) {
            final packageName = args['packageName'] as String?;
            final title = args['title'] as String?;
            final text = args['text'] as String?;

            debugPrint('Notificación recibida: pkg=$packageName, title=$title, text=$text');

            final parsed = NotificationParser.parse(packageName, title, text);
            if (parsed != null) {
              _controller.add(parsed);
            }
          }
          break;
        default:
          debugPrint('Método no implementado en Flutter: ${call.method}');
      }
    });
  }

  /// Verifica si el permiso para escuchar notificaciones está concedido
  static Future<bool> isPermissionGranted() async {
    try {
      final bool granted =
          await _channel.invokeMethod('isPermissionGranted') ?? false;
      return granted;
    } on PlatformException catch (e) {
      debugPrint('Error al verificar permisos de notificación: $e');
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Abre la pantalla del sistema operativo para otorgar permiso de lectura de notificaciones
  static Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (e) {
      debugPrint('Error al abrir configuración de permisos: $e');
    }
  }

  /// Permite simular una notificación para pruebas rápidas
  static void simulateTransaction({
    required double amount,
    String? merchant,
    String type = 'Transferencia',
    String rawText = 'Prueba manual simulada',
  }) {
    final data = TransactionData(
      amount: amount,
      merchant: merchant,
      type: type,
      rawText: rawText,
    );
    _controller.add(data);
  }
}
