import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../../core/widgets/mapa_ubicacion.dart';
import '../reportes/modelo_reporte.dart';
import 'modelo_evaluacion.dart';

/// M3 · Evaluacion completa de un reporte pendiente:
/// RF-012 propuesta del sistema, RF-013 riesgos del inspector,
/// RF-014/RF-016 gravedad y prioridad (recalculo automatico),
/// RF-015 indicador de urgencia, RF-017 aprobar, RF-018 descartar.
class PantallaEvaluar extends StatefulWidget {
  final int idReporte;

  const PantallaEvaluar({super.key, required this.idReporte});

  @override
  State<PantallaEvaluar> createState() => _PantallaEvaluarState();
}

class _PantallaEvaluarState extends State<PantallaEvaluar> {
  ReporteDetalle? _reporte;
  PropuestaEvaluacion? _propuesta;
  EvaluacionGuardada? _evaluacion; // ya registrada en el servidor (o recien guardada)
  bool _cargando = true;
  String? _error;

  // Formulario del inspector
  bool _riesgoPeatones = false;
  bool _riesgoCiclistas = false;
  bool _riesgoVehiculos = false;
  String? _gravedad;
  String? _prioridad;
  bool _gravedadTocada = false;
  bool _prioridadTocada = false;

  bool _guardando = false;
  bool _decidiendo = false;

  final Map<int, Uint8List> _bytesFotos = {};

  bool get _evaluada => _evaluacion != null;

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
      final detalle =
          await dio.get('/api/reportes/${widget.idReporte}');
      final propuesta =
          await dio.get('/api/evaluacion/${widget.idReporte}/propuesta');

      EvaluacionGuardada? existente;
      try {
        final r = await dio
            .get('/api/evaluacion/${widget.idReporte}/evaluacion');
        existente =
            EvaluacionGuardada.fromJson(Map<String, dynamic>.from(r.data));
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow; // 404 = aun sin evaluar
      }

      if (!mounted) return;
      setState(() {
        _reporte =
            ReporteDetalle.fromJson(Map<String, dynamic>.from(detalle.data));
        _propuesta = PropuestaEvaluacion.fromJson(
            Map<String, dynamic>.from(propuesta.data));
        _evaluacion = existente;
        if (existente != null) {
          _riesgoPeatones = existente.riesgoPeatones;
          _riesgoCiclistas = existente.riesgoCiclistas;
          _riesgoVehiculos = existente.riesgoVehiculos;
          _gravedad = existente.gravedad;
          _prioridad = existente.prioridad;
        } else {
          _gravedad = _propuesta!.gravedadPropuesta;
          _prioridad = _propuesta!.prioridadPropuesta;
        }
        _gravedadTocada = false;
        _prioridadTocada = false;
      });
      await _descargarFotos();
    } on DioException catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _descargarFotos() async {
    final fotos = _reporte?.fotografias ?? const <FotografiaReporte>[];
    for (final foto in fotos) {
      if (_bytesFotos.containsKey(foto.idFoto)) continue;
      try {
        final respuesta = await dio.get(
          foto.url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (!mounted) return;
        setState(() => _bytesFotos[foto.idFoto] = respuesta.data as Uint8List);
      } catch (_) {
        // miniatura pendiente; se reintenta al recargar
      }
    }
  }

  // ------------------------------------------------------- RF-013 a RF-016

  Future<void> _guardarEvaluacion() async {
    setState(() => _guardando = true);
    try {
      final cuerpo = <String, dynamic>{
        'riesgo_peatones': _riesgoPeatones,
        'riesgo_ciclistas': _riesgoCiclistas,
        'riesgo_vehiculos': _riesgoVehiculos,
        // Si el inspector no toca un valor, el sistema lo deriva solo
        // (RF-012/014); si cambia la gravedad, la prioridad se recalcula
        // (RF-016) al no enviar prioridad.
        if (_gravedadTocada && _gravedad != null) 'gravedad': _gravedad,
        if (_prioridadTocada && _prioridad != null) 'prioridad': _prioridad,
      };
      final respuesta = await dio.post(
        '/api/evaluacion/${widget.idReporte}/evaluar',
        data: cuerpo,
      );
      final guardada =
          EvaluacionGuardada.fromJson(Map<String, dynamic>.from(respuesta.data));
      if (!mounted) return;
      setState(() {
        _evaluacion = guardada;
        _gravedad = guardada.gravedad;
        _prioridad = guardada.prioridad;
        _gravedadTocada = false;
        _prioridadTocada = false;
      });
      _snack(
        'Evaluacion guardada: gravedad ${guardada.gravedad}, '
        'prioridad ${guardada.prioridad}'
        '${guardada.urgente ? ' · URGENTE' : ''}',
      );
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ------------------------------------------------------------- RF-017

  Future<void> _aprobar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aprobar para intervencion'),
        content: const Text(
          'El reporte pasara a "Aprobado para intervencion" y estara listo '
          'para que se pueda asignar la reparación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _decidiendo = true);
    try {
      await dio.post('/api/evaluacion/${widget.idReporte}/aprobar');
      if (!mounted) return;
      _snack('Reporte #${widget.idReporte} aprobado para intervención');
      context.go('/bandeja');
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _decidiendo = false);
    }
  }

  // ------------------------------------------------------------- RF-018

  Future<void> _descartar() async {
    final controlador = TextEditingController();
    String? justificacion;
    try {
      justificacion = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Descartar reporte'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText:
                  'Justificacion obligatoria. Ej.: El dano corresponde a una '
                  'propiedad privada y no al municipio...',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controlador.text.trim()),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
    } finally {
      controlador.dispose();
    }
    if (justificacion == null) return;
    if (justificacion.length < 4) {
      _snack('La justificación necesita al menos 4 caracteres');
      return;
    }

    setState(() => _decidiendo = true);
    try {
      await dio.post(
        '/api/evaluacion/${widget.idReporte}/descartar',
        data: {'justificacion': justificacion},
      );
      if (!mounted) return;
      _snack('Reporte #${widget.idReporte} descartado');
      context.go('/bandeja');
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _decidiendo = false);
    }
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluar reporte #${widget.idReporte}'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: _cargando && _reporte == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _reporte == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _tarjetaReporte(_reporte!),
                          const SizedBox(height: 12),
                          if (_propuesta != null) _tarjetaPropuesta(_propuesta!),
                          if (_evaluacion != null) ...[
                            const SizedBox(height: 12),
                            _tarjetaEvaluacion(_evaluacion!),
                          ],
                          const SizedBox(height: 16),
                          _formulario(),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed:
                                _guardando || _decidiendo ? null : _guardarEvaluacion,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_evaluada
                                ? 'Actualizar evaluacion'
                                : 'Guardar evaluación'),
                          ),
                          if (!_evaluada)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Registra la evaluacion para habilitar las '
                                'decisiones.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _evaluada && !_decidiendo
                                      ? _aprobar
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Aprobar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _evaluada && !_decidiendo
                                      ? _descartar
                                      : null,
                                  icon: const Icon(Icons.block),
                                  label: const Text('Descartar'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _tarjetaReporte(ReporteDetalle r) {
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
            Text('Enviado el $fecha · riesgo indicado: ${r.riesgoIndicado}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(r.descripcion),
            const SizedBox(height: 8),
            MapaUbicacion(latitud: r.latitud, longitud: r.longitud),
            const SizedBox(height: 12),
            if (r.fotografias.isEmpty)
              const Text('Sin fotografias.',
                  style: TextStyle(color: Colors.black54))
            else
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.fotografias.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final foto = r.fotografias[i];
                    final bytes = _bytesFotos[foto.idFoto];
                    return GestureDetector(
                      onTap: bytes == null ? null : () => _verFoto(bytes),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: bytes != null
                            ? Image.memory(bytes,
                                width: 92, height: 92, fit: BoxFit.cover)
                            : Container(
                                width: 92,
                                height: 92,
                                color: Colors.black12,
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _tarjetaPropuesta(PropuestaEvaluacion p) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propuesta del sistema',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _fila('Gravedad propuesta', p.gravedadPropuesta),
            _fila('Prioridad propuesta', p.prioridadPropuesta),
            _fila('Urgente', p.urgentePropuesto ? 'Sí' : 'No'),
            if (p.reglaAplicada != null)
              _fila('Regla aplicada', p.reglaAplicada!),
            const SizedBox(height: 4),
            Text(
              'Puedes confirmar estos valores o modificarlos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEvaluacion(EvaluacionGuardada e) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm')
        .format(e.fechaEvaluacion.toLocal());
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evaluacion registrada el $fecha',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _fila('Gravedad', e.gravedad),
            _fila('Prioridad', e.prioridad),
            _fila('Urgente', e.urgente ? 'Si' : 'No'),
            _fila(
              'Riesgos',
              [
                if (e.riesgoPeatones) 'peatones',
                if (e.riesgoCiclistas) 'ciclistas',
                if (e.riesgoVehiculos) 'vehiculos',
              ].isEmpty
                  ? 'ninguno'
                  : [
                      if (e.riesgoPeatones) 'peatones',
                      if (e.riesgoCiclistas) 'ciclistas',
                      if (e.riesgoVehiculos) 'vehiculos',
                    ].join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evaluacion del inspector',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Riesgos observados',
                style: Theme.of(context).textTheme.bodySmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Riesgo para peatones'),
              value: _riesgoPeatones,
              onChanged: (v) => setState(() => _riesgoPeatones = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Riesgo para ciclistas'),
              value: _riesgoCiclistas,
              onChanged: (v) => setState(() => _riesgoCiclistas = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Riesgo para vehiculos'),
              value: _riesgoVehiculos,
              onChanged: (v) => setState(() => _riesgoVehiculos = v),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Gravedad',
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _gravedad,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                        DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                        DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                      ],
                      onChanged: (valor) => setState(() {
                        _gravedad = valor;
                        _gravedadTocada = true;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Prioridad',
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _prioridad,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'BAJA', child: Text('Baja')),
                        DropdownMenuItem(value: 'MEDIA', child: Text('Media')),
                        DropdownMenuItem(value: 'ALTA', child: Text('Alta')),
                      ],
                      onChanged: (valor) => setState(() {
                        _prioridad = valor;
                        _prioridadTocada = true;
                      }),
                    ),
                  ),
                ),
              ],
            ),
            if (_gravedadTocada && !_prioridadTocada)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'La prioridad se recalculara automaticamente segun la nueva '
                  'gravedad.',
                  style: Theme.of(context).textTheme.bodySmall,
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
            width: 140,
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
