// Copyright 2024 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

// AIzaSyCDRy528NkxcpPs1UuBJ_cQrY4R_ZRPUWc

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/link.dart';
import 'package:dart_openai/dart_openai.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voz Interior',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 171, 222, 244),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(title: 'Voz Interior'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? apiKey;
  List<Map<String, String>> favoriteConversations = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voz Interior', // Centered title
          style: TextStyle(
            fontSize: 20, // Font size for the title
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), // Hamburger menu icon
            onPressed: () {
              // Open the drawer
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chair), // Chef hat icon
            onPressed: () {
              // Add your chef hat action here
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(top: 70), // Add top padding here
            children: <Widget>[
              Container(
                height: 50, // Set the height for the header
                width: 100,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 72, 248),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                    top: Radius.circular(20),
                  ), // Rounded corners for both top and bottom
                ),
                child: const Center( // Center the text horizontally
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20, // Adjust font size if needed
                      color: Colors.white, // Ensure text color is visible
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Sessão'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  // Implement navigation logic to "Diálogo" if needed
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favotiros'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FavoritesPage(favorites: favoriteConversations), // Pass the favorites list
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: ChatWidget(
        favoriteConversations: favoriteConversations,
        onSaveFavorite: _saveConversationToFavorites,
      ),
    );
  }
  void _saveConversationToFavorites(String title, String summary) {
    setState(() {
      favoriteConversations.add({
        'title': title,
        'summary': summary,
      });
    });
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.favoriteConversations, // Receive the favorites list
    required this.onSaveFavorite, // Receive a callback to save favorites
    super.key,
  });

  final List<Map<String, String>> favoriteConversations; // Store the favorites list
  final Function(String, String) onSaveFavorite; // Callback for saving favorites

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  List<Map<String, String>> favoriteConversations = [];

  @override
  void initState() {
    super.initState();
    _messages = [];
    // Optionally add an initial assistant message
    _messages.add({
      'role': 'assistant',
      'content': 'Olá! Como posso ajudá-lo hoje?'
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
  }

  void _saveConversationToFavorites() async {
    // Show a loading indicator while processing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Prepare the messages to send to the backend
      final messages = _messages;

      // Call the '/summary' endpoint
      final summaryResponse = await http.post(
        Uri.parse('http://127.0.0.1:5000/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
      );

      if (summaryResponse.statusCode != 200) {
        throw Exception('Failed to generate summary');
      }

      final summaryData = jsonDecode(summaryResponse.body);
      final summary = summaryData['summary'] ?? 'No summary available';

      // Call the '/title' endpoint
      final titleResponse = await http.post(
        Uri.parse('http://127.0.0.1:5000/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
      );

      if (titleResponse.statusCode != 200) {
        throw Exception('Failed to generate title');
      }

      final titleData = jsonDecode(titleResponse.body);
      final title = titleData['title'] ?? 'Sessão Favorita';

      // Save to favorites
      widget.onSaveFavorite(title, summary);

      // Close the loading indicator
      Navigator.of(context).pop();

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sessão salva como "$title"')),
      );
    } catch (e) {
      // Close the loading indicator
      Navigator.of(context).pop();

      // Show an error message
      _showError('Erro ao salvar a sessão: $e');
    }
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = _messages;
    return Column(
      children: [
        // The header with title and delete button
        Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 115, 75, 234), // Solid background color for the header
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20), top: Radius.circular(20)), // Rounded corners at the bottom
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Padding around the container
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8), // Padding on the left for the Text component
              child: const Text(
                'Sessão',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Ensure the text is visible
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _clearConversation,
                  icon: const Icon(Icons.delete, color: Colors.white), // Ensure the icon is visible
                ),
                // Step 2: Add favorite button
                IconButton(
                  onPressed: _saveConversationToFavorites,
                  icon: const Icon(Icons.favorite, color: Colors.white), // Heart icon for favorite
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), // Background color with opacity
              borderRadius: BorderRadius.circular(16.0), // Rounded corners
              image: DecorationImage(
                image: AssetImage('assets/couch.jpg'), // Background image for conversation
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.50), // Add black overlay with opacity
                  BlendMode.darken,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemBuilder: (context, idx) {
                  final message = history[idx];
                  // Skip system messages
                  if (message['role'] == 'system') {
                    return SizedBox.shrink(); // Returns an empty widget
                  }
                  final text = message['content'] ?? '';
                  return MessageWidget(
                    text: text,
                    isFromUser: message['role'] == 'user',
                  );
                },
                itemCount: history.length,
              ),
            ),
          ),
        ),
        // Message input area is NOT affected by background image
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 25,
            horizontal: 15,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  focusNode: _textFieldFocus,
                  decoration:
                      textFieldDecoration(context, 'Digite uma mensagem...'),
                  controller: _textController,
                  onSubmitted: (String value) {
                    _sendChatMessage(value);
                  },
                  maxLines: null, // Allow unlimited lines for the text field
                  minLines: 1, // Minimum lines when there is no input
                ),
              ),
              const SizedBox.square(dimension: 15),
              if (!_loading)
                IconButton(
                  onPressed: () async {
                    _sendChatMessage(_textController.text);
                  },
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      // Optimistically add the user's message to the chat history
      _messages.add({'role': 'user', 'content': message});
      _scrollDown();
    });

    try {
      // Prepare the messages list to send to the Flask API
      final messages = _messages;

      // Send the POST request to the Flask API
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/chat'), // Update URL as needed
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Ensure that 'messages' is in the response
        if (data.containsKey('messages')) {
          final updatedMessages = List<Map<String, dynamic>>.from(data['messages']);
          setState(() {
            // Update the messages list with the messages from the backend
            _messages = updatedMessages;
            _loading = false;
            _scrollDown();
          });
        } else {
          // Handle unexpected response format
          _showError('Unexpected response format from server.');
          setState(() {
            _loading = false;
          });
        }
      } else {
        // Handle error response
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Unknown error';
        _showError('Error: $errorMessage');
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      _textFieldFocus.requestFocus();
      _scrollDown();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  final String text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 16, // Horizontal padding for the message
                ),
                margin: EdgeInsets.only(
                  bottom: 4,
                  left: isFromUser ? 70 : 10, // More distance from left edge for user messages
                  right: isFromUser ? 10 : 70, // More distance from right edge for assistant messages
                ),
                child: MarkdownBody(data: text),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12), // Horizontal padding for sender label
          child: Text(
            isFromUser ? 'Você' : 'Terapeuta', // Conditionally display "User" or "Assistant"
            style: TextStyle(
              fontSize: 14, // Smaller font size for the label
              color: const Color.fromARGB(255, 152, 152, 245), // Faded color for text
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6), // Space between the sender label and the message bubble
      ],
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

class FavoritesPage extends StatefulWidget {
  final List<Map<String, String>> favorites;

  const FavoritesPage({super.key, required this.favorites});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  void _deleteFavorite(int index) {
    setState(() {
      widget.favorites.removeAt(index); // Remove the item from the list
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sessão deletada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessões Favoritas'),
      ),
      body: ListView.builder(
        itemCount: widget.favorites.length,
        itemBuilder: (context, index) {
          final conversation = widget.favorites[index];
          return ListTile(
            title: Text(conversation['title']!),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteFavorite(index),
              tooltip: 'Apagar Favorito',
            ),
            onTap: () {
              // Navigate to the conversation detail page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConversationDetailPage(
                    title: conversation['title']!,
                    summary: conversation['summary']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ConversationDetailPage extends StatelessWidget {
  final String title;
  final String summary;

  const ConversationDetailPage({super.key, required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to the favorites page
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/couch.jpg'), // Background image
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7), // Dark overlay for readability
              BlendMode.darken,
            ),
          ),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              summary,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white, // Text color for readability
              ),
            ),
          ),
        ),
      ),
    );
  }
}