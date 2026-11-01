const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '/api');
const sessionMaxSeconds = int.fromEnvironment(
  'SESSION_MAX_SECONDS',
  defaultValue: 1800,
);
