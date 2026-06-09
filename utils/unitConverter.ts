export function metresToFeet(m: number): number {
  return m * 3.28084;
}

export function feetToMetres(ft: number): number {
  return ft * 0.3048;
}

export function formatDistance(metres: number, useFeet: boolean): string {
  if (useFeet) {
    if (metres === 0) return '<1 ft';
    const feet = metresToFeet(metres);
    return `${Math.round(feet)} ft`;
  }
  if (metres === 0) return '<0.5 m';
  return `${metres % 1 === 0 ? metres.toFixed(0) : metres.toFixed(1)} m`;
}

// Distance list for DistancePicker (always stored in metres)
// 0.5 m steps up to 7 m, then 1 m steps from 8 m to 30 m
export function getDistanceList(
  useFeet: boolean
): Array<{ value: number; label: string }> {
  const items: Array<{ value: number; label: string }> = [
    { value: 0, label: useFeet ? '<1 ft' : '<0.5 m' },
  ];
  // 0.5 m increments up to 7 m
  for (let m = 0.5; m <= 7.0; m = Math.round((m + 0.5) * 10) / 10) {
    items.push({ value: m, label: formatDistance(m, useFeet) });
  }
  // 1 m increments from 8 m to 30 m
  for (let m = 8; m <= 30; m++) {
    items.push({ value: m, label: formatDistance(m, useFeet) });
  }
  return items;
}
