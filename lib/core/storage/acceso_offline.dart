import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import 'sesion_storage.dart';

/// Un perfil por dispositivo, habilitado solo después de autenticarlo online.
/// El PIN nunca se guarda; el registro completo reside en almacenamiento seguro.
class AccesoOffline {
  static const _storage = FlutterSecureStorage();
  static const _clave = 'acceso_offline_v1';
  static const _maxIntentos = 5;
  static final _derivador = Pbkdf2(
      macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256);

  static Future<Map<String, dynamic>?> _leer() async {
    final texto = await _storage.read(key: _clave);
    if (texto == null) return null;
    return Map<String, dynamic>.from(jsonDecode(texto) as Map);
  }

  static Future<void> _guardar(Map<String, dynamic> datos) =>
      _storage.write(key: _clave, value: jsonEncode(datos));

  static Future<List<int>> _derivar(String pin, List<int> sal) async {
    final clave = await _derivador.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)), nonce: sal);
    return clave.extractBytes();
  }

  static bool _iguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diferencia = 0;
    for (var i = 0; i < a.length; i++) {
      diferencia |= a[i] ^ b[i];
    }
    return diferencia == 0;
  }

  static Future<String?> nombreDisponible() async {
    final datos = await _leer();
    if (datos == null || datos['servidor'] != ApiConfig.baseUrl) return null;
    return datos['nombre'] as String;
  }

  static Future<void> configurar(Sesion sesion, String pin) async {
    if (sesion.rol != 'ciudadano' || sesion.idUsuario <= 0) {
      throw StateError('Solo una cuenta ciudadana puede activar el acceso sin conexión.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw StateError('El PIN debe contener exactamente 6 dígitos.');
    }
    final azar = Random.secure();
    final sal = List<int>.generate(16, (_) => azar.nextInt(256));
    final hash = await _derivar(pin, sal);
    await _guardar({
      'servidor': ApiConfig.baseUrl,
      'id': sesion.idUsuario,
      'nombre': sesion.nombre,
      'rol': sesion.rol,
      'token': sesion.token,
      'sal': base64Encode(sal),
      'hash': base64Encode(hash),
      'intentos': 0,
    });
  }

  /// Actualiza el token solo si un login online corresponde al mismo perfil.
  static Future<void> actualizarSesion(Sesion sesion) async {
    final datos = await _leer();
    if (datos == null || datos['servidor'] != ApiConfig.baseUrl ||
        datos['id'] != sesion.idUsuario || sesion.rol != 'ciudadano') {
      return;
    }
    datos['token'] = sesion.token;
    datos['nombre'] = sesion.nombre;
    datos['intentos'] = 0;
    await _guardar(datos);
  }

  static Future<Sesion> desbloquear(String pin) async {
    final datos = await _leer();
    if (datos == null || datos['servidor'] != ApiConfig.baseUrl ||
        datos['rol'] != 'ciudadano') {
      throw StateError('No hay acceso sin conexión configurado para este servidor.');
    }
    if ((datos['intentos'] as int? ?? 0) >= _maxIntentos) {
      throw StateError('PIN bloqueado. Inicia sesión con internet para restablecerlo.');
    }
    final obtenido = await _derivar(pin, base64Decode(datos['sal'] as String));
    if (!_iguales(obtenido, base64Decode(datos['hash'] as String))) {
      final intentos = (datos['intentos'] as int? ?? 0) + 1;
      datos['intentos'] = intentos;
      await _guardar(datos);
      if (intentos >= _maxIntentos) {
        throw StateError('PIN bloqueado. Inicia sesión con internet para restablecerlo.');
      }
      throw StateError('PIN incorrecto. Quedan ${_maxIntentos - intentos} intentos.');
    }
    datos['intentos'] = 0;
    await _guardar(datos);
    return Sesion(
      token: datos['token'] as String,
      idUsuario: datos['id'] as int,
      nombre: datos['nombre'] as String,
      rol: datos['rol'] as String,
    );
  }

  static Future<void> eliminar() => _storage.delete(key: _clave);
}
