import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/api_constants.dart';
import 'api_client.dart';

class ImageUploader {
  final ApiClient _api;
  ImageUploader(this._api);

  /// Pick an image from the gallery and upload it. Returns the absolute URL,
  /// or null if the user cancelled.
  Future<String?> pickAndUpload({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1600,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      imageQuality: 85,
    );
    if (picked == null) return null;
    return upload(picked.path);
  }

  Future<String> upload(String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
    });
    try {
      final resp = await _api.upload(ApiConstants.uploadImage, form);
      final url = resp.data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ApiException('Upload failed — no URL returned');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final imageUploaderProvider = Provider<ImageUploader>((ref) {
  return ImageUploader(ref.read(apiClientProvider));
});
