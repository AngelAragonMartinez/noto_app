import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/features/notes/data/notes_repository.dart';

import '../../../fakes/fake_vault_store.dart';

void main() {
  test('creates, searches, trashes, and restores notes', () async {
    final store = FakeVaultStore();
    final repository = NotesRepository(store: store);

    final note = await repository.create(title: 'Ideas', body: 'Minimal notes');
    await repository.save(note.copyWith(tags: const ['product', 'security']));

    expect(await repository.search('security'), hasLength(1));
    expect(await repository.list(), hasLength(1));

    await repository.moveToTrash(note.id);
    expect(await repository.list(), isEmpty);
    expect(await repository.list(includeDeleted: true), hasLength(1));

    await repository.restore(note.id);
    expect(await repository.list(), hasLength(1));
  });
}
