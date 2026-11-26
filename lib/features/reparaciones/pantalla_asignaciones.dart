import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import 'modelo_trabajo.dart';

/// RF-020 · Reportes en 'Aprobado para intervencion' todavia sin asignar.
/// Al tocar uno se abre el formulario de asignacion (RF-020/RF-021).
class PantallaAsignaciones extends StatefulWidget {
  const PantallaAsignaciones({super.key});

  @override
  State<PantallaAsignaciones> createState() => _PantallaAsignacionesState();
}

class _PantallaAsignacionesState extends State<PantallaAsignaciones> {
  List<DisponibleAsignar> _disponibles = [];
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
      final respuesta = await dio.get('/api/reparaciones/disponibles');
      setState(() {
        _disponibles = (respuesta.data as List)
            .map((e) =>
                DisponibleAsignar.fromJson(Map<String, dynamic>.from(e)))
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
        title: const Text('Asignar reparaciones'),
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
                  child: _disponibles.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.assignment_outlined,
                                size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'No hay reportes aprobados sin asignar.\n'
                                'Desliza hacia abajo para actualizar.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _disponibles.length,
                          itemBuilder: (context, i) =>
                              _tarjeta(_disponibles[i]),
                        ),
                ),
    );
  }

  Widget _tarjeta(DisponibleAsignar d) {
    final fecha =
        DateFormat('dd/MM/yyyy HH:mm').format(d.fechaHora.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: d.prioridad == 'ALTA'
              ? Colors.red.shade700
              : d.prioridad == 'MEDIA'
                  ? Colors.orange.shade800
                  : Colors.green.shade700,
          child: const Icon(Icons.construction, color: Colors.white),
        ),
        title: Text('#${d.idReporte} · ${d.categoria}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fecha, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (d.prioridad != null)
                  Chip(
                    label: Text('Prioridad ${d.prioridad}'),
                    backgroundColor: d.prioridad == 'ALTA'
                        ? Colors.red.shade700
                        : d.prioridad == 'MEDIA'
                            ? Colors.orange.shade800
                            : Colors.green.shade700,
                    labelStyle:
                        const TextStyle(color: Colors.white, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  avatar: const Icon(Icons.photo, size: 16),
                  label: Text('${d.cantidadFotos} fotos'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: () => context.go('/asignar/${d.idReporte}'),
      ),
    );
  }
}
