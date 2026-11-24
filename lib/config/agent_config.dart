/// Base URL of the finance agent backend.
/// The Android emulator reaches the host machine's localhost at 10.0.2.2.
/// Override per run, e.g. for web or a real device:
///   flutter run --dart-define=AGENT_BASE_URL=http://localhost:8000
const String agentBaseUrl = String.fromEnvironment('AGENT_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
