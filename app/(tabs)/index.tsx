import React, { useEffect, useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity,
  ScrollView, SafeAreaView, RefreshControl, Alert,
} from 'react-native';
import { router } from 'expo-router';
import { deleteRound, getRounds, Round, updateRound } from '../../db/queries';
import { colors, spacing, borderRadius } from '../../constants/theme';
import { useRoundStore } from '../../store/roundStore';

export default function OnCourseTab() {
  const [rounds, setRounds] = useState<Round[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const resetRound = useRoundStore((s) => s.reset);

  const load = useCallback(async () => {
    const data = await getRounds();
    setRounds(data);
  }, []);

  useEffect(() => { load(); }, [load]);

  const refresh = async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  };

  const startNewRound = () => {
    resetRound();
    router.push('/round/setup');
  };

  const openRound = (r: Round) => {
    if (!r.is_complete) {
      router.push(`/round/input?roundId=${r.id}`);
    } else {
      router.push(`/round/summary?roundId=${r.id}`);
    }
  };

  const formatDate = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
  };

  const handleRoundActions = (r: Round) => {
    Alert.alert('Round Actions', r.course_name || 'Unnamed Course', [
      {
        text: 'Bearbeiten',
        onPress: async () => {
          if (r.is_complete) {
            await updateRound(r.id, { is_complete: 0 });
            await load();
          }
          router.push(`/round/input?roundId=${r.id}`);
        },
      },
      {
        text: r.is_complete ? 'Öffnen' : 'Weiterführen',
        onPress: () => openRound(r),
      },
      {
        text: 'Löschen',
        style: 'destructive',
        onPress: async () => {
          await deleteRound(r.id);
          await load();
        },
      },
      { text: 'Abbrechen', style: 'cancel' },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.logo}>Puttor</Text>
        <Text style={styles.subtitle}>On Course</Text>
      </View>

      {/* Start button */}
      <View style={styles.startSection}>
        <TouchableOpacity style={styles.startBtn} onPress={startNewRound} activeOpacity={0.85}>
          <Text style={styles.startIcon}>⛳</Text>
          <Text style={styles.startText}>Start New Round</Text>
        </TouchableOpacity>
      </View>

      {/* Recent rounds */}
      <ScrollView
        style={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.primary} />}
      >
        {rounds.length > 0 && (
          <Text style={styles.sectionTitle}>RECENT ROUNDS</Text>
        )}

        {rounds.map((r) => (
          <TouchableOpacity
            key={r.id}
            style={styles.roundCard}
            onPress={() => openRound(r)}
            activeOpacity={0.8}
          >
            <View style={styles.roundLeft}>
              <Text style={styles.courseName}>{r.course_name || 'Unnamed Course'}</Text>
              <Text style={styles.roundMeta}>
                {formatDate(r.date)}
                {r.putter_name ? `  ·  ${r.putter_name}` : ''}
              </Text>
            </View>
            <View style={styles.roundRight}>
              <TouchableOpacity
                style={styles.menuBtn}
                onPress={() => handleRoundActions(r)}
                hitSlop={10}
              >
                <Text style={styles.menuDots}>⋮</Text>
              </TouchableOpacity>
              <View style={[styles.statusBadge, r.is_complete ? styles.badgeDone : styles.badgeLive]}>
                <Text style={styles.statusText}>{r.is_complete ? 'Complete' : 'In Progress'}</Text>
              </View>
              <Text style={styles.arrowText}>›</Text>
            </View>
          </TouchableOpacity>
        ))}

        {rounds.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>🏌️</Text>
            <Text style={styles.emptyText}>No rounds yet.</Text>
            <Text style={styles.emptySubText}>Hit "Start New Round" to begin tracking.</Text>
          </View>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },

  header: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  logo: {
    fontSize: 30,
    fontWeight: '800',
    color: colors.primary,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textSecondary,
    marginTop: 2,
  },

  startSection: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  startBtn: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.lg,
    paddingVertical: spacing.lg,
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 12,
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 6,
  },
  startIcon: { fontSize: 24 },
  startText: {
    fontSize: 18,
    fontWeight: '800',
    color: '#FFFFFF',
    letterSpacing: 0.3,
  },

  scroll: { flex: 1 },

  sectionTitle: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    fontSize: 11,
    fontWeight: '700',
    color: colors.textMuted,
    letterSpacing: 1.4,
  },

  roundCard: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.sm,
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },

  roundLeft: { flex: 1, gap: 4 },
  courseName: { fontSize: 16, fontWeight: '700', color: colors.text },
  roundMeta:  { fontSize: 13, color: colors.textSecondary },

  roundRight: { flexDirection: 'row', alignItems: 'center', gap: 10 },

  menuBtn: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: borderRadius.full,
    backgroundColor: colors.surfaceElevated,
    borderWidth: 1,
    borderColor: colors.border,
  },
  menuDots: { fontSize: 16, color: colors.textSecondary, fontWeight: '800' },

  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: borderRadius.full,
  },
  badgeDone: { backgroundColor: colors.primary + '22' },
  badgeLive: { backgroundColor: colors.accent + '22' },
  statusText: { fontSize: 11, fontWeight: '700', color: colors.textSecondary },

  arrowText: { fontSize: 22, color: colors.textMuted },

  empty: {
    alignItems: 'center',
    paddingTop: 60,
    gap: 10,
  },
  emptyIcon:    { fontSize: 48 },
  emptyText:    { fontSize: 18, fontWeight: '700', color: colors.text },
  emptySubText: { fontSize: 14, color: colors.textSecondary, textAlign: 'center', paddingHorizontal: 40 },
});
