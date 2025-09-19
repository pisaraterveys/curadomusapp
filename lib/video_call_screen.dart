import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;

class VideoCallScreen extends StatefulWidget {
  final String room; // e.g. "curadomus_<uid>"
  final String userName; // display name
  final String? patientId; // ✅ stable patient ID (not just Firebase uid)
  final String? callDocId; // Firestore call doc

  const VideoCallScreen({
    super.key,
    required this.room,
    required this.userName,
    this.patientId,
    this.callDocId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  lk.Room? _room;
  bool _joining = true;
  bool _ended = false;
  String? _callDocId;
  lk.VideoTrack? _remoteVideoTrack;

  // Chart form controllers
  final _reasonCtrl = TextEditingController();
  final _backgroundCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _planCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _printIdToken();
    _startCallFlow();
  }

  Future<void> _printIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken();
      debugPrint("🔑 Firebase ID Token: $idToken");
    }
  }

  Future<Map<String, dynamic>> _fetchLiveKitToken() async {
    final url = Uri.parse(
      "https://us-central1-curadomusapp.cloudfunctions.net/createLiveKitToken",
    );

    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");
    final idToken = await user.getIdToken();

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $idToken",
      },
      body: jsonEncode({
        "room": widget.room,
        "identity": user.uid,
        "name": widget.userName,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to get token: ${response.body}");
    }
  }

  Future<void> _startCallFlow() async {
    try {
      _callDocId = widget.callDocId;

      final data = await _fetchLiveKitToken();
      final token = data['token'] as String;
      final url = data['url'] as String;

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      room.events.listen((event) {
        debugPrint("📡 [VIDEO EVENT] $event");
        if (event is lk.TrackSubscribedEvent &&
            event.track is lk.VideoTrack) {
          setState(() => _remoteVideoTrack = event.track as lk.VideoTrack);
        }
        if (event is lk.TrackUnsubscribedEvent &&
            event.track is lk.VideoTrack) {
          setState(() => _remoteVideoTrack = null);
        }
      });

      await room.connect(url, token);
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _room = room;
        _joining = false;
      });
    } catch (e) {
      setState(() => _joining = false);
      debugPrint("❌ Video error: $e");
    }
  }

  Future<void> _endCall() async {
    if (_ended) return;
    _ended = true;

    try {
      await _room?.disconnect();
      _room?.dispose();
    } catch (_) {}

    if (_callDocId != null) {
      await _db.collection('calls').doc(_callDocId!).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _saveVisit() async {
    final provider = _auth.currentUser;
    if (provider == null || widget.patientId == null) return;

    await _db.collection("visits").add({
      "patientId": widget.patientId, // ✅ stable patient id
      "providerId": provider.uid,
      "providerName": widget.userName,
      "reason": _reasonCtrl.text.trim(),
      "background": _backgroundCtrl.text.trim(),
      "status": _statusCtrl.text.trim(),
      "plan": _planCtrl.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Visit saved")),
    );

    _reasonCtrl.clear();
    _backgroundCtrl.clear();
    _statusCtrl.clear();
    _planCtrl.clear();
  }

  @override
  void dispose() {
    _endCall();
    super.dispose();
  }

  Widget _remoteVideo() {
    if (_remoteVideoTrack == null) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAFA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text("Waiting for provider…"),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: lk.VideoTrackRenderer(_remoteVideoTrack!),
    );
  }

  Widget _localVideo() {
    if (_room?.localParticipant == null) return const SizedBox();

    for (var pub in _room!.localParticipant!.videoTrackPublications) {
      final track = pub.track;
      if (track != null && track is lk.VideoTrack) {
        return Positioned(
          right: 16,
          bottom: 16,
          width: 120,
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: lk.VideoTrackRenderer(
              track,
              mirrorMode: lk.VideoViewMirrorMode.mirror,
            ),
          ),
        );
      }
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final maxW =
        MediaQuery.of(context).size.width > 720 ? 720.0 : double.infinity;

    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Video Consultation",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: _endCall,
            ),
          ],
        ),
        body: Row(
          children: [
            // Video area
            Expanded(
              flex: 3,
              child: Center(
                child: _joining
                    ? const CircularProgressIndicator()
                    : Stack(
                        children: [
                          Positioned.fill(child: _remoteVideo()),
                          _localVideo(),
                        ],
                      ),
              ),
            ),

            // Chart sidebar
            Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.black12)),
                color: Colors.white,
              ),
              child: ListView(
                children: [
                  Text("🧑‍⚕️ Visit Chart",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(labelText: "Reason"),
                  ),
                  TextField(
                    controller: _backgroundCtrl,
                    decoration: const InputDecoration(labelText: "Background"),
                  ),
                  TextField(
                    controller: _statusCtrl,
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                  TextField(
                    controller: _planCtrl,
                    decoration: const InputDecoration(labelText: "Plan"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF89bcbe),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saveVisit,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Visit"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
