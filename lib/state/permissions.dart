import '../models/app_user.dart';

enum Operation {
  viewCatalog,
  manageCatalog,
  manageReaders,
  issueLoan,
  returnLoan,
  ownLoans,
  extendOwnLoan,
  loanDesk,
  manageUsers,
  statistics,
  hardDelete,
  restore,
}

class Permissions {
  static bool allows(Role role, Operation operation) => switch (operation) {
    Operation.viewCatalog => true,
    Operation.manageCatalog ||
    Operation.manageReaders ||
    Operation.issueLoan ||
    Operation.returnLoan => role != Role.reader,
    Operation.ownLoans || Operation.extendOwnLoan => role == Role.reader,
    Operation.loanDesk => role == Role.librarian,
    Operation.manageUsers ||
    Operation.statistics ||
    Operation.hardDelete ||
    Operation.restore => role == Role.admin,
  };
}

String safeDestination(String? from) {
  final uri = Uri.tryParse(from ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      ['/login', '/register'].contains(uri.path)) {
    return '/';
  }
  return uri.toString();
}
