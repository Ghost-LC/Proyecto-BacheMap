import 'package:flutter/material.dart';

/// Fotografia original del reporte (RF-007/RF-008).
class FotografiaReporte {
  final int idFoto;
  final DateTime fechaRegistro;
  final String tipo;
  final String url;

  const FotografiaReporte({
    required this.idFoto,
    required this.fechaRegistro,
    required this.tipo,
    required this.url,
  });

  factory FotografiaReporte.fromJson(Map<String, dynamic> json) =>
      FotografiaReporte(
        idFoto: json['id_foto'] as int,
        fechaRegistro: DateTime.parse(json['fecha_registro'] as String),
        tipo: json['tipo'] as String,
        url: json['url'] as String,
      );
}

/// Reporte completo tal como lo devuelve la API.
class ReporteDetalle {
  final int idReporte;
  final String descripcion;
  final DateTime fechaHora;
  final String riesgoIndicado;
  final double latitud;
  final double longitud;
  final double? latitudOriginal;
  final double? longitudOriginal;
  final double? precisionGps;
  final String estado;
  final String? justificacion;
  final int idCategoria;
  final String categoria;
  final int? idBarrio;
  final String? barrio;
  final String? nombreReportante;
  final List<FotografiaReporte> fotografias;

  const ReporteDetalle({
    required this.idReporte,
    required this.descripcion,
    required this.fechaHora,
    required this.riesgoIndicado,
    required this.latitud,
    required this.longitud,
    this.latitudOriginal,
    this.longitudOriginal,
    this.precisionGps,
    required this.estado,
    this.justificacion,
    required this.idCategoria,
    required this.categoria,
    this.idBarrio,
    this.barrio,
    this.nombreReportante,
    required this.fotografias,
  });

  factory ReporteDetalle.fromJson(Map<String, dynamic> json) =>
      ReporteDetalle(
        idReporte: json['id_reporte'] as int,
        descripcion: json['descripcion'] as String,
        fechaHora: DateTime.parse(json['fecha_hora'] as String),
        riesgoIndicado: json['riesgo_indicado'] as String,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        latitudOriginal: (json['latitud_original'] as num?)?.toDouble(),
        longitudOriginal: (json['longitud_original'] as num?)?.toDouble(),
        precisionGps: (json['precision_gps'] as num?)?.toDouble(),
        estado: json['estado'] as String,
        justificacion: json['justificacion'] as String?,
        idCategoria: json['id_categoria'] as int,
        categoria: json['categoria'] as String,
        idBarrio: json['id_barrio'] as int?,
        barrio: json['barrio'] as String?,
        nombreReportante: json['nombre_reportante'] as String?,
        fotografias: (json['fotografias'] as List)
            .map((f) => FotografiaReporte.fromJson(Map<String, dynamic>.from(f)))
            .toList(),
      );
}

/// Estados fijos de la ERF (DA-08) con su etiqueta y color para la interfaz.
class EstadosReporte {
  static const Map<String, String> etiquetas = {
    'REPORTADO': 'Reportado',
    'PENDIENTE_REVISION': 'Pendiente de revisión',
    'APROBADO_INTERVENCION': 'Aprobado para intervención',
    'EN_REPARACION': 'En reparación',
    'REPARADO': 'Reparado',
    'CERRADO_DESCARTADO': 'Cerrado / descartado',
  };

  static String etiqueta(String estado) => etiquetas[estado] ?? estado;

  static Color color(String estado) {
    switch (estado) {
      case 'REPORTADO':
        return const Color(0xFF496374);
      case 'PENDIENTE_REVISION':
        return const Color(0xFF855300);
      case 'APROBADO_INTERVENCION':
        return const Color(0xFF315B8A);
      case 'EN_REPARACION':
        return const Color(0xFF6D4C84);
      case 'REPARADO':
        return const Color(0xFF246B4B);
      case 'CERRADO_DESCARTADO':
        return const Color(0xFF52616C);
      default:
        return const Color(0xFF52616C);
    }
  }

  static Chip chip(String estado) => Chip(
        label: Text(
          etiqueta(estado),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: color(estado),
        visualDensity: VisualDensity.compact,
      );
}
