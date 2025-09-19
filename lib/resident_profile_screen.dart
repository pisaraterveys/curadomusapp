import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'video_call_screen.dart';

class ResidentProfileScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ResidentProfileScreen({super.key, required this.data});

  /// Normalize Firestore arrays into List<String>
  List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  IconData _getAvatar(String? gender, String? dob) {
    if (gender == "Nainen" || gender == "female") {
      if (_isUnderage(dob)) return Icons.girl;
      return Icons.woman;
    } else if (gender == "Mies" || gender == "male") {
      if (_isUnderage(dob)) return Icons.boy;
      return Icons.man;
    }
    return Icons.person;
  }

  bool _isUnderage(String? dob) {
    if (dob == null || dob.isEmpty) return false;
    try {
      final parts = dob.split(".");
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final birthDate = DateTime(year, month, day);
        final age = DateTime.now().difference(birthDate).inDays ~/ 365;
        return age < 18;
      }
    } catch (_) {}
    return false;
  }

  Widget _buildInfoCard(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFaacfd0).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF34495e),
              )),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text("-", style: GoogleFonts.poppins(color: Colors.black54))
          else
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text("• $e",
                    style: GoogleFonts.poppins(color: const Color(0xFF46627f))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$label:",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF34495e),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: const Color(0xFF46627f),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startCall(BuildContext context) async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No caller UID found")),
        );
        return;
      }

      final buyerSnap =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final buyerData = buyerSnap.data() ?? {};

      final roomId = "curadomus_${DateTime.now().millisecondsSinceEpoch}";

      final mergedData = {
        "room": roomId,
        "startedByUid": uid,                 // main account UID
        "residentId": data["id"],            // ✅ family member id for visits
        "residentName": data["name"] ?? "",
        "firstName": buyerData["firstName"] ?? "",
        "lastName": buyerData["lastName"] ?? "",
        "dob": data["dob"] ?? buyerData["dob"] ?? "",
        "gender": data["gender"] ?? buyerData["gender"] ?? "",
        "city": buyerData["city"] ?? "",
        "street": buyerData["address"] ?? buyerData["street"] ?? "",
        "subscription": buyerData["subscription"] ?? "",
        "insuranceCompany": buyerData["insuranceCompany"] ?? "",
        "insuranceId": buyerData["insuranceId"] ?? "",
        "diagnoses": data["diagnoses"] ?? buyerData["diagnoses"] ?? [],
        "medications": data["medications"] ?? buyerData["medications"] ?? [],
        "notes": data["notes"] ?? buyerData["notes"] ?? "",
        "status": "active",
        "createdAt": FieldValue.serverTimestamp(),
      };

      // Save call doc
      await FirebaseFirestore.instance.collection("calls").add(mergedData);

      // ✅ Do NOT pass patientData here — VideoCallScreen doesn't accept it.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            room: roomId,
            userName:
                "${buyerData["firstName"] ?? ""} ${buyerData["lastName"] ?? ""}",
            patientUid: data["id"], // residentId
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start call: $e")),
      );
    }
  }

  Widget _visitHistory(String residentId) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFaacfd0).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("visits")
            .where("patientId", isEqualTo: residentId) // ✅ fetch by residentId
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Text("No visit history",
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.black54)),
            );
          }

          final docs = snap.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final v = docs[index].data() as Map<String, dynamic>;
              final createdAt = (v["createdAt"] as Timestamp?)?.toDate();
              final formattedDate = createdAt != null
                  ? DateFormat("dd.MM.yyyy HH:mm").format(createdAt)
                  : "-";
              final providerName = v["providerName"] ?? "Unknown";

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  title: Text(
                    "📅 $formattedDate",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    "👨‍⚕️ $providerName",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.black54),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Reason: ${v["reason"] ?? "-"}",
                              style: GoogleFonts.poppins(fontSize: 14)),
                          Text("Background: ${v["background"] ?? "-"}",
                              style: GoogleFonts.poppins(fontSize: 14)),
                          Text("Status: ${v["status"] ?? "-"}",
                              style: GoogleFonts.poppins(fontSize: 14)),
                          Text("Plan: ${v["plan"] ?? "-"}",
                              style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diagnoses = _asStringList(data["diagnoses"]);
    final medications = _asStringList(data["medications"]);
    final residentId = data["id"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          "${data["name"] ?? "Asukas"} - Profiili",
          style: GoogleFonts.poppins(
            color: const Color(0xFF34495e),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF34495e)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF89bcbe),
                  child: Icon(
                    _getAvatar(data["gender"], data["dob"]),
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data["name"] ?? "Nimetön",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF34495e),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${data["dob"] ?? "-"} | ${data["gender"] ?? "-"}",
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF46627f), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildInfoCard("Diagnoosit", diagnoses),
          _buildInfoCard("Lääkitykset", medications),

          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFaacfd0).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Esitiedot",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF34495e),
                    )),
                const SizedBox(height: 8),
                Text(
                  data["notes"] ?? "-",
                  style: GoogleFonts.poppins(color: const Color(0xFF46627f)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text("Perustiedot",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF34495e),
              )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFaacfd0).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                _buildField("Puhelin", data["phone"]),
                _buildField("Sähköposti", data["email"]),
                _buildField("Osoite", data["address"]),
                _buildField("Vakuutusyhtiö", data["insuranceCompany"]),
                _buildField("Vakuutus-ID", data["insuranceId"]),
                _buildField("Tilaus", data["subscription"]),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89bcbe),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
            onPressed: () => _startCall(context),
            icon: const Icon(Icons.video_call),
            label: Text(
              "Contact Health Care Provider",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 24),

          Text("Visit History",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF34495e))),
          const SizedBox(height: 12),

          _visitHistory(residentId),
        ],
      ),
    );
  }
}
