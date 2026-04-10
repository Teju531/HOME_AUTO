# IoT Home Automation Project Report

## 1. Project Summary

This project is a Flutter-based smart home application for managing home members, channels, devices, and scenes from a mobile app. The current codebase is no longer just a static UI prototype. It now includes real Firebase authentication, Firestore-backed data storage, QR-based onboarding, BLE-based device provisioning and local control, MQTT-based remote control, scene automation, multi-home support, and per-user access permissions.

In short, the project has evolved from a frontend app into a working full-stack mobile control system for an IoT home automation setup.

## 2. Main Goal of the Project

The purpose of the application is to allow a user to:

- create or join a smart home
- add hardware channels/modules to that home
- configure those channels over Bluetooth
- control connected devices locally or remotely
- organize devices into scenes
- automate scenes with timers and schedules
- invite other users and control what they are allowed to access

## 3. What Has Been Completed

### 3.1 Application Foundation

The app has been structured as a Flutter application with:

- centralized route-based navigation
- portrait-only layout enforcement
- reusable UI constants and widgets
- a singleton state/store model for app-wide data handling

Core app startup also initializes Firebase and uses an auth wrapper to decide whether the user should go to onboarding, home setup, or the main dashboard.

## 3.2 Onboarding and Authentication

The project includes a complete user entry flow:

- onboarding carousel introducing connect, control, and save concepts
- email/password login
- email/password signup
- Google Sign-In
- forgot-password email reset
- create-new-password UI flow

This means the app already supports both first-time onboarding and returning-user authentication.

## 3.3 Home Creation and Home Joining

The app supports both creating and joining homes.

Implemented flows include:

- create a new home with a display name
- join an existing home by home ID
- join by scanning an invite QR code
- join by entering an invite code manually
- automatic loading of the user's homes from Firestore
- switching between multiple homes
- leaving a home
- deleting a home as owner

The multi-home design is an important step because it means the app is already structured for users who belong to more than one household/setup.

## 3.4 Member Management and Home Sharing

The Users feature is one of the stronger parts of the current project.

It supports:

- loading members from Firestore
- real-time home member updates
- invite token generation
- rendering invite QR codes for family members
- one-use invite code flow with 24-hour expiry
- removing members from a home
- leaving a home as a normal member
- deleting the home as owner

This gives the project real household-sharing behavior rather than single-user-only control.

## 3.5 User Permissions

The app includes a permission system for shared-home access.

Implemented permission features:

- owner gets full access
- non-owner permissions can be loaded from Firestore
- permission filtering is applied when displaying channels/devices
- device-level permissions are stored as `channelName|||deviceIndex`
- permissions can be saved per member
- a dedicated user-permissions screen allows enabling/disabling access by channel and device

This is an important backend feature because it turns the app into a role-aware control system instead of a simple shared dashboard.

## 3.6 Channel Onboarding and Device Provisioning

The project includes a real channel provisioning flow.

What is already implemented:

- QR scanner screen using camera access
- extraction of MAC addresses from scanned QR values
- ownership validation of a device before onboarding
- Bluetooth enable/scan/connect flow using `flutter_blue_plus`
- discovery of a writable BLE characteristic
- Wi-Fi credential entry screen
- BLE transfer of Wi-Fi + MQTT configuration to the IoT module
- transition into a connection progress flow
- auto-creation of the channel in app state after provisioning

The configuration packet being sent to the hardware includes:

- Wi-Fi SSID
- Wi-Fi password
- MQTT host
- MQTT port
- MQTT user/home topic ID
- MQTT command/state/telemetry/ack topic paths

This means the app is already designed not only to control devices, but also to configure them for network connectivity.

## 3.7 Device and Channel Management

The app supports management of both channels and devices.

### Channel features completed

- add channel
- show channels on the home screen and channel list screen
- toggle full channel ON/OFF
- rename channel
- delete channel
- clear all devices from a channel

### Device features completed

- add device to a selected channel
- select device icon while adding
- assign devices to plugs
- enforce duplicate-name checks on the same plug
- enforce a max-2-devices-per-plug rule
- rename a device
- delete a device
- display devices per channel and across the whole home
- toggle device ON/OFF from multiple screens

This is a strong CRUD implementation for the device layer of the system.

## 3.8 Live Device Control

The project supports two control modes:

- BLE for local instant control
- MQTT for remote/cloud control

The runtime logic is designed so that:

- BLE is attempted first when connected
- MQTT is used as fallback when BLE is unavailable
- UI state is updated optimistically
- failed sends revert the UI state
- updated device/channel states are persisted to Firestore

This hybrid approach is a valuable design decision because it supports both local responsiveness and remote operation.

## 3.9 MQTT Communication

The app includes an MQTT service layer with:

- broker connection and reconnection logic
- command publishing for full channel state
- command publishing for individual device state
- inbound message handling
- support for telemetry and ack payload tracking
- command string generation such as `*1000#`

The codebase also contains MQTT inbound parsing in the app store so that device or channel state pushed back from the IoT module can update app state and Firestore.

This indicates that two-way communication has been actively implemented, not just one-way command sending.

## 3.10 BLE Control

A dedicated BLE control service is already present.

It handles:

- connecting to an IoT module
- finding the relevant BLE characteristic
- sending per-plug commands
- sending full-channel commands
- tracking connection status
- disconnect cleanup

The home dashboard also includes a BLE connection status banner so the user can understand whether the app is in local Bluetooth mode or remote Wi-Fi/MQTT mode.

## 3.11 Scenes and Automation

Scene management is one of the most advanced parts of the app.

Completed scene features include:

- create scene
- edit existing scene
- assign selected devices to a scene
- manually toggle a scene
- timer-based auto-off scenes
- schedule-based scenes
- day-of-week selection for schedules
- automatic periodic schedule checking
- countdown display for active timer scenes
- Firestore persistence of scenes and scene state

When a scene runs, the app resolves which devices belong to it and applies target ON/OFF states across those devices.

This gives the project real automation capability instead of only manual switching.

## 3.12 Profile and Account Management

The My Account area already supports:

- viewing account email
- editing display name
- changing password with reauthentication
- selecting a profile image from gallery
- storing profile image path locally using shared preferences
- leaving the current home
- logging out safely

This adds a personal-account layer beyond pure device control.

## 3.13 Data Persistence and Backend Integration

The Firestore layer is extensive and already handles:

- homes collection
- members
- invite tokens
- permissions
- registered devices
- channels
- nested devices within channels
- scenes
- user profile metadata

The backend logic also supports:

- deleting a home and cleaning related subcollections
- maintaining `homeId` and `homeIds`
- loading all home memberships
- member display name fallback handling
- device ownership lookup using collection group queries

This is a meaningful backend implementation, not just a placeholder integration.

## 4. Technical Architecture

### 4.1 Frontend Stack

- Flutter
- Dart
- Material UI

### 4.2 Key Packages in Use

- `firebase_core`
- `firebase_auth`
- `google_sign_in`
- `cloud_firestore`
- `flutter_blue_plus`
- `mqtt_client`
- `mobile_scanner`
- `permission_handler`
- `qr_flutter`
- `image_picker`
- `shared_preferences`

### 4.3 State Management Pattern

The app uses a singleton `AppStore` model backed by `ValueNotifier`s rather than Provider, Bloc, or Riverpod.

This store is responsible for:

- channel state
- scene state
- member state
- profile photo state
- BLE connection state
- telemetry and ack state
- loading data from Firestore
- dispatching BLE/MQTT control operations

That makes `AppStore` the main business-logic hub of the application.

## 5. End-to-End User Flow Already Supported

The following end-to-end workflow is now possible in the project:

1. User opens app and completes onboarding.
2. User signs up or logs in.
3. User creates a new home or joins one by ID/invite QR.
4. User scans a device QR code.
5. App extracts the module MAC address.
6. App checks whether the module already belongs to another home.
7. App scans and connects to the module over BLE.
8. User enters Wi-Fi credentials.
9. App sends Wi-Fi and MQTT settings to the device.
10. App registers the channel and stores it in Firestore.
11. User adds electronic devices under that channel.
12. User controls those devices locally with BLE or remotely through MQTT.
13. User creates scenes to automate selected devices.
14. User invites family members and assigns them access permissions.

That is a strong complete workflow for a student/project-level home automation system.

## 6. Evidence From Git History

Recent commit history shows the project moving through clear development phases:

- `2026-02-12` `f726ca0` - iot automation application
- `2026-02-13` `c5934f8` - app updated upto signup and login page
- `2026-03-05` `553ad06` - application updated and its is ready for backend setup
- `2026-03-26` `7ddab23` - the tow way communication has been done
- `2026-03-31` `ba45ebc` - backend completed
- `2026-04-07` `20f6c74` - after final edit

From the repository state and commit messages, the project appears to have progressed through:

- initial app setup
- onboarding and auth UI
- backend preparation
- two-way device communication
- backend completion
- final integration edits

## 7. Current Project Strengths

The strongest completed parts of the project are:

- complete Flutter screen flow across major app modules
- real Firebase Auth integration
- Firestore data modeling across homes/channels/devices/scenes/members
- practical BLE-based provisioning flow
- remote/local dual control model
- scene timer and schedule logic
- multi-home support
- permission-based member access

These are all major project deliverables for a home automation app.

## 8. Areas That Still Need Polishing

The project is strong, but a few parts still look like they need refinement before calling it fully production-ready:

- README still describes the app mostly as a UI project, while the codebase now contains much more backend functionality.
- Test coverage is minimal. There is only a basic widget smoke test.
- Some screens and flows appear more polished than others, which suggests integration happened quickly near the end.
- The permission "Clone" action currently shows UI but does not yet appear to perform a real clone operation.
- The connection-success/failure flow exists in the UI, but the current connecting screen auto-adds the channel after a delay rather than waiting for a verified success signal from hardware.

These do not reduce the amount of work completed, but they are useful to mention honestly in a final presentation or report.

## 9. Final Assessment

This home automation project has already implemented most of the core requirements of a modern smart-home mobile app:

- authentication
- home creation and joining
- hardware onboarding
- local and remote control
- scene automation
- member access control
- backend persistence

The codebase shows clear evidence that this project has moved beyond mock screens and into real system integration. It is best described as a functional Flutter IoT home automation application with Firebase, BLE, MQTT, automation, and shared-home management already in place.

## 10. Important Files in the Project

The main implementation is concentrated in these files:

- `lib/main.dart`
- `lib/models/app_store.dart`
- `lib/services/firestore_service.dart`
- `lib/services/mqtt_service.dart`
- `lib/services/ble_control_service.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/home_setup_screen.dart`
- `lib/screens/add_channel_qr_screen.dart`
- `lib/screens/add_channel_wifi_screen.dart`
- `lib/screens/manage_scene_screen.dart`
- `lib/screens/users_screen.dart`
- `lib/screens/user_permissions_screen.dart`
- `lib/screens/my_account_screen.dart`

## 11. Short Conclusion for Submission Use

This project successfully delivers a Flutter-based IoT home automation mobile application that supports smart home creation, device onboarding, BLE and MQTT communication, remote device control, scene automation, user invitation, and permission-based shared access using Firebase and Firestore.
