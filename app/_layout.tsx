import { Stack } from 'expo-router';
import { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { useSettingsStore } from '../store/settingsStore';
import { getDatabase } from '../db/database';

export default function RootLayout() {
  const loadSettings = useSettingsStore((s) => s.loadSettings);

  useEffect(() => {
    // Initialise DB then load settings
    getDatabase().then(() => loadSettings());
  }, []);

  return (
    <>
      <StatusBar style="light" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen
          name="round/setup"
          options={{ presentation: 'modal', headerShown: false }}
        />
        <Stack.Screen name="round/input"   options={{ headerShown: false }} />
        <Stack.Screen
          name="round/summary"
          options={{ presentation: 'card', headerShown: false }}
        />
      </Stack>
    </>
  );
}
