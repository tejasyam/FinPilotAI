import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../transactions/controllers/finance_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final FinanceController controller;

  Future<void> _toggleReminders(BuildContext context, bool enabled) async {
    if (!enabled) {
      await controller.setBillRemindersEnabled(false);
      return;
    }
    final continueSetup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable bill reminders?'),
        content: const Text(
          'FinPilotAI can schedule local notifications on this device for your saved bill due dates. Your bills stay in local storage. Android or iOS will ask for notification permission next. Browser previews do not support scheduled bill reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (continueSetup != true || !context.mounted) return;
    await controller.setBillRemindersEnabled(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.elevated,
                  child: Icon(Icons.person_outline, color: AppColors.mint),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local profile preview',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No account is signed in',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              children: [
                _item(
                  context,
                  Icons.person_outline,
                  'Profile',
                  'Profile editing is planned',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.mint,
                  ),
                  title: const Text('Monthly limit'),
                  subtitle: const Text('Manage overall and category budgets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.budgets),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.receipt_long,
                    color: AppColors.mint,
                  ),
                  title: const Text('Bills and reminders'),
                  subtitle: const Text(
                    'Manage upcoming, overdue, and paid bills',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.bills),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.psychology_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text('On-device language model'),
                  subtitle: const Text(
                    'Unavailable and disabled: no model runtime or model is installed. The Advisor uses its deterministic local fallback. No model is downloaded automatically.',
                  ),
                  value: false,
                  onChanged: null,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.notifications_none,
                    color: AppColors.mint,
                  ),
                  title: const Text('Bill due reminders'),
                  subtitle: Text(
                    controller.billRemindersEnabled
                        ? 'Local due-date reminders are enabled.'
                        : _notificationAvailability(),
                  ),
                  value: controller.billRemindersEnabled,
                  onChanged: (value) => _toggleReminders(context, value),
                ),
                if (controller.notificationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      controller.notificationError!,
                      style: const TextStyle(color: AppColors.coral),
                    ),
                  ),
                _item(
                  context,
                  Icons.lock_outline,
                  'App lock',
                  'No app lock is enabled',
                ),
                _item(
                  context,
                  Icons.privacy_tip_outlined,
                  'Privacy and data',
                  'Local-first foundation',
                ),
                _item(
                  context,
                  Icons.help_outline,
                  'Help and support',
                  'Foundation preview',
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppColors.coral),
                  title: const Text('Sign out'),
                  subtitle: const Text('Return to local profile entry'),
                  onTap: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'FinPilotAI · Foundation preview',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  String _notificationAvailability() {
    if (kIsWeb) {
      return 'Scheduled reminders are unavailable in browser previews.';
    }
    return 'Enable device notifications for saved bill due dates.';
  }

  static Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String note,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.mint),
    title: Text(label),
    subtitle: Text(note),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is planned for a later milestone.')),
    ),
  );
}
