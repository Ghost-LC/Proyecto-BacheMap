import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import 'modelo_reporte.dart';

/// Listado de reportes visibles para el usuario actual (DA-12):
/// el ciudadano ve los suyos; los roles municipales, todos.
class PantallaMisReportes extends StatefulWidget {
  const PantallaMisReportes({super.key});

  @override
  State<PantallaMisReportes> createState() => _PantallaMisReportesState();
}

class _PantallaMisReportesState extends State<PantallaMisReportes> {
  List<ReporteDetalle> _reportes = [];
  bool _cargando = true;
  String? _error;
  final _busqueda = TextEditingController();
  Timer? _esperaBusqueda;
  int _secuencia = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _esperaBusqueda?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _cambioBusqueda(String texto) {
    _esperaBusqueda?.cancel();
    // Invalida inmediatamente cualquier respuesta de una búsqueda anterior.
    _secuencia++;
    setState(() {
      _cargando = true;
      _error = null;
    });
    _esperaBusqueda = Timer(const Duration(milliseconds: 350), _cargar);
  }

  Future<void> _cargar() async {
    _esperaBusqueda?.cancel();
    final secuencia = ++_secuencia;
    final termino = _busqueda.text.trim();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuesta = await dio.get(
        '/api/reportes',
        queryParameters: termino.isEmpty ? null : {'q': termino},
      );
      if (!mounted || secuencia != _secuencia) return;
      setState(() {
        _reportes = (respuesta.data as List)
            .map((e) => ReporteDetalle.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      if (!mounted || secuencia != _secuencia) return;
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted && secuencia == _secuencia) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/reportes/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _busqueda,
              onChanged: _cambioBusqueda,
              maxLength: 120,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cargar(),
              decoration: InputDecoration(
                labelText: 'Buscar reportes',
                hintText: 'Número, descripción, categoría o barrio',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _busqueda.clear();
                          _cambioBusqueda('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          if (!_cargando && _error == null && _reportes.length == 300)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Se muestran hasta 300 reportes. Usa una búsqueda más específica.',
              ),
            ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: _reportes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              const Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  _busqueda.text.trim().isEmpty
                                      ? 'No hay reportes disponibles.'
                                      : 'No se encontraron reportes para esta búsqueda.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: _reportes.length,
                            itemBuilder: (context, i) {
                              final r = _reportes[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: EstadosReporte.color(
                                      r.estado,
                                    ),
                                    child: const Icon(
                                      Icons.report_problem,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    '#${r.idReporte} · ${r.categoria}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Registrado el ${DateFormat('dd/MM/yyyy HH:mm').format(r.fechaHora.toLocal())}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      EstadosReporte.chip(r.estado),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  isThreeLine: true,
                                  onTap: () =>
                                      context.go('/reportes/${r.idReporte}'),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
