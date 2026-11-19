import 'suite_lock_store_base.dart';

export 'suite_lock_store_base.dart';

/// Fuera de la web no hay `localStorage`: el desbloqueo vive en memoria.
SuiteLockStore createSuiteLockStore() => MemorySuiteLockStore();
