import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../advisor/domain/advisor_conversation_store.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../domain/finance_export.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({
    required this.controller,
    required this.conversationStore,
    super.key,
  });

  final FinanceController controller;
  final AdvisorConversationStore conversationStore;

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _busy = false;

  Future<void> _clearAdvisorConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Advisor conversation?'),
        content: const Text(
          'This clears the in-memory conversation for this app session. It does not change saved financial records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear conversation'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      widget.conversationStore.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advisor conversation cleared.')),
      );
    }
  }

  Future<void> _export() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export local finance data?'),
        content: const Text(
          'The JSON file includes accounts, transactions, budgets, and bills. It contains private financial details. Save or share it only with a destination you trust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prepare export'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final snapshot = await widget.controller.buildFinancialExport();
      if (!mounted) return;
      final bytes = utf8.encode(FinanceExport.encode(snapshot));
      final filename =
          'finpilotai_finances_${DateTime.now().toIso8601String().substring(0, 10)}.json';
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: 'FinPilotAI finance export',
          subject: 'FinPilotAI finance export',
          files: [XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: [filename],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export was handed to the platform share or download flow.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare or share the export.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This permanently deletes all saved accounts, transactions, budgets, bills (including recurring bill schedules), local profile details, and app preferences from this device. Scheduled bill notifications will be canceled. This cannot be undone. You will return to local profile entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all local data'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.deleteAllLocalData();
      if (mounted) {
        widget.conversationStore.clear();
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not safely complete deletion. No records were deleted.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy and data')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How local data works',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                'Finance records are stored in this app’s local database. They are not synced to a FinPilotAI server. A local profile is not password protected or encrypted by an app lock; device access controls still matter.',
              ),
              SizedBox(height: 10),
              Text(
                'Receipt text recognition runs on-device where supported. Receipt images and OCR text are not uploaded or saved by the receipt flow. The Advisor is a deterministic local summary, not an installed language model.',
              ),
              SizedBox(height: 10),
              Text(
                'Browser data is stored for this browser origin and can be removed by browser storage controls. Browser and desktop previews do not schedule native bill notifications.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Clear Advisor conversation'),
          subtitle: const Text(
            'Conversation is held only in memory for this app session.',
          ),
          onTap: _busy ? null : _clearAdvisorConversation,
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export financial records'),
          subtitle: Text(
            _canShareFiles
                ? 'Save or share accounts, transactions, budgets, and bills as JSON.'
                : 'File sharing is not supported on Linux in this build.',
          ),
          onTap: _busy || !_canShareFiles ? null : _export,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(
            Icons.delete_forever_outlined,
            color: AppColors.coral,
          ),
          title: const Text('Delete all local data'),
          subtitle: const Text(
            'Permanently remove this device’s local records and settings.',
          ),
          onTap: _busy ? null : _deleteAllData,
        ),
        if (_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    ),
  );

  bool get _canShareFiles =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.linux;
}
