import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'form_error.dart';
import '../models/asset.dart';

class AssetBottomSheet extends StatefulWidget {
  final Asset? asset;

  const AssetBottomSheet({super.key, this.asset});

  @override
  State<AssetBottomSheet> createState() => _AssetBottomSheetState();
}

class _AssetBottomSheetState extends State<AssetBottomSheet> {
  String? _error;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.asset != null) {
      _nameController.text = widget.asset!.name;
      _valueController.text = widget.asset!.value.toString();
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final valueRaw = _valueController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for the asset.');
      return;
    }

    final value = double.tryParse(valueRaw);
    if (value == null) {
      setState(() => _error = 'Enter the asset\'s current value as a number.');
      return;
    }

    final provider = Provider.of<FinanceProvider>(context, listen: false);

    if (widget.asset != null) {
      provider.updateAsset(Asset(
        id: widget.asset!.id,
        name: name,
        value: value,
      ));
    } else {
      provider.addAsset(Asset(
        id: const Uuid().v4(),
        name: name,
        value: value,
      ));
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: AppTheme.lavender, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.asset != null ? 'Update asset' : 'Add new asset', style: GoogleFonts.urbanist(fontSize: 26, fontWeight: FontWeight.w700, color: context.fg)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Asset Name',
              hintText: 'e.g., Gold, Real Estate, Savings',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Current Value',
              prefixText: '${Provider.of<FinanceProvider>(context).currencySymbol} ',
            ),
          ),
          FormError(_error),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: Text(widget.asset != null ? 'Save Changes' : 'Add Asset'),
            ),
          ),
        ],
      ),
    );
  }
}
