// PGA Tour strokes gained putting baseline (Mark Broadie methodology)
// Distances in metres, make probability as fraction 0–1
// Converted from standard feet-based PGA Tour data (1 ft = 0.3048 m)

export interface SGBaseline {
  distanceM: number;
  makeProbability: number; // 0–1
  expectedPutts: number;   // average putts to hole out from this distance
}

const TOUR_BASELINE: SGBaseline[] = [
  { distanceM: 0.3,  makeProbability: 0.990, expectedPutts: 1.010 },
  { distanceM: 0.5,  makeProbability: 0.985, expectedPutts: 1.015 },
  { distanceM: 0.6,  makeProbability: 0.975, expectedPutts: 1.025 },
  { distanceM: 0.9,  makeProbability: 0.950, expectedPutts: 1.050 },
  { distanceM: 1.0,  makeProbability: 0.930, expectedPutts: 1.075 },
  { distanceM: 1.2,  makeProbability: 0.900, expectedPutts: 1.105 },
  { distanceM: 1.5,  makeProbability: 0.840, expectedPutts: 1.170 },
  { distanceM: 1.8,  makeProbability: 0.760, expectedPutts: 1.248 },
  { distanceM: 2.0,  makeProbability: 0.700, expectedPutts: 1.310 },
  { distanceM: 2.5,  makeProbability: 0.580, expectedPutts: 1.432 },
  { distanceM: 3.0,  makeProbability: 0.470, expectedPutts: 1.545 },
  { distanceM: 3.5,  makeProbability: 0.380, expectedPutts: 1.635 },
  { distanceM: 4.0,  makeProbability: 0.310, expectedPutts: 1.705 },
  { distanceM: 4.5,  makeProbability: 0.260, expectedPutts: 1.755 },
  { distanceM: 5.0,  makeProbability: 0.220, expectedPutts: 1.795 },
  { distanceM: 6.0,  makeProbability: 0.165, expectedPutts: 1.847 },
  { distanceM: 7.0,  makeProbability: 0.125, expectedPutts: 1.884 },
  { distanceM: 8.0,  makeProbability: 0.095, expectedPutts: 1.912 },
  { distanceM: 9.0,  makeProbability: 0.075, expectedPutts: 1.930 },
  { distanceM: 10.0, makeProbability: 0.060, expectedPutts: 1.944 },
  { distanceM: 12.0, makeProbability: 0.045, expectedPutts: 1.957 },
  { distanceM: 15.0, makeProbability: 0.032, expectedPutts: 1.970 },
  { distanceM: 20.0, makeProbability: 0.022, expectedPutts: 1.980 },
  { distanceM: 25.0, makeProbability: 0.016, expectedPutts: 1.985 },
  { distanceM: 30.0, makeProbability: 0.012, expectedPutts: 1.990 },
];

export function getBaseline(distanceM: number): SGBaseline {
  if (distanceM <= TOUR_BASELINE[0].distanceM) return TOUR_BASELINE[0];
  if (distanceM >= TOUR_BASELINE[TOUR_BASELINE.length - 1].distanceM)
    return TOUR_BASELINE[TOUR_BASELINE.length - 1];

  for (let i = 0; i < TOUR_BASELINE.length - 1; i++) {
    const a = TOUR_BASELINE[i];
    const b = TOUR_BASELINE[i + 1];
    if (distanceM >= a.distanceM && distanceM <= b.distanceM) {
      const t = (distanceM - a.distanceM) / (b.distanceM - a.distanceM);
      return {
        distanceM,
        makeProbability: a.makeProbability + t * (b.makeProbability - a.makeProbability),
        expectedPutts:   a.expectedPutts   + t * (b.expectedPutts   - a.expectedPutts),
      };
    }
  }
  return TOUR_BASELINE[TOUR_BASELINE.length - 1];
}

export { TOUR_BASELINE };
