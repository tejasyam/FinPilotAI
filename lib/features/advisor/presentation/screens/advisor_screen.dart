import 'package:flutter/material.dart';

import '../../../shell/presentation/main_shell.dart';

class AdvisorScreen extends StatelessWidget {
  const AdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePage(
    title: 'Advisor',
    icon: Icons.auto_awesome_outlined,
    description: 'Personalized insights are not available until real finance summaries exist. No AI model or financial service is connected.',
  );
}
