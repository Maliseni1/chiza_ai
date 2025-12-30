import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';
import 'package:chiza_ai/features/chat/presentation/screens/settings_screen.dart'; // Import Settings

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch provider to update list when new chats are added
    final chatProvider = Provider.of<ChatProvider>(context);
    final history = chatProvider.history;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            color: Colors.deepPurple[50],
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    chatProvider.startNewChat();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Start New Chat"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.search),
            title: const Text("Search"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Search coming soon!")),
              );
            },
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Recent History",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // REAL HISTORY LIST
          Expanded(
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No history yet. Start chatting!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final session = history[index];
                      return ListTile(
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${session.date.day}/${session.date.month} ${session.date.hour}:${session.date.minute}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          // In a full app, this would load that specific chat session
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Settings
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Built by",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.science,
                      size: 16,
                      color: Colors.deepPurple[400],
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Chiza Labs",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
