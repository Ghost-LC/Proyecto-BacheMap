import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';

/// Pantalla de verificacion de la iteracion I0: comprueba que la app movil
/// alcanza al backend y que la base de datos y PostGIS responden.
class PantallaSalud extends StatefulWidget {
  const PantallaSalud({super.key});

  @override
  State<PantallaSalud> createState() => _PantallaSaludState();
}

class _PantallaSaludState extends State<PantallaSalud> {
  bool _cargando = false;
  Map<String, dynamic>? _datos;
  String? _error;

  Future<void> _verificar() async {
    setState(() {
      _cargando = true;
      _datos = null;
      _error = null;
    });
    try {
      final respuesta = await dio.get('/api/salud');
      if (!mounted) return;
      setState(() => _datos = Map<String, dynamic>.from(respuesta.data));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mensajeDeError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensajeDeError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No se pudo conectar con el servidor.\n'
          'Verifica que la PC este encendida, que el telefono y la PC esten '
          'en la misma red WiFi, y que la API este ejecutandose.\n'
          'URL intentada: ${ApiConfig.baseUrl}';
    }
    return 'Error de conexion: ${e.message ?? e.type.name}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Baches y Daños Viales'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servidor',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      ApiConfig.baseUrl,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comprueba si la aplicación puede comunicarse con el servidor.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargando ? null : _verificar,
              icon: _cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Verificar conexión con el servidor'),
            ),
            const SizedBox(height: 16),
            if (_datos != null) _tarjetaExito(_datos!),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaExito(Map<String, dynamic> datos) {
    final filas = <Widget>[
      _fila('API', '${datos['estado'] == 'ok' ? '✅' : '⚠️'} ${datos['estado']}'),
      _fila('Versión', '${datos['version']}'),
      _fila('Base de datos', '${datos['base_datos']}'),
      _fila('PostGIS', '${datos['postgis'] ?? 'no disponible'}'),
    ];
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conexión exitosa',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...filas,
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(etiqueta)),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
