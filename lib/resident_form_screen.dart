import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// -------------------- ICD MODEL + LOADER --------------------
class ICDCode {
  final String code;
  final String description;

  ICDCode({required this.code, required this.description});

  factory ICDCode.fromJson(Map<String, dynamic> json) {
    final desc = (json['desc'] ?? json['description'] ?? '') as String;
    return ICDCode(
      code: json['code'] as String,
      description: desc,
    );
  }
}

List<ICDCode>? _icdCache;
Future<List<ICDCode>> loadICDCodes() async {
  if (_icdCache != null) return _icdCache!;
  final jsonString = await rootBundle.loadString('assets/data/icd10_codes.json');
  final List data = json.decode(jsonString) as List;
  _icdCache =
      data.map((e) => ICDCode.fromJson(e as Map<String, dynamic>)).toList();
  return _icdCache!;
}

/// Autocomplete field (same as Buyer form)
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Autocomplete<ICDCode>(
            optionsBuilder: (value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<ICDCode>.empty();
              return _all.where((c) =>
                  c.code.toLowerCase().contains(q) ||
                  c.description.toLowerCase().contains(q));
            },
            displayStringForOption: (o) => "${o.code} - ${o.description}",
            onSelected: (o) {
              widget.controller.text = "${o.code} - ${o.description}";
            },
            fieldViewBuilder: (context, textCtrl, focusNode, _) {
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
                onChanged: (v) => widget.controller.value = textCtrl.value,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final o = options.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text("${o.code} - ${o.description}"),
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
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.onRemove,
          ),
      ],
    );
  }
}

/// -------------------- RESIDENT FORM SCREEN --------------------

class ResidentFormScreen extends StatefulWidget {
  final String uid;
  final String name;
  final Function(Map<String, dynamic>) onSubmit;

  const ResidentFormScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.onSubmit,
  });

  @override
  State<ResidentFormScreen> createState() => _ResidentFormScreenState();
}

class _ResidentFormScreenState extends State<ResidentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _gender = "Mies";

  final List<TextEditingController> _diagnoses = [TextEditingController()];
  final List<TextEditingController> _medications = [TextEditingController()];

  bool _saving = false;

  @override
  void dispose() {
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _diagnoses) c.dispose();
    for (final c in _medications) c.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      "name": widget.name,
      "gender": _gender,
      "dob": _dobCtrl.text,
      "phone": _phoneCtrl.text,
      "diagnoses":
          _diagnoses.map((c) => c.text).where((e) => e.isNotEmpty).toList(),
      "medications":
          _medications.map((c) => c.text).where((e) => e.isNotEmpty).toList(),
      "notes": _notesCtrl.text,
    };

    try {
      final docRef = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .collection("family")
          .add(data);

      widget.onSubmit({"id": docRef.id, ...data});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          "${widget.name} - details",
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
                Image.asset('assets/logo/curadomus.png', width: 120),
                const SizedBox(height: 24),

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gender
                        DropdownButtonFormField<String>(
                          value: _gender,
                          items: const [
                            DropdownMenuItem(value: "Mies", child: Text("Mies")),
                            DropdownMenuItem(value: "Nainen", child: Text("Nainen")),
                          ],
                          onChanged: (v) => setState(() => _gender = v!),
                          decoration: const InputDecoration(labelText: "Gender"),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _dobCtrl,
                          decoration: const InputDecoration(
                              labelText: "Date of Birth (dd.MM.yyyy)"),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: "Phone"),
                        ),
                        const SizedBox(height: 24),

                        // Diagnoses
                        Text(
                          "Diagnoses",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF34495e),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < _diagnoses.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ICDSearchField(
                              controller: _diagnoses[i],
                              canRemove: _diagnoses.length > 1,
                              onRemove: () => _removeDiagnosis(i),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _addDiagnosis,
                          icon: const Icon(Icons.add),
                          label: const Text("Add diagnosis"),
                        ),
                        const SizedBox(height: 16),

                        // Medications
                        Text(
                          "Medications",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF34495e),
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
                                      labelText: "Medication / dosage"),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _medications.length > 1
                                    ? () => _removeMedication(i)
                                    : null,
                              ),
                            ],
                          ),
                        TextButton.icon(
                          onPressed: _addMedication,
                          icon: const Icon(Icons.add),
                          label: const Text("Add medication"),
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: "Notes"),
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
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const CircularProgressIndicator()
                                : const Text("Save"),
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
