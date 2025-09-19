import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalVideoCallScreen extends StatefulWidget {
  final String room;
  final Map<String, dynamic> patientData;

  const ProfessionalVideoCallScreen({
    super.key,
    required this.room,
    required this.patientData,
  });

  @override
  State<ProfessionalVideoCallScreen> createState() =>
      _ProfessionalVideoCallScreenState();
}

class _ProfessionalVideoCallScreenState
    extends State<ProfessionalVideoCallScreen> {
  final _reasonCtrl = TextEditingController();
  final _backgroundCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  final _planCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const brandNavy = Color(0xFF34495e);
    const brandTeal = Color(0xFF89bcbe);

    final patient = widget.patientData;
    final fullName = patient['fullName'] ?? "Unknown";
    final age = patient['age'] ?? "";
    final subscription = patient['subscription'] ?? "—";
    final city = patient['city'] ?? "";
    final street = patient['street'] ?? "";
    final diagnoses = patient['diagnoses'] ?? "—";
    final medications = patient['medications'] ?? "—";
    final notes = patient['notes'] ?? "—";
    final insurance = patient['insurance'] ?? "—";
    final email = patient['email'] ?? "—";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: brandNavy),
        title: Text(
          "Professional Video Call",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: brandNavy,
          ),
        ),
      ),
      body: Row(
        children: [
          // Video area
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brandTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: brandTeal),
              ),
              child: Center(
                child: Text(
                  "📹 Video Call Here\n(Room: ${widget.room})",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: brandNavy,
                  ),
                ),
              ),
            ),
          ),

          // Patient info + chart
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF9FAFB),
              child: ListView(
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: brandTeal,
                          child: const Icon(Icons.person,
                              size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: brandNavy,
                          ),
                        ),
                        if (age.toString().isNotEmpty)
                          Text("Age: $age",
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.black54)),
                        if (subscription.toString().isNotEmpty)
                          Text("Subscription: $subscription",
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFaacfd0).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("City: $city"),
                        Text("Street: $street"),
                        Text("Insurance: $insurance"),
                        Text("Email: $email"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Diagnoses
                  Text("Diagnoses",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: brandNavy)),
                  Text(diagnoses,
                      style: GoogleFonts.poppins(color: Colors.black87)),

                  const SizedBox(height: 12),

                  // Medications
                  Text("Medications",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: brandNavy)),
                  Text(medications,
                      style: GoogleFonts.poppins(color: Colors.black87)),

                  const SizedBox(height: 20),

                  // Notes
                  Text("Notes",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: brandNavy)),
                  Text(notes,
                      style: GoogleFonts.poppins(color: Colors.black87)),

                  const SizedBox(height: 20),

                  // Charting form
                  Text("Charting",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: brandNavy)),
                  const SizedBox(height: 10),
                  _chartField("Reason", _reasonCtrl),
                  _chartField("Background", _backgroundCtrl),
                  _chartField("Status", _statusCtrl),
                  _chartField("Plan", _planCtrl),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Save charting (TODO: Firestore)")));
                    },
                    icon: const Icon(Icons.save),
                    label: Text(
                      "Save",
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }
}
