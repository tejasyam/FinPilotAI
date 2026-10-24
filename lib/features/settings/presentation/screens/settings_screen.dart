import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../advisor/domain/advisor_conversation_store.dart';
import '../../../transactions/controllers/finance_controller.dart';
import 'privacy_data_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.controller,
    required this.conversationStore,
    super.key,
  });

  final FinanceController controller;
  final AdvisorConversationStore conversationStore;

  Future<void> _toggleReminders(BuildContext context, bool enabled) async {
    if (!enabled) {
      await controller.setBillRemindersEnabled(false);
      return;
    }
    final continueSetup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable bill reminders?'),
        content: Text(
          controller.notificationPermissionDenied
              ? 'Notification permission was previously denied. Enable it in device settings first. FinPilotAI will ask again only after you choose Try permission again.'
              : 'FinPilotAI can schedule local notifications on Android or iOS for saved bill due dates. Browser and desktop previews do not schedule native bill reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              controller.notificationPermissionDenied
                  ? 'Try permission again'
                  : 'Continue',
            ),
          ),
        ],
      ),
    );
    if (continueSetup != true || !context.mounted) return;
    if (controller.notificationPermissionDenied) {
      await controller.retryBillNotificationPermission();
    } else {
      await controller.setBillRemindersEnabled(true);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await controller.signOut();
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not end the local session. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.elevated,
                  child: Icon(Icons.person_outline, color: AppColors.mint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.localProfileName ?? 'Local profile',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.localProfileEmail == null
                            ? 'Stored on this device · not password protected'
                            : '${controller.localProfileEmail} · local only',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
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
                        ? 'Native local due-date reminders are enabled.'
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.lock_outline,
                    color: AppColors.muted,
                  ),
                  title: const Text('App lock'),
                  subtitle: const Text(
                    'No app lock or password protection is enabled',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.mint,
                  ),
                  title: const Text('Privacy and data'),
                  subtitle: const Text(
                    'Review local storage, export, and deletion controls',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PrivacyDataScreen(
                        controller: controller,
                        conversationStore: conversationStore,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppColors.coral),
                  title: const Text('Sign out'),
                  subtitle: const Text(
                    'End this local session; keep financial records on device',
                  ),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'FinPilotAI · local finance preview',
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
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return controller.notificationPermissionDenied
          ? 'Permission was denied. Enable it in device settings to retry.'
          : 'Enable device notifications for saved bill due dates.';
    }
    return 'Scheduled bill reminders are supported on Android and iOS only.';
  }
}
