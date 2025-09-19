import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'resident_form_screen.dart';
import 'resident_profile_screen.dart';

class FamilyScreen extends StatefulWidget {
  final String uid; // 👈 buyer uid
  final Map<String, dynamic> buyerData;

  const FamilyScreen({
    super.key,
    required this.uid,
    required this.buyerData,
  });

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final List<TextEditingController> _familyMembers = [TextEditingController()];

  void _addMember() {
    setState(() => _familyMembers.add(TextEditingController()));
  }

  void _removeMember(int i) {
    setState(() {
      _familyMembers[i].dispose();
      _familyMembers.removeAt(i);
    });
  }

  Future<void> _finish() async {
    final names = _familyMembers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<Map<String, dynamic>> familyDetails = [];

    for (final name in names) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => ResidentFormScreen(
            uid: widget.uid,
            name: name,
            onSubmit: (memberData) {
              Navigator.pop(context, memberData);
            },
          ),
        ),
      );

      if (result != null) {
        familyDetails.add(result);
      }
    }

    // ✅ Fetch buyer data from Firestore and pass as `data`
    final buyerSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .get();
    final buyerData = buyerSnap.data() ?? {};
    buyerData["id"] = widget.uid; // keep uid in the map

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResidentProfileScreen(data: buyerData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW =
        MediaQuery.of(context).size.width > 720 ? 720.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF34495e)),
        title: Text(
          'Family Members',
          style: GoogleFonts.poppins(
            color: const Color(0xFF34495e),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ✅ Logo
                Image.asset('assets/logo/curadomus.png', width: 440),
                const SizedBox(height: 32),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(
                        "Add family members",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF34495e),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic members list
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _familyMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _familyMembers[i],
                                decoration: const InputDecoration(
                                  labelText: "Member name",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _familyMembers.length > 1
                                  ? () => _removeMember(i)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Add button
                      TextButton.icon(
                        onPressed: _addMember,
                        icon: const Icon(Icons.add),
                        label: const Text("Add member"),
                      ),
                      const SizedBox(height: 24),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF89bcbe),
                            foregroundColor: Colors.white,
                            textStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                          onPressed: _finish,
                          child: const Text("Continue"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
