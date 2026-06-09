import React from 'react';
import { View, Text, StyleSheet, SafeAreaView } from 'react-native';
import { colors, spacing } from '../../constants/theme';

export default function GamesTab() {
  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.container}>
        <Text style={styles.icon}>🎯</Text>
        <Text style={styles.title}>Games</Text>
        <Text style={styles.sub}>Putting practice games coming soon.</Text>
        <Text style={styles.hint}>
          {'• Clock\n• Gate game\n• 9-point game\n• Make X in a row'}
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:      { flex: 1, backgroundColor: colors.background },
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.xl, gap: 16 },
  icon:      { fontSize: 56 },
  title:     { fontSize: 28, fontWeight: '800', color: colors.text },
  sub:       { fontSize: 16, color: colors.textSecondary, textAlign: 'center' },
  hint:      { fontSize: 14, color: colors.textMuted, textAlign: 'left', lineHeight: 26 },
});
