import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_client.dart';
import '../../core/providers/sesion_provider.dart';
import '../../core/storage/acceso_offline.dart';
import '../../core/theme/app_theme.dart';

/// RF-037 · Autenticacion de los cuatro roles.
class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  bool _ocltaClave = true;
  String? _perfilOffline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _siYaHaySesion());
    _cargarPerfilOffline();
  }

  Future<void> _cargarPerfilOffline() async {
    try {
      final nombre = await AccesoOffline.nombreDisponible();
      if (mounted) setState(() => _perfilOffline = nombre);
    } catch (_) {
      // El inicio de sesión online sigue disponible.
    }
  }

  Future<void> _siYaHaySesion() async {
    final sesion = await ref.read(sesionProvider.future);
    if (sesion != null && mounted) context.go('/menu');
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref
          .read(sesionProvider.notifier)
          .iniciar(_correo.text.trim(), _clave.text);
      if (mounted) context.go('/menu');
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo iniciar sesión: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _iniciarOffline() async {
    final controlador = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acceso sin conexión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cuenta guardada: $_perfilOffline. Introduce tu PIN de 6 dígitos.'),
            TextField(
              controller: controlador,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const Text('Disponible solo cuando no se puede conectar con el servidor.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controlador.text),
              child: const Text('Desbloquear')),
        ],
      ),
    );
    controlador.dispose();
    if (pin == null || !mounted) return;
    setState(() => _cargando = true);
    try {
      await ref.read(sesionProvider.notifier).iniciarSinConexion(pin);
      if (mounted) context.go('/menu');
    } catch (e) {
      if (mounted) {
        final mensaje = e is StateError ? e.message.toString() : 'No se pudo acceder: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.azulOscuro, AppTheme.primario],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/branding/bachemap_icon.png',
                            width: 62,
                            height: 62,
                            semanticLabel: 'Icono de BacheMap',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'CIUDADANÍA EN ACCIÓN',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFFFDB86),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'BacheMap',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reporte de Baches y Daños Viales',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Juntos cuidamos nuestras calles.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFDCEBF4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Bienvenido', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Inicia sesión para continuar',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textoSecundario,
                      )),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _clave,
                    obscureText: _ocltaClave,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocltaClave
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _ocltaClave = !_ocltaClave),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    onFieldSubmitted: (_) => _iniciar(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _cargando ? null : _iniciar,
                    child: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  if (_perfilOffline != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _cargando ? null : _iniciarOffline,
                      icon: const Icon(Icons.offline_bolt_outlined),
                      label: const Text('Acceder sin conexión con PIN'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/recuperacion'),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/registro'),
                    child: const Text('¿No tienes cuenta? Regístrate como ciudadano'),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
