// Modelos del M4 · Gestion de reparaciones (RF-020 a RF-027, RF-041).

class IntegranteCuadrilla {
  final int idUsuario;
  final String nombre;
  final String correo;

  const IntegranteCuadrilla({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
  });

  factory IntegranteCuadrilla.fromJson(Map<String, dynamic> json) =>
      IntegranteCuadrilla(
        idUsuario: json['id_usuario'] as int,
        nombre: json['nombre'] as String,
        correo: json['correo'] as String,
      );
}

class Cuadrilla {
  final int idCuadrilla;
  final String nombre;
  final List<IntegranteCuadrilla> integrantes;

  const Cuadrilla({
    required this.idCuadrilla,
    required this.nombre,
    required this.integrantes,
  });

  factory Cuadrilla.fromJson(Map<String, dynamic> json) => Cuadrilla(
        idCuadrilla: json['id_cuadrilla'] as int,
        nombre: json['nombre'] as String,
        integrantes: (json['integrantes'] as List)
            .map((e) =>
                IntegranteCuadrilla.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Reporte aprobado todavia sin asignar (RF-020).
class DisponibleAsignar {
  final int idReporte;
  final String categoria;
  final String descripcion;
  final DateTime fechaHora;
  final double latitud;
  final double longitud;
  final String? prioridad;
  final int cantidadFotos;

  const DisponibleAsignar({
    required this.idReporte,
    required this.categoria,
    required this.descripcion,
    required this.fechaHora,
    required this.latitud,
    required this.longitud,
    this.prioridad,
    required this.cantidadFotos,
  });

  factory DisponibleAsignar.fromJson(Map<String, dynamic> json) =>
      DisponibleAsignar(
        idReporte: json['id_reporte'] as int,
        categoria: json['categoria'] as String,
        descripcion: json['descripcion'] as String,
        fechaHora: DateTime.parse(json['fecha_hora'] as String),
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        prioridad: json['prioridad'] as String?,
        cantidadFotos: json['cantidad_fotos'] as int,
      );
}

class MaterialTrabajo {
  final String nombre;
  final double cantidad;

  const MaterialTrabajo({required this.nombre, required this.cantidad});

  factory MaterialTrabajo.fromJson(Map<String, dynamic> json) =>
      MaterialTrabajo(
        nombre: json['nombre'] as String,
        cantidad: (json['cantidad'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'nombre': nombre, 'cantidad': cantidad};
}

class FotoTrabajo {
  final int idFoto;
  final DateTime fechaRegistro;
  final String tipo; // ORIGINAL | POSTERIOR (RF-025)
  final String url;

  const FotoTrabajo({
    required this.idFoto,
    required this.fechaRegistro,
    required this.tipo,
    required this.url,
  });

  factory FotoTrabajo.fromJson(Map<String, dynamic> json) => FotoTrabajo(
        idFoto: json['id_foto'] as int,
        fechaRegistro: DateTime.parse(json['fecha_registro'] as String),
        tipo: json['tipo'] as String,
        url: json['url'] as String,
      );
}

/// El reporte visto desde el trabajo: ubicacion, descripcion, fotos,
/// prioridad y fecha programada (RF-022).
class ReporteEnTrabajo {
  final int idReporte;
  final String categoria;
  final String descripcion;
  final DateTime fechaHora;
  final String estado;
  final double latitud;
  final double longitud;
  final String? prioridad;
  final bool? urgente;
  final List<FotoTrabajo> fotografias;

  const ReporteEnTrabajo({
    required this.idReporte,
    required this.categoria,
    required this.descripcion,
    required this.fechaHora,
    required this.estado,
    required this.latitud,
    required this.longitud,
    this.prioridad,
    this.urgente,
    required this.fotografias,
  });

  factory ReporteEnTrabajo.fromJson(Map<String, dynamic> json) =>
      ReporteEnTrabajo(
        idReporte: json['id_reporte'] as int,
        categoria: json['categoria'] as String,
        descripcion: json['descripcion'] as String,
        fechaHora: DateTime.parse(json['fecha_hora'] as String),
        estado: json['estado'] as String,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        prioridad: json['prioridad'] as String?,
        urgente: json['urgente'] as bool?,
        fotografias: (json['fotografias'] as List)
            .map((f) => FotoTrabajo.fromJson(Map<String, dynamic>.from(f)))
            .toList(),
      );
}

/// Asignacion de reparacion (RF-020): cuadrilla O trabajador (DA-10).
class TrabajoAsignado {
  final int idTrabajo;
  final int idReporte;
  final int? idCuadrilla;
  final String? cuadrilla;
  final int? idMantenimiento;
  final String? responsable;
  final String? fechaProgramada; // YYYY-MM-DD (RF-021)
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? descripcionTrabajo;
  final String? observaciones;
  final List<MaterialTrabajo> materiales;
  final ReporteEnTrabajo reporte;

  const TrabajoAsignado({
    required this.idTrabajo,
    required this.idReporte,
    this.idCuadrilla,
    this.cuadrilla,
    this.idMantenimiento,
    this.responsable,
    this.fechaProgramada,
    this.fechaInicio,
    this.fechaFin,
    this.descripcionTrabajo,
    this.observaciones,
    required this.materiales,
    required this.reporte,
  });

  factory TrabajoAsignado.fromJson(Map<String, dynamic> json) =>
      TrabajoAsignado(
        idTrabajo: json['id_trabajo'] as int,
        idReporte: json['id_reporte'] as int,
        idCuadrilla: json['id_cuadrilla'] as int?,
        cuadrilla: json['cuadrilla'] as String?,
        idMantenimiento: json['id_mantenimiento'] as int?,
        responsable: json['responsable'] as String?,
        fechaProgramada: json['fecha_programada'] as String?,
        fechaInicio: json['fecha_inicio'] != null
            ? DateTime.parse(json['fecha_inicio'] as String)
            : null,
        fechaFin: json['fecha_fin'] != null
            ? DateTime.parse(json['fecha_fin'] as String)
            : null,
        descripcionTrabajo: json['descripcion_trabajo'] as String?,
        observaciones: json['observaciones'] as String?,
        materiales: (json['materiales'] as List)
            .map((m) => MaterialTrabajo.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        reporte: ReporteEnTrabajo.fromJson(
            Map<String, dynamic>.from(json['reporte'])),
      );
}
