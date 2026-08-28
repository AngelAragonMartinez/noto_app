import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  static const _tempDirPrefix = 'noto_attachment_';

  /// Prefix used before the temp directories were tracked and swept.
  static const _legacyTempDirPrefix = 'notes_app_';

  static final DateTime _sessionStart = DateTime.now();

  final List<Directory> _sessionTempDirs = [];
  bool _sweptStaleTempDirs = false;

  /// Windows device names, which cannot be used as file names even with an
  /// extension.
  static const _windowsReservedNames = {
    'CON', 'PRN', 'AUX', 'NUL', //
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Reduces [rawName] to a bare file name safe to create inside a directory
  /// we control and to hand to the OS file launcher.
  ///
  /// Uses an allowlist rather than stripping known-bad characters: an
  /// attachment's name is attacker-influenced (it comes from whatever file the
  /// user was given) and ends up on a command line when the file is opened.
  /// Accented Latin letters are kept so Spanish file names survive intact.
  ///
  /// Returns [fallback] when nothing usable remains.
  @visibleForTesting
  static String safeFileName(String rawName, {required String fallback}) {
    // Keep only the last segment, treating both separators as such on every
    // platform: p.basename ignores '\' on Unix, and an attachment name can
    // have come from any OS.
    var name = rawName.split(RegExp(r'[/\\]')).last;
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-. ()À-ſ]'), '_');
    // Windows silently strips trailing dots and spaces, and a leading dot
    // hides the file on Unix.
    name = name.replaceAll(RegExp(r'^[.\s]+'), '');
    name = name.replaceAll(RegExp(r'[.\s]+$'), '');
    if (name.isEmpty) return fallback;

    if (_windowsReservedNames.contains(
      p.basenameWithoutExtension(name).toUpperCase(),
    )) {
      name = '_$name';
    }

    // Keep well clear of MAX_PATH once joined with the temp directory.
    const maxLength = 120;
    if (name.length > maxLength) {
      final ext = p.extension(name);
      final stem = p.basenameWithoutExtension(name);
      name = stem.substring(0, maxLength - ext.length) + ext;
    }
    return name;
  }

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

  /// Decrypts [attachment] into a private temp directory so the OS can open it
  /// with its default application.
  ///
  /// The copy is plaintext, so it is tracked for deletion: on app exit via
  /// [cleanUpTempFiles], and — for copies a crash left behind — on the next
  /// call here. It cannot be deleted immediately because the external viewer
  /// still holds it open.
  Future<File> writeToTemp(NoteAttachment attachment) async {
    _sweepStaleTempDirs();
    final bytes = await read(attachment);
    final tempRoot = await Directory.systemTemp.createTemp(_tempDirPrefix);
    _sessionTempDirs.add(tempRoot);
    final file = File(
      p.join(
        tempRoot.path,
        safeFileName(attachment.originalName, fallback: '${attachment.id}.bin'),
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Deletes every decrypted copy this session wrote to the temp directory.
  ///
  /// Call when the app is closing. Failures are ignored: a file a viewer still
  /// holds open is picked up by the next run's sweep instead.
  Future<void> cleanUpTempFiles() async {
    for (final dir in _sessionTempDirs) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    }
    _sessionTempDirs.clear();
  }

  /// Deletes decrypted copies left by earlier runs.
  ///
  /// Only directories last modified before this session started are removed,
  /// so a second Noto instance running alongside this one keeps its own files.
  void _sweepStaleTempDirs() {
    if (_sweptStaleTempDirs) return;
    _sweptStaleTempDirs = true;
    try {
      for (final entry in Directory.systemTemp.listSync().whereType<Directory>()) {
        final name = p.basename(entry.path);
        if (!name.startsWith(_tempDirPrefix) &&
            !name.startsWith(_legacyTempDirPrefix)) {
          continue;
        }
        try {
          if (entry.statSync().modified.isBefore(_sessionStart)) {
            entry.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
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
    // p.isWithin applies the platform's path semantics. A manual startsWith
    // compared case-sensitively, so on Windows a target spelled with different
    // casing than the app data root failed the check and the plaintext copy
    // was silently left on disk. isWithin also rejects root itself.
    if (!p.isWithin(root, normalizedTarget)) {
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
      // Never route this through `cmd /c start` with runInShell: cmd would
      // treat &, ^, % and ! inside the file name as syntax, so an attachment
      // named "invoice&calc&.pdf" ran commands. FileProtocolHandler takes the
      // path as a plain argument, with no shell in the chain.
      await Process.start(
        'rundll32',
        ['url.dll,FileProtocolHandler', path],
        mode: ProcessStartMode.detached,
      );
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
