import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:notes_app/app/notes_app.dart';

void main() {
  testWidgets('renders the notes app without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NotesApp()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
