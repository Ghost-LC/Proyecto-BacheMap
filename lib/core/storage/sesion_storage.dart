import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sesion guardada en almacenamiento seguro del dispositivo (JWT + datos basicos).
class Sesion {
  final String token;
  final int idUsuario;
  final String nombre;
  final String rol;

  const Sesion({
    required this.token,
    required this.idUsuario,
    required this.nombre,
    required this.rol,
  });

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
        token: json['access_token'] as String,
        idUsuario: json['id_usuario'] as int,
        nombre: json['nombre'] as String,
        rol: json['rol'] as String,
      );
}

class SesionStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kToken = 'token';
  static const String _kId = 'id_usuario';
  static const String _kNombre = 'nombre';
  static const String _kRol = 'rol';

  /// Cache sincrono que usa el interceptor de dio para adjuntar el token.
  static String? tokenCache;

  static Future<Sesion?> leer() async {
    try {
      final token = await _storage.read(key: _kToken);
      if (token == null) return null;
      tokenCache = token;
      return Sesion(
        token: token,
        idUsuario: int.tryParse(await _storage.read(key: _kId) ?? '') ?? 0,
        nombre: await _storage.read(key: _kNombre) ?? '',
        rol: await _storage.read(key: _kRol) ?? '',
      );
    } catch (_) {
      // Entorno de pruebas o almacenamiento no disponible
      tokenCache = null;
      return null;
    }
  }

  static Future<void> guardar(Sesion sesion) async {
    await _storage.write(key: _kToken, value: sesion.token);
    await _storage.write(key: _kId, value: sesion.idUsuario.toString());
    await _storage.write(key: _kNombre, value: sesion.nombre);
    await _storage.write(key: _kRol, value: sesion.rol);
    tokenCache = sesion.token;
  }

  static Future<void> limpiar() async {
    try {
      await _storage.delete(key: _kToken);
      await _storage.delete(key: _kId);
      await _storage.delete(key: _kNombre);
      await _storage.delete(key: _kRol);
    } catch (_) {}
    tokenCache = null;
  }
}
