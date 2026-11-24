import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Inline validation message shown just above a sheet's submit button.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(message!, style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700, color: context.accent)),
      ),
    );
  }
}
