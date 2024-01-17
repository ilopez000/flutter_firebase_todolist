import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter To-Do App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthScreen(),
      routes: {
        '/todos': (context) => TodosScreen(),
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signInWithEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (userCredential.user != null) {
        Navigator.pushReplacementNamed(context, '/todos');
      }
    } on FirebaseAuthException catch (error) {
      _showErrorDialog(error.message ?? 'An error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (userCredential.user != null) {
        Navigator.pushReplacementNamed(context, '/todos');
      }
    } on FirebaseAuthException catch (error) {
      _showErrorDialog(error.message ?? 'An error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter To-Do App'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signInWithEmail,
                child: Text('Login'),
              ),
              ElevatedButton(
                onPressed: _signUpWithEmail,
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class TodosScreen extends StatefulWidget {
  @override
  _TodosScreenState createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final _firestore = FirebaseFirestore.instance;
  User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _fetchTodos();
    }
  }

  void _fetchTodos() async {
    if (currentUser != null) {
      final todosQuery = await _firestore.collection('todos')
          .where('UID de usuario', isEqualTo: currentUser!.uid)
          .get();

      for (final todo in todosQuery.docs) {
        print(todo.data());
      }
    }
  }

  void _addTodo(String title) {
    if (currentUser != null) {
      _firestore.collection('todos').add({
        'title': title,
        'UID de usuario': currentUser!.uid,
      });
    }
  }

  void _showAddTodoDialog(BuildContext context) {
    final TextEditingController _newTodoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New Todo'),
        content: TextField(
          controller: _newTodoController,
          decoration: InputDecoration(labelText: 'Title'),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: Text('Add'),
            onPressed: () {
              if (_newTodoController.text.isNotEmpty) {
                _addTodo(_newTodoController.text);
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
      ),
      body: currentUser == null
          ? Center(child: Text('No user logged in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('todos')
            .where('UID de usuario', isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final todos = snapshot.data!.docs.map((doc) => doc.data()).toList();

            return ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                return ListTile(
                  title: Text(todo['title'] ?? 'Untitled'),
                  trailing: IconButton(
                    onPressed: () {
                      // Aquí podrías agregar una lógica adicional para confirmar antes de eliminar
                      _firestore.collection('todos').doc(todo['id'].toString()).delete();
                    },
                    icon: Icon(Icons.delete),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error fetching data'));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }
}
