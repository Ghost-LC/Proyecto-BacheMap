import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';

class Barrio {
  final int id;
  final String nombre;
  final Map<String, dynamic> poligono;

  const Barrio({
    required this.id,
    required this.nombre,
    required this.poligono,
  });

  factory Barrio.fromJson(Map<String, dynamic> j) => Barrio(
        id: j['id_barrio'] as int,
        nombre: j['nombre'] as String,
        poligono: Map<String, dynamic>.from(j['poligono'] as Map),
      );
}

// Cuadrado de ejemplo alrededor de Santa Cruz (lon, lat) para el alta
const _poligonoEjemplo = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': [
    [
      [-64.74, -21.54],
      [-64.72, -21.54],
      [-64.72, -21.53],
      [-64.74, -21.53],
      [-64.74, -21.54],
    ],
  ],
};

/// RF-043 · Gestion de barrios como poligonos GeoJSON (solo administrador).
/// El sistema usa estos poligonos para asociar cada reporte a su barrio
/// automaticamente (RF-044, PostGIS).
class PantallaBarrios extends StatefulWidget {
  const PantallaBarrios({super.key});

  @override
  State<PantallaBarrios> createState() => _PantallaBarriosState();
}

class _PantallaBarriosState extends State<PantallaBarrios> {
  List<Barrio> _barrios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await dio.get('/api/administracion/barrios');
      setState(() {
        _barrios = (r.data as List)
            .map((e) => Barrio.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Valida el texto del poligono antes de enviarlo (el servidor vuelve a
  /// validarlo con PostGIS: ST_IsValid).
  Map<String, dynamic>? _parsearPoligono(String texto) {
    try {
      final objeto = jsonDecode(texto);
      if (objeto is! Map<String, dynamic>) {
        _snack('El poligono debe ser un objeto JSON.');
        return null;
      }
      return objeto;
    } on FormatException {
      _snack('El poligono no es un JSON valido.');
      return null;
    }
  }

  Future<void> _formulario({Barrio? existente}) async {
    final nombre = TextEditingController(text: existente?.nombre ?? '');
    final poligono = TextEditingController(
      text: jsonEncode(existente?.poligono ?? _poligonoEjemplo),
    );
    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existente == null
              ? 'Nuevo barrio'
              : 'Editar barrio'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nombre,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: poligono,
                  maxLines: 7,
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Poligono GeoJSON (Polygon / MultiPolygon)',
                    hintText:
                        '{"type": "Polygon", "coordinates": [[[lon, lat], ...]]}',
                    hintStyle: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(existente == null ? 'Crear' : 'Guardar')),
          ],
        ),
      );
      if (confirmado != true) return;

      final geojson = _parsearPoligono(poligono.text.trim());
      if (geojson == null) return;
      final tipo = geojson['type'];
      if (tipo != 'Polygon' && tipo != 'MultiPolygon') {
        _snack('El GeoJSON debe ser type Polygon o MultiPolygon.');
        return;
      }
      if (nombre.text.trim().length < 2) {
        _snack('El nombre necesita al menos 2 caracteres.');
        return;
      }

      if (existente == null) {
        await dio.post(
          '/api/administracion/barrios',
          data: {'nombre': nombre.text.trim(), 'poligono': geojson},
        );
      } else {
        await dio.patch(
          '/api/administracion/barrios/${existente.id}',
          data: {'nombre': nombre.text.trim(), 'poligono': geojson},
        );
      }
      await _cargar();
    } on DioException catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      nombre.dispose();
      poligono.dispose();
    }
  }

  Future<void> _eliminar(Barrio b) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar "${b.nombre}"'),
        content: const Text(
            'Los reportes asociados quedaran sin barrio. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await dio.delete('/api/administracion/barrios/${b.id}');
      await _cargar();
    } on DioException catch (e) {
      _snack(mensajeDeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barrios'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo barrio'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Cada barrio se guarda como poligono GeoJSON; al '
                          'registrar un reporte el sistema lo asocia al barrio '
                          'que contiene su ubicación.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (_barrios.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Aun no hay barrios registrados.'),
                        ),
                      ..._barrios.map(
                        (b) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.location_city_outlined),
                            title: Text(b.nombre),
                            subtitle: Text(
                              '${b.poligono['type']} · '
                              '${_anillos(b)} anillo(s) de coordenadas',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (opcion) {
                                if (opcion == 'editar') {
                                  _formulario(existente: b);
                                } else {
                                  _eliminar(b);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'editar',
                                    child: Text('Editar poligono')),
                                PopupMenuItem(
                                    value: 'eliminar',
                                    child: Text('Eliminar barrio')),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
    );
  }

  int _anillos(Barrio b) {
    final tipo = b.poligono['type'];
    final coords = b.poligono['coordinates'];
    if (coords is! List) return 0;
    if (tipo == 'MultiPolygon') {
      return coords.fold<int>(
          0, (total, p) => total + (p is List ? p.length : 0));
    }
    return coords.length;
  }
}
