import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

import 'pose_mask_painter.dart';

import 'pose_detection/models/point3d.dart';
import 'pose_detection/body_detection.dart';
import 'pose_detection/models/image_result.dart';
import 'pose_detection/models/pose.dart';
import 'pose_detection/models/pose_landmark.dart';
import 'pose_detection/models/pose_landmark_type.dart';

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
  // int _selectedTabIndex = 0;
  bool takePicture = false;

  Point3d leftWristPosition = Point3d(x: 0, y: 0, z: 0);
  Point3d rightWristPosition = Point3d(x: 0, y: 0, z: 0);

  Point3d leftAnklePosition = Point3d(x: 0, y: 0, z: 0);

  Point3d rightAnklePosition = Point3d(x: 0, y: 0, z: 0);

  // bool _isDetectingPose = true;
  // bool _isDetectingBodyMask = false;

  Image? _selectedImage;

  Pose? _detectedPose;
  ui.Image? _maskImage;
  Image? _cameraImage;
  Size _imageSize = Size.zero;

  @override
  void initState() {
    // TODO: implement initState
    _startCameraStream();
    _toggleDetectPose();
    super.initState();
  }

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

  Future<void> _startCameraStream() async {
    final request = await Permission.camera.request();
    if (request.isGranted) {
      await BodyDetection.startCameraStream(
        onFrameAvailable: _handleCameraImage,
        onPoseAvailable: (pose) {
          _handlePose(pose);
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

  Future<void> _toggleDetectPose() async {
    await BodyDetection.enablePoseDetection();

    setState(() {
      _detectedPose = null;
    });
  }

  void _resetState() {
    setState(() {
      _maskImage = null;
      _detectedPose = null;
      _imageSize = Size.zero;
    });
  }

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
                      debug: true,
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
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _cameraDetectionView),
    );
  }
}
