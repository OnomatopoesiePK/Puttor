import { getDatabase } from './database';
import { getBaseline } from '../data/strokesGained';
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

export async function completeRound(id: number): Promise<void> {
  const db = await getDatabase();
  await db.runAsync('UPDATE rounds SET is_complete = 1 WHERE id = ?', [id]);
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
}): Promise<Putt> {
  const db = await getDatabase();
  const baseline = getBaseline(params.distance_m === 0 ? 0.25 : params.distance_m);
  const sg = calculateSG(
    params.distance_m === 0 ? 0.25 : params.distance_m,
    params.result === 'holed'
  );

  const run = await db.runAsync(
    `INSERT INTO putts
       (round_id, hole_number, putt_number, distance_m, side_slope_pct,
        hill_slope_pct, double_break, result, sg_baseline, sg_actual)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      params.round_id, params.hole_number, params.putt_number,
      params.distance_m, params.side_slope_pct, params.hill_slope_pct,
      params.double_break, params.result,
      baseline.makeProbability, sg,
    ]
  );

  return {
    id: run.lastInsertRowId,
    ...params,
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
  }
): Promise<void> {
  const db = await getDatabase();
  const baseline = getBaseline(params.distance_m === 0 ? 0.25 : params.distance_m);
  const sg = calculateSG(
    params.distance_m === 0 ? 0.25 : params.distance_m,
    params.result === 'holed'
  );

  await db.runAsync(
    `UPDATE putts
     SET distance_m=?, side_slope_pct=?, hill_slope_pct=?,
         double_break=?, result=?, sg_baseline=?, sg_actual=?
     WHERE id=?`,
    [
      params.distance_m, params.side_slope_pct, params.hill_slope_pct,
      params.double_break, params.result,
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

// ─── Stats ────────────────────────────────────────────────────────────────────

export interface DistanceBracket {
  bracket: string;
  made: number;
  total: number;
  tourMakePct: number;
}

export interface RoundStats {
  totalPutts: number;
  holes: number;
  avgPuttsPerHole: number;
  sgTotal: number;
  makeByDistance: DistanceBracket[];
  missCounts: Record<string, number>;
  puttsByHole: Record<number, number>;
}

export async function getRoundStats(roundId: number): Promise<RoundStats> {
  const putts = await getPuttsForRound(roundId);

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
    { label: '<1 m',  min: 0,  max: 1  },
    { label: '1–2 m', min: 1,  max: 2  },
    { label: '2–3 m', min: 2,  max: 3  },
    { label: '3–5 m', min: 3,  max: 5  },
    { label: '5–10 m',min: 5,  max: 10 },
    { label: '>10 m', min: 10, max: 999 },
  ];

  const makeByDistance: DistanceBracket[] = BRACKETS.map((b) => {
    const dm = putts.filter((p) => {
      const d = p.distance_m === 0 ? 0.25 : p.distance_m;
      return d >= b.min && d < b.max;
    });
    const made = dm.filter((p) => p.result === 'holed').length;
    const mid  = b.max === 999 ? 15 : (b.min + b.max) / 2;
    return {
      bracket: b.label,
      made,
      total: dm.length,
      tourMakePct: getBaseline(mid).makeProbability * 100,
    };
  });

  const missCounts: Record<string, number> = {};
  for (const p of putts) {
    missCounts[p.result] = (missCounts[p.result] ?? 0) + 1;
  }

  return { totalPutts, holes, avgPuttsPerHole, sgTotal, makeByDistance, missCounts, puttsByHole };
}
