import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/transactions/controllers/finance_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = FinanceController();
  try {
    await controller.initializeDatabase();
  } catch (error) {
    controller.setStartupError(error);
  }
  runApp(FinPilotApp(financeController: controller));
}
