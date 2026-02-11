import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import '../models/stream_settings.dart';

class ScreenShareService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  WebSocket? _clientSocket;
  HttpServer? _signalServer;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  final ValueNotifier<String> status = ValueNotifier<String>('Idle');
  final ValueNotifier<String?> localUrl = ValueNotifier<String?>(null);

  Future<void> initialize() async {
    await localRenderer.initialize();
    await FlutterVolumeController.setVolume(1.0, showSystemUI: false);
  }

  Future<void> start(StreamSettings settings) async {
    status.value = 'Preparing capture...';

    await _disposeConnectionOnly();

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': {
        'frameRate': 60,
        'width': settings.scaledWidth,
        'height': settings.scaledHeight,
        'aspectRatio': settings.aspectPreset.ratio,
        'resizeMode': 'crop-and-scale',
        'mandatory': {
          'minWidth': settings.scaledWidth,
          'minHeight': settings.scaledHeight,
          'maxFrameRate': 60,
        },
      },
    };

    _localStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    _peerConnection = await createPeerConnection({
      'sdpSemantics': 'unified-plan',
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    for (final track in _localStream!.getTracks()) {
      final sender = await _peerConnection!.addTrack(track, _localStream!);
      if (track.kind == 'video') {
        final parameters = await sender.getParameters();
        final encodings = parameters.encodings;
        if (encodings.isNotEmpty) {
          encodings[0].maxBitrate = settings.bitrateKbps * 1000;
          encodings[0].maxFramerate = 60;
          encodings[0].scaleResolutionDownBy = (100 / settings.resolutionPercent);
          parameters.encodings = encodings;
          await sender.setParameters(parameters);
        }
      }
    }

    await _startSignalingServer();
    await _setVolume(settings.audioVolume);

    status.value = 'Waiting for viewer on local network... Crop: ${settings.crop}';
  }

  Future<void> _startSignalingServer() async {
    _signalServer?.close(force: true);
    _signalServer = await HttpServer.bind(InternetAddress.anyIPv4, 8920);

    unawaited(() async {
      await for (final request in _signalServer!) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _clientSocket = socket;
          status.value = 'Viewer connected. Negotiating...';
          await _bindSocket(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('WebSocket endpoint only')
            ..close();
        }
      }
    }());

    localUrl.value = 'ws://${await _localIp()}:8920';
  }

  Future<void> _bindSocket(WebSocket socket) async {
    final offer = await _peerConnection!.createOffer({'offerToReceiveAudio': 0, 'offerToReceiveVideo': 0});
    await _peerConnection!.setLocalDescription(offer);
    socket.add(jsonEncode({'type': 'offer', 'sdp': offer.sdp}));

    socket.listen((message) async {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'answer') {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'] as String, type),
        );
        status.value = 'Streaming live';
      }
      if (type == 'candidate') {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'] as String,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          ),
        );
      }
    }, onDone: () {
      status.value = 'Viewer disconnected';
      _clientSocket = null;
    }, onError: (_) {
      status.value = 'Signaling error';
      _clientSocket = null;
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (_clientSocket == null) {
        return;
      }
      _clientSocket!.add(jsonEncode({
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };
  }

  Future<void> _setVolume(double volume) async {
    await FlutterVolumeController.setVolume(volume.clamp(0, 1), showSystemUI: false);
  }

  Future<String> _localIp() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<void> stop() async {
    await _disposeConnectionOnly();
    await _clientSocket?.close();
    await _signalServer?.close(force: true);
    _clientSocket = null;
    _signalServer = null;
    localUrl.value = null;
    status.value = 'Stopped';
  }

  Future<void> _disposeConnectionOnly() async {
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    await _peerConnection?.close();
    _peerConnection = null;
    localRenderer.srcObject = null;
  }

  Future<void> dispose() async {
    await stop();
    await localRenderer.dispose();
    status.dispose();
    localUrl.dispose();
  }
}
