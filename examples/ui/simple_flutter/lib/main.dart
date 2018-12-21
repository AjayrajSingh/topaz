import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/application_deprecated.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Gesture Demo',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Gesture Demo - Multiple Process'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int leftCounter = 0;
  int rightCounter = 0;

  List<MaterialColor> colors = <MaterialColor>[
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple
  ];

  void _onLeftDismissed(DismissDirection direction) {
    setState(() {
      leftCounter++;
    });
  }

  void _onRightDismissed(DismissDirection direction) {
    setState(() {
      rightCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: new Center(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Dismissible(
                      key: new Key('left$leftCounter'),
                      onDismissed: _onLeftDismissed,
                      resizeDuration: null,
                      child: new Card(
                        child: new Container(
                            width: 300.0,
                            height: 300.0,
                            color: colors[leftCounter % colors.length]),
                      )),
                  new Text('Left, $leftCounter')
                ]),
            new Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Dismissible(
                      key: new Key('right$rightCounter'),
                      onDismissed: _onRightDismissed,
                      resizeDuration: null,
                      child: new Card(
                          child: new Container(
                        width: 300.0,
                        height: 300.0,
                        child: new ApplicationWidget(
                            url:
                                'fuchsia-pkg://fuchsia.com/simple_flutter#meta/leaf_flutter.cmx',
                            launcher:
                                StartupContext.fromStartupInfo().launcher),
                      ))),
                  new Text('Right, $rightCounter')
                ]),
          ],
        ),
      ),
    );
  }
}
