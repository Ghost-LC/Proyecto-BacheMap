import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/sesion_storage.dart';

/// Adjunta el token JWT a cada peticion si hay sesion activa (RF-039).
class _InterceptorToken extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = SesionStorage.tokenCache;
    if (!options.headers.containsKey('Authorization') && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Cliente HTTP compartido por todas las features.
Dio crearDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(_InterceptorToken());
  return dio;
}

final Dio dio = crearDio();

/// Mensaje amigable para la interfaz a partir de un error de la API.
String mensajeDeError(Object error) {
  if (error is DioException) {
    final datos = error.response?.data;
    if (datos is Map && datos['detail'] is String) {
      return datos['detail'] as String;
    }
    if (datos is List) {
      return 'Datos invalidos: revisa los campos marcados.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar con el servidor. Verifica que la API este '
          'ejecutandose y que el telefono este en la misma red.';
    }
    if (error.type == DioExceptionType.badResponse && error.response?.statusCode == 401) {
      return 'Sesion expirada. Vuelve a iniciar sesion.';
    }
    return 'Error de conexion (${error.type.name}).';
  }
  return 'Error inesperado: $error';
}
