import { create } from 'zustand';
import { getSetting, setSetting } from '../db/queries';

interface SettingsState {
  units: 'metric' | 'imperial';
  hapticsEnabled: boolean;
  isLoaded: boolean;
  loadSettings: () => Promise<void>;
  setUnits: (units: 'metric' | 'imperial') => Promise<void>;
  setHaptics: (enabled: boolean) => Promise<void>;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  units: 'metric',
  hapticsEnabled: true,
  isLoaded: false,

  loadSettings: async () => {
    const units   = await getSetting('units');
    const haptics = await getSetting('haptics');
    set({
      units: (units as 'metric' | 'imperial') ?? 'metric',
      hapticsEnabled: haptics !== 'false',
      isLoaded: true,
    });
  },

  setUnits: async (units) => {
    await setSetting('units', units);
    set({ units });
  },

  setHaptics: async (enabled) => {
    await setSetting('haptics', enabled ? 'true' : 'false');
    set({ hapticsEnabled: enabled });
  },
}));
