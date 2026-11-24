import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';
import '../widgets/tap_scale.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _profController = TextEditingController();
  final _goalController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _profController.dispose();
    _goalController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    await provider.saveUserProfile(
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim().isNotEmpty
          ? _mobileController.text.trim()
          : 'Not Set',
      age: 'Not Set',
      profession: _profController.text.trim(),
      pin: _pinController.text.trim(),
    );

    final goalText = _goalController.text.trim();
    if (goalText.isNotEmpty) {
      provider.setMonthlyGoal(double.tryParse(goalText) ?? 0);
    }

    provider.login();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  TapScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: context.surface, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_back_rounded, color: context.fg),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create\nAccount',
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
                              'Set up your profile & security PIN',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.fgMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppTheme.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: AppTheme.ink, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // --- Profile Section ---
                  const _SectionLabel(label: 'PROFILE'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Your Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Mobile Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Mobile number is required';
                      }
                      final digits =
                          v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 10) {
                        return 'Enter a valid mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _profController,
                    decoration: const InputDecoration(
                      hintText: 'Profession (optional)',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _goalController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Monthly Savings Goal ₹ (optional)',
                      prefixIcon: Icon(Icons.savings_outlined),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- Security Section ---
                  const _SectionLabel(label: 'SECURITY PIN'),
                  const SizedBox(height: 4),
                  Text(
                    'You\'ll use this 4-digit PIN to unlock the app.',
                    style: GoogleFonts.urbanist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.fgMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Enter 4-digit PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length != 4) {
                        return 'PIN must be exactly 4 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPinController,
                    obscureText: _obscureConfirm,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Confirm PIN',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != _pinController.text) return 'PINs do not match';
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  // Submit
                  TapScale(
                    onTap: _isLoading ? null : _submit,
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.only(left: 28, right: 8),
                      decoration: BoxDecoration(
                        color: context.cta,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.onCta,
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
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
                              color: context.isDark
                                  ? AppTheme.ink
                                  : AppTheme.lime,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 28,
                              color: context.isDark
                                  ? AppTheme.lime
                                  : AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: context.fgFaint,
      ),
    );
  }
}
