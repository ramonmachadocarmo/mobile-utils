import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Continuação da splash nativa (mesmo fundo e logo na mesma posição) com o
/// nome e a tagline, que a splash nativa não consegue mostrar. Some sozinha.
/// Não aparece quando o app abre por deep link (ex.: toque no widget).
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  /// Medido no emulador para coincidir com o logo da splash nativa do Android 12+.
  static const logoSize = 173.0;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> {
  late bool _visible = PlatformDispatcher.instance.defaultRouteName == '/';
  late bool _mounted = _visible;

  @override
  void initState() {
    super.initState();
    if (_visible) _hideLater();
  }

  // Conta a partir do primeiro quadro desenhado: até lá a splash nativa ainda
  // cobre a tela (no modo debug isso passa de 1 s).
  Future<void> _hideLater() async {
    // Limite de 3 s por garantia (em testes esse sinal nunca chega).
    await Future.any([
      WidgetsBinding.instance.waitUntilFirstFrameRasterized,
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    // Sempre o mesmo Stack: trocar a estrutura recriaria o Navigator (child).
    return Stack(
      children: [
        widget.child,
        if (_mounted)
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 350),
              onEnd: () => setState(() => _mounted = false),
              child: const _SplashContent(),
            ),
          ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: BrandColors.splash,
        child: Stack(
          children: [
            const Center(
              child: Image(
                image: AssetImage('assets/branding/splash_logo.png'),
                width: SplashOverlay.logoSize,
                height: SplashOverlay.logoSize,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: height / 2 + SplashOverlay.logoSize / 2 - 8,
              child: Column(
                children: [
                  Text(
                    'OmniTool',
                    style: GoogleFonts.poppins(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: BrandColors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All-In-One Mobile Utilities',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: BrandColors.white,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: height * 0.1,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
