import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:math' as math;
import './models/detectedObj.dart';

List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController _cameraController;
  bool _loading;
  bool showCapturedPhoto;
  List<DetectedObj> objects = [];
  File _newImage;

  int previewH;
  int previewW;
  double _screenH;
  double _screenW;

  void initState() {
    super.initState();
    // print(cameras);
    _cameraController = CameraController(cameras[1], ResolutionPreset.max);
    _cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });

    _loading = true;

    loadModel().then((value) {
      setState(() {
        _loading = false;
      });
    });
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/ssd_mobilenet.tflite",
      labels: "assets/ssd_mobilenet.txt",
    );
  }

  // loadModel() async {
  //   await Tflite.loadModel(
  //     model:
  //         "assets/posenet_mobilenet_v1_100_257x257_multi_kpt_stripped.tflite",
  //   );
  // }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // Classifiy the image selected
  classifyImage(File image) async {
    if (image.path == null) return;

    // var output = await Tflite.runPoseNetOnImage(
    //     path: image.path, // required
    //     imageMean: 125.0, // defaults to 125.0
    //     imageStd: 125.0, // defaults to 125.0
    //     numResults: 2, // defaults to 5
    //     threshold: 0.7, // defaults to 0.5
    //     nmsRadius: 10, // defaults to 20
    //     asynch: true // defaults to true
    //     );

    await Tflite.detectObjectOnImage(
      path: image.path, // required
      model: "SSDMobileNet",
      threshold: 0.3,
      imageMean: 127.5,
      imageStd: 127.5,
      numResultsPerClass: 1, // defaults to 5
    ).then((results) {
      results.forEach((element) {
        if (element['confidenceInClass'] <= 0.40) return;
        var detectedObject = new DetectedObj(
            element['detectedClass'], element['confidenceInClass'] * 100);

        setState(() {
          _loading = false;
          objects.add(detectedObject);
        });
      });

      print(objects);
    });
  }

  Widget cameraModule() {
    print(_screenH / 1.5);
    if (!_cameraController.value.isInitialized) {
      return Container();
    }
    return ClipRRect(
      borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0)),
      child: Stack(
        children: [
          Container(
            height: _screenH / 1.5,
            width: _screenW,
            decoration: BoxDecoration(),
            child: AspectRatio(
                aspectRatio: _cameraController.value.aspectRatio,
                child: CameraPreview(_cameraController)),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
                child: Icon(Icons.camera_alt), onPressed: takePhoto),
          ),
        ],
      ),
    );
  }

  void takePhoto() async {
    // clear objects array
    setState(() {
      objects.clear();
    });

    //on camera button press
    try {
      final path = join(
        (await getTemporaryDirectory()).path, //Temporary path
        '${DateTime.now()}.png',
      );

      await _cameraController.takePicture(path); //take photo

      File newImage = File(path);

      await classifyImage(newImage);

      setState(() {
        _newImage = newImage;
      });
    } catch (e) {
      print(e);
    }
  }

  Widget displayImage() {
    FileImage(_newImage)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          // setState(() {
          //   previewW = info.image.width;
          //   previewH = info.image.height;
          // });
        })));

    return ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(16.0)),
        child: Container(
            height: 150,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(216, 216, 216, 100),
                  blurRadius: 4.0,
                  spreadRadius: 2.0,
                  offset: Offset(
                    2.0,
                    3.0,
                  ),
                ),
              ],
            ),
            child: Image.file(_newImage)));
  }

  Widget showResults() {
    return Expanded(
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          itemCount: objects.length,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int index) {
            if (index < objects.length) {
              String title = objects[index].title;
              return Container(
                height: 150,
                padding: EdgeInsets.all(16.0),
                margin: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(216, 216, 216, 100),
                      blurRadius: 4.0,
                      spreadRadius: 2.0,
                      offset: Offset(
                        2.0,
                        3.0,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(objects[index].title.toString()),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(objects[index].confidence.toString()),
                    ),
                    FaIcon(FontAwesomeIcons. + title)

                    // FaIcon(FontAwesomeIcons.gamepad)
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget test() {
    return Positioned(
        left: 10,
        top: 200,
        height: 100,
        child: Container(width: 200, color: Colors.black));
  }

  @override
  Widget build(BuildContext context) {
    var screen = MediaQuery.of(context).size;
    setState(() {
      _screenH = screen.height;
      _screenW = screen.width;
    });
    return Scaffold(
        // appBar: AppBar(
        //   title: Text("ml test"),
        // ),
        body: Stack(
      overflow: Overflow.visible,
      children: [
        Column(
          children: <Widget>[
            // RaisedButton(
            //   child: Text("sal"),
            //   onPressed: takePhoto,
            //   elevation: 4,
            // ),
            cameraModule(),

            Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 16.0),
              child: Row(
                children: <Widget>[
                  _newImage != null
                      ? displayImage()
                      : Container(
                          // height: 150,
                          // width: 100,
                          // color: Colors.grey,
                          ),
                  objects.isNotEmpty ? showResults() : Container()
                ],
              ),
            ),
          ],
        ),
      ],
    ));
  }
}
