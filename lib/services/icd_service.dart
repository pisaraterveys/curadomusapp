import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/icd_code.dart';

Future<List<ICDCode>> loadICDCodes() async {
  final jsonString = await rootBundle.loadString('assets/data/icd10_codes.json');
  final List data = json.decode(jsonString);
  return data.map((e) => ICDCode.fromJson(e)).toList();
}
