// main.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:record/record.dart'; // Import the 'record' package

// At the top of your file, after the imports
const bool useLocalServer = true; // Set this to true for local development, false for production
const String localUrl = 'http://127.0.0.1:8000';
const String serverUrl = 'http://3.94.59.201:8000';

// Create a getter for the base URL
String get baseUrl => useLocalServer ? localUrl : serverUrl;

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
  List<Map<String, String>> favoriteConversations = [];

  void _saveConversationToFavorites(String title, String summary) {
    setState(() {
      favoriteConversations.add({
        'title': title,
        'summary': summary,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voz Interior',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chair),
            onPressed: () {
              // Add your action here
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 70),
            children: <Widget>[
              Container(
                height: 50,
                width: 100,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 124, 72, 248),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                    top: Radius.circular(20),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Sessão'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favoritos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FavoritesPage(
                        favorites: favoriteConversations,
                      ),
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
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.favoriteConversations,
    required this.onSaveFavorite,
    super.key,
  });

  final List<Map<String, String>> favoriteConversations;
  final Function(String, String) onSaveFavorite;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;
  final _audioRecorder = AudioRecorder(); // Initialize the recorder
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Optionally add an initial assistant message
    _messages.add({
      'role': 'assistant',
      'content': 'Olá! Como posso ajudá-lo hoje?'
    });
  }

  Future<void> _startRecording() async {
    try {
      // Check and request permission
      if (await _audioRecorder.hasPermission()) {
        // Get the temporary directory
        String filePath = '/Users/pedroloes/Documents/drope/flutter_projects/mind_talks/temp/temp_audio.m4a';

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(),
          path: filePath);

        setState(() {
          _isRecording = true;
        });
      } else {
        _showError(
            'Permissão para acessar o microfone negada. Por favor, habilite nas configurações do aplicativo.');
      }
    } catch (e) {
      _showError('Erro ao iniciar a gravação: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Stop recording
      String? filePath = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (filePath != null) {
        File audioFile = File(filePath);
        await _sendAudioFile(audioFile);
      }
    } catch (e) {
      _showError('Erro ao parar a gravação: $e');
    }
  }

  Future<void> _sendAudioFile(File audioFile) async {
    setState(() {
      _loading = true;
    });

    try {
      // Check if the file exists before proceeding
      if (await audioFile.exists()) {
        // Read the file into memory as bytes
        var bytes = await audioFile.readAsBytes();

        // Create a multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/transcription'),
        );

        // Add the audio file to the request
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'audio.m4a',
            // contentType: MediaType('audio', 'm4a'), // Optionally remove this if causing issues
          ),
        );

        // Send the request
        var response = await request.send();

        // Process the response
        if (response.statusCode == 200) {
          var responseData = await http.Response.fromStream(response);
          final data = jsonDecode(utf8.decode(responseData.bodyBytes));  // Add UTF-8 decoding here

          final transcription = data['transcription'] ?? '';
          final transcribedText = transcription['text'] ?? '';
          print('Transcribed Text: $transcribedText');
          
          setState(() {
            _messages.add({'role': 'user', 'content': transcribedText});
          });

          // Send the transcribed text to get the assistant's reply
          await _sendChatMessage(transcribedText);
        } else {
          _showError('Erro ao transcrever o áudio. Status: ${response.statusCode}');
        }
      } else {
        _showError('Arquivo de áudio não encontrado.');
      }
    } catch (e) {
      _showError('Erro ao enviar o arquivo de áudio: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
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
      // print('$baseUrl/summary');

      // Call the '/summary' endpoint
      final summaryResponse = await http.post(
        Uri.parse('$baseUrl/summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
        encoding: Encoding.getByName('utf-8'),
      );

      if (summaryResponse.statusCode != 200) {
        throw Exception('Failed to generate summary');
      }
      
      final summaryData = jsonDecode(utf8.decode(summaryResponse.bodyBytes));
      final summary = summaryData['summary'] ?? 'No summary available';

      // Call the '/title' endpoint
      final titleResponse = await http.post(
        Uri.parse('$baseUrl/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
        encoding: Encoding.getByName('utf-8'),
      );

      if (titleResponse.statusCode != 200) {
        throw Exception('Failed to generate title');
      }

      final titleData = jsonDecode(utf8.decode(titleResponse.bodyBytes));
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
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 115, 75, 234),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
                top: Radius.circular(20),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Sessão',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _clearConversation,
                      icon: const Icon(Icons.delete, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: _saveConversationToFavorites,
                      icon: const Icon(Icons.favorite, color: Colors.white),
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
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16.0),
              image: DecorationImage(
                image: const AssetImage('assets/couch.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.50),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0),
              child: ListView.builder(
                controller: _scrollController,
                itemBuilder: (context, idx) {
                  final message = history[idx];
                  // Skip system messages
                  if (message['role'] == 'system') {
                    return const SizedBox.shrink();
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
                  maxLines: null,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 10),
              if (!_loading)
                Row(
                  children: [
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: Icon(
                        Icons.mic,
                        color: _isRecording ? Colors.red : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () {
                        _sendChatMessage(_textController.text);
                      },
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
      // Prepare the messages list to send to the FastAPI backend
      final messages = _messages;

      // Send the POST request to the FastAPI backend
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'messages': messages}),
        encoding: Encoding.getByName('utf-8'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // Ensure that 'messages' is in the response
        if (data.containsKey('messages')) {
          final updatedMessages =
              List<Map<String, dynamic>>.from(data['messages']);
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
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
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
          title: const Text('Erro'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
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
                  horizontal: 16,
                ),
                margin: EdgeInsets.only(
                  bottom: 4,
                  left: isFromUser ? 70 : 10,
                  right: isFromUser ? 10 : 70,
                ),
                child: MarkdownBody(data: text),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            isFromUser ? 'Você' : 'Terapeuta',
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 152, 152, 245),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

InputDecoration textFieldDecoration(BuildContext context, String hintText) =>
    InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: hintText,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Colors.white,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(14),
        ),
        borderSide: BorderSide(
          color: Colors.white,
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
      widget.favorites.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sessão deletada')),
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

  const ConversationDetailPage(
      {super.key, required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/couch.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
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
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
