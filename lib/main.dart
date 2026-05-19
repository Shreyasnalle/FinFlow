import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/finance_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/pin_login_screen.dart';
import 'screens/main_screen.dart';
import 'models/transaction.dart';
import 'models/financial_goal.dart';
import 'models/recurring_bill.dart';
import 'models/asset.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Hive.initFlutter();

  // Register adapters here (must be generated first via build_runner)
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(FinancialGoalAdapter());
  Hive.registerAdapter(RecurringBillAdapter());
  Hive.registerAdapter(AssetAdapter());

  final financeProvider = FinanceProvider();
  await financeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: financeProvider),
      ],
      child: const FinFlowApp(),
    ),
  );
}

class FinFlowApp extends StatelessWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        // Determine where the splash screen should land
        final Widget destination = provider.isLoggedIn
            ? const MainScreen()
            : provider.hasProfile
                ? const PinLoginScreen()
                : const WelcomeScreen();

        return MaterialApp(
          title: 'FinFlow Forecast',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          home: SplashScreen(destination: destination),
        );
      },
    );
  }
}
