/// Datos extraídos de una notificación bancaria o de pago.
class TransactionData {
  final double amount;
  final String? merchant;
  final String type; // 'Transferencia', 'Consumo / Compra', 'Retiro', 'Débito'
  final String rawText;
  final String? packageName;
  final DateTime timestamp;

  TransactionData({
    required this.amount,
    this.merchant,
    required this.type,
    required this.rawText,
    this.packageName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'merchant': merchant,
      'type': type,
      'rawText': rawText,
      'packageName': packageName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Analizador de notificaciones bancarias (Banco Pichincha, Deuna, Pacífico, Guayaquil, etc.)
class NotificationParser {
  /// Lista de palabras clave que descartan notificaciones informativas o de seguridad
  static final List<String> _ignoreKeywords = [
    'código de seguridad',
    'codigo de seguridad',
    'otp',
    'contraseña',
    'clave temporal',
    'código de verificación',
    'inicio de sesión',
    'actualización de términos',
  ];

  /// Analiza el texto y título de una notificación y extrae la información si corresponde a un gasto/transferencia.
  static TransactionData? parse(String? packageName, String? title, String? text) {
    if (text == null || text.trim().isEmpty) return null;

    final fullContent = '${title ?? ""} $text'.trim();
    final lower = fullContent.toLowerCase();

    // 1. Descartar notificaciones irrelevantes o de autenticación
    for (final ignored in _ignoreKeywords) {
      if (lower.contains(ignored)) {
        return null;
      }
    }

    // 2. Extraer el monto ($5.50, $ 5,50, USD 12.30, 15.00 USD)
    final amount = _extractAmount(fullContent);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 3. Determinar el tipo de transacción
    final type = _detectType(lower);

    // 4. Determinar el comercio o destinatario
    final merchant = _extractMerchant(fullContent, lower);

    return TransactionData(
      amount: amount,
      merchant: merchant,
      type: type,
      rawText: fullContent,
      packageName: packageName,
    );
  }

  /// Extrae el valor numérico del monto de la notificación
  static double? _extractAmount(String content) {
    // Patrones comunes:
    // \$ ?\d+([\.,]\d{2})?
    // USD ?\d+([\.,]\d{2})?
    // por valor de \$?12.50
    final patterns = [
      RegExp(r'(?:\$|USD)\s*([0-9]+(?:[\.,][0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'([0-9]+(?:[\.,][0-9]{2}))\s*(?:USD|\$)', caseSensitive: false),
      RegExp(r'(?:por|monto|valor|total)(?:\s+de)?\s*(?:\$|USD)?\s*([0-9]+(?:[\.,][0-9]{1,2})?)', caseSensitive: false),
    ];

    for (final reg in patterns) {
      final match = reg.firstMatch(content);
      if (match != null) {
        String numStr = match.group(1)!;
        // Normalizar coma a punto si es separador decimal
        numStr = numStr.replaceAll(',', '.');
        final val = double.tryParse(numStr);
        if (val != null && val > 0) {
          return val;
        }
      }
    }

    return null;
  }

  /// Detecta el tipo de transacción
  static String _detectType(String textLower) {
    if (textLower.contains('transfer') || textLower.contains('transferencia')) {
      return 'Transferencia';
    }
    if (textLower.contains('compra') || textLower.contains('consumo') || textLower.contains('pago')) {
      return 'Consumo / Compra';
    }
    if (textLower.contains('retiro')) {
      return 'Retiro';
    }
    if (textLower.contains('débito') || textLower.contains('debito')) {
      return 'Débito';
    }
    return 'Gasto / Transferencia';
  }

  /// Intenta extraer el nombre del comercio o persona
  static String? _extractMerchant(String raw, String lower) {
    // "en SUPERMAXI por $..." o "a JUAN PEREZ por $..." o "en FARMACIAS FYBECA"
    final merchantPatterns = [
      RegExp(r'(?:en|comercio|establecimiento)\s+([A-Za-z0-9\s\.\-_&]+?)(?:\s+por|\s+el|\s+valor|\s*\$|\s*USD|$)', caseSensitive: false),
      RegExp(r'(?:a|para|beneficiario)\s+([A-Za-z0-9\s\.\-_&]+?)(?:\s+por|\s+el|\s+valor|\s*\$|\s*USD|$)', caseSensitive: false),
    ];

    for (final reg in merchantPatterns) {
      final match = reg.firstMatch(raw);
      if (match != null) {
        String candidate = match.group(1)!.trim();
        // Limpiar palabras residuales comunes
        candidate = candidate.replaceAll(RegExp(r'^(el|la|los|las)\s+', caseSensitive: false), '');
        if (candidate.isNotEmpty && candidate.length > 2 && candidate.length < 50) {
          return candidate;
        }
      }
    }

    return null;
  }
}
