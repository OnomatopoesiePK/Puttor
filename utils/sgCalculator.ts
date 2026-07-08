import { getBaseline } from '../data/strokesGained';

// Typical leave distance after a miss (the remaining putt you're left with)
function getTypicalLeave(distanceM: number): number {
  if (distanceM <= 1.5) return 0.3;
  if (distanceM <= 3.0) return 0.5;
  if (distanceM <= 6.0) return 0.7;
  if (distanceM <= 10.0) return 0.9;
  return 1.2;
}

export function calculateSG(distanceM: number, holed: boolean): number {
  const baseline = getBaseline(distanceM);

  if (holed) {
    // SG = expected_putts_from_here - actual_putts_taken
    // Positive = gained strokes vs tour average
    return baseline.expectedPutts - 1;
  } else {
    // Missed: used 1 putt and left the ball at typical leave distance
    const leave = getTypicalLeave(distanceM);
    const leaveBaseline = getBaseline(leave);
    // SG = starting_expected - (1 putt used + remaining expected)
    return baseline.expectedPutts - (1 + leaveBaseline.expectedPutts);
  }
}

export function calculateRoundSG(
  putts: Array<{ distanceM: number; result: string }>
): number {
  return putts.reduce(
    (total, p) => total + calculateSG(p.distanceM, p.result === 'holed'),
    0
  );
}
