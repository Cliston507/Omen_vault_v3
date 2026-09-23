# Blueprint: Omen Vault V3

## Overview

Omen Vault V3 is a Flutter application designed for robust analytics tracking, secure user authentication, and data persistence, all while providing a polished user experience. This document outlines the project's architecture, design principles, and feature implementation details.

## Style, Design, and Features (Version 1.2)

### Architecture
*   **State Management:** The application uses `provider` for managing theme and authentication state.
*   **Theming:** A centralized theme system is implemented using Material 3 principles (`ColorScheme.fromSeed`) and `google_fonts` for typography.
*   **Structure:** The UI is separated into logical feature screens. Authentication flow is managed by a dedicated wrapper widget.
*   **Services:** Dedicated services for Authentication (`AuthService`) and Database (`DatabaseService`) will be implemented to separate business logic from the UI.
*   **Local Database:** An encrypted SQLCipher singleton using `sqflite` and `flutter_secure_storage` for master key management.

### Visual Design
*   **Color Scheme:** A dynamic color scheme is generated from a primary seed color (`Colors.deepPurple`).
*   **Typography:** The `google_fonts` package provides the `Oswald` font for bold headlines and `Roboto` for body text.
*   **Layout:** The UI features clean, modern layouts with components like `Card` and `ElevatedButton`.
*   **Interactivity:** The app includes a theme toggle and user authentication flow.

### Features
*   **Firebase Analytics:** The core feature is a screen that allows users to trigger and log a custom `video_recording_test` event to Firebase Analytics.
*   **Theme Toggle:** Users can switch between light and dark themes.
*   **Firebase Authentication:**
    *   Users can sign in with Email/Password or anonymously.
    *   An authentication wrapper manages the user session, directing users to the appropriate screen.
*   **Cloud Firestore:**
    *   User data will be stored securely in a Firestore database.
    *   A profile screen will display user information retrieved from Firestore.
*   **Encrypted Local Storage:**
    *   A `mutation_queue` table is initialized in the local encrypted database to store pending data mutations.

## Current Plan: Encrypted Local Database

The following steps were performed to set up the encrypted local database:

1.  **Create `develop-v3` Branch:** A new branch `develop-v3` was created to isolate the new feature development.
2.  **Add Dependencies:** Added `sqflite` and `flutter_secure_storage` to the `pubspec.yaml` file.
3.  **Create Database Helper:** Created `lib/helpers/db_helper.dart` with an encrypted SQLCipher singleton.
4.  **Initialize `mutation_queue` Table:** The `mutation_queue` table is created on the first launch of the database.
