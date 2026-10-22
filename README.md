# 📱 TransfConsumption

Aplicación móvil desarrollada en Flutter para Android que detecta automáticamente notificaciones de transferencias y consumos bancarios (ej. Banco Pichincha, Deuna, etc.), muestra un diálogo flotante rápido para categorizar el gasto y genera estadísticas y reportes detallados en tiempo real.

---

## ✨ Características Principales

1. **Detección Automática de Notificaciones**:
   - Integración nativa con `NotificationListenerService` en Android.
   - Algoritmo inteligente que extrae monto, comercio/destinatario y tipo de transacción.
   - Filtro de seguridad que descarta códigos OTP y mensajes de inicio de sesión.

2. **Categorización Inmediata ("¿De qué fue?")**:
   - Popup interactivo estilo modal al detectar una transferencia.
   - Categorías preconfiguradas con colores e iconos:
     - 🚗 **Transporte**
     - 🍔 **Comida**
     - 🛒 **Compras**
     - 🏠 **Hogar**
     - 💊 **Salud**
     - 🎮 **Entretenimiento**
     - 📚 **Educación**
     - 🧾 **Servicios**
     - ➕ **Otros**
   - Campo para notas personalizadas.

3. **Dashboard & Estadísticas**:
   - Total gastado en el mes, promedio diario y conteo de transacciones.
   - Gráfico de dona (`fl_chart`) interactivo por categorías.
   - Gráfico de barras por semana, mes y año.
   - Ranking de los comercios donde más gastas.

4. **Historial Completo de Consumos**:
   - Filtros rápidos por fecha (Hoy, Esta semana, Este mes, Todas) y categoría.
   - Búsqueda en tiempo real por comercio o notas.
   - Edición y eliminación (deslizar para borrar).
   - Registro manual de gastos cuando pagas en efectivo.

5. **Privacidad y Exportación**:
   - Base de datos local SQLite con `sqflite`. Ningún dato sale de tu teléfono.
   - Exportación de todo el historial a formato CSV / Excel mediante el botón de compartir.
   - Función para simular notificaciones bancarias con 1 clic para pruebas.

---

## 🛠️ Requisitos de Android

Para que la app pueda leer las notificaciones de tu banco:
1. Al abrir la app, ve a la pestaña **Ajustes**.
2. Presiona en **Acceso a Notificaciones** -> Activar.
3. El sistema Android abrirá la pantalla de configuración; busca **TransfConsumption** y activa el interruptor.

---

## 🚀 Cómo ejecutar en desarrollo

```bash
# Obtener dependencias
flutter pub get

# Ejecutar pruebas unitarias
flutter test

# Compilar / Ejecutar en tu teléfono Android conectado o emulador
flutter run
```

---

## 📦 Estructura del Proyecto

```text
lib/
├── database/
│   └── database_helper.dart      # Singleton SQLite (transacciones y categorías)
├── models/
│   ├── category_model.dart       # Modelo de categoría con colores e iconos
│   └── transaction_model.dart    # Modelo de transacción
├── providers/
│   └── transaction_provider.dart # Estado global reactivo
├── screens/
│   ├── home_screen.dart          # Dashboard principal con métricas del mes
│   ├── settings_screen.dart      # Configuración, simulación y exportación CSV
│   ├── statistics_screen.dart    # Gráficos de dona y barras con fl_chart
│   └── transactions_screen.dart  # Lista de transacciones con filtros y búsqueda
├── services/
│   ├── notification_parser.dart  # Regex y heurística de texto bancario
│   └── notification_service.dart # Canal de comunicación nativo Android <-> Flutter
└── main.dart                     # Entrada principal y selector modal
```
