import 'dart:convert';

class UserModel {
  final String id;
  final String name;
  final String email;
  final double handicap;
  final String? city;
  final String? profilePictureUrl;
  final bool isAdmin;
  final String? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.handicap,
    this.city,
    this.profilePictureUrl,
    this.isAdmin = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:                 json['id'] as String,
    name:               json['name'] as String,
    email:              json['email'] as String,
    handicap:           (json['handicap'] as num?)?.toDouble() ?? 0,
    city:               json['city'] as String?,
    profilePictureUrl:  json['profile_picture_url'] as String?,
    isAdmin:            json['is_admin'] as bool? ?? false,
    createdAt:          json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':                   id,
    'name':                 name,
    'email':                email,
    'handicap':             handicap,
    'city':                 city,
    'profile_picture_url':  profilePictureUrl,
    'is_admin':             isAdmin,
    'created_at':           createdAt,
  };

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonStr) =>
      UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  UserModel copyWith({
    String? name,
    double? handicap,
    String? city,
    String? profilePictureUrl,
  }) => UserModel(
    id:                 id,
    name:               name ?? this.name,
    email:              email,
    handicap:           handicap ?? this.handicap,
    city:               city ?? this.city,
    profilePictureUrl:  profilePictureUrl ?? this.profilePictureUrl,
    isAdmin:            isAdmin,
    createdAt:          createdAt,
  );
}
