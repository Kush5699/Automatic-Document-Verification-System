import '../models/identity_data.dart';

/// Smart rule-based entity extractor for identity documents.
/// 
/// Uses regex patterns, label detection, and heuristics to extract
/// fields from OCR text — no LLM, no API, no network, fully private.
/// Runs in < 10ms on any device.
class SmartExtractor {

  /// Main extraction method
  IdentityData extract(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    
    final allText = ocrText.toUpperCase();
    
    // Extract all fields
    final idType = _detectIdType(allText);
    final dates = _extractAllDates(ocrText);
    final dob = _findDob(ocrText, dates);
    final expiry = _findExpiry(ocrText, dates, dob);
    final gender = _extractGender(allText);
    final idNumber = _extractIdNumber(lines, allText);
    final stateResult = _extractState(allText);
    final postalCode = _extractPostalCode(ocrText);
    final nameResult = _extractName(lines, allText);
    final addressResult = _extractAddress(lines, allText, nameResult['usedLines'] ?? []);
    final country = _detectCountry(allText, idType);

    return IdentityData(
      firstName: _titleCase(nameResult['firstName']),
      lastName: _titleCase(nameResult['lastName']),
      dateOfBirth: dob,
      gender: gender,
      address: addressResult['address'],
      city: _titleCase(addressResult['city'] ?? stateResult['city']),
      state: stateResult['state'],
      postalCode: postalCode,
      country: country,
      idNumber: idNumber,
      idType: idType,
      expiryDate: expiry,
      nationality: null,
      rawOcrText: ocrText,
      processingTimeMs: 0,
    );
  }

  // ═══════════════════════════════════════════════
  //  ID TYPE DETECTION
  // ═══════════════════════════════════════════════

  String? _detectIdType(String text) {
    final patterns = {
      'Driving License': [
        r'DRIVER.?S?\s*LIC', r'DRIVING\s*LIC', r'DL\b', r'DRIVER\s+LICENSE',
        r'LICENCE', r'PERMIS\s+DE\s+CONDUIRE', r'FÜHRERSCHEIN',
      ],
      'Passport': [
        r'PASSPORT', r'PASSEPORT', r'REISEPASS', r'PASAPORTE',
      ],
      'National ID': [
        r'NATIONAL\s+ID', r'IDENTITY\s+CARD', r'CARTE\s+D.IDENTIT',
        r'AADHAAR', r'AADHAR', r'PAN\s*CARD', r'PERMANENT\s+ACCOUNT',
        r'VOTER\s+ID', r'ELECTION\s+COMMISSION',
      ],
      'PAN Card': [
        r'INCOME\s*TAX', r'PERMANENT\s*ACCOUNT\s*NUMBER', r'PAN',
      ],
      'Voter ID': [
        r'VOTER', r'ELECTION', r'ELECTORAL',
      ],
    };

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
          return entry.key;
        }
      }
    }
    return 'Other';
  }

  // ═══════════════════════════════════════════════
  //  DATE EXTRACTION
  // ═══════════════════════════════════════════════

  List<Map<String, String>> _extractAllDates(String text) {
    final datePatterns = [
      // MM/DD/YYYY or MM-DD-YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
      // YYYY/MM/DD
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      // DD MMM YYYY (e.g., 15 Jan 1990)
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})', caseSensitive: false),
    ];

    final results = <Map<String, String>>[];
    for (final pattern in datePatterns) {
      for (final match in pattern.allMatches(text)) {
        results.add({
          'full': match.group(0)!,
          'position': match.start.toString(),
        });
      }
    }
    return results;
  }

  String? _findDob(String text, List<Map<String, String>> dates) {
    if (dates.isEmpty) return null;

    final upper = text.toUpperCase();
    final dobLabels = [
      r'D\.?O\.?B\.?', r'DATE\s*OF\s*BIRTH', r'BIRTH\s*DATE', r'BORN',
      r'FECHA\s*DE\s*NACIMIENTO', r'GEBURTSDATUM', r'जन्म\s*तिथि',
    ];

    // Find date closest to a DOB label
    for (final label in dobLabels) {
      final labelMatch = RegExp(label, caseSensitive: false).firstMatch(upper);
      if (labelMatch != null) {
        // Find the nearest date after the label
        int minDist = 999999;
        String? bestDate;
        for (final date in dates) {
          final datePos = int.parse(date['position']!);
          final dist = datePos - labelMatch.end;
          if (dist >= -5 && dist < minDist) {
            minDist = dist;
            bestDate = date['full'];
          }
        }
        if (bestDate != null) return bestDate;
      }
    }

    // Fallback: if multiple dates, DOB is usually the earliest date by value
    if (dates.length >= 2) {
      return dates.first['full']; // First date found is often DOB
    }

    return dates.isNotEmpty ? dates.first['full'] : null;
  }

  String? _findExpiry(String text, List<Map<String, String>> dates, String? dob) {
    if (dates.isEmpty) return null;

    final upper = text.toUpperCase();
    final expLabels = [r'EXP', r'EXPIR', r'VALID\s*(THRU|UNTIL|TILL)', r'VENC'];

    for (final label in expLabels) {
      final labelMatch = RegExp(label, caseSensitive: false).firstMatch(upper);
      if (labelMatch != null) {
        int minDist = 999999;
        String? bestDate;
        for (final date in dates) {
          final datePos = int.parse(date['position']!);
          final dist = datePos - labelMatch.end;
          if (dist >= -5 && dist < minDist) {
            minDist = dist;
            bestDate = date['full'];
          }
        }
        if (bestDate != null) return bestDate;
      }
    }

    // Fallback: if we have DOB and multiple dates, expiry is the other one
    if (dob != null && dates.length >= 2) {
      for (final date in dates) {
        if (date['full'] != dob) return date['full'];
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════
  //  GENDER EXTRACTION
  // ═══════════════════════════════════════════════

  String? _extractGender(String text) {
    // Look for explicit gender labels
    final genderPatterns = [
      RegExp(r'(?:SEX|GENDER)\s*[:\s]*\b(M|F|MALE|FEMALE)\b', caseSensitive: false),
      RegExp(r'\b(MALE|FEMALE)\b', caseSensitive: false),
      // Standalone M or F near SEX label
      RegExp(r'SEX\s*[:\s]*(M|F)\b', caseSensitive: false),
    ];

    for (final pattern in genderPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final g = match.group(1)!.toUpperCase();
        if (g == 'M' || g == 'MALE') return 'Male';
        if (g == 'F' || g == 'FEMALE') return 'Female';
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════
  //  ID NUMBER EXTRACTION
  // ═══════════════════════════════════════════════

  String? _extractIdNumber(List<String> lines, String allText) {
    // Look for labeled ID numbers
    final idPatterns = [
      // "NO." or "NO:" followed by alphanumeric
      RegExp(r'(?:NO|DL|LICENSE|LICENCE|ID|CARD)\s*[.:#]?\s*([A-Z0-9][\w-]{4,})', caseSensitive: false),
      // PAN card format: 5 letters + 4 digits + 1 letter
      RegExp(r'\b([A-Z]{5}\d{4}[A-Z])\b'),
      // Aadhaar: 12 digits with optional spaces
      RegExp(r'\b(\d{4}\s?\d{4}\s?\d{4})\b'),
      // General: long alphanumeric sequences that look like IDs
      RegExp(r'\b([A-Z]\d{3,}[-\s]?\d{3,}[-\s]?\d{0,4})\b'),
    ];

    for (final pattern in idPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }

    // Fallback: find long alphanumeric strings (6+ chars) that aren't words
    for (final line in lines) {
      final match = RegExp(r'\b([A-Z0-9]{2,}[-\s]?[A-Z0-9]{2,}[-\s]?[A-Z0-9]*)\b')
          .firstMatch(line.toUpperCase());
      if (match != null) {
        final candidate = match.group(1)!;
        // Must have at least one digit and be 6+ chars
        if (candidate.length >= 6 && RegExp(r'\d').hasMatch(candidate) && 
            !_isCommonWord(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }

  bool _isCommonWord(String text) {
    final common = {
      'DRIVER', 'LICENSE', 'LICENCE', 'CLASS', 'ALABAMA', 'CALIFORNIA',
      'PASSPORT', 'NATIONAL', 'IDENTITY', 'ADDRESS', 'ENDORSEMENTS',
      'RESTRICTIONS', 'INCOME', 'DEPARTMENT', 'PERMANENT', 'ACCOUNT',
      'NUMBER', 'ELECTION', 'COMMISSION', 'INDIA', 'STATES', 'UNITED',
    };
    return common.contains(text);
  }

  // ═══════════════════════════════════════════════
  //  STATE EXTRACTION
  // ═══════════════════════════════════════════════

  Map<String, String?> _extractState(String text) {
    // US state abbreviations and full names
    const usStates = {
      'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
      'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
      'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii', 'ID': 'Idaho',
      'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
      'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
      'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
      'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
      'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
      'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
      'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
      'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
      'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
      'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'District of Columbia',
    };

    // Indian states
    const indianStates = {
      'AP': 'Andhra Pradesh', 'AR': 'Arunachal Pradesh', 'AS': 'Assam',
      'BR': 'Bihar', 'CG': 'Chhattisgarh', 'GJ': 'Gujarat', 'HR': 'Haryana',
      'HP': 'Himachal Pradesh', 'JK': 'Jammu and Kashmir', 'JH': 'Jharkhand',
      'KA': 'Karnataka', 'KL': 'Kerala', 'MP': 'Madhya Pradesh',
      'MH': 'Maharashtra', 'MN': 'Manipur', 'ML': 'Meghalaya', 'MZ': 'Mizoram',
      'NL': 'Nagaland', 'OD': 'Odisha', 'PB': 'Punjab', 'RJ': 'Rajasthan',
      'SK': 'Sikkim', 'TN': 'Tamil Nadu', 'TS': 'Telangana', 'TR': 'Tripura',
      'UP': 'Uttar Pradesh', 'UK': 'Uttarakhand', 'WB': 'West Bengal',
      'DL': 'Delhi', 'GA': 'Goa',
    };

    // Check for full state names first
    for (final entry in usStates.entries) {
      if (text.contains(entry.value.toUpperCase())) {
        return {'state': entry.value, 'city': null};
      }
    }

    // Check abbreviations (only when followed by space + zip or at line boundary)
    final abbrMatch = RegExp(r'\b([A-Z]{2})\s+(\d{5})').firstMatch(text);
    if (abbrMatch != null) {
      final abbr = abbrMatch.group(1)!;
      if (usStates.containsKey(abbr)) {
        return {'state': usStates[abbr], 'city': null};
      }
      if (indianStates.containsKey(abbr)) {
        return {'state': indianStates[abbr], 'city': null};
      }
    }

    return {'state': null, 'city': null};
  }

  // ═══════════════════════════════════════════════
  //  POSTAL CODE EXTRACTION
  // ═══════════════════════════════════════════════

  String? _extractPostalCode(String text) {
    // US ZIP: 5 digits or 5+4
    final usZip = RegExp(r'\b(\d{5}(?:-\d{4})?)\b').firstMatch(text);
    if (usZip != null) return usZip.group(1);

    // Indian PIN: 6 digits
    final inPin = RegExp(r'\b(\d{6})\b').firstMatch(text);
    if (inPin != null) return inPin.group(1);

    // UK postcode
    final ukPost = RegExp(r'\b([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})\b').firstMatch(text.toUpperCase());
    if (ukPost != null) return ukPost.group(1);

    return null;
  }

  // ═══════════════════════════════════════════════
  //  NAME EXTRACTION
  // ═══════════════════════════════════════════════

  Map<String, dynamic> _extractName(List<String> lines, String allText) {
    final usedLines = <int>[];

    // Strategy 1: Look for labeled names (FN/LN, FIRST NAME/LAST NAME, NAME)
    final fnPatterns = [
      RegExp(r'(?:FIRST\s*NAME|FN|GIVEN\s*NAME|PRENOM)\s*[:\s]*([A-Z][A-Za-z\s]+)', caseSensitive: false),
    ];
    final lnPatterns = [
      RegExp(r'(?:LAST\s*NAME|LN|SURNAME|FAMILY\s*NAME|NOM)\s*[:\s]*([A-Z][A-Za-z\s]+)', caseSensitive: false),
    ];

    String? firstName, lastName;

    for (final p in fnPatterns) {
      final m = p.firstMatch(allText);
      if (m != null) firstName = m.group(1)!.trim();
    }
    for (final p in lnPatterns) {
      final m = p.firstMatch(allText);
      if (m != null) lastName = m.group(1)!.trim();
    }

    if (firstName != null || lastName != null) {
      return {'firstName': firstName, 'lastName': lastName, 'usedLines': usedLines};
    }

    // Strategy 2: Look for "Name:" label
    final nameLabel = RegExp(r'(?:^|\n)\s*(?:NAME|TH/\s*Name)\s*[:\s]*(.+)', caseSensitive: false)
        .firstMatch(allText);
    if (nameLabel != null) {
      final parts = nameLabel.group(1)!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        // For Indian names: PATEL KUSH ASHVINBHAI → first=KUSH, last=PATEL
        // For Western names: CONNOR SAMPLE → first=CONNOR, last=SAMPLE
        return {
          'firstName': parts.length >= 3 ? parts[1] : parts[0],
          'lastName': parts.length >= 3 ? parts[0] : parts.last,
          'usedLines': usedLines,
        };
      }
      return {'firstName': parts.first, 'lastName': null, 'usedLines': usedLines};
    }

    // Strategy 3: Heuristic — find lines that are JUST names (all alpha, 2-3 words)
    final skipWords = {
      'DRIVER', 'LICENSE', 'LICENCE', 'CLASS', 'STATE', 'PASSPORT', 'NATIONAL',
      'IDENTITY', 'CARD', 'INCOME', 'TAX', 'DEPARTMENT', 'PERMANENT', 'ACCOUNT',
      'NUMBER', 'ENDORSEMENTS', 'RESTRICTIONS', 'GOVT', 'GOVERNMENT', 'OF',
      'INDIA', 'UNITED', 'STATES', 'REPUBLIC', 'ELECTION', 'COMMISSION',
    };

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final words = line.split(RegExp(r'\s+'));

      // Name candidate: 1-4 words, all alphabetic, not a known label
      if (words.length >= 1 && words.length <= 4 &&
          words.every((w) => RegExp(r'^[A-Za-z]+$').hasMatch(w)) &&
          !words.any((w) => skipWords.contains(w.toUpperCase()))) {
        
        // Skip if it looks like a city/state
        if (_isLikelyCity(line.toUpperCase())) continue;

        usedLines.add(i);
        if (words.length == 1) {
          if (firstName == null) {
            firstName = words[0];
          } else {
            lastName = words[0];
            break;
          }
        } else if (words.length == 2) {
          firstName = words[0];
          lastName = words[1];
          break;
        } else {
          // 3+ words: first word is first name, last word is last name
          firstName = words.first;
          lastName = words.last;
          break;
        }
      }
    }

    return {'firstName': firstName, 'lastName': lastName, 'usedLines': usedLines};
  }

  // ═══════════════════════════════════════════════
  //  ADDRESS EXTRACTION
  // ═══════════════════════════════════════════════

  Map<String, String?> _extractAddress(List<String> lines, String allText, List<dynamic> usedNameLines) {
    // Strategy 1: Look for labeled address
    final addrLabel = RegExp(
      r'(?:ADDRESS|ADD|ADDR|RESIDENCE)\s*[:\s]*(.*)',
      caseSensitive: false,
    ).firstMatch(allText);

    if (addrLabel != null) {
      return {'address': addrLabel.group(1)!.trim(), 'city': null};
    }

    // Strategy 2: Find lines with street patterns (numbers + street names)
    final streetPatterns = RegExp(
      r'^\d+\s+\w+\s+(?:STREET|ST|DRIVE|DR|AVENUE|AVE|ROAD|RD|BOULEVARD|BLVD|LANE|LN|WAY|COURT|CT|CIRCLE|CIR|PLACE|PL)',
      caseSensitive: false,
    );

    String? address;
    String? city;

    for (int i = 0; i < lines.length; i++) {
      if (usedNameLines.contains(i)) continue;
      
      final line = lines[i].trim();

      if (streetPatterns.hasMatch(line)) {
        address = line;
        // Next line might be city, state, zip
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final cityMatch = RegExp(r'^([A-Za-z\s]+?)[\s,]+[A-Z]{2}\s+\d{5}').firstMatch(nextLine);
          if (cityMatch != null) {
            city = cityMatch.group(1)!.trim();
            address = '$address, $nextLine';
          }
        }
        break;
      }

      // Lines with both letters and a ZIP code pattern
      final cityStateZip = RegExp(r'^([A-Za-z\s]+)\s+[A-Z]{2}\s+\d{5}').firstMatch(line);
      if (cityStateZip != null && address == null) {
        city = cityStateZip.group(1)!.trim();
      }
    }

    return {'address': address, 'city': city};
  }

  // ═══════════════════════════════════════════════
  //  COUNTRY DETECTION
  // ═══════════════════════════════════════════════

  String? _detectCountry(String text, String? idType) {
    final countryPatterns = {
      'United States': [r'UNITED\s+STATES', r'USA\b', r'U\.S\.A'],
      'India': [r'\bINDIA\b', r'BHARAT', r'भारत'],
      'United Kingdom': [r'UNITED\s+KINGDOM', r'\bU\.?K\.?\b', r'BRITAIN'],
      'Canada': [r'\bCANADA\b'],
      'Australia': [r'\bAUSTRALIA\b'],
      'Germany': [r'\bGERMANY\b', r'DEUTSCHLAND'],
      'France': [r'\bFRANCE\b', r'REPUBLIQUE\s+FRANCAISE'],
    };

    for (final entry in countryPatterns.entries) {
      for (final pattern in entry.value) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
          return entry.key;
        }
      }
    }

    // Heuristic: US state found → probably US
    if (idType == 'Driving License') {
      final stateResult = _extractState(text);
      if (stateResult['state'] != null) return 'United States';
    }

    if (idType == 'PAN Card') return 'India';

    return null;
  }

  // ═══════════════════════════════════════════════
  //  UTILITIES
  // ═══════════════════════════════════════════════

  bool _isLikelyCity(String text) {
    final cities = {
      'MONTGOMERY', 'NEW YORK', 'LOS ANGELES', 'CHICAGO', 'HOUSTON',
      'PHOENIX', 'PHILADELPHIA', 'SAN ANTONIO', 'SAN DIEGO', 'DALLAS',
      'MUMBAI', 'DELHI', 'BANGALORE', 'KOLKATA', 'CHENNAI', 'HYDERABAD',
    };
    return cities.contains(text.trim());
  }

  String? _titleCase(String? text) {
    if (text == null || text.isEmpty) return text;
    return text.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
