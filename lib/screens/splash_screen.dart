import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget destination;
  const SplashScreen({super.key, required this.destination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _iconOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _loadingOpacity;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    Animation<double> fade(double from, double to) =>
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Interval(from, to, curve: Curves.easeIn),
          ),
        );

    _iconOpacity = fade(0.0, 0.3);
    _textOpacity = fade(0.3, 0.6);
    _taglineOpacity = fade(0.6, 0.8);
    _loadingOpacity = fade(0.8, 1.0);

    _fadeController.forward();
    _navigateToDestination();
  }

  Future<void> _navigateToDestination() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.destination,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Stack(
            children: [
              // Decorative lavender / lime blobs
              Positioned(
                top: -80,
                right: -60,
                child: Opacity(
                  opacity: _iconOpacity.value,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: context.soft,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                left: -50,
                child: Opacity(
                  opacity: _iconOpacity.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.lime.withValues(alpha: context.isDark ? 0.18 : 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _iconOpacity.value,
                      child: Transform.scale(
                        scale: 0.8 + (_iconOpacity.value * 0.2),
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: AppTheme.blue,
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 52,
                                color: AppTheme.white,
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.lime,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.north_east_rounded,
                                      size: 14, color: AppTheme.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'FinFlow',
                            style: GoogleFonts.urbanist(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: context.fg,
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            '.',
                            style: GoogleFonts.urbanist(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: context.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        'Master your finances',
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: context.fgMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 56),
                    Opacity(
                      opacity: _loadingOpacity.value,
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(context.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
