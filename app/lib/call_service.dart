// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';

import 'method_channels/replay_kit_channel.dart';

class CallService {
  static final CallService _instance = CallService._private();
  factory CallService() {
    return _instance;
  }
  CallService._private();

  static CallService get instance => _instance;

  String _currentCallId = '';
  String _userId = '';

  final String _appName = 'LiveKitSample';

  // LiveKit
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  LocalAudioTrack? _audioTrack;

  void init({required String userId}) {
    _currentCallId = '';
    _userId = userId;
  }

  void createCallId() {
    const uuid = Uuid();
    setCurrentCallId(callId: uuid.v4());
  }

  void setCurrentCallId({required String callId}) {
    _currentCallId = callId;
  }

  String getCurrentCallId() {
    return _currentCallId;
  }

  Future<bool> hasActiveCalls() async {
    final calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      return calls.isNotEmpty;
    }
    return false;
  }

  Future<dynamic> getCurrentCall() async {
    final calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        _currentCallId = calls[0]['id'];
        return calls[0];
      } else {
        _currentCallId = '';
        return null;
      }
    }
  }

  /// 着信
  Future<void> showCallkitIncoming(Map<String, dynamic> data) async {
    if (await hasActiveCalls()) {
      endAllCalls();
    }

    setCurrentCallId(callId: data['callId']);
    final params = CallKitParams(
      id: data['callId'],
      nameCaller: data['callerUserName'],
      appName: _appName,
      avatar: data['callerIconUrl'],
      handle: '0123456789', // Phone number/Email/Any.
      type: 0, // 0 - Audio Call, 1 - Video Call
      duration: 30000, // 着信表示時間(デフォ30秒)
      textAccept: '応答',
      textDecline: '拒否',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: '応答なしサブタイトル',
        callbackText: 'コールバックテキスト',
      ),
      extra: <String, dynamic>{
        // ここに任意のデータを格納できる
      },
      headers: <String, dynamic>{},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'assets/test.png',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        // audioSessionPreferredSampleRate: 44100.0,
        // audioSessionPreferredIOBufferDuration: 0.005,
        // supportsDTMF: true,
        // supportsHolding: true,
        // supportsGrouping: false,
        // supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    // 着信画面を表示
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// 発信
  Future<void> startCall() async {
    if (await hasActiveCalls()) {
      endAllCalls();
    }

    createCallId();
    final params = CallKitParams(
      id: _currentCallId,
      nameCaller: Platform.isAndroid ? 'ABC Inc.' : 'XYZ Inc.',
      appName: _appName,
      handle: '0123456789', // Phone number/Email/Any.
      type: 0, // 0 - Audio Call, 1 - Video Call
      duration: 30000,
      extra: <String, dynamic>{},
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: false,
      ),
    );

    // LiveKitのRoom作成
    await createRoom();

    // プッシュ通知送信
    await pushNotification();

    await FlutterCallkitIncoming.startCall(params);
    if (lkPlatformIs(PlatformType.iOS)) {
      await FlutterCallkitIncoming.setCallConnected(_currentCallId);
    }
  }

  /// 通話終了
  Future<void> endCall() async {
    await dissconnectRoom();
    await FlutterCallkitIncoming.endCall(_currentCallId);
  }

  /// 通話終了(全て)
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
    if (_room != null) {
      await dissconnectRoom();
      if (_currentCallId.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(_currentCallId);
      }
    }
  }

  void onListener(void Function(CallEvent) callback) {
    try {
      FlutterCallkitIncoming.onEvent.listen((event) async {
        switch (event!.event) {
          // 着信
          case Event.actionCallIncoming:
            print('FlutterCallkitIncoming.onEvent: ----- 着信 -----');
            break;
          // 通話開始
          case Event.actionCallStart:
            print('FlutterCallkitIncoming.onEvent: ----- 通話開始 -----');
            break;
          // 通話応答
          case Event.actionCallAccept:
            print('FlutterCallkitIncoming.onEvent: ----- 通話応答 -----');

            // LiveKitのRoom作成
            createRoom();
            break;
          // 通話拒否
          case Event.actionCallDecline:
            print('FlutterCallkitIncoming.onEvent: ----- 通話拒否 ----- ');
            await callDecline();
            break;
          // 通話終了
          case Event.actionCallEnded:
            print('FlutterCallkitIncoming.onEvent: ----- 通話終了 ----- ');
            break;
          // 通話タイムアウト
          case Event.actionCallTimeout:
            print('FlutterCallkitIncoming.onEvent: ----- 通話タイムアウト ----- ');
            break;
          case Event.actionCallCallback:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallCallback ----- ');
            // only Android - click action `Call back` from missed call notification
            break;
          case Event.actionCallToggleHold:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallToggleHold ----- ');
            // only iOS
            break;
          case Event.actionCallToggleMute:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallToggleMute ----- ');
            // only iOS
            break;
          case Event.actionCallToggleDmtf:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallToggleDmtf ----- ');
            // only iOS
            break;
          case Event.actionCallToggleGroup:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallToggleGroup ----- ');
            // only iOS
            break;
          case Event.actionCallToggleAudioSession:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallToggleAudioSession ----- ');
            // only iOS
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionDidUpdateDevicePushTokenVoip ----- ');
            // only iOS
            break;
          case Event.actionCallCustom:
            print(
                'FlutterCallkitIncoming.onEvent: ----- actionCallCustom ----- ');
            break;
        }

        callback(event);
      });
    } catch (e) {
      print('FlutterCallkitIncoming.onEvent: <error> $e');
    }
  }

  Future<void> createRoom() async {
    try {
      _room = Room();
      if (_listener != null) {
        _listener?.dispose();
      }
      _listener = _room?.createListener();
      onRoomEventLisner();

      // LiveKitのRoomOptions
      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      // LiveKitのトークン発行
      final response = await http.get(Uri.parse(
          '${dotenv.env['CLOUD_FUNCTIONS_URL']}/createToken?userId=$_userId&roomId=$_currentCallId'));
      final token = response.body.trim();
      _audioTrack ??= await LocalAudioTrack.create(
        const AudioCaptureOptions(),
      );

      await _room!.connect(
        '${dotenv.env['LIVEKIT_URL']}',
        token,
        roomOptions: roomOptions,
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(track: _audioTrack),
        ),
      );

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _room!.setSpeakerOn(true);

      Hardware.instance.setSpeakerphoneOn(true);
      if (lkPlatformIs(PlatformType.iOS)) {
        ReplayKitChannel.listenMethodChannel(_room!);
      }
      await _audioTrack!.start();
    } catch (e) {
      print('createRoom: <error> $e');
    }
  }

  Future<void> dissconnectRoom() async {
    if (_room == null) return;

    if (_audioTrack != null && _audioTrack!.isActive) {
      Hardware.instance.setSpeakerphoneOn(false);
      await _audioTrack!.stop();
      _audioTrack = null;
    }

    _room?.setSpeakerOn(false);
    await _room?.disconnect().then((value) {
      _listener?.dispose();
      _room = null;
    });
  }

  Future<void> callDecline() async {
    try {
      _room = Room();
      if (_listener != null) {
        _listener?.dispose();
      }
      _listener = _room?.createListener();
      onRoomEventLisner();

      // LiveKitのRoomOptions
      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      // LiveKitのトークン発行
      final response = await http.get(Uri.parse(
          '${dotenv.env['CLOUD_FUNCTIONS_URL']}/createToken?userId=$_userId&roomId=$_currentCallId'));
      final token = response.body.trim();
      _audioTrack ??= await LocalAudioTrack.create(
        const AudioCaptureOptions(),
      );

      await _room!.connect(
        '${dotenv.env['LIVEKIT_URL']}',
        token,
        roomOptions: roomOptions,
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(track: _audioTrack),
        ),
      );

      // await _room!.localParticipant?.setMicrophoneEnabled(false);
      // _room!.setSpeakerOn(false);

      Future.delayed(const Duration(milliseconds: 500), () async {
        await _room?.disconnect().then((value) {
          _listener?.dispose();
          _room = null;
          _audioTrack = null;
        });
      });
    } catch (e) {
      print('callDecline: <error> $e');
    }
  }

  void onRoomEventLisner() {
    try {
      _listener!.listen((event) {
        if (event is RoomConnectedEvent) {
          print("LiveKitListener.onEvent: ----- ルーム接続開始 -----");
        } else if (event is RoomDisconnectedEvent) {
          print(
              "LiveKitListener.onEvent: ----- ルーム接続終了 ----- : ${event.reason}");
          if (event.reason == DisconnectReason.disconnected) {
            // 誰か抜けたら終了
            // endCall();
          }
        } else if (event is ParticipantConnectedEvent) {
          print(
              "LiveKitListener.onEvent: ----- 誰か入ってきたイベント -----: ${event.participant.identity}");
        } else if (event is ParticipantDisconnectedEvent) {
          print(
              "LiveKitListener.onEvent: ----- 誰か抜けたイベント -----: ${event.participant.identity}");
          // 誰か抜けたら終了
          endCall();
        } else if (event is TrackSubscribedEvent) {
          print(
              'LiveKitListener.onEvent: ----- TrackSubscribedEvent ----- : $event');
        }
      });
    } catch (e) {
      print('LiveKitListener.onEvent: <error> $e');
    }
  }

  Future<void> pushNotification() async {
    final toIOS = Platform.isIOS ? 0 : 1;
    final q =
        '?callId=$_currentCallId&callerUserId=$_userId&isCall=1&toIOS=$toIOS';
    final url = '${dotenv.env['CLOUD_FUNCTIONS_URL']}/sendMessage$q';
    await http.get(Uri.parse(url));
  }
}
