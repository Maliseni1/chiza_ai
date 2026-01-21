import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chiza_ai/features/chat/providers/chat_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isChecking = false;
  String _appVersion = "Loading...";

  static const String _githubRepo = "Maliseni1/chiza_ai"; 

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isChecking = true);

    try {
      // 1. Fetch latest release from GitHub API
      final url = Uri.parse("https://api.github.com/repos/$_githubRepo/releases/latest");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tagName = data['tag_name'] ?? ""; 
        final String htmlUrl = data['html_url']; 

        // 2. Normalize versions (remove 'v')
        final String cleanTag = tagName.replaceAll('v', '').trim();
        final String cleanCurrent = _appVersion.replaceAll('v', '').trim();

        // 3. Compare
        if (_isNewer(cleanTag, cleanCurrent)) {
          if (mounted) {
            _showUpdateDialog(tagName, data['body'] ?? "New features available.", htmlUrl);
          }
        } else {
          _showSnackBar("You are up to date! ($cleanCurrent)");
        }
      } else if (response.statusCode == 404) {
         _showSnackBar("Repo not found. Check repository name.");
      } else {
        _showSnackBar("Could not check updates (Error ${response.statusCode})");
      }
    } catch (e) {
      _showSnackBar("Update check failed. Check internet connection.");
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  bool _isNewer(String remote, String current) {
    try {
      List<int> rParts = remote.split('.').map(int.parse).toList();
      List<int> cParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < rParts.length; i++) {
        int cPart = (i < cParts.length) ? cParts[i] : 0;
        if (rParts[i] > cPart) return true;
        if (rParts[i] < cPart) return false;
      }
      return rParts.length > cParts.length;
    } catch (e) {
      return false; 
    }
  }

  void _showUpdateDialog(String version, String notes, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Update Available ($version)"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("A new prototype version is available."),
              const Divider(),
              Text(notes, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          // --- SECTION 1: DATA ---
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Data Management",
              style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Clear Chat History"),
            subtitle: const Text("Delete all saved conversations"),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear History?"),
                  content: const Text("This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Delete", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                // ignore: use_build_context_synchronously
                await Provider.of<ChatProvider>(context, listen: false).clearAllHistory();
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("History cleared")),
                  );
                }
              }
            },
          ),
          
          const Divider(),

          // --- SECTION 2: ABOUT & UPDATES ---
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "System",
              style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Current Version"),
            trailing: Text(_appVersion),
          ),
          ListTile(
            leading: _isChecking 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.system_update, color: Colors.deepPurple),
            title: const Text("Check for Updates"),
            subtitle: const Text("Check GitHub for new prototype"),
            onTap: _isChecking ? null : _checkForUpdates,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
          const ListTile(
            leading: Icon(Icons.science),
            title: Text("Developer"),
            trailing: Text("Chiza Labs"),
          ),
        ],
      ),
    );
  }
}