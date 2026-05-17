import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notes/data/note_export_repository.dart';
import '../features/notes/domain/note.dart';
import 'locale_controller.dart';

/// UI strings for English (default) and Spanish.
class AppStrings {
  AppStrings(Locale locale) : _es = locale.languageCode == 'es';

  final bool _es;

  // —— General
  String get appName => 'Noto';

  String get languageTooltip =>
      _es ? 'Idioma: español (cambiar a inglés)' : 'Language: English (switch to Spanish)';

  // —— Welcome
  String get welcomeTitle => _es ? 'Bienvenido a Noto' : 'Welcome to Noto';

  String get welcomeSubtitle => _es
      ? 'Tus notas viven en este equipo, en una bóveda local cifrada. '
          'No se suben a la nube: tú exportas cuando quieras.'
      : 'Your notes live on this device in an encrypted local vault. '
          'Nothing is uploaded — you export only when you choose.';

  String get welcomeBulletVault => _es
      ? 'Cifrado robusto en disco para la bóveda y los adjuntos.'
      : 'Strong at-rest encryption for your vault and attachments.';

  String get welcomeBulletEditor => _es
      ? 'Texto enriquecido, imágenes en el cuerpo y archivos adjuntos.'
      : 'Rich text, inline images in the body, and vault attachments.';

  String get welcomeBulletExport => _es
      ? 'Exporta a PDF, RTF, Markdown, HTML, texto y más.'
      : 'Export to PDF, RTF, Markdown, HTML, plain text, and more.';

  String get welcomeGuideHintBefore => _es
      ? 'Al continuar aparece en tu lista '
      : 'After you continue, ';

  String get welcomeGuideHintAfter => _es
      ? ' con la guía completa. Ábrela cuando quieras.'
      : ' appears in your list with the full walkthrough. Open it anytime.';

  String get welcomeTutorialSectionListTitle =>
      _es ? 'Lista de notas y papelera' : 'Note list and trash';

  String get welcomeTutorialSectionListBody => _es
      ? 'A la izquierda tienes las pestañas Notas y Papelera, un buscador y el botón para crear una nota nueva. '
          'Toca una nota para abrirla. En pantallas estrechas puedes ocultar o mostrar el panel con el icono de la barra lateral en la parte superior.'
      : 'On the left: Notes and Trash tabs, a search field, and a button to create a new note. '
          'Tap a note to open it. On narrow screens you can hide or show the side panel with the sidebar icon in the top bar.';

  String get welcomeTutorialSectionEditorTitle =>
      _es ? 'Editor de la nota' : 'Note editor';

  String get welcomeTutorialSectionEditorBody => _es
      ? 'Escribe el título y las etiquetas (separadas por comas) encima del texto. '
          'La barra de formato incluye estilos, listas, citas, bloques de código, alineación, interlineado y enlace. '
          'El icono de imagen inserta fotos en el cuerpo: se ven en la nota y se pueden incrustar al exportar. '
          'Adjuntar añade archivos a la nota cifrados en la bóveda (distinto de las imágenes del texto). '
          'Buscar permite localizar y reemplazar texto en la nota.'
      : 'Edit the title and tags (comma-separated) above the body. '
          'The format bar includes styles, lists, quotes, code blocks, alignment, line spacing, and links. '
          'The image button inserts pictures in the body—they display in the note and can be embedded on export. '
          'Attach adds vault-encrypted files to the note (separate from inline images). '
          'Find lets you search and replace text in the note.';

  String get welcomeTutorialSectionVaultTitle =>
      _es ? 'Bóveda y cuándo se guarda' : 'Vault and when data is saved';

  String get welcomeTutorialSectionVaultBody => _es
      ? 'Las notas viven en una bóveda cifrada en tu equipo. Los cambios se mantienen en pantalla hasta que los vuelcas al almacenamiento: '
          'al usar Guardar o Guardar como (exportas y se actualiza la bóveda), al cerrar Noto y elegir Guardar en el aviso, '
          'o al pasar a otra nota y confirmar que quieres guardar. Si sales sin guardar, puedes perder el trabajo no volcado.'
      : 'Notes live in an encrypted vault on your device. Edits stay in memory until you persist them: '
          'use Save or Save as (export also updates the vault), quit and choose Save in the prompt, '
          'or switch notes and confirm you want to save. Closing without saving can lose unsaved work.';

  String get welcomeTutorialSectionExportTitle =>
      _es ? 'Exportar (Word, PDF, etc.)' : 'Export (Word, PDF, etc.)';

  String get welcomeTutorialSectionExportBody => _es
      ? 'Guardar como abre el cuadro de diálogo del sistema y permite elegir formato: PDF, RTF, HTML, Markdown, texto plano, JSON, etc. '
          'Guardar repite la última exportación en la misma ruta. Para abrir en Word o LibreOffice suelen ir bien RTF y HTML; las imágenes del texto se incrustan en HTML, RTF y PDF cuando es posible.'
      : 'Save as opens the system dialog and lets you pick a format: PDF, RTF, HTML, Markdown, plain text, JSON, and more. '
          'Save writes again to your last export path. For Word or LibreOffice, RTF and HTML work well; inline images are embedded in HTML, RTF, and PDF when possible.';

  String get welcomeTutorialSectionTrashTitle =>
      _es ? 'Papelera y archivos en el disco' : 'Trash and files on disk';

  String get welcomeTutorialSectionTrashBody => _es
      ? 'Mover a la papelera oculta la nota de la lista principal; puedes restaurarla o borrarla para siempre desde la pestaña Papelera. '
          'Al borrar definitivamente, Noto elimina la nota de la bóveda y, dentro de su carpeta de datos, copias guardadas ahí (por ejemplo en la carpeta exports) e imágenes incrustadas en notas. '
          'Si exportaste un archivo a otra carpeta fuera de Noto, esa copia no se borra sola.'
      : 'Move to trash removes the note from the main list; you can restore or permanently delete it from the Trash tab. '
          'Permanent delete removes the note from the vault and, inside Noto’s data folder, copies saved there (e.g. the exports folder) and images embedded in notes. '
          'If you exported a file to some other folder, that copy is not deleted automatically.';

  String get welcomeTutorialSectionOpenTitle =>
      _es ? 'Abrir e importar' : 'Open and import';

  String get welcomeTutorialSectionOpenBody => _es
      ? 'El menú Abrir permite elegir un archivo (texto, Markdown, HTML, JSON…) y crear una nota nueva a partir de él. También puedes reabrir rutas recientes desde el mismo menú.'
      : 'The Open menu picks a file (text, Markdown, HTML, JSON, …) and creates a new note from it. You can also reopen recent paths from that menu.';

  String get welcomeTutorialSectionUiTitle =>
      _es ? 'Interfaz e información' : 'Interface and help';

  String get welcomeTutorialSectionUiBody => _es
      ? 'Puedes cambiar entre tema claro y oscuro, alternar español e inglés, y abrir Acerca de para la versión y el enlace al creador. '
          'El icono de la lista en la barra de la nota compacta u oculta el panel lateral en vistas anchas.'
      : 'Switch light or dark theme, toggle English and Spanish, and open About for version and author links. '
          'The list icon on the note bar can hide or show the side panel on wide layouts.';

  String get welcomeContinue => _es ? 'Continuar' : 'Continue';

  String get userGuideNoteTitle =>
      _es ? 'Noto — Guía de uso' : 'Noto — User guide';

  String get userGuideLegacyTitleEn => 'Guide: how to use Noto';

  String get userGuideLegacyTitleEs => 'Guía: cómo usar Noto';

  String get userGuideIntro => _es
      ? 'Una guía clara para dominar Noto. Puedes conservarla, editarla o borrarla: es tuya.'
      : 'A calm, skimmable tour of Noto. Keep it, edit it, or delete it — it\'s yours.';

  String get userGuideFooterThanksBold => _es ? 'Gracias' : 'Thank you';

  String get userGuideFooterThanksRest => _es
      ? ' por usar Noto.\n\n'
      : ' for using Noto.\n\n';

  String get userGuideFooterCreatorLabel => _es ? 'Autor' : 'Creator';

  String get aboutTagline => _es
      ? 'Notas en tu equipo. Cifradas por defecto.'
      : 'Notes on your device. Encrypted by default.';

  // —— About
  String get aboutVersionLine => _es ? 'Versión' : 'Version';

  String get aboutCreatedBy => _es ? 'Creado por' : 'Created by';

  String get aboutSourceCode => _es ? 'Código fuente' : 'Source code';

  String get aboutLicenseLabel => _es ? 'Licencia' : 'License';

  String get aboutClose => _es ? 'Cerrar' : 'Close';

  // —— Home / notes
  String get hideSidebar => _es ? 'Ocultar panel lateral' : 'Hide sidebar';

  String get showSidebar => _es ? 'Mostrar panel lateral' : 'Show sidebar';

  String get lightMode => _es ? 'Modo claro' : 'Light mode';

  String get darkMode => _es ? 'Modo oscuro' : 'Dark mode';

  String get themeTooltipSystem =>
      _es ? 'Seguir el tema del sistema (toca para modo claro)' : 'Match system theme (tap for light mode)';

  String get themeTooltipLight =>
      _es ? 'Modo claro fijado (toca para oscuro)' : 'Light mode (tap for dark)';

  String get themeTooltipDark =>
      _es ? 'Modo oscuro fijado (toca para seguir al sistema)' : 'Dark mode (tap to follow system again)';

  String get newNote => _es ? 'Nota nueva' : 'New note';

  String get about => _es ? 'Acerca de' : 'About';

  String get openMenu => _es ? 'Abrir' : 'Open';

  String get openFile => _es ? 'Abrir archivo…' : 'Open file…';

  String get noRecentFiles => _es ? 'Sin archivos recientes' : 'No recent files';

  String get dismissBanner => _es ? 'Cerrar aviso' : 'Dismiss';

  String get search => _es ? 'Buscar' : 'Search';

  String get notesTab => _es ? 'Notas' : 'Notes';

  String get trashTab => _es ? 'Papelera' : 'Trash';

  String get trashEmpty => _es ? 'La papelera está vacía' : 'Trash is empty';

  String get noNotesYet => _es ? 'Aún no hay notas' : 'No notes yet';

  String get trashEmptyHint =>
      _es ? 'Las notas eliminadas aparecen aquí.' : 'Deleted notes show up here.';

  String get createFirstNote =>
      _es ? 'Crea tu primera nota.' : 'Create your first note.';

  String get untitled => _es ? 'Sin título' : 'Untitled';

  String get notePreviewEmpty => _es ? 'Vacío' : 'Empty';

  String get saveChangesTitle => _es ? '¿Guardar cambios?' : 'Save changes?';

  String get saveChangesBody => _es
      ? 'Esta nota tiene cambios sin guardar. ¿Qué quieres hacer?'
      : 'This note has unsaved changes. What would you like to do?';

  String get quitSaveTitle => _es
      ? '¿Quiere guardar los cambios?'
      : 'Do you want to save your changes?';

  String get quitSaveDescription => _es
      ? 'Los documentos abiertos contienen cambios sin guardar. '
          'Los cambios que no se guarden se perderán de forma permanente.'
      : 'Open notes have unsaved changes. '
          'Any changes you do not save will be permanently lost.';

  String get discardChangesQuit => _es ? 'Descartar' : 'Discard';

  String get noteOnlyInVaultSubtitle => _es
      ? 'Solo en la bóveda de Noto (sin exportar)'
      : 'In Noto vault only (not exported)';

  String get insertImageTooltip =>
      _es ? 'Insertar imagen' : 'Insert image';

  String get undoTooltip => _es ? 'Deshacer' : 'Undo';

  String get redoTooltip => _es ? 'Rehacer' : 'Redo';

  String get cancel => _es ? 'Cancelar' : 'Cancel';

  String get dontSave => _es ? 'No guardar' : "Don't save";

  String get save => _es ? 'Guardar' : 'Save';

  String get titleHint => _es ? 'Título' : 'Title';

  String get inTrashLine => _es ? 'En la papelera ·' : 'In trash ·';

  String get updatedPrefix => _es ? 'Actualizado' : 'Updated';

  String get tagsHint =>
      _es ? 'Etiquetas (separadas por comas)' : 'Tags (comma-separated)';

  String get editorPlaceholder =>
      _es ? 'Empieza a escribir…' : 'Start writing…';

  String get attachments => _es ? 'Adjuntos' : 'Attachments';

  String get removeAttachmentTitle =>
      _es ? 'Quitar adjunto' : 'Remove attachment';

  String removeAttachmentBody(String name) => _es
      ? '¿Quitar «$name» de esta nota? Esta acción no se puede deshacer.'
      : 'Remove "$name" from this note? This cannot be undone.';

  String get remove => _es ? 'Quitar' : 'Remove';

  String get back => _es ? 'Atrás' : 'Back';

  String get trashToolbar => _es ? 'Papelera' : 'Trash';

  String get findReplace => _es ? 'Buscar y reemplazar (Ctrl+F)' : 'Find & replace (Ctrl+F)';

  String get attach => _es ? 'Adjuntar' : 'Attach';

  String get saveAs => _es ? 'Guardar como' : 'Save as';

  String get moveToTrash => _es ? 'Mover a la papelera' : 'Move to trash';

  String get closeNoteConfirmTitle =>
      _es ? '¿Quitar esta nota de Noto?' : 'Remove this note from Noto?';

  String closeNoteConfirmBody(String displayTitle) => _es
      ? '«$displayTitle» dejará de aparecer en Noto.'
      : '«$displayTitle» will no longer appear in Noto.';

  String get closeNoteConfirmAction =>
      _es ? 'Quitar de Noto' : 'Remove from Noto';

  String get closeNoteListTooltip =>
      _es ? 'Quitar de Noto' : 'Remove from Noto';

  String get restore => _es ? 'Restaurar' : 'Restore';

  String get deleteForever => _es ? 'Eliminar para siempre' : 'Delete forever';

  String get pickANote => _es ? 'Elige una nota' : 'Pick a note';

  String get pickANoteHint =>
      _es ? 'O crea una para empezar a escribir.' : 'Or create one to start writing.';

  String get openAttachment => _es ? 'Abrir' : 'Open';

  String get removeAttachmentAction =>
      _es ? 'Quitar adjunto' : 'Remove attachment';

  String get attachmentChipTooltip => _es
      ? 'Abrir adjunto · clic derecho o mantener para opciones'
      : 'Open attachment · right-click or long-press for options';

  String get findHideReplace => _es ? 'Ocultar reemplazo' : 'Hide replace row';

  String get findShowReplace => _es ? 'Mostrar reemplazo' : 'Show replace row';

  String get noMatches => _es ? 'Sin coincidencias' : 'No matches';

  String get matchCase => _es ? 'Mayúsculas' : 'Match case';

  String get previousMatch => _es ? 'Anterior' : 'Previous';

  String get nextMatch => _es ? 'Siguiente' : 'Next';

  String get closeFind => _es ? 'Cerrar (Esc)' : 'Close (Esc)';

  String get replaceWithHint =>
      _es ? 'Reemplazar por' : 'Replace with';

  String get replace => _es ? 'Reemplazar' : 'Replace';

  String get replaceAll => _es ? 'Todo' : 'All';

  // —— File picker type groups
  String get fileFilterImport => _es ? 'Importar' : 'Import';

  String get fileFilterDocuments => _es ? 'Documentos' : 'Documents';

  // —— Controller / flash messages
  String get fileMissingRecents => _es
      ? 'El archivo ya no está ahí — quitado de recientes'
      : 'File is no longer there — removed from recents';

  String openedFile(String name) =>
      _es ? 'Abierto: $name' : 'Opened: $name';

  String attachmentRemoved(String name) => _es
      ? 'Adjunto quitado: $name'
      : 'Attachment removed: $name';

  String attachmentSaved(String name) => _es
      ? 'Adjunto guardado (cifrado): $name'
      : 'Attachment saved (encrypted): $name';

  String savedToPath(String path) =>
      _es ? 'Guardado en $path' : 'Saved to $path';

  String exportFormatLabel(NoteExportFormat f) {
    switch (f) {
      case NoteExportFormat.txt:
        return _es ? 'Texto plano' : 'Plain text';
      case NoteExportFormat.markdown:
        return 'Markdown';
      case NoteExportFormat.rtf:
        return _es ? 'RTF (Word / LibreOffice)' : 'RTF (Word / LibreOffice)';
      case NoteExportFormat.pdf:
        return 'PDF';
      case NoteExportFormat.html:
        return 'HTML';
      case NoteExportFormat.json:
        return 'JSON';
    }
  }
}

String notePreviewLine(Note note, AppStrings s) {
  final text = note.bodyPlainText.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return s.notePreviewEmpty;
  return text.length <= 120 ? text : '${text.substring(0, 120)}...';
}

final appStringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(localeControllerProvider));
});
