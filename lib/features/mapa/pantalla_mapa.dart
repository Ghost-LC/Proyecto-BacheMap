import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../administracion/pantalla_barrios.dart' show Barrio;
import '../administracion/pantalla_categorias.dart' show Categoria;
import '../reportes/modelo_reporte.dart' show EstadosReporte;
import 'modelo_mapa.dart';

/// M6 · Mapa de reportes (RF-032 a RF-035):
/// - RF-032: el backend entrega solo los marcadores visibles por rol.
/// - RF-033: filtros por categoria, fechas, barrio y estado (combinados).
/// - RF-034: al tocar un marcador se muestran descripcion y fotografias.
/// - RF-035: se resaltan los 3 barrios con mas reportes activos.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  List<MarcadorMapa> _marcadores = [];
  List<SectorMapa> _sectores = [];
  List<Categoria> _categorias = [];
  List<Barrio> _barrios = [];
  bool _cargando = true;
  String? _error;

  // Filtros activos (RF-033)
  int? _categoriaId;
  int? _idBarrio;
  String? _estado;
  DateTime? _desde;
  DateTime? _hasta;

  int get _cantidadFiltros => [
        _categoriaId,
        _idBarrio,
        _estado,
        _desde,
        _hasta,
      ].where((f) => f != null).length;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
    _cargar();
  }

  Map<String, String> get _parametros {
    final p = <String, String>{};
    if (_categoriaId != null) p['categoria_id'] = '$_categoriaId';
    if (_idBarrio != null) p['id_barrio'] = '$_idBarrio';
    if (_estado != null) p['estado'] = _estado!;
    if (_desde != null) {
      p['desde'] = DateFormat('yyyy-MM-dd').format(_desde!);
    }
    if (_hasta != null) {
      p['hasta'] = DateFormat('yyyy-MM-dd').format(_hasta!);
    }
    return p;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuestas = await Future.wait([
        dio.get('/api/mapa/reportes', queryParameters: _parametros),
        dio.get('/api/mapa/sectores'),
      ]);
      final marcadores = (respuestas[0].data as List)
          .map((e) => MarcadorMapa.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final sectores = (respuestas[1].data as List)
          .map((e) => SectorMapa.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) {
        setState(() {
          _marcadores = marcadores;
          _sectores = sectores;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Categorias y barrios auxiliares para los filtros (RF-033).
  Future<void> _cargarCatalogos() async {
    try {
      final respuestas = await Future.wait([
        dio.get('/api/administracion/categorias'),
        dio.get('/api/administracion/barrios'),
      ]);
      final categorias = (respuestas[0].data as List)
          .map((e) => Categoria.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.habilitada)
          .toList();
      final barrios = (respuestas[1].data as List)
          .map((e) => Barrio.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) {
        setState(() {
          _categorias = categorias;
          _barrios = barrios;
        });
      }
    } on DioException {
      // Auxiliares: el mapa sigue funcionando sin ellos
    }
  }

  // --- RF-033 · Panel de filtros ------------------------------------------

  Future<void> _abrirFiltros() async {
    int? categoria = _categoriaId;
    int? barrio = _idBarrio;
    String? estado = _estado;
    DateTime? desde = _desde;
    DateTime? hasta = _hasta;

    final aplicar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> elegirFecha(bool esDesde) async {
            final hoy = DateTime.now();
            final f = await showDatePicker(
              context: context,
              initialDate: (esDesde ? desde : hasta) ?? hoy,
              firstDate: DateTime(2024, 1, 1),
              lastDate: hoy,
            );
            if (f != null) {
              setSheetState(() {
                if (esDesde) {
                  desde = f;
                } else {
                  hasta = f;
                }
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filtros del mapa',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButton<int?>(
                  isExpanded: true,
                  value: categoria,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Todas las categorias')),
                    for (final c in _categorias)
                      DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.nombre)),
                  ],
                  onChanged: (v) => setSheetState(() => categoria = v),
                ),
                DropdownButton<int?>(
                  isExpanded: true,
                  value: barrio,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Todos los barrios')),
                    for (final b in _barrios)
                      DropdownMenuItem<int?>(
                          value: b.id, child: Text(b.nombre)),
                  ],
                  onChanged: (v) => setSheetState(() => barrio = v),
                ),
                DropdownButton<String?>(
                  isExpanded: true,
                  value: estado,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Todos los estados')),
                    for (final e in EstadosReporte.etiquetas.entries)
                      DropdownMenuItem<String?>(
                          value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setSheetState(() => estado = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => elegirFecha(true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(desde == null
                            ? 'Desde'
                            : DateFormat('dd/MM/yyyy').format(desde!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => elegirFecha(false),
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(hasta == null
                            ? 'Hasta'
                            : DateFormat('dd/MM/yyyy').format(hasta!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          categoria = null;
                          barrio = null;
                          estado = null;
                          desde = null;
                          hasta = null;
                        });
                      },
                      child: const Text('Limpiar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (aplicar != true || !mounted) return;
    setState(() {
      _categoriaId = categoria;
      _idBarrio = barrio;
      _estado = estado;
      _desde = desde;
      _hasta = hasta;
    });
    await _cargar();
  }

  // --- RF-034 · Popup con descripcion y fotografias ------------------------

  void _abrirMarcador(MarcadorMapa m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _HojaReporte(
        marcador: m,
        onVerDetalle: () {
          Navigator.pop(context);
          context.go('/reportes/${m.idReporte}');
        },
      ),
    );
  }

  // --- Geometria de los sectores (RF-035) ---------------------------------

  List<LatLng> _puntosDelPoligono(Map<String, dynamic> poligono) {
    final coords = poligono['coordinates'];
    if (coords is! List || coords.isEmpty) return const [];
    // Polygon: [anillo...]; MultiPolygon: [[anillo...], ...]
    final anillos = poligono['type'] == 'MultiPolygon' ? coords.first : coords;
    if (anillos is! List || anillos.isEmpty) return const [];
    final anillo = anillos.first;
    if (anillo is! List) return const [];
    return [
      for (final p in anillo)
        if (p is List && p.length >= 2)
          LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
    ];
  }

  // --- Interfaz ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de reportes'),
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: _abrirFiltros,
            icon: Badge(
              isLabelVisible: _cantidadFiltros > 0,
              label: Text('$_cantidadFiltros'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
          const BotonMenuPrincipal(),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(-21.535, -64.73),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'bo.baches.reporte',
              ),
              // RF-035: sectores de mayor concentracion resaltados
              PolygonLayer(
                polygons: [
                  for (final s in _sectores)
                    Polygon(
                      points: _puntosDelPoligono(s.poligono),
                      color: const Color(0x33FF6F00),
                      borderColor: const Color(0xFFFF6F00),
                      borderStrokeWidth: 3,
                      label: s.nombre,
                      labelStyle: const TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              // RF-032: un marcador por reporte visible para el rol
              MarkerLayer(
                markers: [
                  for (final m in _marcadores)
                    Marker(
                      point: LatLng(m.latitud, m.longitud),
                      width: 38,
                      height: 38,
                      child: GestureDetector(
                        onTap: () => _abrirMarcador(m),
                        child: Icon(
                          Icons.location_on,
                          size: 34,
                          color: EstadosReporte.color(m.estado),
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_cargando && _marcadores.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null && _marcadores.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _cargar,
                        child: const Text('Reintentar')),
                  ],
                ),
              ),
            ),
          if (!_cargando && _error == null && _marcadores.isEmpty)
            const Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _Aviso(
                  texto: 'Sin reportes visibles con los filtros actuales.'),
            ),
          // Leyenda de los sectores resaltados (RF-035)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xEFFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sectores con más reportes activos',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  if (_sectores.isEmpty)
                    const Text('Sin sectores todavia',
                        style: TextStyle(fontSize: 11)),
                  for (var i = 0; i < _sectores.length; i++)
                    Text(
                      '${i + 1}. ${_sectores[i].nombre} · '
                      '${_sectores[i].totalActivos} activos',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE6FFEB3B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// Hoja inferior con la descripcion y las fotografias del reporte
/// seleccionado en el mapa (RF-034).
class _HojaReporte extends StatefulWidget {
  final MarcadorMapa marcador;
  final VoidCallback onVerDetalle;

  const _HojaReporte({required this.marcador, required this.onVerDetalle});

  @override
  State<_HojaReporte> createState() => _HojaReporteState();
}

class _HojaReporteState extends State<_HojaReporte> {
  final Map<int, Uint8List> _bytes = {};
  final Set<int> _cargando = {};

  @override
  void initState() {
    super.initState();
    _descargarFotos();
  }

  Future<void> _descargarFotos() async {
    for (final foto in widget.marcador.fotografias) {
      if (_bytes.containsKey(foto.idFoto)) continue;
      setState(() => _cargando.add(foto.idFoto));
      try {
        final r = await dio.get(
          foto.url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (mounted) {
          setState(() {
            _bytes[foto.idFoto] = r.data as Uint8List;
            _cargando.remove(foto.idFoto);
          });
        }
      } catch (_) {
        if (mounted) setState(() => _cargando.remove(foto.idFoto));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.marcador;
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(m.fechaHora.toLocal());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.categoria,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              EstadosReporte.chip(m.estado),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$fecha · ${m.barrio ?? 'Sin barrio'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text('Descripcion',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(m.descripcion),
          const SizedBox(height: 12),
          Text('Fotografias (${m.fotografias.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (m.fotografias.isEmpty)
            const Text('Este reporte no tiene fotografias.')
          else
            SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [for (final f in m.fotografias) _foto(f)],
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onVerDetalle,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ver detalle completo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foto(FotoMapa foto) {
    final bytes = _bytes[foto.idFoto];
    return Container(
      width: 112,
      height: 112,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, fit: BoxFit.cover),
            )
          : _cargando.contains(foto.idFoto)
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Center(
                  child: Icon(Icons.broken_image, color: Colors.black38),
                ),
    );
  }
}
