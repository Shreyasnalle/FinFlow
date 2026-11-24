// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../database/demo_seed.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_profile_sheet.dart';
import '../services/pdf_export_service.dart';
import 'welcome_screen.dart';
import '../widgets/tap_scale.dart';
import '../widgets/smooth_wheel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: context.fg,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: TapScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: context.surface, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back_rounded, color: context.fg),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [SmoothWheel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Profile card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.blue,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(provider.userName),
                      style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.userProfession.isNotEmpty ? provider.userProfession : provider.userMobile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(
                              fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Account ──
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            subtitle: provider.userName,
            onTap: () => _showEditProfile(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change PIN',
            subtitle: 'Update your security PIN',
            onTap: () => _showChangePinDialog(context, provider),
          ),

          const _SettingsDivider(),

          // ── Appearance ──
          _SectionHeader(title: 'Appearance'),
          _SettingsTile(
            icon: Icons.currency_exchange_rounded,
            title: 'Currency',
            subtitle: provider.currency,
            onTap: () => _showCurrencyPicker(context, provider),
          ),

          const _SettingsDivider(),

          // ── Security & Privacy ──
          _SectionHeader(title: 'Security & Privacy'),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () => _showInfoDialog(
              context,
              'Privacy Policy',
              'All your financial data is stored securely on this device only. '
                  'We do not collect, upload, or share any personal or financial information. '
                  'Your PIN is stored locally and never transmitted.',
            ),
          ),

          const _SettingsDivider(),

          // ── Data ──
          _SectionHeader(title: 'Data Management'),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export Data',
            subtitle: 'Download your financial data',
            onTap: () {
              PdfExportService.exportFinanceReport(provider);
            },
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Clear All Data',
            subtitle: 'Permanently delete all transactions & goals',
            onTap: () => _showClearDataDialog(context, provider),
          ),
          if (DemoSeed.enabled && provider.userName == DemoSeed.userName)
            _SettingsTile(
              icon: Icons.science_outlined,
              title: 'Reload demo data',
              subtitle: 'Regenerate 3 years of sample history ending today',
              onTap: () async {
                await provider.loadDemoData();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo data reloaded')),
                );
              },
            ),

          const _SettingsDivider(),

          // ── About ──
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'v1.0.0 (Build 1)',
          ),
          const _SettingsDivider(),

          // ── Log Out ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context, provider),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.urbanist(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(color: context.accent, width: 1.5),
                  foregroundColor: context.accent,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ]))],
      ),
    );
  }

  // ── Helpers ──

  void _showEditProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileSheet(),
    );
  }

  void _showCurrencyPicker(BuildContext context, FinanceProvider provider) {
    final currencies = ['₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.soft,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Currency',
              style: GoogleFonts.urbanist(
                  fontSize: 20, fontWeight: FontWeight.w700, color: context.fg),
            ),
            const SizedBox(height: 8),
            ...currencies.map(
              (c) => ListTile(
                leading: Radio<String>(
                  value: c,
                  groupValue: provider.currency,
                  activeColor: context.accent,
                  onChanged: (v) {
                    provider.setCurrency(v!);
                    Navigator.pop(context);
                  },
                ),
                title: Text(c, style: GoogleFonts.urbanist(fontWeight: FontWeight.w600, color: context.fg)),
                onTap: () {
                  provider.setCurrency(c);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(
      BuildContext context, FinanceProvider provider) {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPinCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinCtrl,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!provider.checkPin(currentPinCtrl.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Current PIN is incorrect')),
                );
                return;
              }
              if (newPinCtrl.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('New PIN must be 4 digits')),
                );
                return;
              }
              if (newPinCtrl.text != confirmPinCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New PINs do not match')),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('PIN updated successfully ✓'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(
      BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.blue),
            SizedBox(width: 8),
            Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your transactions, goals, bills, and assets. '
          'Your profile will remain. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blue,
              foregroundColor: AppTheme.white,
            ),
            onPressed: () {
              provider.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All data cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Text('Log Out'),
        content: const Text(
            'Are you sure you want to log out? You\'ll need to enter your PIN to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blue,
              foregroundColor: AppTheme.white,
            ),
            onPressed: () {
              provider.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (r) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: Text(title),
        content: Text(body),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Settings Widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.urbanist(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: context.fgFaint,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: context.border, height: 1),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppTheme.lime,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.ink, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16, color: context.fg),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.urbanist(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: context.fgMuted,
        ),
      ),
      trailing: onTap == null ? null : Icon(Icons.chevron_right_rounded, color: context.fgFaint),
      onTap: onTap,
    );
  }
}
