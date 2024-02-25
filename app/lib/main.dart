// ignore_for_file: avoid_print

import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_router.dart';
import 'call_service.dart';
import 'navigation_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print(
      "----- バックグラウンドプッシュ通知受信 ----- ${message.data['type']} : ${message.messageId}");
  await Firebase.initializeApp();
  // プッシュ通知の種別がcallの場合は着信画面を表示
  if (message.data['type'] == 'call') {
    _callKitInComingHandler(message.data);
  }
}

void _callKitInComingHandler(Map<String, dynamic> data) {
  final callId = data['callId']!;
  CallService.instance.setCurrentCallId(callId: callId);
  CallService.instance.showCallkitIncoming(data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print('LIVEKIT_URL: ${dotenv.env['LIVEKIT_URL']}');
  print('CLOUD_FUNCTIONS_URL: ${dotenv.env['CLOUD_FUNCTIONS_URL']}');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    initFirebase();
    WidgetsBinding.instance.addObserver(this);

    checkAndNavigationCallingPage();
    getDevicePushTokenVoIP();
    final userId = Random().nextInt(10).toString();
    CallService.instance.init(userId: userId);
  }

  Future<void> checkAndNavigationCallingPage() async {
    var currentCall = await CallService.instance.getCurrentCall();
    if (currentCall != null) {
      // TODO(take): 着信がある場合は着信画面に遷移
      // NavigationService.instance
      //     .pushNamedIfNotCurrent(AppRoute.callingPage, args: currentCall);
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    print(state);
    if (state == AppLifecycleState.resumed) {
      // Check call when open app from background
      checkAndNavigationCallingPage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    final firebaseMessaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        print(
            "----- FirebaseMessaging.onMessage.listen ----- ${message.data['type']} : ${message.messageId}");

        if (message.data['type'] == 'call') {
          _callKitInComingHandler(message.data);
        }
      },
    );

    var setting = await firebaseMessaging.getNotificationSettings();
    var permission = setting.authorizationStatus;
    if (permission == AuthorizationStatus.notDetermined ||
        permission == AuthorizationStatus.denied) {
      await firebaseMessaging.requestPermission();
      setting = await firebaseMessaging.getNotificationSettings();
      permission = setting.authorizationStatus;
    }

    firebaseMessaging.getToken().then(
      (token) {
        print('FCM Token: $token');
      },
    );
  }

  Future<void> getDevicePushTokenVoIP() async {
    // VoIP取得(iOSのみ)
    final devicePushTokenVoIP =
        await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    print('PushTokenVoIP: $devicePushTokenVoIP');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      onGenerateRoute: AppRoute.generateRoute,
      initialRoute: AppRoute.homePage,
      navigatorKey: NavigationService.instance.navigationKey,
      navigatorObservers: <NavigatorObserver>[
        NavigationService.instance.routeObserver
      ],
    );
  }
}
