import 'package:image_picker/image_picker.dart';

/// Datos del perfil recién registrado para la pantalla de éxito.
class RegisteredProfessionalPreview {
  const RegisteredProfessionalPreview({
    this.professionalId,
    required this.name,
    required this.professions,
    required this.city,
    required this.phone,
    required this.bio,
    this.profilePhotoUrl,
    this.galleryImages = const [],
  });

  final String? professionalId;
  final String name;
  final List<String> professions;
  final String city;
  final String phone;
  final String bio;
  final String? profilePhotoUrl;
  final List<XFile> galleryImages;
}
