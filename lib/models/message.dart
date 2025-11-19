class Message {
  final String text;
  final bool isUser;
  final DateTime time;

  Message({required this.text, this.isUser = true, DateTime? time}) : time = time ?? DateTime.now();
}
