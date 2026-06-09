import React, { useEffect, useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity, RefreshControl,
} from 'react-native';
import { router } from 'expo-router';
import { getRounds, getRoundStats, Round, RoundStats } from '../../db/queries';
import { colors, spacing, borderRadius } from '../../constants/theme';
import { StrokesGainedChart } from '../../components/StrokesGainedChart';

export default function StatisticsTab() {
  const [rounds, setRounds]   = useState<Round[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [stats, setStats]     = useState<RoundStats | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const data = await getRounds();
    setRounds(data.filter((r) => r.is_complete));
    if (selected === null && data.length > 0 && data[0].is_complete) {
      setSelected(data[0].id);
    }
  }, [selected]);

  useEffect(() => { load(); }, []);

  useEffect(() => {
    if (selected !== null) {
      getRoundStats(selected).then(setStats);
    }
  }, [selected]);

  const refresh = async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  };

  const sgColor = (sg: number) =>
    sg > 0.5 ? colors.primary : sg < -0.5 ? colors.error : colors.warning;

  const formatDate = (iso: string) =>
    new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: '2-digit' });

  return (
    <SafeAreaView style={styles.safe}>
      <Text style={styles.header}>Statistics</Text>

      <ScrollView
        style={styles.scroll}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.primary} />}
      >
        {/* Round selector */}
        {rounds.length > 0 && (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.roundScroll}>
            {rounds.map((r) => (
              <TouchableOpacity
                key={r.id}
                style={[styles.roundChip, selected === r.id && styles.roundChipSel]}
                onPress={() => setSelected(r.id)}
              >
                <Text style={[styles.chipText, selected === r.id && styles.chipTextSel]}>
                  {r.course_name || 'Round'} · {formatDate(r.date)}
                </Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        )}

        {/* Stats */}
        {stats && (
          <View style={styles.statsSection}>
            {/* Summary row */}
            <View style={styles.row3}>
              <StatBox label="Total Putts" value={String(stats.totalPutts)} />
              <StatBox label="Holes" value={String(stats.holes)} />
              <StatBox
                label="Avg/Hole"
                value={stats.avgPuttsPerHole.toFixed(1)}
              />
            </View>

            <View style={styles.sgCard}>
              <Text style={styles.sgLabel}>STROKES GAINED PUTTING</Text>
              <Text style={[styles.sgValue, { color: sgColor(stats.sgTotal) }]}>
                {stats.sgTotal > 0 ? '+' : ''}{stats.sgTotal.toFixed(2)}
              </Text>
              <Text style={styles.sgSub}>vs PGA Tour baseline</Text>
            </View>

            {/* Make % chart */}
            <View style={styles.card}>
              <StrokesGainedChart data={stats.makeByDistance} />
            </View>

            {/* Miss breakdown */}
            <View style={styles.card}>
              <Text style={styles.cardTitle}>MISS PATTERN</Text>
              <View style={styles.missGrid}>
                {Object.entries(stats.missCounts)
                  .filter(([k]) => k !== 'holed')
                  .sort(([, a], [, b]) => b - a)
                  .map(([k, v]) => (
                    <View key={k} style={styles.missItem}>
                      <Text style={styles.missCount}>{v}</Text>
                      <Text style={styles.missLabel}>{k.replace('_', ' ').toUpperCase()}</Text>
                    </View>
                  ))}
              </View>
            </View>

            {/* Putts by hole */}
            <View style={styles.card}>
              <Text style={styles.cardTitle}>PUTTS PER HOLE</Text>
              <View style={styles.holeRow}>
                {Object.entries(stats.puttsByHole)
                  .sort(([a], [b]) => Number(a) - Number(b))
                  .map(([hole, count]) => (
                    <View key={hole} style={styles.holeItem}>
                      <Text style={styles.holeNum}>{hole}</Text>
                      <Text style={[
                        styles.holeCount,
                        { color: count === 1 ? colors.primary : count >= 3 ? colors.error : colors.text }
                      ]}>{count}</Text>
                    </View>
                  ))}
              </View>
            </View>
          </View>
        )}

        {rounds.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>📊</Text>
            <Text style={styles.emptyText}>No completed rounds yet.</Text>
          </View>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function StatBox({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statBox}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  safe:   { flex: 1, backgroundColor: colors.background },
  header: {
    fontSize: 28, fontWeight: '800', color: colors.primary,
    padding: spacing.lg, paddingBottom: spacing.sm,
  },
  scroll: { flex: 1 },

  roundScroll: { paddingLeft: spacing.lg, marginBottom: spacing.sm },
  roundChip: {
    paddingHorizontal: 14, paddingVertical: 8,
    backgroundColor: colors.surface,
    borderRadius: borderRadius.full,
    borderWidth: 1, borderColor: colors.border,
    marginRight: 8,
  },
  roundChipSel: { borderColor: colors.primary, backgroundColor: colors.primary + '22' },
  chipText:    { fontSize: 12, color: colors.textSecondary },
  chipTextSel: { color: colors.primary, fontWeight: '700' },

  statsSection: { padding: spacing.lg, gap: spacing.md },

  row3: { flexDirection: 'row', gap: spacing.sm },
  statBox: {
    flex: 1, backgroundColor: colors.surface, borderRadius: borderRadius.md,
    padding: spacing.md, alignItems: 'center', borderWidth: 1, borderColor: colors.border,
  },
  statValue: { fontSize: 26, fontWeight: '800', color: colors.text },
  statLabel: { fontSize: 10, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8, marginTop: 2 },

  sgCard: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
    gap: 4,
  },
  sgLabel: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },
  sgValue: { fontSize: 40, fontWeight: '900', letterSpacing: -1 },
  sgSub:   { fontSize: 12, color: colors.textSecondary },

  card: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.md, borderWidth: 1, borderColor: colors.border, gap: 12,
    alignItems: 'center',
  },
  cardTitle: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },

  missGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, justifyContent: 'center' },
  missItem: { alignItems: 'center', width: 70 },
  missCount: { fontSize: 22, fontWeight: '800', color: colors.error },
  missLabel: { fontSize: 9, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  holeRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  holeItem: { alignItems: 'center', width: 36 },
  holeNum:  { fontSize: 10, color: colors.textMuted },
  holeCount:{ fontSize: 20, fontWeight: '800' },

  empty: { alignItems: 'center', paddingTop: 80, gap: 12 },
  emptyIcon: { fontSize: 48 },
  emptyText: { fontSize: 16, color: colors.textSecondary },
});
