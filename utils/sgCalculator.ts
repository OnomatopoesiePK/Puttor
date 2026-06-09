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
    // Used 1 putt; tour expected baseline.expectedPutts
    return 1 - baseline.expectedPutts;
  } else {
    // Missed — you'll need at least one more putt from the leave distance
    const leave = getTypicalLeave(distanceM);
    const leaveBaseline = getBaseline(leave);
    // SG = putts_used - expected_putts = (1 + leaveBaseline.expectedPutts) - baseline.expectedPutts
    return -((1 + leaveBaseline.expectedPutts) - baseline.expectedPutts);
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
