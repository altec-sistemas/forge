// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:forge_flutter/forge_flutter.dart';

void main() async {
  // Create the application instance
  final app = Application();

  // Register bundles
  app.addBundle(TodoBundle());

  // Run the app with your main widget
  await app.run((i) => const MyApp());
}

// Define a simple service
class TodoService {
  final List<String> _todos = ['Buy groceries', 'Write documentation'];

  List<String> get todos => List.unmodifiable(_todos);

  void addTodo(String todo) {
    _todos.add(todo);
  }

  void removeTodo(int index) {
    _todos.removeAt(index);
  }
}

// Create a bundle to organize your services
class TodoBundle extends Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    builder.registerSingleton<TodoService>((c) => TodoService());
  }

  @override
  Future<void> boot(Injector container) async {
    print('TodoBundle initialized!');
  }
}

// Your main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge Flutter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TodoScreen(),
    );
  }
}

// Use services in your widgets via the global injector
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late final TodoService _todoService;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _todoService = injector.get<TodoService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter a new todo',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _todoService.todos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: Text(_todoService.todos[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeTodo(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addTodo() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _todoService.addTodo(_controller.text);
        _controller.clear();
      });
    }
  }

  void _removeTodo(int index) {
    setState(() {
      _todoService.removeTodo(index);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
