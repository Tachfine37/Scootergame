/// Small, replayable routes. Every route is available from the start.
class DeliveryStage {
  const DeliveryStage(
    this.name,
    this.subtitle,
    this.seconds,
    this.baseSpeed,
    this.interval,
    this.goal,
    this.twoStars,
    this.threeStars,
  );

  final String name;
  final String subtitle;
  final double seconds;
  final double baseSpeed;
  final double interval;
  final int goal;
  final int twoStars;
  final int threeStars;

  int starsFor(int cargo) => cargo >= threeStars
      ? 3
      : cargo >= twoStars
      ? 2
      : cargo >= goal
      ? 1
      : 0;
}

const deliveryStages = [
  DeliveryStage('Downtown', 'First delivery', 30, 22, 1.03, 5, 10, 16),
  DeliveryStage('Seaside', 'Coastal escape', 35, 25, .95, 7, 13, 20),
  DeliveryStage('Garden District', 'Watch the bumps', 40, 27, .90, 9, 16, 24),
  DeliveryStage('Golden Hour', 'The final express', 45, 30, .85, 11, 19, 28),
];
