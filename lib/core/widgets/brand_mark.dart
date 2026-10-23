import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 36 : 48,
        height: compact ? 36 : 48,
        decoration: BoxDecoration(
          color: AppColors.mint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.mint,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'FinPilotAI',
        style: TextStyle(
          fontSize: compact ? 18 : 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
