import { Tabs } from 'expo-router';
import { View, Text, StyleSheet } from 'react-native';
import { colors } from '../../constants/theme';

function TabIcon({ emoji, label, focused }: { emoji: string; label: string; focused: boolean }) {
  return (
    <View style={styles.tabIcon}>
      <Text style={[styles.emoji, focused && styles.emojiFocused]}>{emoji}</Text>
      <Text style={[styles.tabLabel, focused && styles.tabLabelFocused]}>{label}</Text>
    </View>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          borderTopWidth: 1,
          height: 80,
          paddingBottom: 16,
        },
        tabBarShowLabel: false,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="⛳" label="ON COURSE" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="games"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="🎯" label="GAMES" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="statistics"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="📊" label="STATS" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon emoji="⚙️" label="SETTINGS" focused={focused} />
          ),
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabIcon: { alignItems: 'center', gap: 3 },
  emoji:        { fontSize: 22, opacity: 0.5 },
  emojiFocused: { opacity: 1 },
  tabLabel:      { fontSize: 9, fontWeight: '600', color: colors.textMuted, letterSpacing: 0.8 },
  tabLabelFocused: { color: colors.primary },
});
