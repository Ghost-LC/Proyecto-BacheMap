/// Configuracion de conexion con el backend.
///
/// La URL base se puede cambiar en tiempo de compilacion sin tocar codigo:
///   flutter run --dart-define=API_BASE=http://192.168.0.14:8000
///
/// - Dispositivo real por USB con `adb reverse tcp:8000 tcp:8000`:
///   http://127.0.0.1:8000
/// - Emulador Android: http://10.0.2.2:8000
/// - Dispositivo real por WiFi: http://IP_DE_LA_PC:8000
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.138:8000',
  );
}
