import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class FaceRecognitionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<bool> compareFaces(String storedImagePath, String currentImagePath) async {
    try {
      print('Comparing faces between:');
      print('Stored image: $storedImagePath');
      print('Current image: $currentImagePath');

      final storedFaces = await _detectFaces(storedImagePath);
      final currentFaces = await _detectFaces(currentImagePath);

      if (storedFaces.isEmpty || currentFaces.isEmpty) {
        print('No faces detected in one or both images');
        return false;
      }

      final storedFace = storedFaces.first;
      final currentFace = currentFaces.first;

      // Compare facial landmarks
      final landmarkMatch = _compareLandmarks(storedFace, currentFace);
      print('Landmark match score: $landmarkMatch');

      // Compare head rotation
      final rotationMatch = _compareRotation(storedFace, currentFace);
      print('Rotation match: $rotationMatch');

      // Compare face contours if available
      final contourMatch = await _compareContours(storedFace, currentFace);
      print('Contour match score: $contourMatch');

      // Calculate overall similarity score (weighted average)
      final double overallScore = (landmarkMatch * 0.5) + // 50% weight for landmarks
                                 (contourMatch * 0.3) + // 30% weight for contours
                                 (rotationMatch ? 0.2 : 0.0); // 20% weight for rotation

      print('Overall match score: $overallScore');

      // More lenient threshold (0.6 instead of 0.7)
      final bool isMatch = overallScore >= 0.6;

      print('Final match result: $isMatch');
      return isMatch;
    } catch (e) {
      print('Error comparing faces: $e');
      return false;
    }
  }

  bool _compareRotation(Face face1, Face face2) {
    const double threshold = 20.0; // More reasonable threshold
    
    final headEulerAngleX1 = face1.headEulerAngleX ?? 0;
    final headEulerAngleY1 = face1.headEulerAngleY ?? 0;
    final headEulerAngleZ1 = face1.headEulerAngleZ ?? 0;
    
    final headEulerAngleX2 = face2.headEulerAngleX ?? 0;
    final headEulerAngleY2 = face2.headEulerAngleY ?? 0;
    final headEulerAngleZ2 = face2.headEulerAngleZ ?? 0;

    return (headEulerAngleX1 - headEulerAngleX2).abs() <= threshold &&
           (headEulerAngleY1 - headEulerAngleY2).abs() <= threshold &&
           (headEulerAngleZ1 - headEulerAngleZ2).abs() <= threshold;
  }

  double _compareLandmarks(Face face1, Face face2) {
    var matchCount = 0;
    var totalPoints = 0;

    // Compare each landmark type
    for (final landmarkType in FaceLandmarkType.values) {
      final landmark1 = face1.landmarks[landmarkType];
      final landmark2 = face2.landmarks[landmarkType];

      if (landmark1 != null && landmark2 != null) {
        totalPoints++;
        // Calculate distance between corresponding points
        final distance = _calculatePointDistance(
          landmark1.position,
          landmark2.position,
        );
        // Consider it a match if points are within 10% of face width (was 8%)
        if (distance < (face1.boundingBox.width * 0.10)) {
          matchCount++;
        }
      }
    }

    return totalPoints > 0 ? matchCount / totalPoints : 0.0;
  }

  Future<double> _compareContours(Face face1, Face face2) async {
    var matchCount = 0;
    var totalPoints = 0;

    // Compare each contour type
    for (final contourType in FaceContourType.values) {
      final contour1 = face1.contours[contourType];
      final contour2 = face2.contours[contourType];

      if (contour1 != null && contour2 != null) {
        final points1 = contour1.points;
        final points2 = contour2.points;

        // Compare corresponding points in contours
        final minPoints = min(points1.length, points2.length);
        for (var i = 0; i < minPoints; i++) {
          totalPoints++;
          final distance = _calculatePointDistance(points1[i], points2[i]);
          // Consider it a match if points are within 6% of face width (was 4%)
          if (distance < (face1.boundingBox.width * 0.06)) {
            matchCount++;
          }
        }
      }
    }

    return totalPoints > 0 ? matchCount / totalPoints : 0.0;
  }

  double _calculatePointDistance(Point<int> p1, Point<int> p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    return sqrt(dx * dx + dy * dy);
  }

  Future<List<Face>> _detectFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await _faceDetector.processImage(inputImage);
  }

  Future<bool> detectFace(String imagePath) async {
    try {
      final faces = await _detectFaces(imagePath);
      return faces.isNotEmpty;
    } catch (e) {
      print('Error detecting face: $e');
      return false;
    }
  }

  Future<String> saveImage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy('${directory.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      print('Error saving image: $e');
      rethrow;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
} 