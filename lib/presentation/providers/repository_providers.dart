import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../data/repositories/workspace_repository_impl.dart';
import 'database_providers.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepositoryImpl(ref.watch(appDatabaseProvider));
});
