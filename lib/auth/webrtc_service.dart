import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _callId;

  WebRTCService(this._callId);

  final Map<String, dynamic> _iceServers = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "stun:stun1.l.google.com:19302"},
    ]
  };

  Future<void> initializePeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _firestore.collection("calls").doc(_callId).collection("candidates").add({
        "candidate": candidate.toMap(),
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print("New track: ${event.track.kind}");
    };
  }

  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _firestore.collection("calls").doc(_callId).set({
      "offer": offer.toMap(),
    });
  }

  Future<void> answerCall(Map<String, dynamic> offer) async {
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(
      offer["sdp"], offer["type"],
    ));

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection("calls").doc(_callId).update({
      "answer": answer.toMap(),
    });
  }

  void closeConnection() {
    _peerConnection?.close();
    _peerConnection = null;
  }
}