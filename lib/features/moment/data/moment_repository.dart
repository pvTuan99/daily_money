import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/moment.dart';

class MomentRepository {
  MomentRepository._();

  static final MomentRepository instance = MomentRepository._();

  Future<Directory> _momentsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/moments');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<File> _metadataFile() async {
    final directory = await _momentsDirectory();
    return File('${directory.path}/moments.json');
  }

  Future<List<Moment>> getMoments() async {
    final file = await _metadataFile();

    if (!await file.exists()) {
      return [];
    }

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final moments = decoded
          .whereType<Map<String, dynamic>>()
          .map(Moment.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return moments;
    } on FormatException {
      return [];
    }
  }

  Future<Moment> saveMoment({
    required String sourceImagePath,
    required String caption,
    MomentSpending? spending,
  }) async {
    final source = File(sourceImagePath);
    if (!await source.exists()) {
      throw const FileSystemException('Không tìm thấy ảnh vừa chụp.');
    }

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final directory = await _momentsDirectory();
    final extension = _fileExtension(sourceImagePath);
    final savedImage = await source.copy('${directory.path}/$id.$extension');

    final moment = Moment(
      id: id,
      imagePath: savedImage.path,
      caption: caption.trim(),
      createdAt: now,
      spending: spending,
    );

    final moments = await getMoments();
    final updated = [moment, ...moments];

    await _writeMoments(updated);

    return moment;
  }

  Future<Moment> updateMoment(Moment updatedMoment) async {
    final moments = await getMoments();
    final index = moments.indexWhere((item) => item.id == updatedMoment.id);

    if (index == -1) {
      throw const FileSystemException('Không tìm thấy khoảnh khắc để cập nhật.');
    }

    moments[index] = updatedMoment;
    moments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _writeMoments(moments);
    return updatedMoment;
  }

  Future<void> deleteMoment(Moment moment) async {
    final moments = await getMoments();
    final updated = moments.where((item) => item.id != moment.id).toList();

    await _writeMoments(updated);

    final imageFile = File(moment.imagePath);
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  Future<void> _writeMoments(List<Moment> moments) async {
    final metadata = await _metadataFile();
    await metadata.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        moments.map((item) => item.toJson()).toList(),
      ),
      flush: true,
    );
  }

  String _fileExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return 'jpg';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}
