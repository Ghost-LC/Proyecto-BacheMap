import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import 'modelo_evaluacion.dart';

/// M3 · Bandeja de evaluacion del inspector (RF-011): reportes en
/// 'Pendiente de revision' con la gravedad ya propuesta por el sistema
/// (RF-012). Al tocar un item se abre la pantalla de evaluacion.
class PantallaBandeja extends StatefulWidget {
  const PantallaBandeja({super.key});

  @override
  State<PantallaBandeja> createState() => _PantallaBandejaState();
}

class _PantallaBandejaState extends State<PantallaBandeja> {
  List<PendienteEvaluacion> _pendientes = [];
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
      final respuesta = await dio.get('/api/evaluacion/pendientes');
      setState(() {
        _pendientes = (respuesta.data as List)
            .map((e) =>
                PendienteEvaluacion.fromJson(Map<String, dynamic>.from(e)))
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
        title: const Text('Bandeja de evaluación'),
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
                  child: _pendientes.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.fact_check_outlined,
                                size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'No hay reportes pendientes de revision.\n'
                                'Desliza hacia abajo para actualizar.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _pendientes.length,
                          itemBuilder: (context, i) =>
                              _tarjeta(_pendientes[i]),
                        ),
                ),
    );
  }

  Widget _tarjeta(PendienteEvaluacion p) {
    final fecha =
        DateFormat('dd/MM/yyyy HH:mm').format(p.fechaHora.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Niveles.color(p.gravedadPropuesta),
          child: const Icon(Icons.priority_high, color: Colors.white),
        ),
        title: Text('#${p.idReporte} · ${p.categoria}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fecha, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Niveles.chip(p.gravedadPropuesta),
                Chip(
                  avatar: const Icon(Icons.photo, size: 16),
                  label: Text('${p.cantidadFotos} fotos'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.warning_amber, size: 16),
                  label: Text(p.riesgoIndicado.toLowerCase()),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
        onTap: () => context.go('/evaluar/${p.idReporte}'),
      ),
    );
  }
}
