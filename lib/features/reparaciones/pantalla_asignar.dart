import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../../core/widgets/mapa_ubicacion.dart';
import '../reportes/modelo_reporte.dart';
import 'modelo_trabajo.dart';

/// RF-020/RF-021 · Asignar un reporte aprobado a una cuadrilla O a un
/// trabajador de mantenimiento (DA-10), indicando la fecha programada.
class PantallaAsignar extends StatefulWidget {
  final int idReporte;

  const PantallaAsignar({super.key, required this.idReporte});

  @override
  State<PantallaAsignar> createState() => _PantallaAsignarState();
}

class _PantallaAsignarState extends State<PantallaAsignar> {
  ReporteDetalle? _reporte;
  List<Cuadrilla> _cuadrillas = [];
  List<IntegranteCuadrilla> _trabajadores = [];
  bool _cargando = true;
  String? _error;

  String _destino = 'cuadrilla';
  int? _idCuadrilla;
  int? _idTrabajador;
  DateTime? _fecha;
  bool _enviando = false;

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
      final respuestas = await Future.wait([
        dio.get('/api/reportes/${widget.idReporte}'),
        dio.get('/api/reparaciones/cuadrillas'),
        dio.get('/api/reparaciones/trabajadores'),
      ]);
      setState(() {
        _reporte = ReporteDetalle.fromJson(
            Map<String, dynamic>.from(respuestas[0].data));
        _cuadrillas = (respuestas[1].data as List)
            .map((e) => Cuadrilla.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _trabajadores = (respuestas[2].data as List)
            .map((e) =>
                IntegranteCuadrilla.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
      helpText: 'Fecha programada de intervención',
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _asignar() async {
    if (_destino == 'cuadrilla' && _idCuadrilla == null) {
      _snack('Elige una cuadrilla');
      return;
    }
    if (_destino == 'trabajador' && _idTrabajador == null) {
      _snack('Elige un trabajador de mantenimiento');
      return;
    }
    setState(() => _enviando = true);
    try {
      await dio.post(
        '/api/reparaciones/trabajos',
        data: {
          'id_reporte': widget.idReporte,
          if (_destino == 'cuadrilla') 'id_cuadrilla': _idCuadrilla,
          if (_destino == 'trabajador') 'id_mantenimiento': _idTrabajador,
          if (_fecha != null)
            'fecha_programada': DateFormat('yyyy-MM-dd').format(_fecha!),
        },
      );
      if (!mounted) return;
      _snack('Reporte #${widget.idReporte} asignado');
      context.go('/asignaciones');
    } catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Asignar reporte #${widget.idReporte}'),
        actions: const [BotonMenuPrincipal()],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _resumen(),
                      const SizedBox(height: 16),
                      _destinoCard(),
                      const SizedBox(height: 16),
                      _fechaCard(),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _enviando ? null : _asignar,
                        icon: _enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.assignment_ind_outlined),
                        label: Text(
                            _enviando ? 'Asignando...' : 'Asignar reparacion'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tras asignar, el responsable podra iniciar la '
                        'reparación.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _resumen() {
    final r = _reporte;
    if (r == null) return const SizedBox.shrink();
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
            const SizedBox(height: 8),
            Text(r.descripcion),
            const SizedBox(height: 8),
            MapaUbicacion(latitud: r.latitud, longitud: r.longitud),
          ],
        ),
      ),
    );
  }

  Widget _destinoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asignar a una cuadrilla o trabajador',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Exactamente uno: cuadrilla o trabajador, nunca ambos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'cuadrilla',
                    label: Text('Cuadrilla'),
                    icon: Icon(Icons.groups)),
                ButtonSegment(
                    value: 'trabajador',
                    label: Text('Trabajador'),
                    icon: Icon(Icons.person)),
              ],
              selected: {_destino},
              onSelectionChanged: (valor) =>
                  setState(() => _destino = valor.first),
            ),
            const SizedBox(height: 12),
            if (_destino == 'cuadrilla')
              _cuadrillas.isEmpty
                  ? const Text(
                      'No hay cuadrillas. El administrador debe crearlas '
                      'primero.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    )
                  : DropdownButtonFormField<int>(
                      initialValue: _idCuadrilla,
                      decoration:
                          const InputDecoration(labelText: 'Cuadrilla'),
                      hint: const Text('Elige una cuadrilla'),
                      items: _cuadrillas
                          .map((c) => DropdownMenuItem(
                                value: c.idCuadrilla,
                                child: Text(c.nombre),
                              ))
                          .toList(),
                      onChanged: (valor) =>
                          setState(() => _idCuadrilla = valor),
                    )
            else
              _trabajadores.isEmpty
                  ? const Text(
                      'No hay trabajadores de mantenimiento habilitados.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    )
                  : DropdownButtonFormField<int>(
                      initialValue: _idTrabajador,
                      decoration:
                          const InputDecoration(labelText: 'Trabajador'),
                      hint: const Text('Elige un trabajador'),
                      items: _trabajadores
                          .map((t) => DropdownMenuItem(
                                value: t.idUsuario,
                                child: Text('${t.nombre} — ${t.correo}'),
                              ))
                          .toList(),
                      onChanged: (valor) =>
                          setState(() => _idTrabajador = valor),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _fechaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha programada de intervención',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fecha == null
                        ? 'Sin fecha todavia (opcional)'
                        : DateFormat('dd/MM/yyyy').format(_fecha!),
                    style: TextStyle(
                      color: _fecha == null ? Colors.black54 : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_fecha == null ? 'Elegir fecha' : 'Cambiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
