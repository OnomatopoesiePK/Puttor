import { create } from 'zustand';
import { Putt, PuttResult } from '../db/queries';

interface PuttDraft {
  distanceM: number;
  sideSlopePct: number;
  hillSlopePct: number;
  doubleBreak: string | null;
  result: PuttResult | null;
  lipOut: boolean;
  missRead: boolean;
  badStrike: boolean;
}

interface RoundState {
  roundId: number | null;
  currentHole: number;
  allPutts: Putt[];
  reviewIndex: number | null; // null = entering new putt
  draft: PuttDraft;

  // Actions
  setRound: (id: number) => void;
  setDraft: (patch: Partial<PuttDraft>) => void;
  resetDraft: () => void;
  resetAfterMiss: () => void;
  addPutt: (putt: Putt) => void;
  updatePuttInStore: (putt: Putt) => void;
  removePuttsAfterOnHole: (holeNumber: number, puttNumber: number) => void;
  setReviewIndex: (index: number | null) => void;
  setCurrentHole: (hole: number) => void;
  goNextHole: () => void;
  restartFromHoleOne: () => void;
  reset: () => void;

  // Derived helpers (computed inline)
  puttsOnHole: (hole: number) => number;
  nextPuttNumber: (hole: number) => number;
}

const DEFAULT_DRAFT: PuttDraft = {
  distanceM: 6.0,  // default 6m for first putt
  sideSlopePct: 0,
  hillSlopePct: 0,
  doubleBreak: null,
  result: null,
  lipOut: false,
  missRead: false,
  badStrike: false,
};

const MISS_DRAFT: PuttDraft = {
  distanceM: 0.3,  // <0.5m for subsequent putts
  sideSlopePct: 0,
  hillSlopePct: 0,
  doubleBreak: null,
  result: null,
  lipOut: false,
  missRead: false,
  badStrike: false,
};

export const useRoundStore = create<RoundState>((set, get) => ({
  roundId: null,
  currentHole: 1,
  allPutts: [],
  reviewIndex: null,
  draft: { ...DEFAULT_DRAFT },

  setRound: (id) => set({ roundId: id }),

  setDraft: (patch) =>
    set((s) => ({ draft: { ...s.draft, ...patch } })),

  resetDraft: () => set({ draft: { ...DEFAULT_DRAFT }, reviewIndex: null }),

  resetAfterMiss: () => set({ draft: { ...MISS_DRAFT }, reviewIndex: null }),

  addPutt: (putt) =>
    set((s) => ({ allPutts: [...s.allPutts, putt] })),

  updatePuttInStore: (putt) =>
    set((s) => ({
      allPutts: s.allPutts.map((p) => (p.id === putt.id ? putt : p)),
    })),

  removePuttsAfterOnHole: (holeNumber, puttNumber) =>
    set((s) => ({
      allPutts: s.allPutts.filter(
        (p) => !(p.hole_number === holeNumber && p.putt_number > puttNumber)
      ),
    })),

  setReviewIndex: (index) => {
    const s = get();
    if (index !== null && s.allPutts[index]) {
      const p = s.allPutts[index];
      set({
        reviewIndex: index,
        draft: {
          distanceM:     p.distance_m,
          sideSlopePct:  p.side_slope_pct,
          hillSlopePct:  p.hill_slope_pct,
          doubleBreak:   p.double_break,
          result:        p.result,
          lipOut:        p.lip_out === 1,
          missRead:      p.miss_read === 1,
          badStrike:     p.bad_strike === 1,
        },
      });
    } else {
      set({ reviewIndex: null, draft: { ...DEFAULT_DRAFT } });
    }
  },

  setCurrentHole: (hole) =>
    set((s) => ({
      currentHole: Math.max(1, Math.min(18, hole)),
      reviewIndex: null,
      draft: { ...s.draft },
    })),

  goNextHole: () =>
    set((s) => ({
      currentHole: s.currentHole + 1,
      reviewIndex: null,
      draft: { ...DEFAULT_DRAFT },
    })),

  restartFromHoleOne: () =>
    set({
      currentHole: 1,
      reviewIndex: null,
      draft: { ...DEFAULT_DRAFT },
    }),

  reset: () =>
    set({
      roundId: null,
      currentHole: 1,
      allPutts: [],
      reviewIndex: null,
      draft: { ...DEFAULT_DRAFT },
    }),

  puttsOnHole: (hole) =>
    get().allPutts.filter((p) => p.hole_number === hole).length,

  nextPuttNumber: (hole) => {
    const existing = get().allPutts.filter((p) => p.hole_number === hole);
    return existing.length + 1;
  },
}));
