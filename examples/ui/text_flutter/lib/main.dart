import 'package:flutter/material.dart';

void main() {
  runApp(ImeDemoApp());
}

class ImeDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Input Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ImeDemoPage(title: 'Input Demo - Text and IME'),
    );
  }
}

class ImeDemoPage extends StatefulWidget {
  const ImeDemoPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _ImeDemoPageState createState() => _ImeDemoPageState();
}

class _ImeDemoPageState extends State<ImeDemoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
          child: Card(
              child: Container(
                  height: 300.0,
                  width: 300.0,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        TextField(
                          cursorWidth: 4.0,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'enter text here'),
                          style: TextStyle(fontSize: 30.0, color: Colors.black),
                        )
                      ])))),
    );
  }
}
