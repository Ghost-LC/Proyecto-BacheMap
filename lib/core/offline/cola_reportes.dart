import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../network/dio_client.dart';
import '../storage/sesion_storage.dart';

/// Cola persistente: cada operación pertenece a una cuenta y a un servidor.
/// Solo se sincroniza mientras la aplicación está en primer plano.
class ColaReportes with WidgetsBindingObserver {
  ColaReportes._();
  static final instancia = ColaReportes._();
  final cambios = ValueNotifier<int>(0);
  Future<Database>? _apertura;
  Timer? _timer;
  bool _sincronizando = false;
  bool _activa = true;

  Future<Database> get _db => _apertura ??= _abrir().catchError((Object error) {
    _apertura = null;
    throw error;
  });

  Future<Database> _abrir() async {
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(p.join(dir.path, 'reportes_offline.db'), version: 1,
        onCreate: (db, _) async {
      await db.execute('''CREATE TABLE pendientes (
        id TEXT PRIMARY KEY, servidor TEXT NOT NULL, usuario INTEGER NOT NULL,
        datos TEXT NOT NULL, fotos TEXT NOT NULL, estado TEXT NOT NULL,
        error TEXT, intentos INTEGER NOT NULL DEFAULT 0,
        creado TEXT NOT NULL, id_remoto INTEGER
      )''');
      await db.execute('''CREATE TABLE catalogos (
        servidor TEXT PRIMARY KEY, datos TEXT NOT NULL
      )''');
    });
  }

  void iniciar() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_activa) unawaited(sincronizar());
    });
    unawaited(sincronizar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activa = state == AppLifecycleState.resumed;
    if (_activa) unawaited(sincronizar());
  }

  void _notificar() => cambios.value++;

  Future<List<Map<String, dynamic>>> categorias() async {
    try {
      final r = await dio.get('/api/administracion/categorias');
      final lista = (r.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      await (await _db).insert('catalogos',
          {'servidor': ApiConfig.baseUrl, 'datos': jsonEncode(lista)},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return lista.where((c) => c['habilitada'] == true).toList();
    } catch (_) {
      final filas = await (await _db).query('catalogos',
          where: 'servidor = ?', whereArgs: [ApiConfig.baseUrl]);
      if (filas.isEmpty) return [];
      return (jsonDecode(filas.first['datos'] as String) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .where((c) => c['habilitada'] == true).toList();
    }
  }

  Future<void> guardar({
    required Sesion sesion,
    required Map<String, dynamic> datos,
    required List<String> fotos,
  }) async {
    if (sesion.rol != 'ciudadano' || sesion.idUsuario <= 0) {
      throw StateError('Se necesita una sesión ciudadana válida.');
    }
    final id = const Uuid().v4();
    final raiz = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(raiz.path, 'reportes_pendientes', id));
    final copias = <String>[];
    try {
      await carpeta.create(recursive: true);
      for (var i = 0; i < fotos.length; i++) {
        final origen = File(fotos[i]);
        final ext = p.extension(origen.path).toLowerCase();
        if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
          throw StateError('Formato de fotografía no admitido: $ext');
        }
        if (await origen.length() > 10 * 1024 * 1024) {
          throw StateError('Una fotografía supera el límite de 10 MiB.');
        }
        final destino = p.join(carpeta.path, 'foto_$i$ext');
        await origen.copy(destino);
        copias.add(destino);
      }
      await (await _db).insert('pendientes', {
        'id': id, 'servidor': ApiConfig.baseUrl, 'usuario': sesion.idUsuario,
        'datos': jsonEncode(datos), 'fotos': jsonEncode(copias),
        'estado': 'pendiente', 'creado': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
      rethrow;
    }
    _notificar();
    iniciar();
    unawaited(sincronizar());
  }

  Future<List<Map<String, Object?>>> listar() async {
    final sesion = await SesionStorage.leer();
    if (sesion == null) return [];
    return (await _db).query('pendientes',
        where: 'servidor = ? AND usuario = ?',
        whereArgs: [ApiConfig.baseUrl, sesion.idUsuario], orderBy: 'creado DESC');
  }

  Future<void> reintentar(String id) async {
    final sesion = await SesionStorage.leer();
    if (sesion == null) return;
    await (await _db).update('pendientes', {'estado': 'pendiente', 'error': null},
        where: 'id = ? AND servidor = ? AND usuario = ? AND estado != ?',
        whereArgs: [id, ApiConfig.baseUrl, sesion.idUsuario, 'enviado']);
    _notificar();
    await sincronizar();
  }

  /// Solo se permite cambiar la categoría tras el rechazo explícito de la API.
  Future<void> cambiarCategoria(String id, int categoria) async {
    if (_sincronizando) throw StateError('Espera a que termine la sincronización.');
    final sesion = await SesionStorage.leer();
    if (sesion == null) throw StateError('Inicia sesión para modificar el envío.');
    final db = await _db;
    final filas = await db.query('pendientes',
        where: 'id = ? AND servidor = ? AND usuario = ? AND estado = ?',
        whereArgs: [id, ApiConfig.baseUrl, sesion.idUsuario, 'error']);
    if (filas.isEmpty ||
        !(filas.first['error'] as String? ?? '').contains('categoria indicada')) {
      throw StateError('Solo se puede cambiar la categoría tras el rechazo del servidor.');
    }
    final datos = Map<String, dynamic>.from(jsonDecode(filas.first['datos'] as String));
    datos['categoria_id'] = categoria.toString();
    await db.update('pendientes', {'datos': jsonEncode(datos), 'estado': 'pendiente', 'error': null},
        where: 'id = ?', whereArgs: [id]);
    _notificar();
    unawaited(sincronizar());
  }

  Future<void> eliminar(String id) async {
    if (_sincronizando) throw StateError('Espera a que termine la sincronización.');
    final sesion = await SesionStorage.leer();
    if (sesion == null) return;
    final db = await _db;
    final filas = await db.query('pendientes',
        where: 'id = ? AND servidor = ? AND usuario = ?',
        whereArgs: [id, ApiConfig.baseUrl, sesion.idUsuario]);
    if (filas.isEmpty) return;
    await db.delete('pendientes', where: 'id = ?', whereArgs: [id]);
    final raiz = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(raiz.path, 'reportes_pendientes', id));
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
    _notificar();
  }

  Future<void> sincronizar() async {
    if (_sincronizando || !_activa) return;
    _sincronizando = true;
    try {
      final sesion = await SesionStorage.leer();
      if (sesion == null || sesion.rol != 'ciudadano') return;
      final db = await _db;
      final filas = await db.query('pendientes',
          where: 'servidor = ? AND usuario = ? AND estado IN (?, ?)',
          whereArgs: [ApiConfig.baseUrl, sesion.idUsuario, 'pendiente', 'enviando'],
          orderBy: 'creado ASC');
      for (final fila in filas) {
        final actual = await SesionStorage.leer();
        if (!_activa || actual == null || actual.idUsuario != sesion.idUsuario ||
            actual.token != sesion.token) break;
        final id = fila['id'] as String;
        await db.update('pendientes', {'estado': 'enviando', 'error': null},
            where: 'id = ?', whereArgs: [id]);
        _notificar();
        try {
          final datos = Map<String, dynamic>.from(jsonDecode(fila['datos'] as String));
          datos['id_operacion'] = id;
          datos['fecha_captura'] = fila['creado'];
          final form = FormData.fromMap(datos);
          var fotosIncompletas = false;
          for (final archivo in (jsonDecode(fila['fotos'] as String) as List)) {
            if (!await File(archivo as String).exists()) {
              fotosIncompletas = true;
              break;
            }
            form.files.add(MapEntry('fotos',
                await MultipartFile.fromFile(archivo, filename: p.basename(archivo))));
          }
          final headers = {'Authorization': 'Bearer ${sesion.token}'};
          late Response<dynamic> respuesta;
          if (fotosIncompletas) {
            try {
              respuesta = await dio.get('/api/reportes/operaciones/$id',
                  options: Options(headers: headers));
            } on DioException catch (e) {
              if (e.response?.statusCode == 404) {
                throw StateError('Falta una fotografía local y el servidor no tiene el reporte. '
                    'Elimina el pendiente y crea otro reporte.');
              }
              rethrow;
            }
          } else {
            respuesta = await dio.post('/api/reportes', data: form,
                options: Options(sendTimeout: const Duration(minutes: 3),
                    receiveTimeout: const Duration(minutes: 3), headers: headers));
          }
          final remoto = (respuesta.data as Map)['id_reporte'] as int;
          await db.update('pendientes',
              {'estado': 'enviado', 'id_remoto': remoto, 'error': null},
              where: 'id = ?', whereArgs: [id]);
          // El registro confirmado permanece visible; se liberan las fotos locales.
          final raiz = await getApplicationDocumentsDirectory();
          final carpeta = Directory(p.join(raiz.path, 'reportes_pendientes', id));
          try {
            if (await carpeta.exists()) await carpeta.delete(recursive: true);
          } on FileSystemException {
            // La confirmación del servidor ya está guardada; no reenviar.
          }
        } catch (e) {
          final codigo = e is DioException ? e.response?.statusCode : null;
          final requiereAtencion = e is! DioException ||
              (codigo != null && codigo >= 400 && codigo < 500 && codigo != 408 && codigo != 429);
          await db.update('pendientes', {
            'estado': requiereAtencion ? 'error' : 'pendiente',
            'error': codigo == 401 || codigo == 403
                ? 'Sesión expirada o sin permiso. Inicia sesión de nuevo y reintenta.'
                : e is StateError ? e.message.toString() : mensajeDeError(e),
            'intentos': (fila['intentos'] as int) + 1,
          }, where: 'id = ?', whereArgs: [id]);
          if (!requiereAtencion || codigo == 401 || codigo == 403) break;
        } finally {
          _notificar();
        }
      }
    } catch (_) {
      // Un fallo de almacenamiento o sesión no debe terminar la aplicación.
      // El registro no confirmado se intentará nuevamente en el siguiente ciclo.
    } finally {
      _sincronizando = false;
    }
  }
}
