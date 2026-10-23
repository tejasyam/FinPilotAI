import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/shell/presentation/main_shell.dart';
import '../features/transactions/controllers/finance_controller.dart';
import '../features/transactions/presentation/screens/transaction_form_screen.dart';
import '../features/transactions/presentation/screens/transaction_history_screen.dart';
import '../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../features/accounts/presentation/screens/accounts_screen.dart';
import '../features/bills/presentation/screens/bills_screen.dart';
import '../features/budgets/presentation/screens/budgets_screen.dart';
import 'app_theme.dart';
import 'router.dart';

class FinPilotApp extends StatelessWidget {
  const FinPilotApp({super.key, this.financeController});

  final FinanceController? financeController;

  @override
  Widget build(BuildContext context) {
    final controller = financeController ?? FinanceController();
    return MaterialApp(
      title: 'FinPilotAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.login,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.transactions:
            return MaterialPageRoute<void>(
              builder: (_) => TransactionHistoryScreen(controller: controller),
            );
          case AppRoutes.newTransaction:
            return MaterialPageRoute<void>(
              builder: (_) => TransactionFormScreen(controller: controller),
            );
          case AppRoutes.editTransaction:
            final id = settings.arguments as String;
            return MaterialPageRoute<void>(
              builder: (_) => TransactionFormScreen(
                controller: controller,
                transactionId: id,
              ),
            );
          case AppRoutes.transactionDetails:
            final id = settings.arguments as String;
            return MaterialPageRoute<void>(
              builder: (_) => TransactionDetailScreen(
                controller: controller,
                transactionId: id,
              ),
            );
          case AppRoutes.accounts:
            return MaterialPageRoute<void>(
              builder: (_) => AccountsScreen(controller: controller),
            );
          case AppRoutes.budgets:
            final month = settings.arguments as DateTime?;
            return MaterialPageRoute<void>(
              builder: (_) =>
                  BudgetsScreen(controller: controller, initialMonth: month),
            );
          case AppRoutes.bills:
            return MaterialPageRoute<void>(
              builder: (_) => BillsScreen(controller: controller),
            );
        }
        return null;
      },
      routes: {
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => MainShell(controller: controller),
      },
    );
  }
}
