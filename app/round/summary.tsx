import React, { useEffect, useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity,
} from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import {
  getRound, getRoundStats, getPuttsForRound,
  Round, RoundStats, Putt,
} from '../../db/queries';
import { colors, spacing, borderRadius } from '../../constants/theme';
import { DistanceMakeChart } from '../../components/DistanceMakeChart';
import { useRoundStore } from '../../store/roundStore';

const RESULT_LABELS: Record<string, string> = {
  holed:       '✅ Holed',
  hole_high:   '🕳️ Hole High',
  short:       '⬇ Short',
  long:        '⬆ Long',
  left:        '⬅ Left',
  right:       '➡ Right',
  short_left:  '↙ Short Left',
  short_right: '↘ Short Right',
  long_left:   '↖ Long Left',
  long_right:  '↗ Long Right',
};

function slopeText(side: number, hill: number): string {
  const sideTxt = side === 0 ? 'Flat' : `${Math.abs(side)}° ${side < 0 ? 'R-L' : 'L-R'}`;
  const hillTxt = hill === 0 ? 'Flat' : `${Math.abs(hill)}° ${hill > 0 ? 'U' : 'D'}`;
  if (side === 0 && hill === 0) return 'Flat';
  return `${sideTxt} / ${hillTxt}`;
}

export default function SummaryScreen() {
  const { roundId: roundIdStr } = useLocalSearchParams<{ roundId: string }>();
  const roundId = Number(roundIdStr);

  const [round, setRound]   = useState<Round | null>(null);
  const [stats, setStats]   = useState<RoundStats | null>(null);
  const [putts, setPutts]   = useState<Putt[]>([]);
  const [expandedHole, setExpandedHole] = useState<number | null>(null);
  const reset = useRoundStore((s) => s.reset);

  useEffect(() => {
    getRound(roundId).then(setRound);
    getRoundStats(roundId).then(setStats);
    getPuttsForRound(roundId).then(setPutts);
  }, [roundId]);

  const puttsByHoleMap = useMemo(() => {
    const map: Record<number, Putt[]> = {};
    for (const p of putts) {
      if (!map[p.hole_number]) map[p.hole_number] = [];
      map[p.hole_number].push(p);
    }
    return map;
  }, [putts]);

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

  const topMiss = Object.entries(stats.missCounts)
    .filter(([k]) => k !== 'holed')
    .sort(([, a], [, b]) => b - a)[0];

  const toggleHole = (h: number) =>
    setExpandedHole((prev) => (prev === h ? null : h));

  const renderHoleCell = (hNum: number) => {
    const count  = stats.puttsByHole[hNum] ?? 0;
    const played = count > 0;
    const isOpen = expandedHole === hNum;

    const bgColor = !played
      ? colors.borderLight
      : count === 1
      ? colors.primary + '33'
      : count >= 3
      ? colors.error + '33'
      : colors.surface;

    const textColor = !played
      ? colors.textMuted
      : count === 1
      ? colors.primary
      : count >= 3
      ? colors.error
      : colors.text;

    return (
      <TouchableOpacity
        key={hNum}
        style={[
          styles.holeCell,
          holeCount === 9 ? styles.holeCellNine : styles.holeCellEighteen,
          { backgroundColor: bgColor },
          isOpen && styles.holeCellOpen,
        ]}
        onPress={() => played && toggleHole(hNum)}
        activeOpacity={played ? 0.7 : 1}
      >
        <Text style={styles.holeCellNum}>{hNum}</Text>
        <Text style={[styles.holeCellCount, { color: textColor }]}>
          {played ? count : '–'}
        </Text>
      </TouchableOpacity>
    );
  };

  const { missReasonCounts: mc, leaveByMissDirection: leave } = stats;
  const hasMissReasons = mc.missRead + mc.badStrike + mc.both > 0;
  const hasLeave = Object.keys(leave).length > 0;
  const holeCount = round.hole_count === 9 ? 9 : 18;

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.navBar}>
        <Text style={styles.navTitle}>Round Summary</Text>
        <TouchableOpacity style={styles.doneBtn} onPress={handleDone}>
          <Text style={styles.doneBtnText}>Done</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>

        {/* Course header */}
        <View style={styles.roundHeader}>
          <Text style={styles.courseName}>{round.course_name || 'Unnamed Course'}</Text>
          <Text style={styles.dateText}>{formatDate(round.date)}</Text>
          {round.putter_name && (
            <Text style={styles.putterTag}>{'🏌️'} {round.putter_name}</Text>
          )}
        </View>

        {/* Key stats row */}
        <View style={styles.row4}>
          <BigStat label="Putts"    value={String(stats.totalPutts)} />
          <BigStat label="Holes"    value={String(stats.holes)} />
          <BigStat label="Avg/Hole" value={stats.avgPuttsPerHole.toFixed(1)} />
          <BigStat
            label="SG"
            value={(stats.sgTotal > 0 ? '+' : '') + stats.sgTotal.toFixed(2)}
            valueColor={sgColor(stats.sgTotal)}
          />
        </View>

        {/* Hole grid */}
        <View style={styles.card}>
          <Text style={styles.cardTitle}>HOLES</Text>
          {holeCount === 9 ? (
            <View style={[styles.holeGrid, styles.holeGridNine]}>
              {Array.from({ length: 9 }, (_, i) => renderHoleCell(i + 1))}
            </View>
          ) : (
            <View style={styles.holeGridEighteenRows}>
              {[0, 1, 2].map((rowIdx) => (
                <View key={`row-${rowIdx}`} style={styles.holeGridEighteenRow}>
                  {Array.from({ length: 6 }, (_, colIdx) => renderHoleCell(rowIdx * 6 + colIdx + 1))}
                </View>
              ))}
            </View>
          )}

          {/* Inline hole detail */}
          {expandedHole !== null && (
            <View style={styles.holeDetail}>
              <Text style={styles.holeDetailTitle}>Hole {expandedHole}</Text>
              {(puttsByHoleMap[expandedHole] ?? [])
                .sort((a, b) => a.putt_number - b.putt_number)
                .map((p) => (
                  <View key={p.id} style={styles.puttRowWrap}>
                    <View style={styles.puttRow}>
                      <Text style={styles.puttNum}>Putt {p.putt_number}</Text>
                      <Text style={styles.puttDist}>{p.distance_m.toFixed(1)}m</Text>
                      <Text
                        style={[
                          styles.puttResult,
                          { color: p.result === 'holed' ? colors.primary : colors.error },
                        ]}
                      >
                        {RESULT_LABELS[p.result] ?? p.result}
                      </Text>
                      <Text
                        style={[
                          styles.puttSG,
                          {
                            color:
                              p.sg_actual > 0
                                ? colors.primary
                                : p.sg_actual < 0
                                ? colors.error
                                : colors.textSecondary,
                          },
                        ]}
                      >
                        {p.sg_actual > 0 ? '+' : ''}{p.sg_actual.toFixed(2)}
                      </Text>
                    </View>
                    <Text style={styles.puttSlope}>{slopeText(p.side_slope_pct, p.hill_slope_pct)}</Text>
                  </View>
                ))}
            </View>
          )}

          <View style={styles.holeLegend}>
            <LegendDot color={colors.primary} label="1 putt" />
            <LegendDot color={colors.text}    label="2 putts" />
            <LegendDot color={colors.error}   label="3+ putts" />
          </View>
        </View>

        {/* Distance make% chart */}
        <View style={styles.card}>
          <DistanceMakeChart data={stats.makeByDistance} />
        </View>

        {/* Miss tendency */}
        {topMiss && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>MISS TENDENCY</Text>
            <Text style={styles.topMissLabel}>
              Most common miss:{' '}
              <Text style={{ color: colors.error }}>
                {RESULT_LABELS[topMiss[0]] ?? topMiss[0]}
              </Text>
              <Text style={{ color: colors.textSecondary }}> ({topMiss[1]}×)</Text>
            </Text>
            <View style={styles.missGrid}>
              {Object.entries(stats.missCounts)
                .filter(([k]) => k !== 'holed')
                .sort(([, a], [, b]) => b - a)
                .map(([k, v]) => (
                  <View key={k} style={styles.missItem}>
                    <Text style={styles.missCount}>{v}×</Text>
                    <Text style={styles.missLabel}>
                      {(RESULT_LABELS[k] ?? k).replace(/^\S+ /, '')}
                    </Text>
                  </View>
                ))}
            </View>
          </View>
        )}

        {/* Miss reasons */}
        {hasMissReasons && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>MISS REASONS</Text>
            <View style={styles.reasonRow}>
              {mc.missRead > 0 && (
                <View style={styles.reasonItem}>
                  <Text style={styles.reasonCount}>{mc.missRead}</Text>
                  <Text style={styles.reasonLabel}>{'Miss\nRead'}</Text>
                </View>
              )}
              {mc.badStrike > 0 && (
                <View style={styles.reasonItem}>
                  <Text style={styles.reasonCount}>{mc.badStrike}</Text>
                  <Text style={styles.reasonLabel}>{'Bad\nStrike'}</Text>
                </View>
              )}
              {mc.both > 0 && (
                <View style={styles.reasonItem}>
                  <Text style={[styles.reasonCount, { color: colors.warning }]}>{mc.both}</Text>
                  <Text style={styles.reasonLabel}>Both</Text>
                </View>
              )}
            </View>
          </View>
        )}

        {/* Leave analysis */}
        {hasLeave && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>LEAVE DISTANCE BY MISS</Text>
            {Object.entries(leave)
              .sort(([, a], [, b]) => b.count - a.count)
              .map(([dir, data]) => (
                <View key={dir} style={styles.leaveRow}>
                  <Text style={styles.leaveDir}>
                    {(RESULT_LABELS[dir] ?? dir).replace(/^\S+ /, '')}
                  </Text>
                  <View style={styles.leaveBarTrack}>
                    <View
                      style={[
                        styles.leaveBar,
                        { width: `${Math.min((data.avgLeaveM / 5) * 100, 100)}%` as any },
                      ]}
                    />
                  </View>
                  <Text style={styles.leaveAvg}>{data.avgLeaveM.toFixed(1)}m</Text>
                  <Text style={styles.leaveCount}>({data.count}×)</Text>
                </View>
              ))}
            <Text style={styles.leaveNote}>avg leave distance per miss direction</Text>
          </View>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function BigStat({
  label, value, valueColor,
}: { label: string; value: string; valueColor?: string }) {
  return (
    <View style={styles.statBox}>
      <Text style={[styles.statValue, valueColor ? { color: valueColor } : undefined]}>
        {value}
      </Text>
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
  safe:        { flex: 1, backgroundColor: colors.background },
  loading:     { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingText: { color: colors.textSecondary, fontSize: 16 },

  navBar: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: spacing.lg, paddingVertical: spacing.md,
    borderBottomWidth: 1, borderBottomColor: colors.border,
  },
  navTitle:    { fontSize: 18, fontWeight: '800', color: colors.text },
  doneBtn:     {
    backgroundColor: colors.primary, borderRadius: borderRadius.sm,
    paddingHorizontal: 18, paddingVertical: 8,
  },
  doneBtnText: { fontSize: 14, fontWeight: '800', color: '#FFF' },

  scroll:  { flex: 1 },
  content: { padding: spacing.lg, gap: spacing.md },

  roundHeader: { gap: 4 },
  courseName:  { fontSize: 22, fontWeight: '800', color: colors.text },
  dateText:    { fontSize: 13, color: colors.textSecondary },
  putterTag:   { fontSize: 13, color: colors.textMuted, marginTop: 2 },

  row4: { flexDirection: 'row', gap: spacing.xs },
  statBox: {
    flex: 1, backgroundColor: colors.surface, borderRadius: borderRadius.md,
    padding: spacing.sm, alignItems: 'center',
    borderWidth: 1, borderColor: colors.border,
  },
  statValue: { fontSize: 20, fontWeight: '900', color: colors.text },
  statLabel: { fontSize: 9, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.6, marginTop: 2 },

  card: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.md, borderWidth: 1, borderColor: colors.border,
    gap: 10, alignItems: 'center',
  },
  cardTitle: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },

  holeGrid: { flexDirection: 'row', flexWrap: 'wrap', width: '100%' },
  holeGridNine: { justifyContent: 'space-between', gap: 6 },
  holeGridEighteenRows: { width: '100%', gap: 6 },
  holeGridEighteenRow: { flexDirection: 'row', justifyContent: 'space-between' },
  holeCell: {
    borderRadius: borderRadius.sm,
    alignItems: 'center', justifyContent: 'center', gap: 2,
    borderWidth: 1, borderColor: colors.border,
  },
  holeCellNine: { width: '31.5%', height: 64 },
  holeCellEighteen: { width: '15.8%', height: 48 },
  holeCellOpen:  { borderColor: colors.accent, borderWidth: 2 },
  holeCellNum:   { fontSize: 9,  color: colors.textMuted, fontWeight: '600' },
  holeCellCount: { fontSize: 18, fontWeight: '900' },

  holeLegend: { flexDirection: 'row', gap: 14, flexWrap: 'wrap', justifyContent: 'center' },

  holeDetail: {
    width: '100%', backgroundColor: colors.surfaceElevated,
    borderRadius: borderRadius.md, padding: spacing.sm,
    borderWidth: 1, borderColor: colors.accent + '55', gap: 6,
  },
  holeDetailTitle: { fontSize: 13, fontWeight: '800', color: colors.accent, marginBottom: 2 },
  puttRowWrap: { gap: 2 },
  puttRow:    { flexDirection: 'row', alignItems: 'center', gap: 8 },
  puttNum:    { fontSize: 11, color: colors.textMuted, width: 44 },
  puttDist:   { fontSize: 12, color: colors.text, fontWeight: '700', width: 40 },
  puttResult: { flex: 1, fontSize: 12, fontWeight: '600' },
  puttSG:     { fontSize: 12, fontWeight: '700', width: 44, textAlign: 'right' },
  puttSlope:  { fontSize: 10, color: colors.textMuted, marginLeft: 52, fontWeight: '700' },

  topMissLabel: { fontSize: 14, color: colors.text, textAlign: 'center' },
  missGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, justifyContent: 'center' },
  missItem: { alignItems: 'center', minWidth: 70 },
  missCount: { fontSize: 22, fontWeight: '800', color: colors.error },
  missLabel: { fontSize: 9, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  reasonRow:   { flexDirection: 'row', gap: spacing.md, justifyContent: 'center' },
  reasonItem:  { alignItems: 'center', minWidth: 64 },
  reasonCount: { fontSize: 28, fontWeight: '900', color: colors.warning },
  reasonLabel: { fontSize: 10, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  leaveRow: { flexDirection: 'row', alignItems: 'center', gap: 8, width: '100%' },
  leaveDir: { width: 72, fontSize: 11, color: colors.textSecondary, fontWeight: '600' },
  leaveBarTrack: {
    flex: 1, height: 8, backgroundColor: colors.borderLight,
    borderRadius: borderRadius.sm, overflow: 'hidden',
  },
  leaveBar:   { height: 8, backgroundColor: colors.accent, borderRadius: borderRadius.sm },
  leaveAvg:   { width: 36, fontSize: 12, fontWeight: '800', color: colors.accent, textAlign: 'right' },
  leaveCount: { width: 32, fontSize: 10, color: colors.textMuted },
  leaveNote:  { fontSize: 10, color: colors.textMuted, fontStyle: 'italic' },
});
