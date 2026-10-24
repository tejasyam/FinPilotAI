import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../transactions/controllers/finance_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.controller, super.key});

  final FinanceController controller;

  Future<void> _enterLocalProfile(BuildContext context) async {
    try {
      await controller.activateLocalSession();
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open local data. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark()),
                const SizedBox(height: 38),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open the local finance data stored on this device.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 26),
                FilledButton(
                  onPressed: () => _enterLocalProfile(context),
                  child: const Text('Open local data'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'This does not verify an account or require a password. Anyone with access to this device and app data may be able to access the finance records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.register),
                  child: const Text('Create local profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
