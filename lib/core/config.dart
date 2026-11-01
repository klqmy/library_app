const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);
const sessionMaxSeconds = int.fromEnvironment(
  'SESSION_MAX_SECONDS',
  defaultValue: 1800,
);
