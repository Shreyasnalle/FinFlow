import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_bottom_sheet.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  void _showAssetSheet(BuildContext context, {var asset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssetBottomSheet(asset: asset),
    );
  }

  void _confirmDelete(BuildContext context, String assetId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete asset'),
        content: const Text('Are you sure you want to delete this asset?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<FinanceProvider>(context, listen: false).deleteAsset(assetId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final currency = provider.currencyFormat;

    double totalAssetsValue = provider.assets.fold(0, (sum, item) => sum + item.value);
    double netWorth = provider.currentBalance + totalAssetsValue;

    return Scaffold(
      appBar: AppBar(title: const Text('My assets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAssetSheet(context),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: context.hero,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total net worth',
                            style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.white.withValues(alpha: 0.85))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(currency.format(netWorth),
                          style: GoogleFonts.urbanist(fontSize: 40, fontWeight: FontWeight.w700, height: 1, color: AppTheme.white)),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _heroStat('Cash balance', currency.format(provider.currentBalance), false)),
                        const SizedBox(width: 12),
                        Expanded(child: _heroStat('Assets value', currency.format(totalAssetsValue), true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.assets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: context.soft, shape: BoxShape.circle),
                      child: Icon(Icons.account_balance_wallet_outlined, size: 36, color: context.onSoft),
                    ),
                    const SizedBox(height: 16),
                    Text('No assets added yet',
                        style: GoogleFonts.urbanist(fontSize: 17, fontWeight: FontWeight.w600, color: context.fgMuted)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final asset = provider.assets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusTile),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
                              child: const Icon(Icons.account_balance, color: AppTheme.ink, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(asset.name,
                                      style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16, color: context.fg)),
                                  const SizedBox(height: 2),
                                  Text('Valuation: ${currency.format(asset.value)}',
                                      style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w500, color: context.fgMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: context.accent),
                              onPressed: () => _showAssetSheet(context, asset: asset),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: context.fgMuted),
                              onPressed: () => _confirmDelete(context, asset.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: provider.assets.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, bool soft) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: soft ? AppTheme.lavender : AppTheme.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.urbanist(
                  fontSize: 12, fontWeight: FontWeight.w600, color: soft ? AppTheme.ink.withValues(alpha: 0.65) : AppTheme.white.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w700, color: soft ? AppTheme.ink : AppTheme.white)),
          ),
        ],
      ),
    );
  }
}
