import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import '../evaluacion/modelo_evaluacion.dart';

/// Modelo de regla de priorizacion (RF-045).
class ReglaPriorizacion {
  final int idRegla;
  final String tipo; // GRAVEDAD o PRIORIDAD
  final Map<String, dynamic> condicion;
  final String? gravedadResultante;
  final String? prioridadResultante;
  final bool activa;

  const ReglaPriorizacion({
    required this.idRegla,
    required this.tipo,
    required this.condicion,
    this.gravedadResultante,
    this.prioridadResultante,
    required this.activa,
  });

  factory ReglaPriorizacion.fromJson(Map<String, dynamic> j) =>
      ReglaPriorizacion(
        idRegla: j['id_regla'] as int,
        tipo: j['tipo'] as String,
        condicion: Map<String, dynamic>.from(j['condicion'] as Map),
        gravedadResultante: j['gravedad_resultante'] as String?,
        prioridadResultante: j['prioridad_resultante'] as String?,
        activa: j['activa'] as bool,
      );
}

/// RF-045 · Configuracion de las reglas de priorizacion (solo administrador).
/// Permite al administrador ver, crear, activar/desactivar o modificar las
/// reglas que determinan la propuesta de gravedad y la prioridad asignada.
class PantallaReglas extends StatefulWidget {
  const PantallaReglas({super.key});

  @override
  State<PantallaReglas> createState() => _PantallaReglasState();
}

class _PantallaReglasState extends State<PantallaReglas> {
  List<ReglaPriorizacion> _reglas = [];
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
      final r = await dio.get('/api/administracion/reglas');
      setState(() {
        _reglas = (r.data as List)
            .map((e) =>
                ReglaPriorizacion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _alternarActiva(ReglaPriorizacion regla, bool valor) async {
    try {
      await dio.patch(
        '/api/administracion/reglas/${regla.idRegla}',
        data: {'activa': valor},
      );
      await _cargar();
    } on DioException catch (e) {
      _snack(mensajeDeError(e));
    }
  }

  Future<void> _crearOEditar({ReglaPriorizacion? regla}) async {
    String tipo = regla?.tipo ?? 'GRAVEDAD';
    String? gravedad = regla?.gravedadResultante ?? (tipo == 'GRAVEDAD' ? 'ALTA' : null);
    String? prioridad = regla?.prioridadResultante ?? (tipo == 'PRIORIDAD' ? 'ALTA' : null);
    
    final condicionCtrl = TextEditingController(
      text: regla != null
          ? jsonEncode(regla.condicion)
          : '{"categoria": "Bache", "riesgo": "VEHICULOS"}',
    );

    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(regla == null
                ? 'Nueva regla'
                : 'Modificar regla #${regla.idRegla}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (regla == null) ...[
                      const Text('Tipo de regla:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: tipo,
                        items: const [
                          DropdownMenuItem(
                              value: 'GRAVEDAD',
                              child: Text('Regla de Gravedad')),
                          DropdownMenuItem(
                              value: 'PRIORIDAD',
                              child: Text('Regla de Prioridad')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() {
                              tipo = v;
                              if (tipo == 'GRAVEDAD') {
                                gravedad = 'ALTA';
                                prioridad = null;
                                condicionCtrl.text =
                                    '{"categoria": "Bache", "riesgo": "VEHICULOS"}';
                              } else {
                                prioridad = 'ALTA';
                                gravedad = null;
                                condicionCtrl.text =
                                    '{"gravedad": "ALTA", "algun_riesgo": ["PEATONES"]}';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (tipo == 'GRAVEDAD') ...[
                      const Text('Gravedad resultante:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: gravedad ?? 'ALTA',
                        items: const [
                          DropdownMenuItem(value: 'BAJA', child: Text('BAJA')),
                          DropdownMenuItem(value: 'MEDIA', child: Text('MEDIA')),
                          DropdownMenuItem(value: 'ALTA', child: Text('ALTA')),
                        ],
                        onChanged: (v) => setDialogState(() => gravedad = v),
                      ),
                    ] else ...[
                      const Text('Prioridad resultante:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: prioridad ?? 'ALTA',
                        items: const [
                          DropdownMenuItem(value: 'BAJA', child: Text('BAJA')),
                          DropdownMenuItem(value: 'MEDIA', child: Text('MEDIA')),
                          DropdownMenuItem(value: 'ALTA', child: Text('ALTA')),
                        ],
                        onChanged: (v) => setDialogState(() => prioridad = v),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Condición (JSON):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: condicionCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ej: {"categoria": "Bache", "riesgo": "VEHICULOS"}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: Text(regla == null ? 'Crear' : 'Guardar'),
              ),
            ],
          ),
        ),
      );

      if (confirmado != true) return;

      Map<String, dynamic> condObj;
      try {
        final parsed = jsonDecode(condicionCtrl.text.trim());
        if (parsed is! Map<String, dynamic>) throw const FormatException();
        condObj = parsed;
      } catch (_) {
        _snack('La condición no es un objeto JSON válido');
        return;
      }

      if (regla == null) {
        final body = {
          'tipo': tipo,
          'condicion': condObj,
          if (tipo == 'GRAVEDAD') 'gravedad_resultante': gravedad,
          if (tipo == 'PRIORIDAD') 'prioridad_resultante': prioridad,
          'activa': true,
        };
        await dio.post('/api/administracion/reglas', data: body);
        _snack('Regla creada exitosamente');
      } else {
        final body = {
          'condicion': condObj,
          if (tipo == 'GRAVEDAD') 'gravedad_resultante': gravedad,
          if (tipo == 'PRIORIDAD') 'prioridad_resultante': prioridad,
        };
        await dio.patch('/api/administracion/reglas/${regla.idRegla}', data: body);
        _snack('Regla actualizada');
      }
      await _cargar();
    } on DioException catch (e) {
      _snack(mensajeDeError(e));
    } finally {
      condicionCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglas de priorización'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _crearOEditar(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva regla'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Las reglas determinan la gravedad propuesta y la prioridad '
                        'al evaluar reportes. Los reportes nuevos se evalúan con '
                        'las reglas activas.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (_reglas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay reglas configuradas.'),
                        ),
                      ..._reglas.map((r) {
                        final resultado = r.tipo == 'GRAVEDAD'
                            ? r.gravedadResultante ?? 'Sin definir'
                            : r.prioridadResultante ?? 'Sin definir';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: r.tipo == 'GRAVEDAD'
                                  ? Colors.indigo.shade100
                                  : Colors.teal.shade100,
                              child: Icon(
                                r.tipo == 'GRAVEDAD'
                                    ? Icons.report_problem
                                    : Icons.low_priority,
                                color: r.tipo == 'GRAVEDAD'
                                    ? Colors.indigo
                                    : Colors.teal,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('${r.tipo} · ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Chip(
                                  label: Text(
                                    r.tipo == 'GRAVEDAD'
                                        ? 'Gravedad $resultado'
                                        : 'Prioridad $resultado',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                  backgroundColor: Niveles.color(resultado),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Condición: ${jsonEncode(r.condicion)}',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 11),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: r.activa,
                                  onChanged: (v) => _alternarActiva(r, v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Editar',
                                  onPressed: () => _crearOEditar(regla: r),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }
}
