## Development Environment

Before starting development, please ensure your system has the following software installed:

- **Operating System**: macOS 14.6 or higher
- **Flutter**: Version 3.24.5 (install according to the [official guide](https://docs.flutter.cn/get-started/install))
- **XCode**: 15.4
- **Android Studio**: Koala | 2024.1.1 Patch 1
- **Git**: For code version control

## Runtime Environment

This application supports the following operating system versions:

| Operating System | Version              | Status |
| --------------- | ----------------- | ---- |
| **iOS**      | 13.0 and above         | ✅   |
| **Android**     | minSdkVersion 24 | ✅   |

### Notes

- **Flutter**: Ensure your version meets the requirements to avoid dependency issues.

## Quick Start

Follow these steps to set up your local development environment:

1. Pull the code

2. Install dependencies

```bash
  flutter clean 
  flutter pub get
```

3. Configure Server Address

  This application supports three environment configurations: development (dev), testing (test), and production (prod).

  #### Method 1: Configure Fixed Server Address (Recommended for Local Development)

  Edit the `openim_common/lib/src/config.dart` file:

  ```dart
  class Config {
    // Define host addresses for different environments
    static const String _devHost = "192.168.31.166";  // Local development environment
    static const String _testHost = "";                // Testing environment (leave empty to enable auto-routing)
    static const String _prodHost = "";                // Production environment (leave empty to enable auto-routing)

    // Set default environment
    static final String _currentEnv = const String.fromEnvironment('ENV', defaultValue: 'dev');
  }
  ```

  #### Server Address Rules

  When configured with an **IP address** (e.g., `192.168.31.166`), the system automatically generates:
  ```
  API URL:      http://192.168.31.166:10002
  WebSocket:    ws://192.168.31.166:10001
  Auth URL:     http://192.168.31.166:10008
  Chat Token:   http://192.168.31.166:10009
  ```

  When configured with a **domain** (e.g., `example.com`), the system automatically generates:
  ```
  API URL:      https://example.com/api
  WebSocket:    wss://example.com/msg_gateway
  Auth URL:     https://example.com/chat
  Chat Token:   https://example.com/chat
  ```

  #### Method 2: Auto-Routing (Recommended for Testing/Production Environments)

  If you leave the environment host address empty (like `_testHost` and `_prodHost` above), the application will automatically find the fastest server on startup.

  See `openim_common/lib/src/utils/api_auto_route.dart` for configuration details.

4. Run the iOS/Android application by executing `flutter run` in the terminal or using the IDE's launch menu.

5. Start development and testing! 🎉

## Audio/Video Calls

Supports one-to-one audio/video calls, and requires [server-side] deployment and configuration.

## Building 🚀

> This project allows building iOS and Android applications separately, but there are some differences in the build process.

   - iOS:
     ```bash
     flutter build ipa
     ```
   - Android:
     ```bash
     flutter build apk
     ```

  The build results will be located in the `build` directory.

## Feature List

### Notes

| Feature Module           | Feature Item                                                    | Status |
| ------------------ | --------------------------------------------------------- | ---- |
| **Account Features**       | Phone/Email Registration, Verification Code Login                            | ✅   |
|                    | View/Modify Personal Information                                         | ✅   |
|                    | Multi-language Settings                                                | ✅   |
|                    | Change Password/Forgot Password                                         | ✅   |
| **Friend Features**       | Find/Request/Search/Add/Delete Friends                              | ✅   |
|                    | Accept/Reject Friend Requests                                         | ✅   |
|                    | Friend Remarks                                                  | ✅   |
|                    | Allow/Disallow Adding Friends                                          | ✅   |
|                    | Friend List/Real-time Friend Profile Sync                                 | ✅   |
| **Blacklist Features**     | Message Restrictions                                                  | ✅   |
|                    | Real-time Blacklist Sync                                        | ✅   |
|                    | Add/Remove from Blacklist                                           | ✅   |
| **Group Features**       | Create/Dismiss Groups                                             | ✅   |
|                    | Request to Join/Invite to Join/Leave Group/Remove Group Members                     | ✅   |
|                    | Group Name/Avatar Changes/Group Profile Change Notifications and Real-time Sync                  | ✅   |
|                    | Group Member Invitations                                            | ✅   |
|                    | Group Owner Transfer                                                  | ✅   |
|                    | Group Owner/Admin Approval of Join Requests                                  | ✅   |
|                    | Search Group Members                                                | ✅   |
| **Message Features**       | Offline Messages                                                  | ✅   |
|                    | Roaming Messages                                                  | ✅   |
|                    | Multi-device Messages                                                  | ✅   |
|                    | Message History                                                  | ✅   |
|                    | Message Deletion                                                  | ✅   |
|                    | Message Clear                                                  | ✅   |
|                    | Message Copy                                                  | ✅   |
|                    | Single Chat Typing Status                                              | ✅   |
|                    | New Message Do Not Disturb                                                | ✅   |
|                    | Clear Chat History                                              | ✅   |
|                    | New Members View Group Chat History                                    | ✅   |
|                    | New Message Notifications                                                | ✅   |
|                    | Text Messages                                                  | ✅   |
|                    | Image Messages                                                  | ✅   |
|                    | Video Messages                                                  | ✅   |
|                    | Emoji Messages                                                  | ✅   |
|                    | File Messages                                                  | ✅   |
|                    | Voice Messages                                                  | ✅   |
|                    | Business Card Messages                                                  | ✅   |
|                    | Location Messages                                              | ✅   |
|                    | Custom Messages                                                | ✅   |
| **Conversation Features**       | Pin Conversations                                                  | ✅   |
|                    | Conversation Read Status                                                  | ✅   |
|                    | Conversation Do Not Disturb                                                | ✅   |
| **REST API**       | Authentication Management                                                  | ✅   |
|                    | User Management                                                  | ✅   |
|                    | Relationship Chain Management                                                | ✅   |
|                    | Group Management                                                  | ✅   |
|                    | Conversation Management                                                  | ✅   |
|                    | Message Management                                                  | ✅   |
| **Webhook**        | Group Callbacks                                                  | ✅   |
|                    | Message Callbacks                                                  | ✅   |
|                    | Push Callbacks                                                  | ✅   |
|                    | Relationship Chain Callbacks                                                | ✅   |
|                    | User Callbacks                                                  | ✅   |
| **Capacity and Performance**     | 10,000 Friends                                                  | ✅   |
|                    | 100,000 Member Groups                                               | ✅   |
|                    | Second-level Sync                                                  | ✅   |
|                    | Cluster Deployment                                                  | ✅   |
|                    | Mutual Kick Policy                                                  |      |
| **Online Status**       | No Mutual Kicking Across All Platforms                                            | ✅   |
|                    | One Device Per Platform                                | ✅   |
|                    | One Device Each for PC, Mobile, Pad, Web, and Mini Program | ✅   |
|                    | PC Not Kicked, One Device Total for Other Platforms                         | ✅   |
| **Audio/Video Calls**     | One-to-One Audio/Video Calls                                          | ✅   |
| **File Object Storage** | Supports Private Minio Deployment                                      | ✅   |
|                    | Supports COS, OSS, Kodo, S3 Public Cloud                            | ✅   |
| **Push Notifications**           | Real-time Online Message Push                                          | ✅   |
|                    | Offline Message Push, Supports Getui, Firebase                          | ✅   |

## Common Issues

##### 1. Does it support multiple languages?
Answer: Yes, it follows the system language by default.

##### 2. Which platforms are supported?
Answer: Currently, the Demo supports Android and iOS.

##### 3. Android debug version runs but release version shows white screen?
Answer: Flutter's release package is obfuscated by default. You can use the following command:

```bash
  flutter build release --no-shrink
```

If this command doesn't work, add the following code to the release configuration in android/app/build.gradle:

```bash
  release {
      minifyEnabled false
      useProguard false
      shrinkResources false
  }
```

##### 4. What if code obfuscation is required?
Answer: Add the following configuration to the obfuscation rules:

```bash
  -keep class io.FREECHAT.**{*;}
  -keep class open_im_sdk.**{*;}
  -keep class open_im_sdk_callback.**{*;}
```

##### 5. Android package cannot be installed on emulator?
Answer: Since the Demo has removed some CPU architectures, if you need to run on an emulator, add the following to android/build.gradle:

```bash
  ndk {
      abiFilters "armeabi-v7a",  "x86"
  }
```

##### 6. iOS run/build release package error?
Answer: Set CPU architecture to arm64, then follow these steps:

```bash
  Execute flutter clean
  Execute flutter pub get
  cd ios/
  rm -f Podfile.lock
  rm -rf Pods
  Execute pod install
  Connect to a real device and run Archive.
```

##### 7. What is the minimum iOS version?

Answer: 13.0

##### 8. Why can't the map be used?

Answer: [Documentation](CONFIGKEY.md)

##### 9. Why can't offline push be used?

Answer: [Documentation](CONFIGKEY.md)

## Development Commands

# View available emulators
flutter emulators

# Launch Android emulator
flutter emulators --launch Medium_Phone_API_35

flutter run

flutter build apk      

# iOS

# List available simulators
xcrun simctl list devices

# Open simulator directly from Xcode
open -a Simulator

# Launch using iPhone 15 device ID
xcrun simctl boot B9686AFC-C95D-43FE-978B-B06217A73F8A

# Run on specific iOS device
flutter run -d B9686AFC-C95D-43FE-978B-B06217A73F8A

flutter run -d iphone

Press r: Hot Reload, maintain app state
Press R: Hot Restart, reset app state
Press h: Show all available commands

# View all available devices
flutter devices

# Clean project
flutter clean

# Get dependencies
flutter pub get

# After modifying the logo, run specific command to generate new icon files
flutter pub get && flutter pub run flutter_launcher_icons

## Environment Switching

### Running Different Environments

The application supports specifying the runtime environment using the `--dart-define=ENV` parameter:

```bash
# Development environment (uses fixed server address, skips auto-routing)
flutter run --dart-define=ENV=dev

# Test environment (executes auto-routing if config is empty)
flutter run --dart-define=ENV=test

# Production environment (executes auto-routing if config is empty)
flutter run --dart-define=ENV=prod
```

### Building Release Versions for Different Environments

```bash
# Build development environment APK
flutter build apk --dart-define=ENV=dev

# Build test environment APK
flutter build apk --dart-define=ENV=test

# Build production environment APK
flutter build apk --dart-define=ENV=prod

# Build iOS release version
flutter build ipa --dart-define=ENV=prod
```

### Environment Configuration Explanation

- **dev (Development)**: Directly uses the fixed address configured in `_devHost`, skips auto-routing, fast startup
- **test (Testing)**: If `_testHost` is empty, executes auto-routing to select the fastest server
- **prod (Production)**: If `_prodHost` is empty, executes auto-routing to select the fastest server

### Default Environment Setting

Modify the default environment in `openim_common/lib/src/config.dart`:

```dart
// Default to development environment
static final String _currentEnv = const String.fromEnvironment('ENV', defaultValue: 'dev');

// If --dart-define=ENV parameter is not specified, the application will use this default environment
```

# Compile latest Flutter code to ios directory
flutter build ios --release