import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/utils/money_parser.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/finance_models.dart';
import '../../../transactions/controllers/finance_controller.dart';

enum _BillFilter { upcoming, overdue, paid, all }

class BillsScreen extends StatefulWidget {
  const BillsScreen({required this.controller, super.key});

  final FinanceController controller;

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  _BillFilter _filter = _BillFilter.upcoming;

  static const _categories = [
    'Housing',
    'Utilities',
    'Internet',
    'Insurance',
    'Loan',
    'Subscription',
    'Other',
  ];

  List<BillReminder> _visibleBills() => switch (_filter) {
    _BillFilter.upcoming => widget.controller.upcomingBills,
    _BillFilter.overdue => widget.controller.overdueBills,
    _BillFilter.paid => widget.controller.paidBills,
    _BillFilter.all => widget.controller.bills,
  };

  Future<void> _editBill([BillReminder? existing]) async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: existing?.title ?? '');
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : '${existing.amountPaise ~/ 100}.${(existing.amountPaise % 100).toString().padLeft(2, '0')}',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    var dueDate = existing?.dueDate.toLocal() ?? DateTime.now();
    var category = existing?.category;
    var recurrence = existing?.recurrence ?? BillRecurrence.none;
    bool saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add bill' : 'Edit bill'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Bill title'),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter a bill title.'
                        : null,
                  ),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    validator: (value) {
                      try {
                        MoneyParser.rupeesToPaise(value ?? '');
                        return null;
                      } catch (error) {
                        return error.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due date'),
                    subtitle: Text(_date(dueDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        setDialogState(() => dueDate = selected);
                      }
                    },
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Uncategorized'),
                      ),
                      ..._categories.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item,
                          child: Text(item),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value),
                  ),
                  DropdownButtonFormField<BillRecurrence>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Repeat schedule',
                    ),
                    items: BillRecurrence.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_recurrenceLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => recurrence = value ?? BillRecurrence.none,
                    ),
                  ),
                  TextFormField(
                    controller: notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final scheduleChanged =
                            existing == null ||
                            existing.dueDate.toLocal().year != dueDate.year ||
                            existing.dueDate.toLocal().month != dueDate.month ||
                            existing.dueDate.toLocal().day != dueDate.day;
                        final bill = BillReminder(
                          id:
                              existing?.id ??
                              'bill-${DateTime.now().microsecondsSinceEpoch}',
                          title: title.text.trim(),
                          amountPaise: MoneyParser.rupeesToPaise(amount.text),
                          dueDate: DateTime(
                            dueDate.year,
                            dueDate.month,
                            dueDate.day,
                            12,
                          ),
                          recurrence: recurrence,
                          isPaid: existing?.isPaid ?? false,
                          category: category,
                          notes: notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                          recurrenceAnchorDate: scheduleChanged
                              ? DateTime(
                                  dueDate.year,
                                  dueDate.month,
                                  dueDate.day,
                                  12,
                                )
                              : existing.recurrenceAnchorDate,
                          recurrenceSeriesId: existing?.recurrenceSeriesId,
                          createdAt: existing?.createdAt,
                        );
                        if (existing == null) {
                          await widget.controller.createBill(bill);
                        } else {
                          await widget.controller.updateBill(bill);
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Could not save bill: $error'),
                            ),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save bill'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    amount.dispose();
    notes.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Bill saved.' : 'Bill updated.'),
        ),
      );
    }
  }

  Future<void> _markPaid(BillReminder bill) async {
    try {
      final next = await widget.controller.markBillPaid(bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next == null
                  ? 'Bill marked as paid.'
                  : 'Bill marked paid. Next occurrence: ${_date(next.dueDate.toLocal())}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark bill as paid: $error')),
        );
      }
    }
  }

  Future<void> _delete(BillReminder bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text('Delete “${bill.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.deleteBill(bill.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bill deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete bill: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bills'),
      actions: [
        IconButton(
          tooltip: 'Add bill',
          onPressed: () => _editBill(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.controller.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.controller.error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.controller.load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final bills = _visibleBills();
        return RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SegmentedButton<_BillFilter>(
                segments: const [
                  ButtonSegment(
                    value: _BillFilter.upcoming,
                    label: Text('Upcoming'),
                  ),
                  ButtonSegment(
                    value: _BillFilter.overdue,
                    label: Text('Overdue'),
                  ),
                  ButtonSegment(value: _BillFilter.paid, label: Text('Paid')),
                  ButtonSegment(value: _BillFilter.all, label: Text('All')),
                ],
                selected: {_filter},
                onSelectionChanged: (selected) =>
                    setState(() => _filter = selected.first),
              ),
              const SizedBox(height: 14),
              if (bills.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: AppColors.muted,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(_emptyMessage()),
                      const SizedBox(height: 12),
                      if (_filter == _BillFilter.upcoming ||
                          _filter == _BillFilter.all)
                        FilledButton.icon(
                          onPressed: () => _editBill(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add a bill'),
                        ),
                    ],
                  ),
                )
              else
                ...bills.map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _billCard(bill),
                  ),
                ),
              if (widget.controller.notificationError case final error?) ...[
                const SizedBox(height: 8),
                AppCard(
                  child: Text(
                    error,
                    style: const TextStyle(color: AppColors.coral),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _billCard(BillReminder bill) {
    final overdue = !bill.isPaid && _isOverdue(bill.dueDate);
    final state = bill.isPaid
        ? 'Paid'
        : overdue
        ? 'Overdue'
        : 'Upcoming';
    final stateColor = bill.isPaid
        ? AppColors.mint
        : overdue
        ? AppColors.coral
        : AppColors.purple;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(state, style: TextStyle(color: stateColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${bill.amountPaise ~/ 100}.${(bill.amountPaise % 100).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Due ${_date(bill.dueDate.toLocal())}'
            '${bill.category == null ? '' : ' · ${bill.category}'}'
            '${bill.recurrence == BillRecurrence.none ? '' : ' · ${_recurrenceLabel(bill.recurrence)}'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (bill.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(bill.notes!),
          ],
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            children: [
              if (!bill.isPaid)
                TextButton.icon(
                  onPressed: () => _markPaid(bill),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark paid'),
                ),
              TextButton.icon(
                onPressed: () => _editBill(bill),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _delete(bill),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _emptyMessage() => switch (_filter) {
    _BillFilter.upcoming =>
      'No upcoming bills. Add one to keep track of due dates.',
    _BillFilter.overdue => 'You have no overdue bills.',
    _BillFilter.paid => 'No paid bills to show yet.',
    _BillFilter.all => 'No bills saved yet.',
  };

  bool _isOverdue(DateTime date) {
    final due = date.toLocal();
    final now = DateTime.now();
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _recurrenceLabel(BillRecurrence recurrence) => switch (recurrence) {
  BillRecurrence.none => 'One-time',
  BillRecurrence.weekly => 'Weekly',
  BillRecurrence.monthly => 'Monthly',
  BillRecurrence.yearly => 'Yearly',
};
