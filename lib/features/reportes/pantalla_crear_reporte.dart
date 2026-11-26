import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/offline/cola_reportes.dart';
import '../../core/storage/sesion_storage.dart';
import '../../core/widgets/boton_menu.dart';
import '../../core/ubicacion/ubicacion.dart';

/// M2 · Envio completo del reporte:
/// RF-001 categoria del catalogo, RF-002 descripcion (la fecha la pone el
/// servidor), RF-003 GPS con advertencia de precision, RF-004/005 marcador
/// en el mapa ajustable, RF-006 de 1 a 5 fotografias, RF-007/010 envio.
class PantallaCrearReporte extends StatefulWidget {
  const PantallaCrearReporte({super.key});

  @override
  State<PantallaCrearReporte> createState() => _PantallaCrearReporteState();
}

class _PantallaCrearReporteState extends State<PantallaCrearReporte> {
  static const int _maxFotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _picker = ImagePicker();
  final _mapaControlador = MapController();

  LatLng _marcador = LatLng(-21.5350, -64.7300); // Tarija
  UbicacionGps? _gps;
  bool _cargandoGps = false;
  String? _errorGps;
  bool _advertenciaOculta = false;
  bool _ubicacionConfirmada = false;

  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaId;
  String _riesgo = 'NINGUNO';
  final List<XFile> _fotos = [];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _pedirUbicacion();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // ---------------------------------------------------------------- GPS

  Future<void> _pedirUbicacion() async {
    setState(() {
      _cargandoGps = true;
      _errorGps = null;
      _advertenciaOculta = false;
    });
    try {
      final gps = await obtenerUbicacionGps();
      if (!mounted) return;
      final punto = LatLng(gps.latitud, gps.longitud);
      setState(() {
        _gps = gps;
        _marcador = punto;
        _ubicacionConfirmada = true;
      });
      try {
        _mapaControlador.move(punto, 17);
      } catch (_) {
        // El mapa todavia no estaba listo; el marcador ya quedo puesto
      }
    } on ExcepcionUbicacion catch (e) {
      if (mounted) setState(() => _errorGps = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _errorGps = 'Error de GPS: $e');
    } finally {
      if (mounted) setState(() => _cargandoGps = false);
    }
  }

  // --------------------------------------------------------- Categorias

  Future<void> _cargarCategorias() async {
    try {
      final lista = await ColaReportes.instancia.categorias();
      if (mounted) setState(() => _categorias = lista);
      if (lista.isEmpty) _snack('No hay categorías guardadas. Conéctate para descargarlas.');
    } catch (_) {
      _snack('No se pudo cargar el catálogo local de categorías.');
    }
  }

  // ----------------------------------------------------------- Fotos

  Future<void> _tomarFoto() async {
    if (_fotos.length >= _maxFotos) {
      _snack('Puedes agregar hasta $_maxFotos fotografías por reporte');
      return;
    }
    final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (foto != null && mounted) setState(() => _fotos.add(foto));
  }

  Future<void> _elegirDeGaleria() async {
    if (_fotos.length >= _maxFotos) {
      _snack('Puedes agregar hasta $_maxFotos fotografías por reporte');
      return;
    }
    final seleccion = await _picker.pickMultiImage(imageQuality: 85);
    final disponibles = _maxFotos - _fotos.length;
    if (seleccion.length > disponibles) {
      _snack('Solo caben $disponibles fotos mas; se guardan las primeras.');
    }
    if (mounted) {
      setState(() => _fotos.addAll(seleccion.take(disponibles)));
    }
  }

  void _quitarFoto(int indice) {
    setState(() => _fotos.removeAt(indice));
  }

  // ----------------------------------------------------------- Envio

  Future<void> _enviar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoriaId == null) {
      _snack('Selecciona la categoría del daño');
      return;
    }
    if (_fotos.isEmpty) {
      _snack('Agrega al menos una fotografía');
      return;
    }
    if (!_ubicacionConfirmada) {
      _snack('Obtén el GPS o selecciona explícitamente la ubicación en el mapa.');
      return;
    }

    setState(() => _enviando = true);
    try {
      final sesion = await SesionStorage.leer();
      if (sesion == null) throw StateError('Inicia sesión para guardar el reporte.');
      await ColaReportes.instancia.guardar(sesion: sesion, datos: {
        'categoria_id': _categoriaId.toString(),
        'descripcion': _descripcion.text.trim(),
        'latitud': _marcador.latitude.toString(),
        'longitud': _marcador.longitude.toString(),
        'riesgo': _riesgo,
        // DA-05 / RF-003: coordenada original del GPS y precision
        if (_gps != null) ...{
          'latitud_original': _gps!.latitud.toString(),
          'longitud_original': _gps!.longitud.toString(),
          'precision_gps': _gps!.precision.toString(),
        },
      }, fotos: _fotos.map((f) => f.path).toList());
      if (!mounted) return;
      _snack('Reporte guardado en el dispositivo. Consulta su estado de envío.');
      context.go('/reportes/pendientes');
    } catch (e) {
      _snack('No se pudo guardar el reporte: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar reporte'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tarjetaGps(),
                const SizedBox(height: 16),
                _seccion(
                  'Ubicación en el mapa',
                  [
                    SizedBox(
                      height: 240,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          mapController: _mapaControlador,
                          options: MapOptions(
                            initialCenter: _marcador,
                            initialZoom: 16,
                             onTap: (posicion, punto) => setState(() {
                               _marcador = punto;
                               _ubicacionConfirmada = true;
                             }),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'bo.optaiv.movil',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _marcador,
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                    Icons.location_pin,
                                    size: 44,
                                    color: Colors.red.shade700,
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 6,
                                          color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el mapa para indicar dónde está el daño. '
                      'La marca señala la ubicación que se guardará.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _seccion(
                  'Categoría del daño (obligatoria)',
                  [
                    DropdownButtonFormField<int>(
                      initialValue: _categoriaId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      hint: _categorias.isEmpty
                          ? const Text('Sin catálogo: conéctate para descargarlo')
                          : const Text('Selecciona una categoria'),
                      items: _categorias
                          .map((c) => DropdownMenuItem<int>(
                                value: c['id_categoria'] as int,
                                child: Text(c['nombre'] as String),
                              ))
                          .toList(),
                      onChanged: (valor) =>
                          setState(() => _categoriaId = valor),
                      validator: (valor) => valor == null
                          ? 'Debes elegir una categoria'
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _seccion(
                  'Descripción del daño (obligatoria)',
                  [
                    TextFormField(
                      controller: _descripcion,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText:
                            'Ej.: Bache de casi un metro en el centro de la '
                            'calle, ya ha causado dos pinchazos...',
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length < 4)
                          ? 'Describe el dano (minimo 4 caracteres)'
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La fecha y hora del reporte la registra el servidor '
                      'automáticamente.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _seccion(
                  'Riesgo observado (opcional)',
                  [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipRiesgo('NINGUNO', 'Ninguno', Icons.block),
                        _chipRiesgo('VEHICULOS', 'Vehiculos', Icons.directions_car),
                        _chipRiesgo('PEATONES', 'Peatones', Icons.directions_walk),
                        _chipRiesgo('AMBOS', 'Ambos', Icons.warning_amber),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _seccion(
                  'Fotografías: ${_fotos.length}/$_maxFotos (mínimo 1)',
                  [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _fotos.length >= _maxFotos ? null : _tomarFoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Camara'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _fotos.length >= _maxFotos
                                ? null
                                : _elegirDeGaleria,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeria'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_fotos.isEmpty)
                      Container(
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Sin fotos todavia: toma al menos 1 con la camara',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _fotos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_fotos[i].path),
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => _quitarFoto(i),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                      _enviando ? 'Guardando...' : 'Guardar y enviar reporte'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se guarda en este dispositivo y se intenta enviar con la app abierta. '
                  'Solo llega al municipio al confirmarse el envío.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaGps() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Ubicación GPS',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (_cargandoGps)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_gps != null)
              Text(
                'Ubicación obtenida. '
                'Precisión aproximada: ${_gps!.precision.toStringAsFixed(0)} m',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (_errorGps == null)
              const Text('Obteniendo posicion...',
                  style: TextStyle(color: Colors.black54)),
            if (_errorGps != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorGps!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
              ),
            if (_gps != null && _gps!.esImprecisa && !_advertenciaOculta)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advertencia: la precision del GPS es de '
                      '${_gps!.precision.toStringAsFixed(0)} m (mayor a 50 m). '
                      'La ubicacion puede ser inexacta; ajusta la marca en el '
                      'mapa si es necesario.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _advertenciaOculta = true),
                        child: const Text('Entendido'),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _cargandoGps ? null : _pedirUbicacion,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(_gps == null ? 'Usar mi ubicacion' : 'Actualizar GPS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...hijos,
          ],
        ),
      ),
    );
  }

  Widget _chipRiesgo(String valor, String texto, IconData icono) {
    final seleccionado = _riesgo == valor;
    return FilterChip(
      selected: seleccionado,
      avatar: Icon(icono, size: 18),
      label: Text(texto),
      onSelected: (_) => setState(() => _riesgo = valor),
    );
  }
}
