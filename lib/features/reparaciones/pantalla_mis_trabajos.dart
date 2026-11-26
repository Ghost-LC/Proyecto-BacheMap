import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../reportes/modelo_reporte.dart';
import 'modelo_trabajo.dart';

/// RF-022 · Los trabajos asignados a la persona o a su cuadrilla, con
/// ubicacion, descripcion, fotografias, prioridad y fecha programada.
class PantallaMisTrabajos extends StatefulWidget {
  const PantallaMisTrabajos({super.key});

  @override
  State<PantallaMisTrabajos> createState() => _PantallaMisTrabajosState();
}

class _PantallaMisTrabajosState extends State<PantallaMisTrabajos> {
  List<TrabajoAsignado> _trabajos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuesta = await dio.get('/api/reparaciones/mis-trabajos');
      setState(() {
        _trabajos = (respuesta.data as List)
            .map((e) => TrabajoAsignado.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis trabajos'),
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
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _trabajos.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.work_outline,
                                size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'No tienes trabajos asignados.\n'
                                'Desliza hacia abajo para actualizar.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _trabajos.length,
                          itemBuilder: (context, i) =>
                              _tarjeta(_trabajos[i]),
                        ),
                ),
    );
  }

  Widget _tarjeta(TrabajoAsignado t) {
    final r = t.reporte;
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(r.fechaHora.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: EstadosReporte.color(r.estado),
          child: const Icon(Icons.construction, color: Colors.white, size: 20),
        ),
        title: Text('#${t.idTrabajo} · ${r.categoria}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fecha, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                EstadosReporte.chip(r.estado),
                if (r.prioridad != null)
                  Chip(
                    label: Text('Prioridad ${r.prioridad}'),
                    backgroundColor:
                        NivelesReparacion.colorPrioridad(r.prioridad),
                    labelStyle:
                        const TextStyle(color: Colors.white, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                if (t.fechaProgramada != null)
                  Chip(
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text(t.fechaProgramada!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (t.cuadrilla != null || t.responsable != null)
              Text(
                t.cuadrilla != null ? 'Cuadrilla: ${t.cuadrilla}' : '',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: () => context.go('/mis-trabajos/${t.idTrabajo}'),
      ),
    );
  }
}

/// Colores de prioridad compartidos de la pantalla de trabajo.
class NivelesReparacion {
  static Color colorPrioridad(String? prioridad) {
    switch (prioridad) {
      case 'ALTA':
        return Colors.red.shade700;
      case 'MEDIA':
        return Colors.orange.shade800;
      case 'BAJA':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }
}
