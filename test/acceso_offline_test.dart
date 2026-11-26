import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/core/storage/acceso_offline.dart';
import 'package:movil/core/storage/sesion_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ciudadano = Sesion(token: 'token-prueba', idUsuario: 17,
      nombre: 'Ciudadana', rol: 'ciudadano');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('configura el PIN y recupera únicamente la cuenta guardada', () async {
    await AccesoOffline.configurar(ciudadano, '123456');
    expect(await AccesoOffline.nombreDisponible(), 'Ciudadana');
    final sesion = await AccesoOffline.desbloquear('123456');
    expect(sesion.idUsuario, 17);
    expect(sesion.token, 'token-prueba');
    final contenido = await const FlutterSecureStorage().read(key: 'acceso_offline_v1');
    expect(contenido, isNot(contains('123456')));
  });

  test('solo permite un PIN válido y un rol ciudadano', () async {
    await expectLater(AccesoOffline.configurar(ciudadano, '123'),
        throwsA(isA<StateError>()));
    await expectLater(AccesoOffline.configurar(
        const Sesion(token: 't', idUsuario: 1, nombre: 'I', rol: 'inspector'),
        '123456'), throwsA(isA<StateError>()));
  });

  test('bloquea tras cinco intentos fallidos y el login online lo restablece', () async {
    await AccesoOffline.configurar(ciudadano, '123456');
    for (var i = 0; i < 5; i++) {
      await expectLater(AccesoOffline.desbloquear('000000'), throwsA(isA<StateError>()));
    }
    await expectLater(AccesoOffline.desbloquear('123456'), throwsA(isA<StateError>()));
    await AccesoOffline.actualizarSesion(ciudadano);
    expect((await AccesoOffline.desbloquear('123456')).idUsuario, 17);
  });

  test('cerrar sesión conserva el PIN y eliminarlo lo desactiva', () async {
    await AccesoOffline.configurar(ciudadano, '123456');
    await SesionStorage.guardar(ciudadano);
    await SesionStorage.limpiar();
    expect(await AccesoOffline.nombreDisponible(), 'Ciudadana');
    await AccesoOffline.eliminar();
    expect(await AccesoOffline.nombreDisponible(), isNull);
  });
}
