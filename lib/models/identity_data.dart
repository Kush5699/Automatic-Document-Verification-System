class IdentityData {
  String? firstName;
  String? lastName;
  String? dateOfBirth;
  String? gender;
  String? address;
  String? city;
  String? state;
  String? postalCode;
  String? country;
  String? idNumber;
  String? idType;
  String? expiryDate;
  String? nationality;
  String? rawOcrText;
  double? processingTimeMs;

  IdentityData({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.idNumber,
    this.idType,
    this.expiryDate,
    this.nationality,
    this.rawOcrText,
    this.processingTimeMs,
  });

  factory IdentityData.fromJson(Map<String, dynamic> json) {
    return IdentityData(
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      idNumber: json['id_number'] as String?,
      idType: json['id_type'] as String?,
      expiryDate: json['expiry_date'] as String?,
      nationality: json['nationality'] as String?,
    );
  }

  Map<String, String?> toDisplayMap() {
    return {
      'First Name': firstName,
      'Last Name': lastName,
      'Date of Birth': dateOfBirth,
      'Gender': gender,
      'Address': address,
      'City': city,
      'State': state,
      'Postal Code': postalCode,
      'Country': country,
      'ID Number': idNumber,
      'ID Type': idType,
      'Expiry Date': expiryDate,
      'Nationality': nationality,
    };
  }
}
