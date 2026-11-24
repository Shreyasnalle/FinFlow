import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  String _error = '';
  bool _showForgotPin = false;
  int _failCount = 0;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(digit);
      _error = '';
    });

    if (_digits.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = '';
    });
  }

  void _verifyPin() {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final pin = _digits.join();
    if (provider.verifyPin(pin)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
      _failCount++;
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _digits.clear();
        if (_failCount >= 1) {
          _showForgotPin = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        // Scrolls on short phones instead of overflowing; fills the screen otherwise.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Avatar & greeting
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: AppTheme.lime,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          provider.userName.isNotEmpty
                              ? provider.userName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.urbanist(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.urbanist(
                        color: context.fgMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.userName,
                      style: GoogleFonts.urbanist(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: context.fg,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PIN dots
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) {
                        final dx = _shakeAnim.value *
                            8 *
                            (_shakeController.isAnimating
                                ? ((_shakeAnim.value * 10).toInt() % 2 == 0
                                    ? 1
                                    : -1)
                                : 0);
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _digits.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: filled ? 18 : 14,
                            height: filled ? 18 : 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? context.accent : context.surface,
                              border: filled
                                  ? null
                                  : Border.all(
                                      color: context.border, width: 1.5),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Error text
                    AnimatedOpacity(
                      opacity: _error.isNotEmpty ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _error,
                        style: GoogleFonts.urbanist(
                          color: AppTheme.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // Forgot PIN link
                    AnimatedOpacity(
                      opacity: _showForgotPin ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: _showForgotPin
                          ? TextButton(
                              onPressed: () =>
                                  _showForgotPinDialog(context, provider),
                              child: Text(
                                'Forgot PIN?',
                                style: GoogleFonts.urbanist(
                                  color: context.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : const SizedBox(height: 48),
                    ),

                    const Spacer(flex: 1),

                    // Number pad
                    _buildNumPad(isDark),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumPad(bool isDark) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 72);
                }
                if (key == 'back') {
                  return _NumPadKey(
                    isDark: isDark,
                    onTap: _onBackspace,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: context.fg,
                      size: 22,
                    ),
                  );
                }
                return _NumPadKey(
                  isDark: isDark,
                  onTap: () => _onDigit(key),
                  child: Text(
                    key,
                    style: GoogleFonts.urbanist(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: context.fg,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showForgotPinDialog(BuildContext context, FinanceProvider provider) {
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    int step = 1; // 1 = verify identity, 2 = set new PIN

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step == 1
                        ? Icons.verified_user_outlined
                        : Icons.lock_reset_rounded,
                    color: AppTheme.ink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  step == 1 ? 'Verify Identity' : 'Set New PIN',
                  style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700, color: ctx.fg),
                ),
              ],
            ),
            content: step == 1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter your registered details to reset your PIN.',
                        style: GoogleFonts.urbanist(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ctx.fgMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: newPinCtrl,
                        obscureText: true,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'New PIN',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPinCtrl,
                        obscureText: true,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Confirm PIN',
                          prefixIcon: Icon(Icons.lock_rounded),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              if (step == 1)
                ElevatedButton(
                  onPressed: () {
                    final enteredName = nameCtrl.text.trim();
                    final enteredMobile = mobileCtrl.text.trim();

                    if (enteredName.isEmpty || enteredMobile.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields'),
                        ),
                      );
                      return;
                    }

                    // Case-insensitive name match + mobile match
                    if (enteredName.toLowerCase() ==
                            provider.userName.toLowerCase() &&
                        enteredMobile == provider.userMobile) {
                      setDialogState(() => step = 2);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Details don\'t match our records',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Verify'),
                ),
              if (step == 2)
                ElevatedButton(
                  onPressed: () {
                    if (newPinCtrl.text.length != 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PIN must be 4 digits'),
                        ),
                      );
                      return;
                    }
                    if (newPinCtrl.text != confirmPinCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PINs do not match'),
                        ),
                      );
                      return;
                    }

                    provider.saveUserProfile(
                      name: provider.userName,
                      mobile: provider.userMobile,
                      age: provider.userAge,
                      profession: provider.userProfession,
                      pin: newPinCtrl.text,
                    );

                    Navigator.pop(ctx);
                    setState(() {
                      _error = '';
                      _showForgotPin = false;
                      _failCount = 0;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PIN reset successfully ✓',
                            style: GoogleFonts.urbanist(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink)),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.lime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: const Text('Reset PIN'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NumPadKey extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;

  const _NumPadKey({
    required this.isDark,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(36),
        splashColor: AppTheme.lime.withValues(alpha: 0.5),
        highlightColor: AppTheme.lime.withValues(alpha: 0.25),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.surface,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
