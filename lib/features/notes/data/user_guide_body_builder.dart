import 'dart:convert';

import '../../../app/app_metadata.dart';
import '../../../app/app_strings.dart';

/// JSON delta for the seeded guide note.
String buildUserGuideNoteBodyDeltaJson(AppStrings s) {
  final ops = <Map<String, Object?>>[];

  void boldLine(String text) {
    ops.add({'insert': text, 'attributes': const {'bold': true}});
    ops.add({'insert': '\n'});
  }

  void italicPara(String text) {
    ops.add({'insert': text, 'attributes': const {'italic': true}});
    ops.add({'insert': '\n\n'});
  }

  void paragraph(String text) {
    ops.add({'insert': text});
    ops.add({'insert': '\n\n'});
  }

  void section(String title, String body) {
    boldLine(title);
    paragraph(body.trim());
  }

  italicPara(s.userGuideIntro);

  section(s.welcomeTutorialSectionListTitle, s.welcomeTutorialSectionListBody);
  section(s.welcomeTutorialSectionEditorTitle, s.welcomeTutorialSectionEditorBody);
  section(s.welcomeTutorialSectionVaultTitle, s.welcomeTutorialSectionVaultBody);
  section(s.welcomeTutorialSectionExportTitle, s.welcomeTutorialSectionExportBody);
  section(s.welcomeTutorialSectionTrashTitle, s.welcomeTutorialSectionTrashBody);
  section(s.welcomeTutorialSectionOpenTitle, s.welcomeTutorialSectionOpenBody);
  section(s.welcomeTutorialSectionUiTitle, s.welcomeTutorialSectionUiBody);

  ops.add({'insert': s.userGuideFooterThanksBold, 'attributes': const {'bold': true}});
  ops.add({'insert': s.userGuideFooterThanksRest});

  ops.add({'insert': s.userGuideFooterCreatorLabel, 'attributes': const {'bold': true}});
  ops.add({'insert': ' · '});
  ops.add({
    'insert': kGithubUsername,
    'attributes': {'link': kGithubProfileUrl},
  });
  ops.add({'insert': '\n\n'});

  ops.add({'insert': s.aboutLicenseLabel, 'attributes': const {'bold': true}});
  ops.add({'insert': '\n'});
  ops.add({'insert': kLicenseName});
  ops.add({'insert': '\n'});
  ops.add({'insert': kLicenseCopyright});
  ops.add({'insert': '\n'});

  return jsonEncode(ops);
}
