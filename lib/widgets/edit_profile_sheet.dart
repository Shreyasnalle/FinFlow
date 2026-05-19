import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';


class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
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
    if (name.isEmpty) return; // Name is required

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26, 
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          const SizedBox(height: 24),
          const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name', hintText: 'John Doe'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _professionController,
            decoration: const InputDecoration(labelText: 'Profession', hintText: 'Software Engineer'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 1234567890'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
