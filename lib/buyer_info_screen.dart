import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'family_screen.dart';

/// -------------------- ICD MODEL + LOADER --------------------

class ICDCode {
  final String code;
  final String description;

  ICDCode({required this.code, required this.description});

  factory ICDCode.fromJson(Map<String, dynamic> json) {
    // Support both "desc" and "description" keys
    final desc = (json['desc'] ?? json['description'] ?? '') as String;
    return ICDCode(
      code: json['code'] as String,
      description: desc,
    );
  }
}

// simple in-memory cache so we only load once
List<ICDCode>? _icdCache;
Future<List<ICDCode>> loadICDCodes() async {
  if (_icdCache != null) return _icdCache!;
  final jsonString = await rootBundle.loadString('assets/data/icd10_codes.json');
  final List data = json.decode(jsonString) as List;
  _icdCache =
      data.map((e) => ICDCode.fromJson(e as Map<String, dynamic>)).toList();
  return _icdCache!;
}

/// Autocomplete field for one diagnosis input.
/// Keeps your layout; typing filters by code or description.
/// When an item is chosen, the given controller gets "CODE - Description".
class ICDSearchField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onRemove;
  final bool canRemove;

  const ICDSearchField({
    super.key,
    required this.controller,
    this.onRemove,
    this.canRemove = false,
  });

  @override
  State<ICDSearchField> createState() => _ICDSearchFieldState();
}

class _ICDSearchFieldState extends State<ICDSearchField> {
  List<ICDCode> _all = [];

  @override
  void initState() {
    super.initState();
    loadICDCodes().then((codes) {
      if (!mounted) return;
      setState(() => _all = codes);
    }).catchError((_) {
      // Fails silently in UI; field still usable as plain text.
      setState(() => _all = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Row + remove icon, to match your existing layout.
    return Row(
      children: [
        Expanded(
          child: Autocomplete<ICDCode>(
            optionsBuilder: (TextEditingValue value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty || _all.isEmpty) {
                return const Iterable<ICDCode>.empty();
              }
              return _all.where((c) =>
                  c.code.toLowerCase().contains(q) ||
                  c.description.toLowerCase().contains(q));
            },
            displayStringForOption: (ICDCode o) => "${o.code} - ${o.description}",
            onSelected: (o) {
              // write the nice "CODE - Description" into the bound controller
              widget.controller.text = "${o.code} - ${o.description}";
            },
            // Use the field the Autocomplete gives us; do NOT overwrite it each build.
            fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
              // Show any prefilled text once, but don't keep reassigning on rebuilds.
              if (widget.controller.text.isNotEmpty && textCtrl.text.isEmpty) {
                textCtrl.text = widget.controller.text;
                textCtrl.selection = TextSelection.collapsed(
                  offset: textCtrl.text.length,
                );
              }
              return TextField(
                controller: textCtrl,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  // Keep the external controller synced as the user types
                  widget.controller.value = textCtrl.value;
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              // Pretty dropdown overlay
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, minWidth: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final o = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(
                            "${o.code} - ${o.description}",
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          onTap: () => onSelected(o),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.canRemove)
          IconButton(
            tooltip: 'Remove',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
      ],
    );
  }
}

/// -------------------- YOUR SCREEN (unchanged layout/design) --------------------

class BuyerInfoScreen extends StatefulWidget {
  final String uid;

  const BuyerInfoScreen({super.key, required this.uid});

  @override
  State<BuyerInfoScreen> createState() => _BuyerInfoScreenState();
}

class _BuyerInfoScreenState extends State<BuyerInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = "Mies"; // default

  final _insuranceCompanyCtrl = TextEditingController();
  final _insuranceIdCtrl = TextEditingController();
  final _esitiedotCtrl = TextEditingController();

  final List<TextEditingController> _diagnoses = [TextEditingController()];
  final List<TextEditingController> _medications = [TextEditingController()];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _insuranceCompanyCtrl.dispose();
    _insuranceIdCtrl.dispose();
    _esitiedotCtrl.dispose();
    for (final c in _diagnoses) c.dispose();
    for (final c in _medications) c.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _addDiagnosis() => setState(() => _diagnoses.add(TextEditingController()));
  void _removeDiagnosis(int i) => setState(() {
        _diagnoses[i].dispose();
        _diagnoses.removeAt(i);
      });

  void _addMedication() =>
      setState(() => _medications.add(TextEditingController()));
  void _removeMedication(int i) => setState(() {
        _medications[i].dispose();
        _medications.removeAt(i);
      });

  Future<void> _saveAndNext() async {
    if (_formKey.currentState?.validate() ?? false) {
      final buyerData = {
        "firstName": _firstNameCtrl.text,
        "lastName": _lastNameCtrl.text,
        "gender": _gender,
        "dob": _dobCtrl.text,
        "address": _addressCtrl.text,
        "phone": _phoneCtrl.text,
        "insuranceCompany": _insuranceCompanyCtrl.text,
        "insuranceId": _insuranceIdCtrl.text,
        "diagnoses": _diagnoses.map((c) => c.text).toList(), // "E11 - Type 2..."
        "medications": _medications.map((c) => c.text).toList(),
        "notes": _esitiedotCtrl.text,
        "email": "", // Will be filled from Auth if needed
        "subscription": "Perus"
      };

      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .set(buyerData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FamilyScreen(uid: widget.uid, buyerData: buyerData),
        ),
      );
    }
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
          'Buyer Information',
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
                Image.asset('assets/logo/curadomus.png', width: 460),
                const SizedBox(height: 32),

                // Card with form
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Names
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameCtrl,
                                validator: _req,
                                decoration:
                                    const InputDecoration(labelText: 'First Name'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameCtrl,
                                validator: _req,
                                decoration:
                                    const InputDecoration(labelText: 'Last Name'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gender
                        DropdownButtonFormField<String>(
                          value: _gender,
                          items: const [
                            DropdownMenuItem(value: "Mies", child: Text("Male")),
                            DropdownMenuItem(value: "Nainen", child: Text("Female")),
                            DropdownMenuItem(value: "Poika", child: Text("Boy")),
                            DropdownMenuItem(value: "Tyttö", child: Text("Girl")),
                          ],
                          onChanged: (v) => setState(() => _gender = v!),
                          decoration: const InputDecoration(labelText: "Gender"),
                        ),
                        const SizedBox(height: 12),

                        // Contact info
                        TextFormField(
                          controller: _addressCtrl,
                          validator: _req,
                          decoration: const InputDecoration(labelText: 'Address'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          validator: _req,
                          decoration:
                              const InputDecoration(labelText: 'Phone Number'),
                        ),
                        const SizedBox(height: 12),

                        // DOB
                        TextFormField(
                          controller: _dobCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Date of Birth (dd.MM.yyyy)'),
                        ),
                        const SizedBox(height: 12),

                        // Insurance
                        TextFormField(
                          controller: _insuranceCompanyCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Insurance Company'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _insuranceIdCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Insurance ID'),
                        ),
                        const SizedBox(height: 24),

                        // Diagnoses (ICD search)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Diagnoses',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF34495e),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < _diagnoses.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ICDSearchField(
                              controller: _diagnoses[i],
                              canRemove: _diagnoses.length > 1,
                              onRemove: () => _removeDiagnosis(i),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _addDiagnosis,
                          icon: const Icon(Icons.add),
                          label: const Text('Add diagnosis'),
                        ),
                        const SizedBox(height: 16),

                        // Medications
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Medications',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF34495e),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < _medications.length; i++)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _medications[i],
                                  decoration: const InputDecoration(
                                      labelText: 'Medication / dosage'),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                onPressed: _medications.length > 1
                                    ? () => _removeMedication(i)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: _addMedication,
                          icon: const Icon(Icons.add),
                          label: const Text('Add medication'),
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _esitiedotCtrl,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'Additional notes'),
                        ),
                        const SizedBox(height: 28),

                        // Submit
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
                            onPressed: _saveAndNext,
                            child: const Text('Save & Continue'),
                          ),
                        ),
                      ],
                    ),
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
