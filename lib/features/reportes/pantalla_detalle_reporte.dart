import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../../core/widgets/mapa_ubicacion.dart';
import '../../core/providers/sesion_provider.dart';
import 'modelo_reporte.dart';
import 'modelo_seguimiento.dart';

/// RF-008 · Detalle del reporte: sus fotografias originales con la fecha de
/// registro, mas los datos basicos y la justificacion si existe (RF-018/019).
/// Para el inspector tambien es el punto de entrada a la evaluacion (M3).
class PantallaDetalleReporte extends ConsumerStatefulWidget {
  final int idReporte;

  const PantallaDetalleReporte({super.key, required this.idReporte});

  @override
  ConsumerState<PantallaDetalleReporte> createState() =>
      _PantallaDetalleReporteState();
}

class _PantallaDetalleReporteState
    extends ConsumerState<PantallaDetalleReporte> {
  ReporteDetalle? _datos;
  bool _cargando = true;
  String? _error;
  List<CambioEstado> _historial = [];
  final Map<int, Uint8List> _bytesFotos = {};
  int _fotosPendientes = 0;

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
      final respuesta =
          await dio.get('/api/reportes/${widget.idReporte}');
      final datos =
          ReporteDetalle.fromJson(Map<String, dynamic>.from(respuesta.data));
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _fotosPendientes = datos.fotografias
            .where((f) => !_bytesFotos.containsKey(f.idFoto))
            .length;
      });
      await _cargarHistorial();
      await _descargarFotos(datos);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// RF-031: historial de cambios de estado (RF-030). Tolerante a 403/404:
  /// sin permiso o sin registros la pantalla sigue funcionando.
  Future<void> _cargarHistorial() async {
    try {
      final respuesta =
          await dio.get('/api/seguimiento/historial/${widget.idReporte}');
      final lista = (respuesta.data as List)
          .map((e) => CambioEstado.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) setState(() => _historial = lista);
    } on DioException {
      if (mounted) setState(() => _historial = const []);
    }
  }

  Future<void> _descargarFotos(ReporteDetalle datos) async {
    for (final foto in datos.fotografias) {
      if (_bytesFotos.containsKey(foto.idFoto)) continue;
      try {
        final respuesta = await dio.get(
          foto.url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (!mounted) return;
        setState(() {
          _bytesFotos[foto.idFoto] = respuesta.data as Uint8List;
          _fotosPendientes--;
        });
      } catch (_) {
        if (mounted) setState(() => _fotosPendientes--);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte #${widget.idReporte}'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: _cargando && _datos == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _datos == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _tarjetas(_datos!),
                      ),
                    ),
    );
  }

  /// Acciones del inspector segun el estado del reporte (RF-017/018 desde
  /// la evaluacion y RF-019 para cerrar uno reparado). El administrador
  /// siempre puede corregir el estado (RF-046, excepcion a RF-029).
  List<Widget> _acciones(ReporteDetalle r) {
    final rol = ref.watch(sesionProvider).value?.rol;
    if (rol == 'administrador') {
      return [
        FilledButton.tonalIcon(
          onPressed: () => _corregirEstado(r),
          icon: const Icon(Icons.rule_outlined),
          label: const Text('Corregir estado'),
        ),
        const SizedBox(height: 12),
      ];
    }
    if (rol != 'inspector') return const [];
    if (r.estado == 'PENDIENTE_REVISION') {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/evaluar/${r.idReporte}'),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Evaluar y decidir'),
        ),
        const SizedBox(height: 12),
      ];
    }
    if (r.estado == 'APROBADO_INTERVENCION') {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/asignar/${r.idReporte}'),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Asignar reparación'),
        ),
        const SizedBox(height: 12),
      ];
    }
    if (r.estado == 'REPARADO') {
      return [
        FilledButton.tonalIcon(
          onPressed: () => _cerrar(r),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Cerrar reporte'),
        ),
        const SizedBox(height: 12),
      ];
    }
    return const [];
  }

  /// RF-019 · Cierre tras verificar la reparacion (resultado obligatorio).
  Future<void> _cerrar(ReporteDetalle r) async {
    final controlador = TextEditingController();
    String? resultado;
    try {
      resultado = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cerrar reporte'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText:
                  'Resultado de la verificacion. Ej.: Pavimento reparado, '
                  'nivelado y verificado en campo...',
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
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      controlador.dispose();
    }
    if (resultado == null) return;
    if (resultado.length < 4) {
      _snack('El resultado necesita al menos 4 caracteres');
      return;
    }
    try {
      await dio.post(
        '/api/evaluacion/${r.idReporte}/cerrar',
        data: {'resultado': resultado},
      );
      if (!mounted) return;
      _snack('Reporte #${r.idReporte} cerrado');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    }
  }

  /// RF-046 · Correccion de estado por el administrador: cualquier destino
  /// (se salta la tabla RF-029) pero con justificacion obligatoria; la API
  /// responde 422 sin ella y 409 si el estado ya esta vigente.
  Future<void> _corregirEstado(ReporteDetalle r) async {
    final controlador = TextEditingController();
    // Se ofrece cualquier estado distinto del vigente (evita el 409)
    final opciones = EstadosReporte.etiquetas.keys
        .where((e) => e != r.estado)
        .toList();
    if (opciones.isEmpty) return;
    String estadoNuevo = opciones.first;
    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Corregir estado'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado vigente: ${EstadosReporte.etiqueta(r.estado)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: estadoNuevo,
                    items: [
                      for (final e in opciones)
                        DropdownMenuItem(
                          value: e,
                          child: Text(EstadosReporte.etiqueta(e)),
                        ),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setDialogState(() => estadoNuevo = valor);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controlador,
                    autofocus: true,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText:
                          'Justificacion obligatoria (minimo 4 caracteres). '
                          'Ejec.: Correccion por verificacion en campo...',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Corregir'),
              ),
            ],
          ),
        ),
      );
      if (confirmado != true) return;
      final justificacion = controlador.text.trim();
      if (justificacion.length < 4) {
        _snack('La justificación necesita al menos 4 caracteres');
        return;
      }
      await dio.post(
        '/api/seguimiento/correccion',
        data: {
          'id_reporte': r.idReporte,
          'estado': estadoNuevo,
          'justificacion': justificacion,
        },
      );
      if (!mounted) return;
      _snack(
          'Estado corregido a ${EstadosReporte.etiqueta(estadoNuevo)}');
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      controlador.dispose();
    }
  }

  List<Widget> _tarjetas(ReporteDetalle r) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(r.fechaHora.toLocal());
    return [
      ..._acciones(r),
      // --- Estado y categoria
      Card(
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
              const SizedBox(height: 8),
              Text('Enviado el $fecha',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              _fila('Riesgo indicado', r.riesgoIndicado),
              if (r.nombreReportante != null)
                _fila('Reportado por', r.nombreReportante!),
              if (r.barrio != null) _fila('Barrio', r.barrio!),
            ],
          ),
        ),
      ),
      // --- Descripcion
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Descripcion',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(r.descripcion),
            ],
          ),
        ),
      ),
      // --- Justificacion / cierre (RF-018, RF-019, RF-031)
      if (r.justificacion != null && r.justificacion!.isNotEmpty)
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Justificacion / resultado del cierre',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(r.justificacion!),
              ],
            ),
          ),
        ),
      // --- Historial de estados (RF-030, visible para el ciudadano RF-031)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Historial de estados',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_historial.isEmpty)
                const Text('Sin registros de cambios de estado.')
              else
                ..._historial.reversed.map(_filaHistorial),
            ],
          ),
        ),
      ),
      // --- Ubicacion
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MapaUbicacion(latitud: r.latitud, longitud: r.longitud),
              if (r.precisionGps != null)
                _fila('Precision GPS',
                    '${r.precisionGps!.toStringAsFixed(0)} m'),
            ],
          ),
        ),
      ),
      // --- Fotografias (RF-008)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Fotografias originales',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  if (_fotosPendientes > 0)
                    Text('$_fotosPendientes cargando...',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha de registro de cada imagen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (r.fotografias.isEmpty)
                const Text('Este reporte no tiene fotografias.')
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: r.fotografias.map(_foto).toList(),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _foto(FotografiaReporte foto) {
    final bytes = _bytesFotos[foto.idFoto];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: Colors.black12,
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${foto.tipo.toLowerCase()} · '
          '${DateFormat('dd/MM/yyyy HH:mm').format(foto.fechaRegistro.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Una entrada del historial: transicion, fecha, usuario y justificacion.
  Widget _filaHistorial(CambioEstado c) {
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(c.fechaHora.toLocal());
    final transicion = c.estadoAnterior == null
        ? 'Inicio: ${EstadosReporte.etiqueta(c.estadoNuevo)}'
        : '${EstadosReporte.etiqueta(c.estadoAnterior!)} -> '
            '${EstadosReporte.etiqueta(c.estadoNuevo)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  transicion,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                fecha,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          Text(
            'Responsable: ${c.usuario}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (c.justificacion != null && c.justificacion!.isNotEmpty)
            Text(
              'Justificacion: ${c.justificacion}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          const Divider(height: 14),
        ],
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
