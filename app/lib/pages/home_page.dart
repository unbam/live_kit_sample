// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../call_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return HomePageState();
  }
}

class HomePageState extends State<HomePage> {
  String textEvents = "";

  @override
  void initState() {
    super.initState();
    if (lkPlatformIs(PlatformType.android)) {
      _checkPremissions();
    }

    textEvents = "";
    CallService.instance.onListener(onEvent);
  }

  Future<void> _checkPremissions() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      print('Microphone Permission disabled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiveKitSample'),
        backgroundColor: Colors.blue,
        actions: <Widget>[
          // 電話発信
          IconButton(
            icon: const Icon(
              Icons.call,
              color: Colors.white,
            ),
            onPressed: startOutGoingCall,
          ),
          // 電話終了
          IconButton(
            icon: const Icon(
              Icons.call_end,
              color: Colors.white,
            ),
            onPressed: endCurrentCall,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          if (textEvents.isNotEmpty) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: Text(textEvents),
              ),
            );
          } else {
            return const Center(
              child: Text('No Event'),
            );
          }
        },
      ),
    );
  }

  /// 電話発信
  Future<void> startOutGoingCall() async {
    await CallService.instance.startCall();
  }

  /// 電話終了
  Future<void> endCurrentCall() async {
    await CallService.instance.endCall();
  }

  void onEvent(CallEvent event) {
    if (!mounted) return;
    setState(() {
      textEvents += '${event.event.name}\n';
    });
  }
}
