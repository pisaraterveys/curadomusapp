import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'resident_profile_screen.dart';
import 'auth_choice_screen.dart';

class ResidenceProfileScreen extends StatelessWidget {
  final String uid;

  const ResidenceProfileScreen({super.key, required this.uid});

  /// Choose avatar based on gender + age
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
        final birthDate =
            DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final age = DateTime.now().difference(birthDate).inDays ~/ 365;
        return age < 18;
      }
    } catch (_) {}
    return false;
  }

  int? _calcAge(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final parts = dob.split(".");
      if (parts.length == 3) {
        final birthDate =
            DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return DateTime.now().difference(birthDate).inDays ~/ 365;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kirjaudu ulos"),
        content: const Text("Haluatko varmasti kirjautua ulos?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Peruuta"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Kyllä"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandNavy = Color(0xFF34495e);
    const brandTeal = Color(0xFF89bcbe);
    const brandLightTeal = Color(0xFFd7e6e7);

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    return WillPopScope(
      onWillPop: () async {
        _confirmLogout(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: brandLightTeal,
          elevation: 0,
          title: Text(
            "Kotitalouden profiili",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: brandNavy,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Image.asset(
                'assets/logo/curadomus.png',
                height: 32,
              ),
            ),
          ],
        ),
        body: StreamBuilder(
          stream: userDoc.snapshots(),
          builder: (context, buyerSnap) {
            if (!buyerSnap.hasData || !buyerSnap.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            final buyer = buyerSnap.data!.data() as Map<String, dynamic>;
            final buyerAge = _calcAge(buyer["dob"]);
            final buyerDx = (buyer["diagnoses"] is List &&
                    buyer["diagnoses"].isNotEmpty)
                ? buyer["diagnoses"][0]
                : "-";

            return StreamBuilder(
              stream: userDoc.collection('family').snapshots(),
              builder: (context, familySnap) {
                final family = familySnap.hasData
                    ? familySnap.data!.docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .toList()
                    : <Map<String, dynamic>>[];

                final buyerIcon = _getAvatar(buyer["gender"], buyer["dob"]);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pääasukas",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: brandNavy,
                          )),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [brandTeal, brandLightTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: HoverCard(
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ResidentProfileScreen(data: {
                                        ...buyer,
                                        "name":
                                            "${buyer["firstName"] ?? ""} ${buyer["lastName"] ?? ""}"
                                      }),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white24,
                                  child: Icon(buyerIcon,
                                      size: 40, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${buyer["firstName"] ?? ""} ${buyer["lastName"] ?? ""}",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text("Kaupunki: ${buyer["city"] ?? "-"}",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                    Text("Osoite: ${buyer["address"] ?? "-"}",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                    Text("Puhelin: ${buyer["phone"] ?? "-"}",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                    Text(
                                        "Vakuutus: ${buyer["insuranceCompany"] ?? "-"}",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                    Text(
                                        "Vakuutus-ID: ${buyer["insuranceId"] ?? "-"}",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          hoverChild: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (buyerAge != null) ...[
                                  const Icon(Icons.cake,
                                      size: 16, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text("Ikä: $buyerAge",
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70, fontSize: 13)),
                                  const SizedBox(width: 12),
                                ],
                                const Icon(Icons.medical_services,
                                    size: 16, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text("DX: $buyerDx",
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (family.isNotEmpty) ...[
                        Text("Perheenjäsenet",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: brandNavy,
                            )),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: family.map((member) {
                            final icon =
                                _getAvatar(member["gender"], member["dob"]);
                            final age = _calcAge(member["dob"]);
                            final dx = (member["diagnoses"] is List &&
                                    member["diagnoses"].isNotEmpty)
                                ? member["diagnoses"][0]
                                : "-";

                            return Container(
                              width: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: HoverCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ResidentProfileScreen(
                                                    data: member),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor:
                                            brandTeal.withOpacity(0.2),
                                        child: Icon(icon,
                                            size: 30, color: brandNavy),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      member["name"] ?? "",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: brandNavy,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                hoverChild: Column(
                                  children: [
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.cake,
                                            size: 14, color: Colors.black54),
                                        const SizedBox(width: 4),
                                        Text("Ikä: ${age ?? "-"}",
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.medical_services,
                                            size: 14, color: Colors.black54),
                                        const SizedBox(width: 4),
                                        Text("DX: $dx",
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Reusable widget to handle hover fade-in
class HoverCard extends StatefulWidget {
  final Widget child;
  final Widget hoverChild;

  const HoverCard({super.key, required this.child, required this.hoverChild});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.child,
          AnimatedOpacity(
            opacity: _hovering ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: widget.hoverChild,
          ),
        ],
      ),
    );
  }
}
