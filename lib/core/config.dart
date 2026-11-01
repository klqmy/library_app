const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);
// Учебная учётная запись; токен хранится только в памяти приложения.
const apiUsername = String.fromEnvironment(
  'API_USERNAME',
  defaultValue: 'admin',
);
const apiPassword = String.fromEnvironment(
  'API_PASSWORD',
  defaultValue: 'admin123',
);
