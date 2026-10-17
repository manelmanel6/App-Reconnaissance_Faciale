import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/face_recognition_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Save face image to local storage
  Future<String> _saveFaceImage(File imageFile, String userId) async {
    try {
      print('Starting to save face image for user: $userId');
      final directory = await getApplicationDocumentsDirectory();
      
      // Create a permanent faces directory in app documents
      final String facesPath = '${directory.path}/permanent_faces';
      final Directory facesDir = Directory(facesPath);
      if (!await facesDir.exists()) {
        await facesDir.create(recursive: true);
      }

      // Use a consistent filename format for each user
      final String fileName = 'face_$userId${path.extension(imageFile.path)}';
      final String fullPath = '$facesPath/$fileName';
      
      print('Saving image to permanent location: $fullPath');
      
      // Delete existing file if it exists
      final File newFile = File(fullPath);
      if (await newFile.exists()) {
        await newFile.delete();
      }

      // Copy the image to the new location
      final File savedImage = await imageFile.copy(fullPath);
      
      // Verify the file was created
      if (!await savedImage.exists()) {
        throw Exception('Failed to save face image: File not created');
      }
      
      print('Face image saved successfully at: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('Error saving face image: $e');
      rethrow;
    }
  }

  // Delete face image from local storage
  Future<void> _deleteFaceImage(String imagePath) async {
    try {
      print('Attempting to delete face image at: $imagePath');
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print('Face image deleted successfully');
      } else {
        print('Face image not found for deletion');
      }
    } catch (e) {
      print('Error deleting face image: $e');
      // Don't rethrow as this is not critical
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required File faceImage,
  }) async {
    try {
      // Normalize the email (trim and lowercase)
      final normalizedEmail = email.trim().toLowerCase();
      print('Starting user registration for email: $normalizedEmail');
      
      // Verify the face image exists
      if (!await faceImage.exists()) {
        throw Exception('Face image file does not exist');
      }

      print('Creating user account with Firebase Auth');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      print('User account created, saving face image');
      // Save face image locally
      final imagePath = await _saveFaceImage(faceImage, userCredential.user!.uid);

      print('Storing user data in Firestore');
      // Store user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': normalizedEmail,
        'password': password,
        'faceImagePath': imagePath,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('User registration completed successfully');
      return userCredential;
    } catch (e) {
      print('Error during registration: $e');
      // Clean up any created resources if registration fails
      if (currentUser != null) {
        try {
          await currentUser!.delete();
          print('Cleaned up Firebase Auth user after registration failure');
        } catch (deleteError) {
          print('Error cleaning up user after registration failure: $deleteError');
        }
      }
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and face
  Future<UserCredential> signInWithEmailAndFace({
    required String email,
    required String currentImagePath,
  }) async {
    try {
      print('Starting face login for email: $email');
      print('Current image path: $currentImagePath');
      
      // Normalize the email (trim and lowercase)
      final normalizedEmail = email.trim().toLowerCase();
      print('Normalized email: $normalizedEmail');
      
      // First, get the user data from Firestore using email
      print('Querying Firestore for user data...');
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      print('Firestore query completed. Found ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isEmpty) {
        print('No user document found in Firestore');
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this email',
        );
      }

      final userDoc = querySnapshot.docs.first;
      final storedEmail = userDoc.get('email') as String?;
      final password = userDoc.get('password') as String?;
      final storedImagePath = userDoc.get('faceImagePath') as String?;

      print('Found user document with email: $storedEmail');

      if (password == null || storedImagePath == null) {
        print('Missing required data for face login');
        throw FirebaseAuthException(
          code: 'invalid-login',
          message: 'Unable to complete face login',
        );
      }

      // Verify the stored image exists
      final storedImage = File(storedImagePath);
      if (!await storedImage.exists()) {
        print('Stored face image not found');
        throw FirebaseAuthException(
          code: 'face-not-found',
          message: 'Face image not found. Please register again.',
        );
      }

      // Compare faces
      print('Starting face comparison...');
      final faceService = FaceRecognitionService();
      
      // First check if faces are detected in both images
      final hasCurrentFace = await faceService.detectFace(currentImagePath);
      final hasStoredFace = await faceService.detectFace(storedImagePath);

      if (!hasCurrentFace || !hasStoredFace) {
        faceService.dispose();
        print('No face detected in one or both images');
        throw FirebaseAuthException(
          code: 'face-not-detected',
          message: hasCurrentFace ? 'Error with stored face image' : 'No face detected in the current image',
        );
      }

      // Compare the faces
      final isMatch = await faceService.compareFaces(storedImagePath, currentImagePath);
      faceService.dispose();
      print('Face comparison result: $isMatch');

      if (!isMatch) {
        throw FirebaseAuthException(
          code: 'face-not-match',
          message: 'Face does not match the registered face',
        );
      }

      // If face matches, proceed with login
      print('Face matched, attempting Firebase Auth login...');
      final result = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      print('Firebase Auth login successful');
      return result;
    } catch (e) {
      print('Error during face login: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update user face image
  Future<void> updateUserFaceImage(File faceImage) async {
    if (currentUser != null) {
      try {
        print('Starting face image update for user: ${currentUser!.uid}');
        
        // Verify the new face image exists
        if (!await faceImage.exists()) {
          throw Exception('New face image file does not exist');
        }

        // Get the current face image path
        final userData = await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        final oldImagePath = userData.get('faceImagePath') as String?;

        // Save new face image
        final newImagePath = await _saveFaceImage(faceImage, currentUser!.uid);

        // Update Firestore with new path
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'faceImagePath': newImagePath,
        });

        // Delete old image if it exists
        if (oldImagePath != null) {
          await _deleteFaceImage(oldImagePath);
        }
        
        print('Face image update completed successfully');
      } catch (e) {
        print('Error updating face image: $e');
        rethrow;
      }
    }
  }

  // Get user face image path
  Future<String?> getUserFaceImage() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        final imagePath = doc.get('faceImagePath') as String?;
        print('Retrieved face image path: $imagePath');
        return imagePath;
      } catch (e) {
        print('Error getting user face image: $e');
        rethrow;
      }
    }
    return null;
  }

  // Get user name
  Future<String?> getUserName() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        return doc.get('name') as String?;
      } catch (e) {
        print('Error getting user name: $e');
        rethrow;
      }
    }
    return null;
  }

  // Update user name
  Future<void> updateUserName(String newName) async {
    if (currentUser != null) {
      try {
        print('Updating name for user: ${currentUser!.uid}');
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'name': newName,
        });
        print('Name updated successfully');
      } catch (e) {
        print('Error updating user name: $e');
        rethrow;
      }
    }
  }
} 