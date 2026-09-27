class FinanceValidationException implements Exception {
  const FinanceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
