import { getDatabase } from './database';
import { getBaseline, TOUR_BASELINE } from '../data/strokesGained';
import { calculateSG } from '../utils/sgCalculator';

// ─── Settings ────────────────────────────────────────────────────────────────

export async function getSetting(key: string): Promise<string | null> {
  const db = await getDatabase();
  const row = await db.getFirstAsync<{ value: string }>(
    'SELECT value FROM settings WHERE key = ?',
    [key]
  );
  return row?.value ?? null;
}

export async function setSetting(key: string, value: string): Promise<void> {
  const db = await getDatabase();
  await db.runAsync(
    'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
    [key, value]
  );
}

// ─── Putters ─────────────────────────────────────────────────────────────────

export interface Putter {
  id: number;
  name: string;
  created_at: string;
}

export async function getPutters(): Promise<Putter[]> {
  const db = await getDatabase();
  return db.getAllAsync<Putter>('SELECT * FROM putters ORDER BY name ASC');
}

export async function addPutter(name: string): Promise<number> {
  const db = await getDatabase();
  const result = await db.runAsync('INSERT INTO putters (name) VALUES (?)', [name]);
  return result.lastInsertRowId;
}

export async function deletePutter(id: number): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM putters WHERE id = ?', [id]);
}

// ─── Rounds ───────────────────────────────────────────────────────────────────

export interface Round {
  id: number;
  course_name: string;
  putter_id: number | null;
  stimp: number;
  wind: 'none' | 'medium' | 'high';
  weather: 'cold' | 'warm' | 'hot';
  date: string;
  is_complete: number;
  hole_count: number;
  notes: string;
  putter_name?: string;
}

export async function createRound(params: {
  course_name: string;
  putter_id: number | null;
  stimp: number;
  wind: string;
  weather: string;
}): Promise<number> {
  const db = await getDatabase();
  const result = await db.runAsync(
    `INSERT INTO rounds (course_name, putter_id, stimp, wind, weather)
     VALUES (?, ?, ?, ?, ?)`,
    [params.course_name, params.putter_id, params.stimp, params.wind, params.weather]
  );
  return result.lastInsertRowId;
}

export async function getRounds(): Promise<Round[]> {
  const db = await getDatabase();
  return db.getAllAsync<Round>(`
    SELECT r.*, p.name AS putter_name
    FROM   rounds r
    LEFT JOIN putters p ON r.putter_id = p.id
    ORDER BY r.date DESC
  `);
}

export async function getRound(id: number): Promise<Round | null> {
  const db = await getDatabase();
  return db.getFirstAsync<Round>(`
    SELECT r.*, p.name AS putter_name
    FROM   rounds r
    LEFT JOIN putters p ON r.putter_id = p.id
    WHERE  r.id = ?
  `, [id]);
}

export async function completeRound(id: number, holeCount = 18): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('UPDATE rounds SET is_complete = 1, hole_count = ? WHERE id = ?', [holeCount, id]);
}

export async function updateRound(
  id: number,
  patch: Partial<Pick<Round, 'course_name' | 'putter_id' | 'stimp' | 'wind' | 'weather' | 'notes' | 'is_complete' | 'hole_count'>>
): Promise<void> {
  const db = await getDatabase();
  const keys = Object.keys(patch) as Array<keyof typeof patch>;
  if (keys.length === 0) return;
  const setClause = keys.map((k) => `${k} = ?`).join(', ');
  const values = keys.map((k) => patch[k] as string | number | null);
  await db.runAsync(`UPDATE rounds SET ${setClause} WHERE id = ?`, [...values, id]);
}

export async function deleteRound(id: number): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM putts WHERE round_id = ?', [id]);
  await db.runAsync('DELETE FROM rounds WHERE id = ?', [id]);
}

// ─── Putts ────────────────────────────────────────────────────────────────────

export type PuttResult =
  | 'holed'
  | 'short'
  | 'long'
  | 'left'
  | 'right'
  | 'short_left'
  | 'short_right'
  | 'long_left'
  | 'long_right'
  | 'hole_high';

export interface Putt {
  id: number;
  round_id: number;
  hole_number: number;
  putt_number: number;
  distance_m: number;
  side_slope_pct: number;
  hill_slope_pct: number;
  double_break: string | null;
  result: PuttResult;
  lip_out: number;
  miss_read: number;
  bad_strike: number;
  sg_baseline: number;
  sg_actual: number;
  created_at: string;
}

export async function addPutt(params: {
  round_id: number;
  hole_number: number;
  putt_number: number;
  distance_m: number;
  side_slope_pct: number;
  hill_slope_pct: number;
  double_break: string | null;
  result: PuttResult;
  lip_out?: boolean;
  miss_read?: boolean;
  bad_strike?: boolean;
}): Promise<Putt> {
  const db = await getDatabase();
  const normalizedDistance = params.distance_m < 0.5 ? 0.3 : params.distance_m;
  const baseline = getBaseline(normalizedDistance);
  const sg = calculateSG(
    normalizedDistance,
    params.result === 'holed'
  );

  const run = await db.runAsync(
    `INSERT INTO putts
       (round_id, hole_number, putt_number, distance_m, side_slope_pct,
        hill_slope_pct, double_break, result, lip_out, miss_read, bad_strike,
        sg_baseline, sg_actual)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      params.round_id, params.hole_number, params.putt_number,
      normalizedDistance, params.side_slope_pct, params.hill_slope_pct,
      params.double_break, params.result,
      params.lip_out ? 1 : 0, params.miss_read ? 1 : 0, params.bad_strike ? 1 : 0,
      baseline.makeProbability, sg,
    ]
  );

  return {
    id: run.lastInsertRowId,
    ...params,
    distance_m: normalizedDistance,
    lip_out: params.lip_out ? 1 : 0,
    miss_read: params.miss_read ? 1 : 0,
    bad_strike: params.bad_strike ? 1 : 0,
    sg_baseline: baseline.makeProbability,
    sg_actual: sg,
    created_at: new Date().toISOString(),
  };
}

export async function updatePutt(
  id: number,
  params: {
    distance_m: number;
    side_slope_pct: number;
    hill_slope_pct: number;
    double_break: string | null;
    result: PuttResult;
    lip_out?: boolean;
    miss_read?: boolean;
    bad_strike?: boolean;
  }
): Promise<void> {
  const db = await getDatabase();
  const normalizedDistance = params.distance_m < 0.5 ? 0.3 : params.distance_m;
  const baseline = getBaseline(normalizedDistance);
  const sg = calculateSG(
    normalizedDistance,
    params.result === 'holed'
  );

  await db.runAsync(
    `UPDATE putts
     SET distance_m=?, side_slope_pct=?, hill_slope_pct=?,
         double_break=?, result=?, lip_out=?, miss_read=?, bad_strike=?,
         sg_baseline=?, sg_actual=?
     WHERE id=?`,
    [
      normalizedDistance, params.side_slope_pct, params.hill_slope_pct,
      params.double_break, params.result,
      params.lip_out ? 1 : 0, params.miss_read ? 1 : 0, params.bad_strike ? 1 : 0,
      baseline.makeProbability, sg, id,
    ]
  );
}

export async function getPuttsForRound(roundId: number): Promise<Putt[]> {
  const db = await getDatabase();
  return db.getAllAsync<Putt>(
    'SELECT * FROM putts WHERE round_id = ? ORDER BY hole_number, putt_number',
    [roundId]
  );
}

export async function deletePutt(id: number): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('DELETE FROM putts WHERE id = ?', [id]);
}

export async function deletePuttsAfterOnHole(
  roundId: number,
  holeNumber: number,
  puttNumber: number
): Promise<void> {
  const db = await getDatabase();
  await db.runAsync(
    'DELETE FROM putts WHERE round_id = ? AND hole_number = ? AND putt_number > ?',
    [roundId, holeNumber, puttNumber]
  );
}

// ─── Stats ────────────────────────────────────────────────────────────────────

export interface DistanceBracket {
  bracket: string;
  made: number;
  total: number;
  tourMakePct: number;
  sgTotal: number;
}

export interface RoundStats {
  totalPutts: number;
  holes: number;
  avgPuttsPerHole: number;
  sgTotal: number;
  makeByDistance: DistanceBracket[];
  missCounts: Record<string, number>;
  puttsByHole: Record<number, number>;
  leaveByMissDirection: Record<string, { count: number; avgLeaveM: number }>;
  missReasonCounts: { missRead: number; badStrike: number; both: number };
}

export async function getRoundStats(roundId: number): Promise<RoundStats> {
  const putts = await getPuttsForRound(roundId);

  const averageTourMakePctForInterval = (min: number, max: number) => {
    const baselineMax = TOUR_BASELINE[TOUR_BASELINE.length - 1].distanceM;
    const effectiveMax = max >= 999 ? baselineMax : max;
    const samples: number[] = [];
    for (let d = min; d <= effectiveMax + 1e-9; d += 0.5) {
      samples.push(getBaseline(Number(d.toFixed(1))).makeProbability * 100);
    }
    if (samples.length === 0) return 0;
    return samples.reduce((sum, v) => sum + v, 0) / samples.length;
  };

  const totalPutts = putts.length;
  const holeSet = new Set(putts.map((p) => p.hole_number));
  const holes = holeSet.size;
  const avgPuttsPerHole = holes > 0 ? totalPutts / holes : 0;
  const sgTotal = putts.reduce((s, p) => s + p.sg_actual, 0);

  const puttsByHole: Record<number, number> = {};
  for (const p of putts) {
    puttsByHole[p.hole_number] = (puttsByHole[p.hole_number] ?? 0) + 1;
  }

  const BRACKETS = [
    { label: '0–1m',   min: 0,  max: 1,  mid: 0.5  },
    { label: '1–2m',   min: 1,  max: 2,  mid: 1.5  },
    { label: '2–3m',   min: 2,  max: 3,  mid: 2.5  },
    { label: '3–4m',   min: 3,  max: 4,  mid: 3.5  },
    { label: '4–5m',   min: 4,  max: 5,  mid: 4.5  },
    { label: '5–6m',   min: 5,  max: 6,  mid: 5.5  },
    { label: '6–7m',   min: 6,  max: 7,  mid: 6.5  },
    { label: '7–9m',   min: 7,  max: 9,  mid: 8.0  },
    { label: '9–12m',  min: 9,  max: 12, mid: 10.5 },
    { label: '12–15m', min: 12, max: 15, mid: 13.5 },
    { label: '15–20m', min: 15, max: 20, mid: 17.5 },
    { label: '20+m',   min: 20, max: 999,mid: 25.0 },
  ];

  const makeByDistance: DistanceBracket[] = BRACKETS.map((b) => {
    const dm = putts.filter((p) => {
      const d = p.distance_m < 0.5 ? 0.3 : p.distance_m;
      return d >= b.min && d < b.max;
    });
    const made = dm.filter((p) => p.result === 'holed').length;
    const sgTotal = dm.reduce((sum, p) => sum + p.sg_actual, 0);
    return {
      bracket: b.label,
      made,
      total: dm.length,
      tourMakePct: averageTourMakePctForInterval(b.min, b.max),
      sgTotal,
    };
  });

  const missCounts: Record<string, number> = {};
  for (const p of putts) {
    missCounts[p.result] = (missCounts[p.result] ?? 0) + 1;
  }

  const missReasonCounts = {
    missRead:  putts.filter((p) => p.miss_read === 1 && p.bad_strike === 0).length,
    badStrike: putts.filter((p) => p.bad_strike === 1 && p.miss_read === 0).length,
    both:      putts.filter((p) => p.miss_read === 1 && p.bad_strike === 1).length,
  };

  // Leave-distance analysis: for each non-holed putt, the next putt on the same
  // hole is the "leave". Group by the miss direction of the first putt.
  const byHole: Record<number, Putt[]> = {};
  for (const p of putts) {
    if (!byHole[p.hole_number]) byHole[p.hole_number] = [];
    byHole[p.hole_number].push(p);
  }
  const leaveSamples: Record<string, number[]> = {};
  for (const holePutts of Object.values(byHole)) {
    const byPuttNumber = new Map<number, Putt>();
    for (const p of holePutts) {
      const existing = byPuttNumber.get(p.putt_number);
      if (!existing || p.id > existing.id) byPuttNumber.set(p.putt_number, p);
    }

    const sorted = [...byPuttNumber.values()].sort((a, b) =>
      a.putt_number !== b.putt_number ? a.putt_number - b.putt_number : a.id - b.id
    );
    for (let i = 0; i < sorted.length - 1; i++) {
      const p = sorted[i];
      if (p.result !== 'holed') {
        const next = sorted[i + 1];
        if (!leaveSamples[p.result]) leaveSamples[p.result] = [];
        leaveSamples[p.result].push(Math.max(0.3, next.distance_m));
      }
    }
  }
  const leaveByMissDirection: Record<string, { count: number; avgLeaveM: number }> = {};
  for (const [dir, samples] of Object.entries(leaveSamples)) {
    const count = samples.length;
    const avgLeaveM = count > 0
      ? samples.reduce((sum, v) => sum + v, 0) / count
      : 0;
    leaveByMissDirection[dir] = {
      count,
      avgLeaveM,
    };
  }

  return {
    totalPutts, holes, avgPuttsPerHole, sgTotal,
    makeByDistance, missCounts, puttsByHole,
    leaveByMissDirection, missReasonCounts,
  };
}
