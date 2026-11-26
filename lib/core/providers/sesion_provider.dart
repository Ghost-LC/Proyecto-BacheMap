import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../storage/acceso_offline.dart';
import '../storage/sesion_storage.dart';

/// Estado de la sesion (null = sin iniciar).
class SesionNotifier extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() async {
    final sesion = await SesionStorage.leer();
    if (sesion == null) return null;
    try {
      final respuesta = await dio.get('/api/acceso/yo');
      final usuario = Map<String, dynamic>.from(respuesta.data);
      if (usuario['id_usuario'] != sesion.idUsuario ||
          usuario['rol'] != sesion.rol) {
        await SesionStorage.limpiar();
        return null;
      }
      return sesion;
    } catch (_) {
      // Sin confirmación del servidor no se restaura automáticamente.
      // El acceso local requiere desbloqueo explícito con PIN.
      await SesionStorage.limpiar();
      return null;
    }
  }

  /// RF-037 · login con correo y contrasena.
  Future<void> iniciar(String correo, String contrasena) async {
    final respuesta = await dio.post(
      '/api/acceso/login',
      data: {'correo': correo, 'contrasena': contrasena},
    );
    final sesion = Sesion.fromJson(Map<String, dynamic>.from(respuesta.data));
    await SesionStorage.guardar(sesion);
    try {
      await AccesoOffline.actualizarSesion(sesion);
    } catch (_) {
      // El acceso online no depende del perfil local opcional.
    }
    state = AsyncData(sesion);
  }

  /// PIN solo si no es posible contactar el servidor; nunca sustituye un 401/403.
  Future<void> iniciarSinConexion(String pin) async {
    try {
      await dio.get('/api/salud', options: Options(
        sendTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        validateStatus: (_) => true,
      ));
      throw StateError('El servidor está disponible. Inicia sesión con tu correo y contraseña.');
    } on DioException catch (e) {
      if (e.response != null || ![
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionError,
      ].contains(e.type)) {
        throw StateError('No se pudo comprobar la disponibilidad del servidor. Intenta de nuevo.');
      }
    }
    final sesion = await AccesoOffline.desbloquear(pin);
    await SesionStorage.guardar(sesion);
    state = AsyncData(sesion);
  }

  /// RF-036 · registro de ciudadano + acceso automatico.
  Future<void> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    await dio.post(
      '/api/acceso/registro',
      data: {'nombre': nombre, 'correo': correo, 'contrasena': contrasena},
    );
    await iniciar(correo, contrasena);
  }

  /// Cierra la sesion en el dispositivo.
  Future<void> cerrar() async {
    await SesionStorage.limpiar();
    state = const AsyncData(null);
  }
}

final sesionProvider =
    AsyncNotifierProvider<SesionNotifier, Sesion?>(SesionNotifier.new);
