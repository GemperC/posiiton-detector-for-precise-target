import 'dart:io';
import 'dart:typed_data';

import 'package:body_detection/models/image_result.dart';
import 'package:body_detection/models/point3d.dart';
import 'package:body_detection/models/pose.dart';
import 'package:body_detection/models/body_mask.dart';
import 'package:body_detection/models/pose_landmark.dart';
import 'package:body_detection/models/pose_landmark_type.dart';
import 'package:body_detection/png_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:body_detection/body_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pose_mask_painter.dart';

class PoseDetectionWidget extends StatefulWidget {
  // final CameraDescription camera;

  const PoseDetectionWidget({
    Key? key,
    // required this.camera,
  }) : super(key: key);

  @override
  _PoseDetectionWidgetState createState() => _PoseDetectionWidgetState();
}

class _PoseDetectionWidgetState extends State<PoseDetectionWidget> {
  int _selectedTabIndex = 0;
  bool takePicture = false;

  Point3d leftWristPosition = Point3d(x: 0, y: 0, z: 0);
  Point3d rightWristPosition = Point3d(x: 0, y: 0, z: 0);

  Point3d leftAnklePosition = Point3d(x: 0, y: 0, z: 0);

  Point3d rightAnklePosition = Point3d(x: 0, y: 0, z: 0);

  // String rightWristPosition = 'null';

  // String leftKneePosition = 'null';

  // String rightKneePosition = 'null';

  bool _isDetectingPose = false;
  bool _isDetectingBodyMask = false;

  Image? _selectedImage;

  Pose? _detectedPose;
  ui.Image? _maskImage;
  Image? _cameraImage;
  Size _imageSize = Size.zero;

  bool checkIfBodyPoseIsCurrent(PoseLandmark leftWrist, PoseLandmark rightWrist,
      PoseLandmark leftAnkle, PoseLandmark rightAnkle) {
    var isLeftWristInPos = false;
    var isRightWristInPos = false;
    var isLeftAnkleInPos = false;
    var isLightAnkleInPos = false;
    var windowWrists = 25;
    var windowAnkles = 10;

    //CHECK LEFT WRIST POSTION
    final leftWristTargetX = 350;
    final leftWristTargetY = 322;
    isLeftWristInPos = checkTargetPose(
        leftWristTargetX, leftWristTargetY, windowWrists, leftWrist);
//CHECK RIGHT WRIST POSTION
    final rightWristTargetX = 158;
    final rightWristTargetY = 258;
    isRightWristInPos = checkTargetPose(
        rightWristTargetX, rightWristTargetY, windowWrists, rightWrist);
    //CHECK ANKLE WRIST POSTION
    final leftAnkleTargetX = 286;
    final leftAnkleTargetY = 171;
    isLeftAnkleInPos = checkTargetPose(
        leftAnkleTargetX, leftAnkleTargetY, windowAnkles, leftAnkle);
    //CHECK ANKLE WRIST POSTION
    final rightAnkleTargetX = 186;
    final rightAnkleTargetY = 176;
    isLightAnkleInPos = checkTargetPose(
        rightAnkleTargetX, rightAnkleTargetY, windowAnkles, rightAnkle);

    if (isLeftWristInPos &
        isRightWristInPos &
        isLeftAnkleInPos &
        isLightAnkleInPos) {
      return true;
    }
    return false;
  }

  bool checkTargetPose(
      int targetX, int targetY, int window, PoseLandmark poseLandmark) {
    if (isInRange(poseLandmark.position.x.toInt(), window, targetX) &
        isInRange(poseLandmark.position.y.toInt(), window, targetY)) {
      return true;
    }
    return false;
  }

  bool isInRange(int num, int window, int target) {
    return num >= (target - window) && num <= (target + window);
  }

  Future<void> _selectImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path != null) {
      _resetState();
      setState(() {
        _selectedImage = Image.file(File(path));
      });
    }
  }

  Future<void> _detectImagePose() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final pose = await BodyDetection.detectPose(image: pngImage);
    _handlePose(pose);
  }

  Future<void> _detectImageBodyMask() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final mask = await BodyDetection.detectBodyMask(image: pngImage);
    _handleBodyMask(mask);
  }

  Future<void> _startCameraStream() async {
    final request = await Permission.camera.request();
    if (request.isGranted) {
      await BodyDetection.startCameraStream(
        onFrameAvailable: _handleCameraImage,
        onPoseAvailable: (pose) {
          if (!_isDetectingPose) return;
          _handlePose(pose);
        },
        onMaskAvailable: (mask) {
          if (!_isDetectingBodyMask) return;
          _handleBodyMask(mask);
        },
      );
    }
  }

  Future<void> _stopCameraStream() async {
    await BodyDetection.stopCameraStream();

    setState(() {
      _cameraImage = null;
      _imageSize = Size.zero;
    });
  }

  void _handleCameraImage(ImageResult result) {
    // Ignore callback if navigated out of the page.
    if (!mounted) return;

    // To avoid a memory leak issue.
    // https://github.com/flutter/flutter/issues/60160
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();

    final image = Image.memory(
      result.bytes,
      gaplessPlayback: true,
      fit: BoxFit.contain,
    );

    setState(() {
      _cameraImage = image;
      _imageSize = result.size;
    });
  }

  void _handlePose(Pose? pose) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    if (pose != null) {
      final leftWrist = pose.landmarks.firstWhere(
          (landmark) => landmark.type == PoseLandmarkType.leftWrist);
      final rightWrist = pose.landmarks.firstWhere(
          (landmark) => landmark.type == PoseLandmarkType.rightElbow);
      final leftAnkle = pose.landmarks.firstWhere(
          (landmark) => landmark.type == PoseLandmarkType.leftShoulder);
      final rightAnkle = pose.landmarks.firstWhere(
          (landmark) => landmark.type == PoseLandmarkType.rightShoulder);

      var currentPoseIsGood = checkIfBodyPoseIsCurrent(
          leftWrist, rightWrist, leftAnkle, rightAnkle);

      if (currentPoseIsGood) {
        setState(() {
          takePicture = true;
        });
      } else {
        setState(() {
          takePicture = false;
        });
      }

      setState(() {
        _detectedPose = pose;

        leftWristPosition = leftWrist.position;
        rightWristPosition = rightWrist.position;
        leftAnklePosition = leftAnkle.position;
        rightAnklePosition = rightAnkle.position;
      });
    }
  }

  void _handleBodyMask(BodyMask? mask) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    if (mask == null) {
      setState(() {
        _maskImage = null;
      });
      return;
    }

    final bytes = mask.buffer
        .expand(
          (it) => [0, 0, 0, (it * 255).toInt()],
        )
        .toList();
    ui.decodeImageFromPixels(Uint8List.fromList(bytes), mask.width, mask.height,
        ui.PixelFormat.rgba8888, (image) {
      setState(() {
        _maskImage = image;
      });
    });
  }

  Future<void> _toggleDetectPose() async {
    if (_isDetectingPose) {
      await BodyDetection.disablePoseDetection();
    } else {
      await BodyDetection.enablePoseDetection();
    }

    setState(() {
      _isDetectingPose = !_isDetectingPose;
      _detectedPose = null;
    });
  }

  Future<void> _toggleDetectBodyMask() async {
    if (_isDetectingBodyMask) {
      await BodyDetection.disableBodyMaskDetection();
    } else {
      await BodyDetection.enableBodyMaskDetection();
    }

    setState(() {
      _isDetectingBodyMask = !_isDetectingBodyMask;
      _maskImage = null;
    });
  }

  void _onTabEnter(int index) {
    // Camera tab
    if (index == 1) {
      _startCameraStream();
    }
  }

  void _onTabExit(int index) {
    // Camera tab
    if (index == 1) {
      _stopCameraStream();
    }
  }

  void _onTabSelectTapped(int index) {
    _onTabExit(_selectedTabIndex);
    _onTabEnter(index);

    setState(() {
      _selectedTabIndex = index;
    });
  }

  Widget? get _selectedTab => _selectedTabIndex == 0
      ? _imageDetectionView
      : _selectedTabIndex == 1
          ? _cameraDetectionView
          : null;

  void _resetState() {
    setState(() {
      _maskImage = null;
      _detectedPose = null;
      _imageSize = Size.zero;
    });
  }

  Widget get _imageDetectionView => SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              GestureDetector(
                child: ClipRect(
                  child: CustomPaint(
                    child: _selectedImage,
                    foregroundPainter: PoseMaskPainter(
                      pose: _detectedPose,
                      mask: _maskImage,
                      imageSize: _imageSize,
                    ),
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _selectImage,
                child: const Text('Select image'),
              ),
              OutlinedButton(
                onPressed: _detectImagePose,
                child: const Text('Detect pose'),
              ),
              OutlinedButton(
                onPressed: _detectImageBodyMask,
                child: const Text('Detect body mask'),
              ),
              OutlinedButton(
                onPressed: _resetState,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      );

  Widget get _cameraDetectionView => SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 110),
                child: ClipRect(
                  child: CustomPaint(
                    child: _cameraImage,
                    foregroundPainter: PoseMaskPainter(
                      pose: _detectedPose,
                      mask: _maskImage,
                      imageSize: _imageSize,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 18.0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      // Text(
                      //   "leftWrist\nx = ${leftWristPosition.x.toString()} \ny = ${leftWristPosition.y.toString()} \nz = ${leftWristPosition.z.toString()}",
                      //   style: TextStyle(
                      //       fontSize: 28,
                      //       color: Colors.red,
                      //       fontWeight: FontWeight.bold),
                      // ),
                      // Text(
                      //   "rightWrist\nx = ${rightWristPosition.x.toString()} \ny = ${rightWristPosition.y.toString()} \nz = ${rightWristPosition.z.toString()}",
                      //   style: TextStyle(
                      //       fontSize: 28,
                      //       color: Colors.red,
                      //       fontWeight: FontWeight.bold),
                      // ),
                      // Text(
                      //   "leftAnkle\nx = ${leftAnklePosition.x.toString()} \ny = ${leftAnklePosition.y.toString()} \nz = ${leftAnklePosition.z.toString()}",
                      //   style: TextStyle(
                      //       fontSize: 28,
                      //       color: Colors.red,
                      //       fontWeight: FontWeight.bold),
                      // ),
                      // Text(
                      //   "rightAnkle\nx = ${rightAnklePosition.x.toString()} \ny = ${rightAnklePosition.y.toString()} \nz = ${rightAnklePosition.z.toString()}",
                      //   style: TextStyle(
                      //       fontSize: 28,
                      //       color: Colors.red,
                      //       fontWeight: FontWeight.bold),
                      // ),
                      Text(
                        takePicture ? "Good" : "Not Good",
                        style: TextStyle(
                            fontSize: 25,
                            color: takePicture ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 130.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: _toggleDetectPose,
                    child: _isDetectingPose
                        ? const Text('Turn off pose detection')
                        : const Text('Turn on pose detection'),
                  ),
                ),
              ),
              // OutlinedButton(
              //   onPressed: _toggleDetectBodyMask,
              //   child: _isDetectingBodyMask
              //       ? const Text('Turn off body mask detection')
              //       : const Text('Turn on body mask detection'),
              // ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Position estimation TEST app')),
      ),
      body: _selectedTab,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Image',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Camera',
          ),
        ],
        currentIndex: _selectedTabIndex,
        onTap: _onTabSelectTapped,
      ),
    );
  }
}
