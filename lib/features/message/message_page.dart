import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagePage extends StatefulWidget {
  final String currentUserId;
  final String receiverId;
  final String receiverName;

  const MessagePage({
    super.key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final messageController = TextEditingController();
  late final String chatId;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    chatId = _generateChatId(widget.currentUserId, widget.receiverId);
    print('Generated Chat ID: $chatId');
  }

  String _generateChatId(String a, String b) {
    return (a.compareTo(b) < 0) ? '$a-$b' : '$b-$a';
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    await Supabase.instance.client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': widget.currentUserId,
      'receiver_id': widget.receiverId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });

    messageController.clear();

    // Scroll to bottom after sending message
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    setState(
      () {},
    ); // Optional: forces widget to rebuild, though stream handles this
  }

  Future<void> debugFetchMessages() async {
    final response = await Supabase.instance.client
        .from('messages')
        .select()
        .eq('chat_id', chatId);
    print('Fetched Messages: $response');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Chat with ${widget.receiverName}",
          style: TextStyle(fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', chatId)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<Map<String, dynamic>> messages = snapshot.data ?? [];
                final List<Map<String, dynamic>> reversedMessages =
                    messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: reversedMessages.length,
                  reverse: true,
                  itemBuilder: (_, index) {
                    final msg = reversedMessages[index];
                    final isMe = msg['sender_id'] == widget.currentUserId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[200] : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft:
                                isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight:
                                isMe ? Radius.zero : const Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          msg['text'],
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                    ),
                    onSubmitted:
                        (_) => sendMessage(), // <-- this triggers on Enter key
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
