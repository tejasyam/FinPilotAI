import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../transactions/controllers/finance_controller.dart';
import '../../domain/advisor_financial_context.dart';
import '../../domain/advisor_conversation_store.dart';
import '../../domain/advisor_provider.dart';

class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({
    required this.controller,
    required this.conversationStore,
    this.provider,
    super.key,
  });

  final FinanceController controller;
  final AdvisorProvider? provider;
  final AdvisorConversationStore conversationStore;

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  late final AdvisorProvider _provider =
      widget.provider ??
      const AdvisorProviderSelector(fallback: DeterministicAdvisorProvider())
          .active;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    widget.conversationStore.addListener(_conversationChanged);
  }

  void _conversationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    widget.conversationStore.removeListener(_conversationChanged);
    super.dispose();
  }

  Future<void> _send([String? suggestedQuestion]) async {
    if (_isResponding || widget.controller.error != null) return;
    final question = (suggestedQuestion ?? _input.text).trim();
    if (question.isEmpty) return;
    _input.clear();
    setState(() {
      _isResponding = true;
    });
    widget.conversationStore.add(AdvisorMessage(isUser: true, text: question));
    try {
      final context = AdvisorFinancialContextBuilder.build(
        now: widget.controller.now,
        accounts: widget.controller.accounts,
        transactions: widget.controller.transactions,
        budgets: widget.controller.budgets,
        upcomingBills: widget.controller.upcomingBills,
        overdueBills: widget.controller.overdueBills,
      );
      final answer = await _provider.answer(question, context);
      if (!mounted) return;
      widget.conversationStore.add(AdvisorMessage(isUser: false, text: answer));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        widget.conversationStore.add(
          const AdvisorMessage(
            isUser: false,
            text: 'I could not create an answer from your saved summaries. Your financial data has not been changed.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
        _scrollToLatest();
      }
    }
  }

  void _clearConversation() {
    setState(() {
      _input.clear();
    });
    widget.conversationStore.clear();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Advisor'),
      actions: [
        IconButton(
          tooltip: 'Clear conversation',
          onPressed: widget.conversationStore.messages.isEmpty || _isResponding
              ? null
              : _clearConversation,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.offline_bolt, color: AppColors.mint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _provider.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _provider.modelAvailable && _provider.modelEnabled
                                ? 'On-device model enabled. Financial data stays on this device.'
                                : 'No language model installed. Answers are deterministic summaries; no financial data leaves this device.',
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
            ),
            if (widget.controller.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: AppCard(
                  child: Column(
                    children: [
                      Text(
                        'Local finance data could not be loaded: ${widget.controller.error}',
                        style: const TextStyle(color: AppColors.coral),
                      ),
                      TextButton(
                        onPressed: widget.controller.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: widget.conversationStore.messages.isEmpty
                  ? _emptyState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount:
                          widget.conversationStore.messages.length +
                          (_isResponding ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == widget.conversationStore.messages.length) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(
                          entry: widget.conversationStore.messages[index],
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: widget.controller.error == null,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Ask about your saved finances…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send question',
                      onPressed:
                          _isResponding || widget.controller.error != null
                          ? null
                          : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _emptyState(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    children: [
      const Icon(Icons.auto_awesome, color: AppColors.mint, size: 40),
      const SizedBox(height: 14),
      Text(
        'Your finances, explained locally',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Ask for a summary or a budgeting suggestion. Answers use calculated totals from your saved accounts, transactions, budgets, and unpaid bills. No database changes are made from chat.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 20),
      _suggestion('How much did I spend this month?'),
      _suggestion('Am I over budget?'),
      _suggestion('What bills are due?'),
      _suggestion('How did expenses compare with last month?'),
    ],
  );

  Widget _suggestion(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      onPressed: _isResponding || widget.controller.error != null
          ? null
          : () => _send(text),
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: Text(text),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.entry});

  final AdvisorMessage entry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: entry.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .82,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isUser ? const Color(0xFF24453F) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(entry.text),
    ),
  );
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Checking local summaries…'),
        ],
      ),
    ),
  );
}
