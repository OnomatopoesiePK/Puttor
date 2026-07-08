import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity, RefreshControl, ActivityIndicator,
} from 'react-native';
import {
  getRounds, getRoundStats, getPutters,
  getPuttsForRound, Round, RoundStats, Putter, DistanceBracket, Putt,
} from '../../db/queries';
import { colors, spacing, borderRadius } from '../../constants/theme';
import { DistanceMakeChart } from '../../components/DistanceMakeChart';
import { DispersionFilter, MissDispersionPlot } from '../../components/MissDispersionPlot';

type FilterMode = 'last1' | 'last3' | 'last5' | 'last10' | 'all' | 'byPutter';

const FILTER_LABELS: { mode: FilterMode; label: string }[] = [
  { mode: 'last1',    label: 'Last 1'    },
  { mode: 'last3',    label: 'Last 3'    },
  { mode: 'last5',    label: 'Last 5'    },
  { mode: 'last10',   label: 'Last 10'   },
  { mode: 'all',      label: 'All Rounds'},
  { mode: 'byPutter', label: 'By Putter' },
];

const RESULT_LABELS: Record<string, string> = {
  hole_high:   'Hole High',
  short:       'Short',
  long:        'Long',
  left:        'Left',
  right:       'Right',
  short_left:  'Short Left',
  short_right: 'Short Right',
  long_left:   'Long Left',
  long_right:  'Long Right',
};

function computeLeaveByMissDirection(putts: Putt[]): Record<string, { count: number; avgLeaveM: number }> {
  const byHole: Record<string, Putt[]> = {};
  for (const p of putts) {
    const key = `${p.round_id}-${p.hole_number}`;
    if (!byHole[key]) byHole[key] = [];
    byHole[key].push(p);
  }

  const leaveSamples: Record<string, number[]> = {};
  for (const holePutts of Object.values(byHole)) {
    const byPuttNumber = new Map<number, Putt>();
    for (const p of holePutts) {
      const existing = byPuttNumber.get(p.putt_number);
      if (!existing || p.id > existing.id) byPuttNumber.set(p.putt_number, p);
    }

    const sorted = [...byPuttNumber.values()].sort((a, b) =>
      a.putt_number !== b.putt_number ? a.putt_number - b.putt_number : a.id - b.id
    );
    for (let i = 0; i < sorted.length - 1; i++) {
      const p = sorted[i];
      if (p.result === 'holed') continue;
      const next = sorted[i + 1];
      if (!leaveSamples[p.result]) leaveSamples[p.result] = [];
      leaveSamples[p.result].push(Math.max(0.3, next.distance_m));
    }
  }

  const out: Record<string, { count: number; avgLeaveM: number }> = {};
  for (const [dir, samples] of Object.entries(leaveSamples)) {
    const count = samples.length;
    const avgLeaveM = count > 0
      ? samples.reduce((sum, v) => sum + v, 0) / count
      : 0;
    out[dir] = {
      count,
      avgLeaveM,
    };
  }
  return out;
}

function mergeStats(list: RoundStats[]): RoundStats {
  if (list.length === 0) {
    return {
      totalPutts: 0, holes: 0, avgPuttsPerHole: 0, sgTotal: 0,
      makeByDistance: [], missCounts: {}, puttsByHole: {},
      leaveByMissDirection: {}, missReasonCounts: { missRead: 0, badStrike: 0, both: 0 },
    };
  }

  const totalPutts      = list.reduce((s, r) => s + r.totalPutts, 0);
  const holes           = list.reduce((s, r) => s + r.holes, 0);
  const sgTotal         = list.reduce((s, r) => s + r.sgTotal, 0);
  const avgPuttsPerHole = holes > 0 ? totalPutts / holes : 0;

  const makeByDistance: DistanceBracket[] = list[0].makeByDistance.map((b, i) => ({
    bracket:     b.bracket,
    made:        list.reduce((s, r) => s + (r.makeByDistance[i]?.made  ?? 0), 0),
    total:       list.reduce((s, r) => s + (r.makeByDistance[i]?.total ?? 0), 0),
    tourMakePct: b.tourMakePct,
    sgTotal:     list.reduce((s, r) => s + (r.makeByDistance[i]?.sgTotal ?? 0), 0),
  }));

  const missCounts: Record<string, number> = {};
  for (const r of list) {
    for (const [k, v] of Object.entries(r.missCounts)) {
      missCounts[k] = (missCounts[k] ?? 0) + v;
    }
  }

  const missReasonCounts = {
    missRead:  list.reduce((s, r) => s + r.missReasonCounts.missRead,  0),
    badStrike: list.reduce((s, r) => s + r.missReasonCounts.badStrike, 0),
    both:      list.reduce((s, r) => s + r.missReasonCounts.both,      0),
  };

  const leaveAcc: Record<string, { totalDist: number; count: number }> = {};
  for (const r of list) {
    for (const [dir, data] of Object.entries(r.leaveByMissDirection)) {
      if (!leaveAcc[dir]) leaveAcc[dir] = { totalDist: 0, count: 0 };
      leaveAcc[dir].totalDist += data.avgLeaveM * data.count;
      leaveAcc[dir].count     += data.count;
    }
  }
  const leaveByMissDirection: Record<string, { count: number; avgLeaveM: number }> = {};
  for (const [dir, acc] of Object.entries(leaveAcc)) {
    leaveByMissDirection[dir] = {
      count: acc.count,
      avgLeaveM: acc.count > 0 ? acc.totalDist / acc.count : 0,
    };
  }

  return {
    totalPutts, holes, avgPuttsPerHole, sgTotal,
    makeByDistance, missCounts, puttsByHole: {},
    leaveByMissDirection, missReasonCounts,
  };
}

export default function StatisticsTab() {
  const [allRounds,        setAllRounds]        = useState<Round[]>([]);
  const [putters,          setPutters]          = useState<Putter[]>([]);
  const [filterMode,       setFilterMode]       = useState<FilterMode>('last5');
  const [selectedPutterId, setSelectedPutterId] = useState<number | null>(null);
  const [roundStats,       setRoundStats]       = useState<Record<number, RoundStats>>({});
  const [loading,          setLoading]          = useState(false);
  const [refreshing,       setRefreshing]       = useState(false);
  const [roundPutts,       setRoundPutts]       = useState<Record<number, Putt[]>>({});
  const [dispersionFilter, setDispersionFilter] = useState<DispersionFilter>('all');
  const [dispersionOpen,   setDispersionOpen]   = useState(false);

  const load = useCallback(async () => {
    const [rounds, pts] = await Promise.all([getRounds(), getPutters()]);
    const complete = rounds.filter((r) => r.is_complete);
    setAllRounds(complete);
    setPutters(pts);
    if (pts.length > 0 && selectedPutterId === null) setSelectedPutterId(pts[0].id);
    return complete;
  }, [selectedPutterId]);

  useEffect(() => { load(); }, []);

  const filteredRounds = useMemo(() => {
    switch (filterMode) {
      case 'last1':    return allRounds.slice(0, 1);
      case 'last3':    return allRounds.slice(0, 3);
      case 'last5':    return allRounds.slice(0, 5);
      case 'last10':   return allRounds.slice(0, 10);
      case 'byPutter': return selectedPutterId
        ? allRounds.filter((r) => r.putter_id === selectedPutterId)
        : allRounds;
      default:         return allRounds;
    }
  }, [allRounds, filterMode, selectedPutterId]);

  useEffect(() => {
    const missing = filteredRounds.filter((r) => !roundStats[r.id]);
    if (missing.length === 0) return;
    setLoading(true);
    Promise.all(missing.map((r) => getRoundStats(r.id).then((s) => [r.id, s] as const)))
      .then((entries) => {
        setRoundStats((prev) => {
          const next = { ...prev };
          for (const [id, s] of entries) next[id] = s;
          return next;
        });
      })
      .finally(() => setLoading(false));
  }, [filteredRounds]);

  useEffect(() => {
    const missing = filteredRounds.filter((r) => !roundPutts[r.id]);
    if (missing.length === 0) return;
    Promise.all(missing.map((r) => getPuttsForRound(r.id).then((p) => [r.id, p] as const))).then(
      (entries) => {
        setRoundPutts((prev) => {
          const next = { ...prev };
          for (const [id, p] of entries) next[id] = p;
          return next;
        });
      }
    );
  }, [filteredRounds, roundPutts]);

  const aggregated = useMemo(() => {
    const available = filteredRounds
      .map((r) => roundStats[r.id])
      .filter((s): s is RoundStats => !!s);
    return mergeStats(available);
  }, [filteredRounds, roundStats]);

  const sgAverage = useMemo(() => {
    const available = filteredRounds
      .map((r) => roundStats[r.id])
      .filter((s): s is RoundStats => !!s);
    if (available.length === 0) return 0;
    const total = available.reduce((sum, s) => sum + s.sgTotal, 0);
    return total / available.length;
  }, [filteredRounds, roundStats]);

  const dispersionPutts = useMemo(() => {
    return filteredRounds.flatMap((r) => roundPutts[r.id] ?? []);
  }, [filteredRounds, roundPutts]);

  const dispersionLabel = useMemo(() => {
    switch (dispersionFilter) {
      case 'rl': return 'Right-Left';
      case 'lr': return 'Left-Right';
      case 'up': return 'Uphill';
      case 'down': return 'Downhill';
      default: return 'All Slopes';
    }
  }, [dispersionFilter]);

  const refresh = async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  };

  const sgColor = (sg: number) =>
    sg > 0.5 ? colors.primary : sg < -0.5 ? colors.error : colors.warning;

  const formatShortDate = (iso: string) =>
    new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });

  const topMiss = Object.entries(aggregated.missCounts)
    .filter(([k]) => k !== 'holed')
    .sort(([, a], [, b]) => b - a)[0];

  const { missReasonCounts: mc } = aggregated;
  const leave = useMemo(() => computeLeaveByMissDirection(dispersionPutts), [dispersionPutts]);
  const hasMissReasons = mc.missRead + mc.badStrike + mc.both > 0;
  const hasLeave = Object.keys(leave).length > 0;

  return (
    <SafeAreaView style={styles.safe}>
      <Text style={styles.header}>Statistics</Text>

      {/* Filter bar */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filterScroll}
        contentContainerStyle={styles.filterContent}
      >
        {FILTER_LABELS.map(({ mode, label }) => (
          <TouchableOpacity
            key={mode}
            style={[styles.filterChip, filterMode === mode && styles.filterChipSel]}
            onPress={() => setFilterMode(mode)}
          >
            <Text style={[styles.filterChipText, filterMode === mode && styles.filterChipTextSel]}>
              {label}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Putter picker */}
      {filterMode === 'byPutter' && putters.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={styles.putterScroll}
          contentContainerStyle={styles.filterContent}
        >
          {putters.map((p) => (
            <TouchableOpacity
              key={p.id}
              style={[styles.putterChip, selectedPutterId === p.id && styles.putterChipSel]}
              onPress={() => setSelectedPutterId(p.id)}
            >
              <Text style={[styles.putterChipText, selectedPutterId === p.id && styles.putterChipTextSel]}>
                {'🏌️'} {p.name}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      )}

      <ScrollView
        style={styles.scroll}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={colors.primary} />
        }
      >
        {allRounds.length === 0 ? (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>{'📊'}</Text>
            <Text style={styles.emptyText}>No completed rounds yet.</Text>
          </View>
        ) : filteredRounds.length === 0 ? (
          <View style={styles.empty}>
            <Text style={styles.emptyIcon}>{'🔍'}</Text>
            <Text style={styles.emptyText}>No rounds match this filter.</Text>
          </View>
        ) : (
          <View style={styles.statsSection}>

            {/* Rounds grid */}
            <View style={styles.card}>
              <Text style={styles.cardTitle}>
                {'ROUNDS (' + filteredRounds.length + ')'}
              </Text>
              <View style={styles.roundsGrid}>
                {filteredRounds.slice(0, 18).map((r) => {
                  const rs = roundStats[r.id];
                  const sg = rs?.sgTotal ?? null;
                  const bgColor = sg === null
                    ? colors.borderLight
                    : sg > 0.5
                    ? colors.primary + '33'
                    : sg < -0.5
                    ? colors.error + '33'
                    : colors.warning + '22';
                  const sgTxtColor = sg === null
                    ? colors.textMuted
                    : sg > 0.5 ? colors.primary
                    : sg < -0.5 ? colors.error
                    : colors.warning;

                  return (
                    <View key={r.id} style={[styles.roundCell, { backgroundColor: bgColor }]}>
                      <Text style={styles.roundCellDate}>{formatShortDate(r.date)}</Text>
                      <Text style={[styles.roundCellSG, { color: sgTxtColor }]}>
                        {sg === null ? '…' : (sg > 0 ? '+' : '') + sg.toFixed(1)}
                      </Text>
                      <Text style={styles.roundCellCourse} numberOfLines={1}>
                        {r.course_name || '—'}
                      </Text>
                    </View>
                  );
                })}
              </View>
            </View>

            {loading && (
              <ActivityIndicator color={colors.primary} style={{ marginVertical: 8 }} />
            )}

            {/* Summary stats */}
            <View style={styles.row3}>
              <StatBox label="Total Putts" value={String(aggregated.totalPutts)} />
              <StatBox label="Holes"       value={String(aggregated.holes)} />
              <StatBox label="Avg/Hole"    value={aggregated.avgPuttsPerHole.toFixed(1)} />
            </View>

            <View style={styles.sgCard}>
              <Text style={styles.sgLabel}>STROKES GAINED PUTTING</Text>
              <Text style={[styles.sgValue, { color: sgColor(sgAverage) }]}> 
                {(sgAverage > 0 ? '+' : '') + sgAverage.toFixed(2)}
              </Text>
              <Text style={styles.sgSub}>
                {'avg / round vs PGA Tour baseline' +
                  (filteredRounds.length > 1 ? ' · ' + filteredRounds.length + ' rounds' : '')}
              </Text>
            </View>

            {/* Distance make% chart */}
            {aggregated.makeByDistance.length > 0 && (
              <View style={styles.card}>
                <DistanceMakeChart
                  data={aggregated.makeByDistance}
                  sgDivisor={Math.max(1, filteredRounds.length)}
                />
              </View>
            )}

            {/* Miss pattern */}
            {topMiss && (
              <View style={styles.card}>
                <Text style={styles.cardTitle}>MISS PATTERN</Text>
                <View style={styles.missGrid}>
                  {Object.entries(aggregated.missCounts)
                    .filter(([k]) => k !== 'holed')
                    .sort(([, a], [, b]) => b - a)
                    .map(([k, v]) => (
                      <View key={k} style={styles.missItem}>
                        <Text style={styles.missCount}>{v}</Text>
                        <Text style={styles.missLabel}>
                          {(RESULT_LABELS[k] ?? k).replace(/_/g, ' ').toUpperCase()}
                        </Text>
                      </View>
                    ))}
                </View>
              </View>
            )}

            <View style={styles.card}>
              <Text style={styles.cardTitle}>MISS DISPERSION</Text>
              <View style={styles.dropdownWrap}>
                <TouchableOpacity
                  style={styles.dropdownButton}
                  onPress={() => setDispersionOpen((v) => !v)}
                >
                  <Text style={styles.dropdownText}>{dispersionLabel}</Text>
                  <Text style={styles.dropdownText}>▾</Text>
                </TouchableOpacity>
                {dispersionOpen && (
                  <View style={styles.dropdownMenu}>
                    {[
                      ['all', 'All Slopes'],
                      ['rl', 'Right-Left'],
                      ['lr', 'Left-Right'],
                      ['up', 'Uphill'],
                      ['down', 'Downhill'],
                    ].map(([key, label]) => (
                      <TouchableOpacity
                        key={key}
                        style={styles.dropdownItem}
                        onPress={() => {
                          setDispersionFilter(key as DispersionFilter);
                          setDispersionOpen(false);
                        }}
                      >
                        <Text style={styles.dropdownItemText}>{label}</Text>
                      </TouchableOpacity>
                    ))}
                  </View>
                )}
              </View>
              <MissDispersionPlot putts={dispersionPutts} filter={dispersionFilter} />
            </View>

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
                        {RESULT_LABELS[dir] ?? dir}
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
                      <Text style={styles.leaveCount}>{data.count} Putts</Text>
                    </View>
                  ))}
              </View>
            )}

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

  filterScroll:      { maxHeight: 44, flexGrow: 0 },
  filterContent:     { paddingHorizontal: spacing.lg, gap: 8, paddingBottom: 4, alignItems: 'center' },
  filterChip:        { paddingHorizontal: 14, paddingVertical: 7, backgroundColor: colors.surface, borderRadius: borderRadius.full, borderWidth: 1, borderColor: colors.border },
  filterChipSel:     { borderColor: colors.primary, backgroundColor: colors.primary + '22' },
  filterChipText:    { fontSize: 12, color: colors.textSecondary, fontWeight: '600' },
  filterChipTextSel: { color: colors.primary, fontWeight: '800' },

  putterScroll:      { maxHeight: 44, flexGrow: 0, marginTop: 4 },
  putterChip:        { paddingHorizontal: 14, paddingVertical: 7, backgroundColor: colors.surface, borderRadius: borderRadius.full, borderWidth: 1, borderColor: colors.border },
  putterChipSel:     { borderColor: colors.accent, backgroundColor: colors.accent + '22' },
  putterChipText:    { fontSize: 12, color: colors.textSecondary, fontWeight: '600' },
  putterChipTextSel: { color: colors.accent, fontWeight: '800' },

  statsSection: { padding: spacing.lg, gap: spacing.md },

  roundsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, justifyContent: 'center' },
  roundCell: {
    width: 64, minHeight: 60, borderRadius: borderRadius.sm,
    padding: 6, alignItems: 'center', justifyContent: 'center',
    borderWidth: 1, borderColor: colors.border, gap: 2,
  },
  roundCellDate:   { fontSize: 9,  color: colors.textMuted, fontWeight: '600' },
  roundCellSG:     { fontSize: 14, fontWeight: '900' },
  roundCellCourse: { fontSize: 8,  color: colors.textMuted, textAlign: 'center' },

  row3: { flexDirection: 'row', gap: spacing.sm },
  statBox: {
    flex: 1, backgroundColor: colors.surface, borderRadius: borderRadius.md,
    padding: spacing.md, alignItems: 'center', borderWidth: 1, borderColor: colors.border,
  },
  statValue: { fontSize: 24, fontWeight: '800', color: colors.text },
  statLabel: { fontSize: 10, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8, marginTop: 2 },

  sgCard: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.lg, alignItems: 'center',
    borderWidth: 1, borderColor: colors.border, gap: 4,
  },
  sgLabel: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },
  sgValue: { fontSize: 40, fontWeight: '900', letterSpacing: -1 },
  sgSub:   { fontSize: 12, color: colors.textSecondary },

  card: {
    backgroundColor: colors.surface, borderRadius: borderRadius.lg,
    padding: spacing.md, borderWidth: 1, borderColor: colors.border,
    gap: 10, alignItems: 'center',
  },
  cardTitle: { fontSize: 10, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },

  dropdownWrap: { width: '100%', zIndex: 2 },
  dropdownButton: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.surfaceElevated,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  dropdownText: { color: colors.text, fontSize: 12, fontWeight: '700' },
  dropdownMenu: {
    marginTop: 6,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
    backgroundColor: colors.surface,
  },
  dropdownItem: {
    paddingHorizontal: 10,
    paddingVertical: 9,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  dropdownItemText: { color: colors.textSecondary, fontSize: 12, fontWeight: '600' },

  missGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, justifyContent: 'center' },
  missItem: { alignItems: 'center', width: 72 },
  missCount: { fontSize: 22, fontWeight: '800', color: colors.error },
  missLabel: { fontSize: 9, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  reasonRow:   { flexDirection: 'row', gap: spacing.md, justifyContent: 'center' },
  reasonItem:  { alignItems: 'center', minWidth: 64 },
  reasonCount: { fontSize: 28, fontWeight: '900', color: colors.warning },
  reasonLabel: { fontSize: 10, color: colors.textMuted, textAlign: 'center', marginTop: 2 },

  leaveRow: { flexDirection: 'row', alignItems: 'center', gap: 8, width: '100%' },
  leaveDir: { width: 76, fontSize: 11, color: colors.textSecondary, fontWeight: '600' },
  leaveBarTrack: {
    flex: 1, height: 8, backgroundColor: colors.borderLight,
    borderRadius: borderRadius.sm, overflow: 'hidden',
  },
  leaveBar:   { height: 8, backgroundColor: colors.accent, borderRadius: borderRadius.sm },
  leaveAvg:   { width: 36, fontSize: 12, fontWeight: '800', color: colors.accent, textAlign: 'right' },
  leaveCount: { width: 68, fontSize: 10, color: colors.textMuted, textAlign: 'right' },

  empty:     { alignItems: 'center', paddingTop: 80, gap: 12 },
  emptyIcon: { fontSize: 48 },
  emptyText: { fontSize: 16, color: colors.textSecondary },
});
