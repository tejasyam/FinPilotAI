import 'package:flutter/foundation.dart';

class AdvisorMessage {
  const AdvisorMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

/// Holds Advisor chat only in memory for the current app session.
class AdvisorConversationStore extends ChangeNotifier {
  final List<AdvisorMessage> _messages = [];

  List<AdvisorMessage> get messages => List.unmodifiable(_messages);

  void add(AdvisorMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void clear() {
    if (_messages.isEmpty) return;
    _messages.clear();
    notifyListeners();
  }
}
