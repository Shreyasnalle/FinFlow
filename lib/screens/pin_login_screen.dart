import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<FinanceProvider>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Avatar & greeting
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.brandDefault.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  provider.userName.isNotEmpty
                      ? provider.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandDefault,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome back,',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              provider.userName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
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
                        ? ((_shakeAnim.value * 10).toInt() % 2 == 0 ? 1 : -1)
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
                      color: filled
                          ? AppTheme.brandDefault
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08)),
                      border: filled
                          ? null
                          : Border.all(
                              color: isDark ? Colors.white24 : Colors.black26,
                              width: 1.5,
                            ),
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
                style: const TextStyle(
                  color: AppTheme.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Forgot PIN link
            AnimatedOpacity(
              opacity: _showForgotPin ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: _showForgotPin
                  ? TextButton(
                      onPressed: () => _showForgotPinDialog(context, provider),
                      child: const Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          color: AppTheme.brandDefault,
                          fontWeight: FontWeight.w600,
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
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 22,
                    ),
                  );
                }
                return _NumPadKey(
                  isDark: isDark,
                  onTap: () => _onDigit(key),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
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
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  step == 1 ? Icons.verified_user_outlined : Icons.lock_reset_rounded,
                  color: AppTheme.brandDefault,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(step == 1 ? 'Verify Identity' : 'Set New PIN'),
              ],
            ),
            content: step == 1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter your registered details to reset your PIN.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.black54,
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
                        content: const Text('PIN reset successfully ✓'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.brandDefault,
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
        splashColor: AppTheme.brandDefault.withValues(alpha: 0.2),
        highlightColor: AppTheme.brandDefault.withValues(alpha: 0.08),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
