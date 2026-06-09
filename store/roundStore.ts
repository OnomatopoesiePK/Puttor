import { create } from 'zustand';
import { Putt, PuttResult } from '../db/queries';

interface PuttDraft {
  distanceM: number;
  sideSlopePct: number;
  hillSlopePct: number;
  doubleBreak: string | null;
  result: PuttResult | null;
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
  addPutt: (putt: Putt) => void;
  updatePuttInStore: (putt: Putt) => void;
  setReviewIndex: (index: number | null) => void;
  goNextHole: () => void;
  reset: () => void;

  // Derived helpers (computed inline)
  puttsOnHole: (hole: number) => number;
  nextPuttNumber: (hole: number) => number;
}

const DEFAULT_DRAFT: PuttDraft = {
  distanceM: 3.0,
  sideSlopePct: 0,
  hillSlopePct: 0,
  doubleBreak: null,
  result: null,
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

  addPutt: (putt) =>
    set((s) => ({ allPutts: [...s.allPutts, putt] })),

  updatePuttInStore: (putt) =>
    set((s) => ({
      allPutts: s.allPutts.map((p) => (p.id === putt.id ? putt : p)),
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
        },
      });
    } else {
      set({ reviewIndex: null, draft: { ...DEFAULT_DRAFT } });
    }
  },

  goNextHole: () =>
    set((s) => ({
      currentHole: s.currentHole + 1,
      reviewIndex: null,
      draft: { ...DEFAULT_DRAFT },
    })),

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
