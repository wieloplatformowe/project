import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(ShoppingListApp());
}

class ShoppingListApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista zakupów',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: NavigationWrapper(),
    );
  }
}

class NavigationWrapper extends StatefulWidget {
  @override
  _NavigationWrapperState createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;
  List<String> _shoppingListItems = [];
  List<String> _cartItems = [];

  void _addToShoppingList(String item) async {
    final db = await _openDatabase();
    await db.insert('shopping_list', {'item': item});
    setState(() {
      _shoppingListItems.add(item);
    });
  }

  void _addToCart(String item) async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.insert('cart', {'item': item});
      await txn.delete('shopping_list', where: 'item = ?', whereArgs: [item]);
    });
    setState(() {
      _cartItems.add(item);
      _shoppingListItems.remove(item);
    });
  }

  void _removeFromCart(String item) async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete('cart', where: 'item = ?', whereArgs: [item]);
      await txn.insert('shopping_list', {'item': item});
    });
    setState(() {
      _cartItems.remove(item);
      _shoppingListItems.add(item);
    });
  }

  void _removeItem(String item) async {
    final db = await _openDatabase();
    await db.transaction((txn) async {
      await txn.delete('shopping_list', where: 'item = ?', whereArgs: [item]);
      await txn.delete('cart', where: 'item = ?', whereArgs: [item]);
    });
    setState(() {
      _shoppingListItems.remove(item);
      _cartItems.remove(item);
    });
  }


  Widget _buildShoppingListItem(String item) {
    return ListTile(
      key: Key(item),
      leading: Checkbox(
        value: _cartItems.contains(item),
        onChanged: (checked) {
          if (checked!) {
            _addToCart(item);
          } else {
            _removeFromCart(item);
          }
        },
      ),
      title: Text(item),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        onPressed: () {
          _removeItem(item);
        },
      ),
    );
  }

  Widget _buildShoppingList() {
    return FutureBuilder<List<String>>(
      future: _fetchShoppingListItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          final items = snapshot.data;
          return ReorderableListView(
            children: items!.map((item) => _buildShoppingListItem(item)).toList(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                _updateShoppingListOrder(items);
              });
            },
          );
        }
      },
    );
  }

  Future<List<String>> _fetchShoppingListItems() async {
    final db = await _openDatabase();
    final results = await db.query('shopping_list', orderBy: 'item_order ASC');
    return results.map((row) => row['item'] as String).toList();
  }

  void _updateShoppingListOrder(List<String> items) async {
    final db = await _openDatabase();
    for (int i = 0; i < items.length; i++) {
      await db.rawUpdate('UPDATE shopping_list SET item_order = ? WHERE item = ?', [i, items[i]]);
    }
  }

  Widget _buildCart() {
    return FutureBuilder<List<String>>(
      future: _fetchCartItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          final items = snapshot.data;
          return ListView.builder(
            itemCount: items!.length,
            itemBuilder: (context, index) {
              return ListTile(
                key: Key(items[index]),
                leading: Checkbox(
                  value: true,
                  onChanged: (checked) {
                    _removeFromCart(_cartItems[index]);
                  },
                ),
                title: Text(items[index]),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    _removeItem(items[index]);
                  },
                ),
              );
            },
          );
        }
      },
    );
  }

  Future<List<String>> _fetchCartItems() async {
    final db = await _openDatabase();
    final results = await db.query('cart');
    return results.map((row) => row['item'] as String).toList();
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    String title = "";
    if (_selectedIndex == 0) {
      currentScreen = _buildShoppingList();
      title = "Lista zakupów";
    } else {
      currentScreen = _buildCart();
      title = "Koszyk";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: currentScreen,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              TextEditingController _textEditingController =
                  TextEditingController();
              return AlertDialog(
                title: Text('Dodaj przedmiot'),
                content: TextField(
                  controller: _textEditingController,
                ),
                actions: [
                  TextButton(
                    child: Text('Anuluj'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Dodaj'),
                    onPressed: () {
                      String newItem = _textEditingController.text.trim();
                      if (newItem.isNotEmpty) {
                        _addToShoppingList(newItem);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Lista zakupów',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Koszyk',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

Future<Database> _openDatabase() async {
  final databasePath = await getDatabasesPath();
  final path = join(databasePath, 'shopping.db');
  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS shopping_list (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item TEXT,
          item_order INTEGER
        )
      ''');
      db.execute('''
        CREATE TABLE IF NOT EXISTS cart (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item TEXT,
          item_order INTEGER
        )
      ''');
    },
  );
}
