import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/security/encrypted_codec.dart';
import '../../../core/security/secure_key_store.dart';
import '../../../core/storage/vault_paths.dart';
import '../../notes/domain/note_attachment.dart';

class DocumentRepository {
  DocumentRepository({
    VaultPaths? paths,
    SecureKeyStore? keyStore,
    EncryptedCodec? codec,
    Uuid? uuid,
    this.importTypeGroupLabel = 'Import',
    this.documentsTypeGroupLabel = 'Documents',
  })  : _paths = paths ?? const VaultPaths(),
        _keyStore = keyStore ?? SecureKeyStore(),
        _codec = codec ?? EncryptedCodec(),
        _uuid = uuid ?? const Uuid();

  final VaultPaths _paths;
  final SecureKeyStore _keyStore;
  final EncryptedCodec _codec;
  final Uuid _uuid;
  final String importTypeGroupLabel;
  final String documentsTypeGroupLabel;

  Future<XFile?> pickNoteImportFile({String? importLabel}) async {
    return openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: importLabel ?? importTypeGroupLabel,
          extensions: const ['txt', 'md', 'html', 'json'],
        ),
      ],
    );
  }

  Future<NoteAttachment?> pickAndStore({String? documentsLabel}) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: documentsLabel ?? documentsTypeGroupLabel,
          extensions: const ['txt', 'md', 'rtf', 'doc', 'docx', 'pdf'],
        ),
      ],
    );
    if (file == null) {
      return null;
    }
    return store(file);
  }

  Future<NoteAttachment> store(XFile sourceFile) async {
    final bytes = await sourceFile.readAsBytes();
    final id = _uuid.v4();
    final vaultName = '$id.bin.enc';
    final payload = await _codec.encrypt(
      bytes,
      await _keyStore.readOrCreateDocumentKey(),
    );
    final file = await _paths.attachmentFile(vaultName);
    await file.writeAsString(jsonEncode(payload.toJson()), flush: true);

    return NoteAttachment(
      id: id,
      originalName: sourceFile.name,
      vaultName: vaultName,
      sizeBytes: bytes.length,
      createdAt: DateTime.now().toUtc(),
      mimeType: _mimeTypeFor(sourceFile.name),
    );
  }

  Future<List<int>> read(NoteAttachment attachment) async {
    final file = await _paths.attachmentFile(attachment.vaultName);
    final payload = EncryptedPayload.fromJson(
      Map<String, Object?>.from(jsonDecode(await file.readAsString()) as Map),
    );
    return _codec.decrypt(payload, await _keyStore.readOrCreateDocumentKey());
  }

  Future<File> writeToTemp(NoteAttachment attachment) async {
    final bytes = await read(attachment);
    final tempRoot = await Directory.systemTemp.createTemp('notes_app_');
    final base = p.basename(attachment.originalName);
    final safeName = base.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    final fileName = safeName.isEmpty ? '${attachment.id}.bin' : safeName;
    final file = File(p.join(tempRoot.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> openAttachment(NoteAttachment attachment) async {
    final file = await writeToTemp(attachment);
    await _openWithSystem(file.path);
  }

  Future<void> deleteVaultFile(String vaultName) async {
    final file = await _paths.attachmentFile(vaultName);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes [path] only if it lives under the app data directory (never arbitrary user paths).
  Future<void> tryDeleteUnderAppData(String? path) async {
    if (path == null || path.isEmpty) return;
    final normalizedTarget = p.normalize(
      File(_fileUriToPath(path)).absolute.path,
    );
    final root = p.normalize((await _paths.appDirectory()).path);
    if (normalizedTarget == root) return;
    if (!normalizedTarget.startsWith('$root${p.separator}')) {
      return;
    }
    try {
      final f = File(normalizedTarget);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  String _fileUriToPath(String url) {
    if (url.startsWith('file://')) {
      return Uri.parse(url).toFilePath();
    }
    return url;
  }

  Future<void> deleteExportCopyIfManaged(String? exportPath) =>
      tryDeleteUnderAppData(exportPath);

  /// Removes local image files referenced in the Quill delta JSON (only under app data).
  Future<void> deleteInlineImagesFromQuillBody(String body) async {
    if (body.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final insert = item['insert'];
        if (insert is Map && insert['image'] is String) {
          await tryDeleteUnderAppData(insert['image'] as String);
        }
      }
    } catch (_) {}
  }

  Future<String?> pickAndStoreInlineImage({String? imagesLabel}) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: imagesLabel ?? 'Images',
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
        ),
      ],
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final id = _uuid.v4();
    var ext = p.extension(file.name).toLowerCase();
    const allowed = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];
    if (!allowed.contains(ext)) {
      ext = '.png';
    }
    final dir = Directory(
      p.join((await _paths.appDirectory()).path, 'inline_images'),
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final out = File(p.join(dir.path, '$id$ext'));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  /// Stores pasted image bytes under app data. Returns absolute path.
  Future<String> storeInlineImageBytes(
    Uint8List bytes, {
    String fileExtension = '.png',
  }) async {
    var ext = fileExtension.toLowerCase();
    if (!ext.startsWith('.')) {
      ext = '.$ext';
    }
    const allowed = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];
    if (!allowed.contains(ext)) {
      ext = '.png';
    }
    final id = _uuid.v4();
    final dir = Directory(
      p.join((await _paths.appDirectory()).path, 'inline_images'),
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final out = File(p.join(dir.path, '$id$ext'));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  Future<void> _openWithSystem(String path) async {
    if (Platform.isLinux) {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
    } else if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '""', path],
          runInShell: true, mode: ProcessStartMode.detached);
    } else {
      throw UnsupportedError('Attachments cannot be opened on this platform.');
    }
  }

  String? _mimeTypeFor(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.txt':
        return 'text/plain';
      case '.md':
        return 'text/markdown';
      case '.rtf':
        return 'application/rtf';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return null;
  }
}
