class AppUser {
  final String uid;
  final String email;
  final String displayName;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
    );
  }
}