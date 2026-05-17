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
    expect(await repository.list(onlyDeleted: true), hasLength(1));

    await repository.restore(note.id);
    expect(await repository.list(), hasLength(1));
  });

  test('list separates active and trashed notes', () async {
    final store = FakeVaultStore();
    final repository = NotesRepository(store: store);

    final active = await repository.create(title: 'Active');
    final trashed = await repository.create(title: 'Trashed');
    await repository.moveToTrash(trashed.id);

    final activeOnly = await repository.list();
    expect(activeOnly.map((n) => n.id), [active.id]);

    final trashedOnly = await repository.list(onlyDeleted: true);
    expect(trashedOnly.map((n) => n.id), [trashed.id]);
  });
}
