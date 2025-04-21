import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:text/features/auth/auth_page.dart';
import 'package:text/features/message/message_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await loadRecentChats();
    setState(() => _isLoading = false);
  }

  Future<void> loadRecentChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chats = await fetchRecentChats();

      // Ensure chats is not empty
      if (chats.isNotEmpty) {
        setState(() {
          _recentChats = chats;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chats: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentChats() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final List<Map<String, dynamic>> recentUsers = [];

    try {
      // First get all unique conversation partners
      final partnersResponse = await Supabase.instance.client
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      // Debug print to check partnersResponse
      debugPrint('partnersResponse: $partnersResponse');

      final seenPartners = <String>{};

      // For each conversation partner, get the last message and unread count
      for (var msg in partnersResponse) {
        final isSentByCurrentUser = msg['sender_id'] == userId;
        final otherUserId =
            isSentByCurrentUser ? msg['receiver_id'] : msg['sender_id'];

        if (!seenPartners.contains(otherUserId)) {
          seenPartners.add(otherUserId);

          // Get user details
          final userResponse =
              await Supabase.instance.client
                  .from('AppUser')
                  .select()
                  .eq('id', otherUserId)
                  .single();

          // Get last message
          final lastMessageResponse =
              await Supabase.instance.client
                  .from('messages')
                  .select('content, created_at, is_read')
                  .or('sender_id.eq.$userId,receiver_id.eq.$userId')
                  .or('sender_id.eq.$otherUserId,receiver_id.eq.$otherUserId')
                  .order('created_at', ascending: false)
                  .limit(1)
                  .single();

          // Get unread count (only if current user is receiver)
          final unreadCount =
              isSentByCurrentUser ? 0 : await fetchUnreadCount(otherUserId);

          recentUsers.add({
            'user': userResponse,
            'lastMessage': lastMessageResponse['content'],
            'isUnread': unreadCount > 0,
            'unreadCount': unreadCount,
            'isSentByCurrentUser': isSentByCurrentUser,
            'timestamp': lastMessageResponse['created_at'],
          });
        }
      }

      // Sort by most recent message
      recentUsers.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      // Debug print to check the final list of recent users
      debugPrint('recentUsers: $recentUsers');

      return recentUsers;
    } catch (e) {
      debugPrint('Error fetching recent chats: $e');
      return [];
    }
  }

  Future<int> fetchUnreadCount(String otherUserId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // Query the messages and count the number of unread ones manually
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('sender_id', otherUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  Future<void> markMessagesAsRead(String otherUserId) async {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    try {
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', otherUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);

      await loadRecentChats();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final response = await Supabase.instance.client
        .from('AppUser')
        .select()
        .ilike('name', '%$query%');

    setState(() => _searchResults = response);
  }

  Widget buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final existingChat = _recentChats.firstWhere(
          (chat) => chat['user']['id'] == user['id'],
          orElse: () => {},
        );

        final hasChattedBefore = existingChat.isNotEmpty;
        final unreadCount =
            hasChattedBefore ? existingChat['unreadCount'] ?? 0 : 0;
        final isUnread = unreadCount > 0;

        return ListTile(
          title: Text(user['name'] ?? 'Unnamed'),
          subtitle:
              hasChattedBefore
                  ? Text(
                    existingChat['lastMessage'] ?? '',
                    style: TextStyle(
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  )
                  : null,
          trailing:
              !hasChattedBefore
                  ? const Text(
                    "New chat",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                  : isUnread
                  ? CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.blue,
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  )
                  : null,
          onTap: () async {
            if (hasChattedBefore) {
              await markMessagesAsRead(user['id']);
            }
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => MessagePage(
                      currentUserId:
                          Supabase.instance.client.auth.currentUser!.id,
                      receiverId: user['id'],
                      receiverName: user['name'],
                    ),
              ),
            ).then((_) => loadRecentChats());
          },
        );
      },
    );
  }

  Widget buildRecentChats() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    debugPrint('Recent Chats Count: ${_recentChats.length}'); // Debugging line

    return _recentChats.isEmpty
        ? const Center(child: Text("No recent chats"))
        : RefreshIndicator(
          onRefresh: loadRecentChats,
          child: ListView.builder(
            itemCount: _recentChats.length,
            itemBuilder: (context, index) {
              final chat = _recentChats[index];
              final user = chat['user'];
              final lastMessage = chat['lastMessage'];
              final isUnread = chat['isUnread'] ?? false;
              final unreadCount = chat['unreadCount'] ?? 0;
              final isSentByCurrentUser = chat['isSentByCurrentUser'] ?? false;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(user['name']?.substring(0, 1) ?? '?'),
                ),
                title: Text(user['name'] ?? 'Unnamed'),
                subtitle: Text(
                  lastMessage ?? 'No messages yet',
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing:
                    isUnread && !isSentByCurrentUser
                        ? CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.blue,
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : null,
                onTap: () async {
                  await markMessagesAsRead(user['id']);
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => MessagePage(
                            currentUserId:
                                Supabase.instance.client.auth.currentUser!.id,
                            receiverId: user['id'],
                            receiverName: user['name'],
                          ),
                    ),
                  ).then((_) => loadRecentChats());
                },
              );
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              onChanged: searchUsers,
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _searchResults.isNotEmpty
                    ? buildSearchResults()
                    : buildRecentChats(),
          ),
        ],
      ),
    );
  }
}
