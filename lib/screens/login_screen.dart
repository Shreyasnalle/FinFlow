import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';
import '../widgets/tap_scale.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _profController = TextEditingController();
  final _goalController = TextEditingController();

  void _submit() {
    if (_nameController.text.isEmpty || _goalController.text.isEmpty) return;

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    provider.saveUserProfile(
      name: _nameController.text,
      mobile: "Not Set",
      age: "Not Set",
      profession: _profController.text,
    );
    provider.setMonthlyGoal(double.tryParse(_goalController.text) ?? 50000);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          text,
          style: GoogleFonts.urbanist(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.fg,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_back_rounded, color: context.fg),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Create\nProfile',
                style: GoogleFonts.urbanist(
                  fontSize: 38,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: context.fg,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tell us a bit about yourself to personalize your forecasting model.',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: context.fgMuted,
                ),
              ),
              const SizedBox(height: 36),

              _label('Your Name'),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Alex Rivera',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 22),

              _label('Profession'),
              TextField(
                controller: _profController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Software Engineer',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 22),

              _label('Monthly Savings Goal (₹)'),
              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 15000',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              const SizedBox(height: 40),

              TapScale(
                onTap: _submit,
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
                            'Continue to Dashboard',
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
                          color: context.isDark ? AppTheme.ink : AppTheme.lime,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 28,
                          color: context.isDark ? AppTheme.lime : AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
