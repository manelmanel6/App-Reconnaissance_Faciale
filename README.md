# Face Recognition Login App

A Flutter application that implements facial recognition for user authentication using Firebase and ML Kit.

## Features

- User registration with email, password, and facial recognition
- Login with email/password or facial recognition
- Face recognition testing
- Profile management with updatable face image
- Sound feedback for successful/failed operations

## Setup

1. Install Flutter and set up your development environment
2. Create a Firebase project and add your Android/iOS apps
3. Download the `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS) files
4. Place these files in their respective platform folders:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
5. Add sound files for success and failure feedback:
   - Place `success.mp3` in `assets/sounds/`
   - Place `failure.mp3` in `assets/sounds/`

## Dependencies

The app uses the following packages:
- firebase_core
- firebase_auth
- cloud_firestore
- google_mlkit_face_detection
- flutter_face_api
- camera
- image_picker
- path_provider
- audioplayers
- permission_handler
- provider
- shared_preferences

## Running the App

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Usage

1. Register a new account:
   - Enter email and password
   - Take a photo for facial recognition
   - Submit registration

2. Login:
   - Choose between email/password or facial recognition
   - If using facial recognition, align your face with the camera

3. Home Screen:
   - Test facial recognition
   - Update your face image
   - View recognition results with sound feedback

## Notes

- Ensure good lighting conditions for optimal face recognition
- Keep your face centered and still during photo capture
- The app requires camera permissions to function properly
