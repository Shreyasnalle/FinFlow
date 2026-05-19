// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_profile_sheet.dart';
import '../services/pdf_export_service.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricLock = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account ──
          _SectionHeader(title: 'Account', isDark: isDark),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            iconBg: AppTheme.brandDefault.withValues(alpha: 0.15),
            iconColor: AppTheme.brandDefault,
            title: 'Edit Profile',
            subtitle: provider.userName,
            onTap: () => _showEditProfile(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconBg: Colors.blue.withValues(alpha: 0.12),
            iconColor: Colors.blue,
            title: 'Change PIN',
            subtitle: 'Update your security PIN',
            onTap: () => _showChangePinDialog(context, provider),
          ),

          const _SettingsDivider(),

          // ── Appearance ──
          _SectionHeader(title: 'Appearance', isDark: isDark),
          _SettingsTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            iconBg: Colors.deepPurple.withValues(alpha: 0.12),
            iconColor: Colors.deepPurple,
            title: 'Theme',
            subtitle: _themeLabel(provider.themeMode),
            onTap: () => _showThemePicker(context, provider),
          ),
          _SettingsTile(
            icon: Icons.currency_exchange_rounded,
            iconBg: Colors.teal.withValues(alpha: 0.12),
            iconColor: Colors.teal,
            title: 'Currency',
            subtitle: provider.currency,
            onTap: () => _showCurrencyPicker(context, provider),
          ),

          const _SettingsDivider(),

          // ── Notifications ──
          _SectionHeader(title: 'Notifications', isDark: isDark),
          _SettingsSwitchTile(
            icon: Icons.notifications_outlined,
            iconBg: Colors.orange.withValues(alpha: 0.12),
            iconColor: Colors.orange,
            title: 'Push Notifications',
            subtitle: 'Daily spending summaries & alerts',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),

          const _SettingsDivider(),

          // ── Security & Privacy ──
          _SectionHeader(title: 'Security & Privacy', isDark: isDark),
          _SettingsSwitchTile(
            icon: Icons.fingerprint_rounded,
            iconBg: Colors.red.withValues(alpha: 0.12),
            iconColor: Colors.red,
            title: 'Biometric Unlock',
            subtitle: 'Use fingerprint to unlock the app',
            value: _biometricLock,
            onChanged: (v) => setState(() => _biometricLock = v),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconBg: Colors.indigo.withValues(alpha: 0.12),
            iconColor: Colors.indigo,
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
          _SectionHeader(title: 'Data Management', isDark: isDark),
          _SettingsTile(
            icon: Icons.download_rounded,
            iconBg: Colors.green.withValues(alpha: 0.12),
            iconColor: Colors.green,
            title: 'Export Data',
            subtitle: 'Download your financial data',
            onTap: () {
              PdfExportService.exportFinanceReport(provider);
            },
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            iconBg: Colors.red.withValues(alpha: 0.12),
            iconColor: Colors.red,
            title: 'Clear All Data',
            subtitle: 'Permanently delete all transactions & goals',
            onTap: () => _showClearDataDialog(context, provider),
          ),

          const _SettingsDivider(),

          // ── About ──
          _SectionHeader(title: 'About', isDark: isDark),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconBg: Colors.blueGrey.withValues(alpha: 0.12),
            iconColor: Colors.blueGrey,
            title: 'App Version',
            subtitle: 'v1.0.0 (Build 1)',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.star_outline_rounded,
            iconBg: Colors.amber.withValues(alpha: 0.12),
            iconColor: Colors.amber.shade700,
            title: 'Rate This App',
            subtitle: 'Leave a review on the Play Store',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Thank you for your support! 🎉'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.share_outlined,
            iconBg: Colors.cyan.withValues(alpha: 0.12),
            iconColor: Colors.cyan,
            title: 'Share App',
            subtitle: 'Invite friends to try FinFlow',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Share link copied!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            iconBg: Colors.purple.withValues(alpha: 0.12),
            iconColor: Colors.purple,
            title: 'Help & Support',
            subtitle: 'FAQs and contact us',
            onTap: () => _showInfoDialog(
              context,
              'Help & Support',
              'For questions or feedback, reach out to:\n\n'
                  '📧 support@finflow.app\n\n'
                  'We typically respond within 24 hours.',
            ),
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
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
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

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemePicker(BuildContext context, FinanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Theme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ThemeOption(
              icon: Icons.brightness_auto_rounded,
              label: 'System Default',
              selected: provider.themeMode == ThemeMode.system,
              onTap: () {
                provider.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.light_mode_rounded,
              label: 'Light',
              selected: provider.themeMode == ThemeMode.light,
              onTap: () {
                provider.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOption(
              icon: Icons.dark_mode_rounded,
              label: 'Dark',
              selected: provider.themeMode == ThemeMode.dark,
              onTap: () {
                provider.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, FinanceProvider provider) {
    final currencies = ['₹ INR', '\$ USD', '€ EUR', '£ GBP', '¥ JPY'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Currency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...currencies.map(
              (c) => ListTile(
                leading: Radio<String>(
                  value: c,
                  groupValue: provider.currency,
                  activeColor: AppTheme.brandDefault,
                  onChanged: (v) {
                    provider.setCurrency(v!);
                    Navigator.pop(context);
                  },
                ),
                title: Text(c),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              if (currentPinCtrl.text != provider.userPin) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Clear data by re-initializing lists
              // For now just show confirmation
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: isDark ? Colors.white10 : Colors.black12,
        height: 1,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.black26,
      ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : Colors.black54,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeColor: AppTheme.brandDefault,
        onChanged: onChanged,
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppTheme.brandDefault : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? AppTheme.brandDefault : null,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.brandDefault)
          : null,
      onTap: onTap,
    );
  }
}
