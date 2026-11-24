import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';
import 'tap_scale.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  String? _error;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate with current values
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    _nameController.text = provider.userName;
    _professionController.text = provider.userProfession;
    _mobileController.text = provider.userMobile;
    _ageController.text = provider.userAge;
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Your name can\'t be empty.');
      return;
    }

    Provider.of<FinanceProvider>(context, listen: false).saveUserProfile(
      name: name,
      mobile: _mobileController.text.trim(),
      age: _ageController.text.trim(),
      profession: _professionController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: context.soft,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Edit Profile',
            style: GoogleFonts.urbanist(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: context.fg,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: 'Full Name', hintText: 'John Doe'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _professionController,
            decoration: const InputDecoration(
                labelText: 'Profession', hintText: 'Software Engineer'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone Number', hintText: '+91 1234567890'),
          ),
          FormError(_error),
          const SizedBox(height: 28),
          TapScale(
            onTap: _submit,
            child: Container(
              height: 60,
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
                        'Save Changes',
                        style: GoogleFonts.urbanist(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.onCta,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.isDark ? AppTheme.ink : AppTheme.lime,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 24,
                      color: context.isDark ? AppTheme.lime : AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
