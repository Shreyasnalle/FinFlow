import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/finance_provider.dart';
import '../models/asset.dart';

class AssetBottomSheet extends StatefulWidget {
  final Asset? asset;

  const AssetBottomSheet({super.key, this.asset});

  @override
  State<AssetBottomSheet> createState() => _AssetBottomSheetState();
}

class _AssetBottomSheetState extends State<AssetBottomSheet> {
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
    if (name.isEmpty || valueRaw.isEmpty) return;

    final value = double.tryParse(valueRaw);
    if (value == null) return;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Text(
            widget.asset != null ? 'Update Asset' : 'Add New Asset',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
