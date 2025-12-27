class Message {
  final String content;
  final bool isUser; // true = User, false = AI
  final DateTime timestamp;

  Message({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}
