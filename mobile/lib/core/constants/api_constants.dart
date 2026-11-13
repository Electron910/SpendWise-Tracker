class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );

  static const String demoEmail = 'demo@spendwise.app';
  static const String demoPassword = 'DemoPassword123';
}
