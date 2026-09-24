class DeliveryVehicle {
  const DeliveryVehicle(
    this.name,
    this.unlockDistance,
    this.storage,
    this.loadRating,
    this.handling,
    this.hitPadding,
  );

  final String name;
  final double unlockDistance;

  /// Enclosed parcels cannot spill. Additional parcels stay on the rack.
  final int storage;
  final int loadRating;
  final double handling;
  final double hitPadding;
}

const deliveryVehicles = [
  DeliveryVehicle('City Scooter', 0, 0, 24, 1, 0),
  DeliveryVehicle('Box Scooter', 800, 6, 32, .95, .02),
  DeliveryVehicle('Touring Bike', 1600, 12, 44, .9, .04),
  DeliveryVehicle('Cargo Trike', 2400, 20, 60, .85, .06),
];
