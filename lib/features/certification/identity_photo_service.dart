import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 证件照取图出口。测试里用假实现替换，页面本身不直接依赖 `image_picker`。
enum IdentityPhotoSource { camera, album }

abstract interface class IdentityPhotoPicker {
  Future<String?> pickFromCamera();

  Future<String?> pickFromAlbum();
}

/// 证件照压缩出口。测试里用假实现替换，避免调用原生编码器。
abstract interface class IdentityPhotoCompressor {
  Future<String?> compressToLimit(String filePath);
}

/// 系统相机 / 相册的默认实现。
///
/// 证件照动辄几 MB，这里在取图时就压到 4096px、质量 85。相册走系统
/// PHPicker 并关闭完整元数据读取：用户只授予本次选中的照片，不需要
/// `NSPhotoLibraryUsageDescription`，与 `peso_shield` 的处理一致。
class DefaultIdentityPhotoPicker implements IdentityPhotoPicker {
  DefaultIdentityPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const int _maximumEdge = 4096;
  static const int _quality = 85;

  final ImagePicker _picker;

  @override
  Future<String?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maximumEdge.toDouble(),
      maxHeight: _maximumEdge.toDouble(),
      imageQuality: _quality,
    );
    return file?.path;
  }

  @override
  Future<String?> pickFromAlbum() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maximumEdge.toDouble(),
      maxHeight: _maximumEdge.toDouble(),
      imageQuality: _quality,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

/// 把证件照压到 500KB 以内，口径与 `peso_shield` 一致。
///
/// 先逐级降 JPEG 质量；仍超限时再按 95% 逐步缩边，直到体积达标或到达
/// 100px 的下限。返回临时文件路径；输入或编码失败时返回 `null`。
class DefaultIdentityPhotoCompressor implements IdentityPhotoCompressor {
  static const int targetBytes = 500 * 1024;

  @override
  Future<String?> compressToLimit(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    if (file.lengthSync() <= targetBytes) return filePath;

    var compressed = file;
    for (var quality = 90; quality >= 10; quality -= 5) {
      final result = await _compress(
        compressed,
        quality: quality,
        keepExif: false,
      );
      if (result == null) return null;
      compressed = result;
      if (compressed.lengthSync() <= targetBytes) return compressed.path;
    }

    final bytes = await compressed.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    var width = frame.image.width;
    var height = frame.image.height;

    while (width > 100 && height > 100) {
      width = (width * 0.95).toInt();
      height = (height * 0.95).toInt();
      final result = await _compress(
        file,
        quality: 95,
        width: width,
        height: height,
      );
      if (result == null) return null;
      compressed = result;
      if (compressed.lengthSync() <= targetBytes) return compressed.path;
    }
    return compressed.path;
  }

  Future<File?> _compress(
    File source, {
    required int quality,
    bool keepExif = true,
    int? width,
    int? height,
  }) async {
    final directory = await getTemporaryDirectory();
    final target =
        '${directory.path}/identity_upload_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';
    // 降质量阶段不能传 0：iOS 插件会按 minWidth/minHeight 计算缩放比例，
    // `0/0` 会把图片缩成 0x0，最终返回空或抛 PlatformException。
    final result = width == null || height == null
        ? await FlutterImageCompress.compressAndGetFile(
            source.path,
            target,
            quality: quality,
            format: CompressFormat.jpeg,
            autoCorrectionAngle: false,
            keepExif: keepExif,
          )
        : await FlutterImageCompress.compressAndGetFile(
            source.path,
            target,
            quality: quality,
            format: CompressFormat.jpeg,
            autoCorrectionAngle: false,
            keepExif: keepExif,
            minWidth: width,
            minHeight: height,
          );
    return result == null ? null : File(result.path);
  }
}
