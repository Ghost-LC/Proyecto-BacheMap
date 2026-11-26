import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../../core/widgets/mapa_ubicacion.dart';
import '../reportes/modelo_reporte.dart';
import 'modelo_trabajo.dart';
import 'pantalla_mis_trabajos.dart';

/// M4 · Flujo completo del trabajador:
/// RF-023 iniciar, RF-024 trabajo y materiales, RF-025 fotos posteriores,
/// RF-026 observaciones y RF-027 finalizar (En reparacion -> Reparado).
class PantallaTrabajo extends StatefulWidget {
  final int idTrabajo;

  const PantallaTrabajo({super.key, required this.idTrabajo});

  @override
  State<PantallaTrabajo> createState() => _PantallaTrabajoState();
}

class _PantallaTrabajoState extends State<PantallaTrabajo> {
  TrabajoAsignado? _trabajo;
  bool _cargando = true;
  String? _error;
  bool _guardando = false;

  final _descripcion = TextEditingController();
  final _observaciones = TextEditingController();
  final _materialNombre = TextEditingController();
  final _materialCantidad = TextEditingController();
  List<MaterialTrabajo> _materiales = [];

  final Map<int, Uint8List> _bytesFotos = {};
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _observaciones.dispose();
    _materialNombre.dispose();
    _materialCantidad.dispose();
    super.dispose();
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
      final respuesta =
          await dio.get('/api/reparaciones/trabajos/${widget.idTrabajo}');
      final trabajo = TrabajoAsignado.fromJson(
          Map<String, dynamic>.from(respuesta.data));
      if (!mounted) return;
      setState(() {
        _trabajo = trabajo;
        _descripcion.text = trabajo.descripcionTrabajo ?? '';
        _observaciones.text = trabajo.observaciones ?? '';
        _materiales = [...trabajo.materiales];
      });
      await _descargarFotos(trabajo);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _descargarFotos(TrabajoAsignado trabajo) async {
    for (final foto in trabajo.reporte.fotografias) {
      if (_bytesFotos.containsKey(foto.idFoto)) continue;
      try {
        final respuesta = await dio.get(
          foto.url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (!mounted) return;
        setState(() => _bytesFotos[foto.idFoto] = respuesta.data as Uint8List);
      } catch (_) {
        // pendiente; se recarga al refrescar
      }
    }
  }

  // ------------------------------------------------------------- RF-023

  Future<void> _iniciar() async {
    setState(() => _guardando = true);
    try {
      await dio.post(
          '/api/reparaciones/trabajos/${widget.idTrabajo}/iniciar');
      if (!mounted) return;
      _snack('Reparación iniciada: estado "En reparación"');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ------------------------------------------------------ RF-024 / RF-026

  Future<void> _guardarDetalle() async {
    final texto = _descripcion.text.trim();
    if (texto.length < 4) {
      _snack('Describe el trabajo realizado (mínimo 4 caracteres)');
      return;
    }
    setState(() => _guardando = true);
    try {
      await dio.put(
        '/api/reparaciones/trabajos/${widget.idTrabajo}/detalle',
        data: {
          'descripcion_trabajo': texto,
          'observaciones':
              _observaciones.text.trim().isEmpty ? null : _observaciones.text.trim(),
          'materiales': _materiales.map((m) => m.toJson()).toList(),
        },
      );
      if (!mounted) return;
      _snack('Detalle del trabajo guardado');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarMaterial() {
    final nombre = _materialNombre.text.trim();
    final cantidad = double.tryParse(
        _materialCantidad.text.trim().replaceAll(',', '.'));
    if (nombre.isEmpty || cantidad == null || cantidad <= 0) {
      _snack('Introduce el nombre y una cantidad válida del material');
      return;
    }
    setState(() {
      _materiales.add(MaterialTrabajo(nombre: nombre, cantidad: cantidad));
      _materialNombre.clear();
      _materialCantidad.clear();
    });
  }

  void _quitarMaterial(int indice) {
    setState(() => _materiales.removeAt(indice));
  }

  // ------------------------------------------------------------- RF-025

  int get _fotosPosteriores => _trabajo?.reporte.fotografias
          .where((f) => f.tipo == 'POSTERIOR')
          .length ??
      0;

  Future<void> _subirFoto(ImageSource origen) async {
    if (_fotosPosteriores >= 5) {
      _snack('Puedes agregar hasta 5 fotografías posteriores');
      return;
    }
    final foto = await _picker.pickImage(source: origen, imageQuality: 85);
    if (foto == null) return;
    setState(() => _guardando = true);
    try {
      final form = FormData();
      form.files.add(MapEntry(
        'fotos',
        await MultipartFile.fromFile(
          foto.path,
          filename: foto.path.split(RegExp(r'[/\\]')).last,
        ),
      ));
      await dio.post(
        '/api/reparaciones/trabajos/${widget.idTrabajo}/fotos',
        data: form,
      );
      if (!mounted) return;
      _snack('Fotografía posterior registrada');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ------------------------------------------------------------- RF-027

  Future<void> _finalizar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar trabajo'),
        content: const Text(
          'El reporte pasara a "Reparado" y quedara pendiente de verificacion '
          'del inspector. Se requiere la descripcion del trabajo y al menos '
          'una fotografía posterior antes de finalizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await dio.post(
          '/api/reparaciones/trabajos/${widget.idTrabajo}/finalizar');
      if (!mounted) return;
      _snack('Trabajo finalizado: estado "Reparado"');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _verFoto(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 340,
          height: 440,
          child: InteractiveViewer(
            maxScale: 6,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trabajo #${widget.idTrabajo}'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: _cargando && _trabajo == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _trabajo == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _cardReporte(_trabajo!),
                          const SizedBox(height: 16),
                          ..._acciones(_trabajo!),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _acciones(TrabajoAsignado t) {
    switch (t.reporte.estado) {
      case 'APROBADO_INTERVENCION':
        return [
          FilledButton.icon(
            onPressed: _guardando ? null : _iniciar,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar reparación'),
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes iniciar el trabajo asignado a ti o a tu cuadrilla.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case 'EN_REPARACION':
        return [
          _cardDetalle(),
          const SizedBox(height: 16),
          _cardFotosPosteriores(),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _guardando ? null : _finalizar,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Finalizar trabajo'),
          ),
        ];
      case 'REPARADO':
        return [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trabajo finalizado',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (t.fechaFin != null)
                    _fila(
                      'Fecha de fin',
                      DateFormat('dd/MM/yyyy HH:mm')
                          .format(t.fechaFin!.toLocal()),
                    ),
                  _fila('Estado', 'Reparado — espera verificacion del inspector'),
                ],
              ),
            ),
          ),
        ];
      default:
        return [
          Text(
            'Este trabajo no esta activo (estado actual: '
            '${EstadosReporte.etiqueta(t.reporte.estado)}).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
    }
  }

  Widget _cardReporte(TrabajoAsignado t) {
    final r = t.reporte;
    final fecha =
        DateFormat('dd/MM/yyyy HH:mm').format(r.fechaHora.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.categoria,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                EstadosReporte.chip(r.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text('Reporte #${r.idReporte} · enviado el $fecha',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(r.descripcion),
            const SizedBox(height: 8),
            if (r.prioridad != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Chip(
                  label: Text('Prioridad ${r.prioridad}'
                      '${r.urgente == true ? ' · URGENTE' : ''}'),
                  backgroundColor: NivelesReparacion.colorPrioridad(r.prioridad),
                  labelStyle:
                      const TextStyle(color: Colors.white, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            MapaUbicacion(latitud: r.latitud, longitud: r.longitud),
            if (t.fechaProgramada != null)
              _fila('Fecha programada', t.fechaProgramada!),
            if (t.cuadrilla != null)
              _fila('Cuadrilla', t.cuadrilla!)
            else if (t.responsable != null)
              _fila('Responsable', t.responsable!),
            if (t.fechaInicio != null)
              _fila(
                'Inicio',
                DateFormat('dd/MM/yyyy HH:mm')
                    .format(t.fechaInicio!.toLocal()),
              ),
            const SizedBox(height: 12),
            Text('Fotografias del reporte',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (r.fotografias.isEmpty)
              const Text('Sin fotografias.',
                  style: TextStyle(color: Colors.black54))
            else
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.fotografias.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final foto = r.fotografias[i];
                    final bytes = _bytesFotos[foto.idFoto];
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: bytes == null ? null : () => _verFoto(bytes),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: bytes != null
                                ? Image.memory(bytes,
                                    width: 88, height: 72, fit: BoxFit.cover)
                                : Container(
                                    width: 88,
                                    height: 72,
                                    color: Colors.black12,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          foto.tipo == 'ORIGINAL' ? 'original' : 'posterior',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardDetalle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalle del trabajo',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _descripcion,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    'Describe el trabajo realizado. Ej.: Relleno del bache '
                    'con mezcla asfaltica y compactado...',
                counterText: '',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _observaciones,
              maxLines: 2,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Observaciones del responsable (opcional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text('Materiales (nombre y cantidad)',
                style: Theme.of(context).textTheme.bodySmall),
            if (_materiales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Sin materiales registrados.',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
              )
            else
              ..._materiales.asMap().entries.map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value.nombre),
                      subtitle: Text('Cantidad: ${entry.value.cantidad}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _quitarMaterial(entry.key),
                      ),
                    ),
                  ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _materialNombre,
                    decoration:
                        const InputDecoration(labelText: 'Material'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _materialCantidad,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                IconButton(
                  onPressed: _agregarMaterial,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Agregar material',
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardarDetalle,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar detalle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardFotosPosteriores() {
    final posteriores = _trabajo!.reporte.fotografias
        .where((f) => f.tipo == 'POSTERIOR')
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fotografías posteriores: ${posteriores.length}/5',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Se distinguen de las originales. Debes subir al menos 1 para '
              'finalizar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando || posteriores.length >= 5
                        ? null
                        : () => _subirFoto(ImageSource.camera),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Camara'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando || posteriores.length >= 5
                        ? null
                        : () => _subirFoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (posteriores.isEmpty)
              const Text('Todavia no hay fotos posteriores.',
                  style: TextStyle(color: Colors.black54, fontSize: 13))
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: posteriores.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final foto = posteriores[i];
                    final bytes = _bytesFotos[foto.idFoto];
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: bytes == null ? null : () => _verFoto(bytes),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: bytes != null
                                ? Image.memory(bytes,
                                    width: 96, height: 84, fit: BoxFit.cover)
                                : Container(
                                    width: 96,
                                    height: 84,
                                    color: Colors.black12,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM HH:mm')
                              .format(foto.fechaRegistro.toLocal()),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(etiqueta,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
