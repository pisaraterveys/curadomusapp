import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ⬇️ IMPORTANT: ensure the path matches your project.
// If your file is in /lib/screens/, change this to: 'screens/professional_video_call_screen.dart'
import 'professional_video_call_screen.dart' as pro;

class CallQueueScreen extends StatefulWidget {
  const CallQueueScreen({super.key});

  @override
  State<CallQueueScreen> createState() => _CallQueueScreenState();
}

class _CallQueueScreenState extends State<CallQueueScreen> {
  final _db = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _userCache = {};

  String _calcAge(dynamic dobRaw) {
    if (dobRaw == null) return '';
    final s = dobRaw.toString().trim();
    if (s.isEmpty) return '';

    DateTime? birth;
    try {
      birth = DateFormat('dd.MM.yyyy').parseStrict(s);
    } catch (_) {}
    if (birth == null) {
      try {
        birth = DateFormat('yyyy-MM-dd').parseStrict(s);
      } catch (_) {}
    }
    if (birth == null && dobRaw is Timestamp) {
      birth = dobRaw.toDate();
    }
    if (birth == null) return '';

    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return '$age yrs';
  }

  String _joinList(dynamic v) {
    if (v is List) {
      final items = v
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (items.isEmpty) return '—';
      return items.join(', ');
    }
    return '—';
  }

  Future<Map<String, dynamic>> _loadUserData(
      String uid, Map<String, dynamic> call) async {
    if (_userCache.containsKey(uid)) return _userCache[uid]!;

    try {
      final snap = await _db.collection('users').doc(uid).get();
      final user = (snap.data() ?? <String, dynamic>{});

      final result = {
        'firstName': (call['firstName'] ?? user['firstName'] ?? '').toString(),
        'lastName': (call['lastName'] ?? user['lastName'] ?? '').toString(),
        'dob': call['dob'] ?? user['dob'],
        'diagnoses': _joinList(call['diagnoses'] ?? user['diagnoses']),
        'medications': _joinList(call['medications'] ?? user['medications']),
        'notes': (call['notes'] ?? user['notes'] ?? '').toString(),
        'city': (user['city'] ?? '').toString(),
        'street': (user['street'] ?? user['address'] ?? '').toString(),
        'subscription': (user['subscription'] ?? '').toString(),
        'insuranceCompany':
            (user['insuranceCompany'] ?? user['insurance'] ?? '').toString(),
        'email': (user['email'] ?? '').toString(),
      };

      _userCache[uid] = result;
      return result;
    } catch (_) {
      final fallback = {
        'firstName': (call['firstName'] ?? '').toString(),
        'lastName': (call['lastName'] ?? '').toString(),
        'dob': call['dob'],
        'diagnoses': _joinList(call['diagnoses']),
        'medications': _joinList(call['medications']),
        'notes': (call['notes'] ?? '').toString(),
      };
      _userCache[uid] = fallback;
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF34495e)),
        title: Text(
          "Call Queue",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF34495e),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection("calls").orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No calls",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final docs = snap.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final call = docs[index].data() as Map<String, dynamic>;
              final room = (call["room"] ?? "Unknown Room").toString();
              final startedByUid = (call['startedByUid'] ?? '').toString();
              final status = (call["status"] ?? "active").toString();
              final createdAt = (call["createdAt"] as Timestamp?)?.toDate();

              Widget buildCard(Map<String, dynamic> patientData) {
                final fullName = [
                  patientData['firstName'] ?? '',
                  patientData['lastName'] ?? ''
                ].where((s) => s.toString().isNotEmpty).join(' ');
                final age = _calcAge(patientData['dob']);
                final city = patientData['city'] ?? '';
                final subscription = patientData['subscription'] ?? '';
                final diagnoses = patientData['diagnoses'] ?? '—';
                final medications = patientData['medications'] ?? '—';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFaacfd0).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE6EEF0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF89bcbe).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF89bcbe)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName.isNotEmpty
                                      ? fullName
                                      : (call['startedByName'] ?? 'Unknown'),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: const Color(0xFF34495e),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (age.isNotEmpty) age,
                                    if (subscription.isNotEmpty) subscription,
                                    if (city.isNotEmpty) city,
                                  ].join('   •   '),
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    color: const Color(0xFF46627f),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status == 'active')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF89bcbe),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final patientData = await _loadUserData(startedByUid, call);

                                final fullName = [
                                  patientData['firstName'] ?? '',
                                  patientData['lastName'] ?? ''
                                ].where((s) => s.toString().isNotEmpty).join(' ');

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => pro.ProfessionalVideoCallScreen(
                                      room: room,
                                      patientData: {
                                        ...patientData,
                                        'age': age,
                                        'fullName': fullName.isNotEmpty ? fullName : 'Unknown',
                                        'startedByUid': startedByUid,
                                        'startedByName': call['startedByName'] ?? fullName,
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Join Call"),
                            ),
                        ],
                      ),

                      if (createdAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          "Requested: ${DateFormat('dd.MM.yyyy HH:mm').format(createdAt)}",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                        ),
                      ],

                      const SizedBox(height: 14),
                      Text("Diagnosis", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text(diagnoses,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Text("Medications", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      Text(medications,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                );
              }

              if ((call['firstName'] != null) || (call['lastName'] != null)) {
                return buildCard({
                  'firstName': call['firstName'] ?? '',
                  'lastName': call['lastName'] ?? '',
                  'dob': call['dob'],
                  'diagnoses': _joinList(call['diagnoses']),
                  'medications': _joinList(call['medications']),
                  'notes': call['notes'] ?? '',
                  'city': call['city'] ?? '',
                  'subscription': call['subscription'] ?? '',
                  'insuranceCompany': call['insuranceCompany'] ?? '',
                });
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _loadUserData(startedByUid, call),
                builder: (context, snapUser) {
                  if (!snapUser.hasData) {
                    return const SizedBox.shrink();
                  }
                  return buildCard(snapUser.data!);
                },
              );
            },
          );
        },
      ),
    );
  }
}
