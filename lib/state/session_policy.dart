enum SessionEnd { manual, inactivity, duration, expired }

class SessionStatus {
  final SessionEnd? ended;
  final int? warningSeconds;
  const SessionStatus({this.ended, this.warningSeconds});
}

class SessionPolicy {
  final Duration idle;
  final Duration maximum;
  final Duration warning;
  const SessionPolicy({
    this.idle = const Duration(minutes: 3),
    this.maximum = const Duration(minutes: 30),
    this.warning = const Duration(seconds: 30),
  });

  SessionStatus check(DateTime now, DateTime started, DateTime lastActivity) {
    if (!now.isBefore(started.add(maximum))) {
      return const SessionStatus(ended: SessionEnd.duration);
    }
    final remaining = lastActivity.add(idle).difference(now);
    if (remaining <= Duration.zero) {
      return const SessionStatus(ended: SessionEnd.inactivity);
    }
    return SessionStatus(
      warningSeconds: remaining <= warning
          ? (remaining.inMilliseconds / 1000).ceil()
          : null,
    );
  }
}
