import 'package:flutter/material.dart';

/// Item de la bandeja del inspector (RF-011) con la gravedad propuesta (RF-012).
class PendienteEvaluacion {
  final int idReporte;
  final String descripcion;
  final DateTime fechaHora;
  final String categoria;
  final String riesgoIndicado;
  final String estado;
  final double latitud;
  final double longitud;
  final double? precisionGps;
  final int cantidadFotos;
  final String gravedadPropuesta;

  const PendienteEvaluacion({
    required this.idReporte,
    required this.descripcion,
    required this.fechaHora,
    required this.categoria,
    required this.riesgoIndicado,
    required this.estado,
    required this.latitud,
    required this.longitud,
    this.precisionGps,
    required this.cantidadFotos,
    required this.gravedadPropuesta,
  });

  factory PendienteEvaluacion.fromJson(Map<String, dynamic> json) =>
      PendienteEvaluacion(
        idReporte: json['id_reporte'] as int,
        descripcion: json['descripcion'] as String,
        fechaHora: DateTime.parse(json['fecha_hora'] as String),
        categoria: json['categoria'] as String,
        riesgoIndicado: json['riesgo_indicado'] as String,
        estado: json['estado'] as String,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        precisionGps: (json['precision_gps'] as num?)?.toDouble(),
        cantidadFotos: json['cantidad_fotos'] as int,
        gravedadPropuesta: json['gravedad_propuesta'] as String,
      );
}

/// Valores que el sistema propone antes de evaluar (RF-012/014/015).
class PropuestaEvaluacion {
  final String gravedadPropuesta;
  final String prioridadPropuesta;
  final bool urgentePropuesto;
  final String? reglaAplicada;

  const PropuestaEvaluacion({
    required this.gravedadPropuesta,
    required this.prioridadPropuesta,
    required this.urgentePropuesto,
    this.reglaAplicada,
  });

  factory PropuestaEvaluacion.fromJson(Map<String, dynamic> json) =>
      PropuestaEvaluacion(
        gravedadPropuesta: json['gravedad_propuesta'] as String,
        prioridadPropuesta: json['prioridad_propuesta'] as String,
        urgentePropuesto: json['urgente_propuesto'] as bool,
        reglaAplicada: json['regla_aplicada'] as String?,
      );
}

/// Evaluacion ya registrada por el inspector (RF-013 a RF-016).
class EvaluacionGuardada {
  final int idEvaluacion;
  final int idReporte;
  final String gravedad;
  final String prioridad;
  final bool urgente;
  final bool riesgoPeatones;
  final bool riesgoCiclistas;
  final bool riesgoVehiculos;
  final DateTime fechaEvaluacion;

  const EvaluacionGuardada({
    required this.idEvaluacion,
    required this.idReporte,
    required this.gravedad,
    required this.prioridad,
    required this.urgente,
    required this.riesgoPeatones,
    required this.riesgoCiclistas,
    required this.riesgoVehiculos,
    required this.fechaEvaluacion,
  });

  factory EvaluacionGuardada.fromJson(Map<String, dynamic> json) =>
      EvaluacionGuardada(
        idEvaluacion: json['id_evaluacion'] as int,
        idReporte: json['id_reporte'] as int,
        gravedad: json['gravedad'] as String,
        prioridad: json['prioridad'] as String,
        urgente: json['urgente'] as bool,
        riesgoPeatones: json['riesgo_peatones'] as bool,
        riesgoCiclistas: json['riesgo_ciclistas'] as bool,
        riesgoVehiculos: json['riesgo_vehiculos'] as bool,
        fechaEvaluacion: DateTime.parse(json['fecha_evaluacion'] as String),
      );
}

/// Niveles (DA-06) con etiqueta y color para la interfaz.
class Niveles {
  static const etiquetas = {
    'BAJA': 'Baja',
    'MEDIA': 'Media',
    'ALTA': 'Alta',
  };

  static String etiqueta(String nivel) => etiquetas[nivel] ?? nivel;

  static Color color(String nivel) {
    switch (nivel) {
      case 'BAJA':
        return Colors.green.shade700;
      case 'MEDIA':
        return Colors.orange.shade800;
      case 'ALTA':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  static Chip chip(String nivel) => Chip(
        label: Text(
          'Gravedad $nivel',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: color(nivel),
        visualDensity: VisualDensity.compact,
      );
}
