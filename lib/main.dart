import 'dart:async';
import 'package:flutter/material.dart';
import 'map_widget/map_params.dart';
import 'map_widget/map_widget.dart';
import 'panorama_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MountainPanorama',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Showing Mountain Panoramas'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _position = "Searching GPS";
  var toMap = StreamController<MapParams>.broadcast();
  var fromMap = StreamController<MapParams>();
  var toPanorama = StreamController<MapParams>.broadcast();
  var fromPanorama = StreamController<MapParams>();
  List<double> origin = [46.5946, 6.31];

  @override
  void initState() {
    super.initState();

    fromMap.stream.listen((event) {
      event.isLocationViewpoint((loc) {
        toPanorama.add(event);
        setState(() {
          _position =
              "${loc.latitude.toStringAsFixed(4)} / ${loc.longitude.toStringAsFixed(4)}";
        });
      });
    });

    fromPanorama.stream.listen((event) {
      toMap.add(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Center(
              child: Column(children: <Widget>[
                const Text(
                  'You are currently here :',
                ),
                Text(
                  _position,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ]),
            ),
            Expanded(
              // height: 500,
              // width: 500,
              child: getMapWidget(toMap.stream, fromMap.sink, origin),
            ),
            Expanded(
              child: SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: Panorama(
                  toPanorama: toPanorama.stream,
                  fromPanorama: fromPanorama.sink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
