import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/certification/identity_photo_service.dart';
import 'package:image_picker/image_picker.dart';

class _ImagePicker extends ImagePicker {
  ImageSource? source;
  bool? fullMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    fullMetadata = requestFullMetadata;
    return XFile('/selected/id.jpg');
  }
}

void main() {
  test('相册只读取用户选中的照片，不请求完整相册元数据', () async {
    final picker = _ImagePicker();
    final service = DefaultIdentityPhotoPicker(picker: picker);

    expect(await service.pickFromAlbum(), '/selected/id.jpg');
    expect(picker.source, ImageSource.gallery);
    expect(picker.fullMetadata, isFalse);
  });

  test('iOS 不声明相册权限，仍保留相机用途说明', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    expect(plist, contains('NSCameraUsageDescription'));
    expect(plist, isNot(contains('NSPhotoLibraryUsageDescription')));
    expect(plist, isNot(contains('NSPhotoLibraryAddUsageDescription')));
    expect(podfile, contains('PERMISSION_CAMERA=1'));
  });
}
