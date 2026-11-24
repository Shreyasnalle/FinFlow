import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/demo_seed.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';
import 'signup_screen.dart';
import 'pin_login_screen.dart';
import '../widgets/tap_scale.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _demoBusy = false;

  Future<void> _tryDemo() async {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    setState(() => _demoBusy = true);
    // Let the "building" label paint before the (synchronous) seeding runs.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final ok = await provider.createDemoAccount();
    if (!mounted) return;
    if (!ok) {
      setState(() => _demoBusy = false);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  void _getStarted() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  void _logIn() {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (provider.hasProfile) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No account found. Please sign up first.',
            style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w600, color: context.onCta),
          ),
          backgroundColor: context.cta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              // Brand row + theme toggle
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.show_chart_rounded,
                        size: 20, color: AppTheme.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FinFlow',
                    style: GoogleFonts.urbanist(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.fg,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Headline
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Take Charge\nOf Your\nMoney',
                        style: GoogleFonts.urbanist(
                          fontSize: 44,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          color: context.fg,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: child,
                      ),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: AppTheme.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.north_east_rounded,
                            color: AppTheme.ink, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Track spending, set goals and see your\nfuture wealth predicted.',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: context.fgMuted,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Preview tiles (mirrors the reference's stat cards)
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      height: 132,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.blue,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Net worth',
                                style: GoogleFonts.urbanist(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.white.withValues(alpha: 0.85),
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: AppTheme.lime,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.north_east_rounded,
                                    size: 14, color: AppTheme.ink),
                              ),
                            ],
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹ 1,24,500',
                              style: GoogleFonts.urbanist(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.white,
                              ),
                            ),
                          ),
                          Text(
                            'across all accounts',
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Container(
                      height: 132,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: context.soft,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved',
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.onSoft.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '74%',
                            style: GoogleFonts.urbanist(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: context.onSoft,
                            ),
                          ),
                          Text(
                            'of goal',
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.onSoft.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // CTA pill with lime arrow
              TapScale(
                onTap: _getStarted,
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.only(left: 28, right: 8),
                  decoration: BoxDecoration(
                    color: context.cta,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            "Let's get started!",
                            style: GoogleFonts.urbanist(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: context.onCta,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.ink : AppTheme.lime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 28,
                          color: isDark ? AppTheme.lime : AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TapScale(
                onTap: _logIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.fgMuted,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w800,
                            color: context.fg,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (DemoSeed.enabled)
                TapScale(
                  onTap: _demoBusy ? null : _tryDemo,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _demoBusy
                          ? 'Building 3 years of demo data…'
                          : 'Explore with a demo account',
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.fgMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
