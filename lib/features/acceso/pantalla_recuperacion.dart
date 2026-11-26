import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_client.dart';

/// RF-038 · Recuperación de acceso por correo.
///
/// Paso 1: se solicita el enlace. En desarrollo la API devuelve el enlace en
/// `enlace_dev` (sin SMTP), por lo que se puede completar el paso 2 sin
/// abrir el correo.
class PantallaRecuperacion extends StatefulWidget {
  const PantallaRecuperacion({super.key});

  @override
  State<PantallaRecuperacion> createState() => _PantallaRecuperacionState();
}

class _PantallaRecuperacionState extends State<PantallaRecuperacion> {
  final _correo = TextEditingController();
  final _token = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  bool _enlaceEnviado = false;

  @override
  void dispose() {
    _correo.dispose();
    _token.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    setState(() => _cargando = true);
    try {
      final r = await dio.post(
        '/api/acceso/recuperar',
        data: {'correo': _correo.text.trim()},
      );
      final enlace = r.data is Map ? r.data['enlace_dev'] as String? : null;
      if (enlace != null && enlace.contains('token=')) {
        _token.text = enlace.split('token=')[1];
      }
      setState(() => _enlaceEnviado = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Si el correo existe, se envió el enlace.')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _restablecer() async {
    if (_token.text.isEmpty || _clave.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pega el enlace/token y una clave de 6+ caracteres')),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await dio.post(
        '/api/acceso/restablecer',
        data: {'token': _token.text.trim(), 'nueva_contrasena': _clave.text},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada. Inicia sesión.')),
        );
        context.go('/');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar acceso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paso 1 · Indica el correo de tu cuenta y te enviaremos un enlace '
              'para restablecer la contraseña.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo registrado',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargando ? null : _solicitar,
              child: const Text('Enviar enlace de recuperación'),
            ),
            if (_enlaceEnviado) ...[
              const Divider(height: 40),
              const Text(
                'Paso 2 · Pega el enlace (o token) recibido y define la contraseña nueva.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _token,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Enlace o token recibido',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clave,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña (minimo 6)',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargando ? null : _restablecer,
                child: const Text('Guardar nueva contraseña'),
              ),
            ],
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Volver a inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
