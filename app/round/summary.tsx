import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity,
} from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { getRound, getRoundStats, Round, RoundStats } from '../../db/queries';
import { colors, spacing, borderRadius } from '../../constants/theme';
import { StrokesGainedChart } from '../../components/StrokesGainedChart';
import { useRoundStore } from '../../store/roundStore';

export default function SummaryScreen() {
  const { roundId: roundIdStr } = useLocalSearchParams<{ roundId: string }>();
  const roundId = Number(roundIdStr);

  const [round, setRound]   = useState<Round | null>(null);
  const [stats, setStats]   = useState<RoundStats | null>(null);
  const reset = useRoundStore((s) => s.reset);

  useEffect(() => {
    getRound(roundId).then(setRound);
    getRoundStats(roundId).then(setStats);
  }, [roundId]);

  const handleDone = () => {
    reset();
    router.replace('/(tabs)');
  };

  if (!stats || !round) {
    return (
      <SafeAreaView style={styles.safe}>
        <View style={styles.loading}>
          <Text style={styles.loadingText}>Loading…</Text>
        </View>
      </SafeAreaView>
    );
  }

  const sgColor = (sg: number) =>
    sg > 0.5 ? colors.primary : sg < -0.5 ? colors.error : colors.warning;

  const formatDate = (iso: string) =>
    new Date(iso).toLocaleDateString('en-GB', {
      weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
    });

  const RESULT_LABELS: Record<string, string> = {
    holed:       '✅ Holed',
    hole_high:   '🕳 Lip Out',
    short:       '⬇ Short',
    long:        '⬆ Long',
    left:        '⬅ Left',
    right:       '➡ Right',
    short_left:  '↙ Short Left',
    short_right: '↘ Short Right',
    long_left:   '↖ Long Left',
    long_right:  '↗ Long Right',
  };

  const topMiss = Object.entries(stats.missCounts)
    .filter(([k]) => k !== 'holed')
    .sort(([, a], [, b]) => b - a)[0];

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.navBar}>
        <Text style={styles.navTitle}>Round Summary</Text>
        <TouchableOpacity style={styles.doneBtn} onPress={handleDone}>
          <Text style={styles.doneBtnText}>Done</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>
        {/* Course & date */}
        <View style={styles.roundHeader}>
          <Text style={styles.courseName}>{round.course_name || 'Unnamed Course'}</Text>
          <Text style={styles.dateText}>{formatDate(round.date)}</Text>
          {round.putter_name && (
            <Text style={styles.putterTag}>🏌️ {round.putter_name}</Text>
          )}
        </View>

        {/* Key stats row */}
        <View style={styles.row3}>
          <BigStat label="Putts" value={String(stats.totalPutts)} />
          <BigStat label="Holes" value={String(stats.holes)} />
          <BigStat label="Avg / hole" value={stats.avgPuttsPerHole.toFixed(1)} />
        </View>

        {/* SG card */}
        <View style={styles.sgCard}>
          <Text style={styles.sgLabel}>STROKES GAINED PUTTING</Text>
          <Text style={[styles.sgValue, { color: sgColor(stats.sgTotal) }]}>
            {stats.sgTotal > 0 ? '+' : ''}{stats.sgTotal.toFixed(2)}
          </Text>
          <Text style={styles.sgSub}>vs PGA Tour baseline</Text>
          <Text style={styles.sgDescription}>
            {stats.sgTotal > 1
              ? '🏆 Elite putting performance!'
              : stats.sgTotal > 0
              ? '✅ Above tour average'
              : stats.sgTotal > -1
              ? '⚠️ Slightly below tour average'
              : '❌ Significant improvement available'}
          </Text>
        </View>

        {/* Make % chart */}
        <View style={styles.card}>
          <StrokesGainedChart data={stats.makeByDistance} />
        </View>

        {/* Top miss tendency */}
        {topMiss && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>MISS TENDENCY</Text>
            <Text style={styles.topMissLabel}>
              Most common miss:
              <Text style={{ color: colors.error }}>  {RESULT_LABELS[topMiss[0]] ?? topMiss[0]}</Text>
              <Text style={{ color: colors.textSecondary }}>  ({topMiss[1]}×)</Text>
            </Text>

            <View style={styles.missGrid}>
              {Object.entries(stats.missCounts)
                .filter(([k]) => k !== 'holed')
                .sort(([, a], [, b]) => b - a)
                .map(([k, v]) => (
                  <View key={k} style={styles.missItem}>
                    <Text style={styles.missCount}>{v}×</Text>
                    <Text style={styles.missLabel}>
                      {(RESULT_LABELS[k] ?? k).replace(/^[^ ]+ /, '')}
                    </Text>
                  </View>
                ))}
            </View>
          </View>
        )}

        {/* Putts by hole */}
        {stats.holes > 0 && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>PUTTS PER HOLE</Text>
            <View style={styles.holeGrid}>
              {Object.entries(stats.puttsByHole)
                .sort(([a], [b]) => Number(a) - Number(b))
                .map(([hole, count]) => (
                  <View key={hole} style={styles.holeCell}>
                    <Text style={styles.holeCellNum}>{hole}</Text>
                    <View
                      style={[
                        styles.holeCellBadge,
                        {
                          backgroundColor:
                            count === 1 ? colors.primary + '44' :
                            count >= 3  ? colors.error   + '44' :
                            colors.border,
                        },
                      ]}
                    >
                      <Text style={[
                        styles.holeCellCount,
                        {
                          color:
                            count === 1 ? colors.primary :
                            count >= 3  ? colors.error   :
                            colors.text,
                        },
                      ]}>
                        {count}
                      </Text>
                    </View>
                  </View>
                ))}
            </View>
            <View style={styles.holeLegend}>
              <LegendDot color={colors.primary} label="1 putt" />
              <LegendDot color={colors.text}    label="2 putts" />
              <LegendDot color={colors.error}   label="3+ putts" />
            </View>
          </View>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function BigStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statBox}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
      <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: color }} />
      <Text style={{ fontSize: 11, color: colors.textSecondary }}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  safe:    { flex: 1, backgroundColor: colors.background },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingText: { color: colors.textSecondary, fontSize: 16 },

  navBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: spacing.lg, paddingVertical: spacing.md,
    borderBottomWidth: 1, borderBottomColor: colors.border,
  },
  navTitle:    { fontSize: 18, fontWeight: '800', color: colors.text },
  doneBtn:     { backgroundColor: colors.primary, borderRadius: borderRadius.sm, paddingHorizontal: 18, paddingVertical: 8 },
  doneBtnText: { fontSize: 14, fontWeight: '800', color: '#FFF' },

  scroll:  { flex: 1 },
  content: { padding: spacing.lg, gap: spacing.md },

  roundHeader: { gap: 4 },
  courseName:  { fontSize: 22, fontWeight: '800', color: colors.text },
  dateText:    { fontSize: 13, color: colors.textSecondary },
  putterTag:   { fontSize: 13, color: colors.textMuted, marginTop: 2 },

  row3: { flexDirection: 'row', gap: spacing.sm },
  statBox: {
    flex: 1, backgroundColor: colors.surface, borderRadius: borderRadius.md,
    padding: spacing.md, alignItems: 'center',
    borderWidth: 1, borderColor: colors.border,
  },
  statValue: { fontSize: 28, fontWeight: '900', color: colors.text },
  statLabel: { fontSize: 10, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8, marginTop: 2 },

  sgCard: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.lg, alignItems: 'center',
    borderWidth: 1, borderColor: colors.border, gap: 6,
  },
  sgLabel: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },
  sgValue: { fontSize: 48, fontWeight: '900', letterSpacing: -1 },
  sgSub:   { fontSize: 12, color: colors.textSecondary },
  sgDescription: { fontSize: 14, color: colors.text, marginTop: 4, fontWeight: '600' },

  card: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.md, borderWidth: 1, borderColor: colors.border,
    gap: 12, alignItems: 'center',
  },
  cardTitle: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },

  topMissLabel: { fontSize: 14, color: colors.text, textAlign: 'center' },

  missGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, justifyContent: 'center' },
  missItem: { alignItems: 'center', minWidth: 70 },
  missCount: { fontSize: 22, fontWeight: '800', color: colors.error },
  missLabel: { fontSize: 9, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  holeGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  holeCell: { alignItems: 'center', width: 36 },
  holeCellNum: { fontSize: 10, color: colors.textMuted, marginBottom: 3 },
  holeCellBadge: { width: 32, height: 32, borderRadius: borderRadius.sm, alignItems: 'center', justifyContent: 'center' },
  holeCellCount: { fontSize: 16, fontWeight: '800' },

  holeLegend: { flexDirection: 'row', gap: 16, flexWrap: 'wrap', justifyContent: 'center' },
});
