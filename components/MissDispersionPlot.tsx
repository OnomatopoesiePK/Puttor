import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Svg, { Circle, Line } from 'react-native-svg';
import { Putt } from '../db/queries';
import { colors, borderRadius } from '../constants/theme';

export type DispersionFilter = 'all' | 'rl' | 'lr' | 'up' | 'down';

interface Props {
  putts: Putt[];
  filter: DispersionFilter;
}

const SIZE = 268;
const C = SIZE / 2;
const MAX_R = 108;
const ARROW_COLOR = colors.accent;

function TopSlopeArrow({ filter }: { filter: DispersionFilter }) {
  if (filter !== 'rl' && filter !== 'lr') return null;

  const isRight = filter === 'lr';
  const y = 12;
  const leftX = 12;
  const rightX = SIZE - 12;
  const head = 10;

  return (
    <Svg width={SIZE} height={24}>
      <Line x1={leftX} y1={y} x2={rightX} y2={y} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
      {isRight ? (
        <>
          <Line x1={rightX} y1={y} x2={rightX - head} y2={y - 6} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
          <Line x1={rightX} y1={y} x2={rightX - head} y2={y + 6} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
        </>
      ) : (
        <>
          <Line x1={leftX} y1={y} x2={leftX + head} y2={y - 6} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
          <Line x1={leftX} y1={y} x2={leftX + head} y2={y + 6} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
        </>
      )}
    </Svg>
  );
}

function RightSlopeArrow({ filter }: { filter: DispersionFilter }) {
  if (filter !== 'up' && filter !== 'down') return null;

  const isUp = filter === 'up';
  const x = 10;
  const topY = 12;
  const bottomY = SIZE - 12;
  const head = 10;

  return (
    <Svg width={24} height={SIZE}>
      <Line x1={x} y1={topY} x2={x} y2={bottomY} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
      {isUp ? (
        <>
          <Line x1={x} y1={topY} x2={x - 6} y2={topY + head} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
          <Line x1={x} y1={topY} x2={x + 6} y2={topY + head} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
        </>
      ) : (
        <>
          <Line x1={x} y1={bottomY} x2={x - 6} y2={bottomY - head} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
          <Line x1={x} y1={bottomY} x2={x + 6} y2={bottomY - head} stroke={ARROW_COLOR} strokeWidth={3} strokeLinecap="round" />
        </>
      )}
    </Svg>
  );
}

function vec(result: Putt['result']) {
  switch (result) {
    case 'left': return { x: -1, y: 0 };
    case 'right': return { x: 1, y: 0 };
    case 'short': return { x: 0, y: 1 };
    case 'long': return { x: 0, y: -1 };
    case 'short_left': return { x: -0.72, y: 0.72 };
    case 'short_right': return { x: 0.72, y: 0.72 };
    case 'long_left': return { x: -0.72, y: -0.72 };
    case 'long_right': return { x: 0.72, y: -0.72 };
    case 'hole_high': return { x: 0, y: -0.55 };
    default: return { x: 0, y: 0 };
  }
}

function includeByFilter(p: Putt, filter: DispersionFilter) {
  if (filter === 'all') return true;
  if (filter === 'rl') return p.side_slope_pct < 0;
  if (filter === 'lr') return p.side_slope_pct > 0;
  if (filter === 'up') return p.hill_slope_pct > 0;
  return p.hill_slope_pct < 0;
}

export function MissDispersionPlot({ putts, filter }: Props) {
  const grouped = useMemo(() => {
    const byHole: Record<string, Putt[]> = {};
    for (const p of putts) {
      const key = `${p.round_id}-${p.hole_number}`;
      if (!byHole[key]) byHole[key] = [];
      byHole[key].push(p);
    }

    const dots: Array<{ x: number; y: number; count: number }> = [];
    const keyMap: Record<string, number> = {};

    for (const holePutts of Object.values(byHole)) {
      const sorted = [...holePutts].sort((a, b) => a.putt_number - b.putt_number);
      for (let i = 0; i < sorted.length; i++) {
        const p = sorted[i];
        if (p.result === 'holed') continue;
        if (!includeByFilter(p, filter)) continue;

        const next = sorted[i + 1];
        const leave = next ? Math.max(0.3, next.distance_m) : Math.max(0.3, p.distance_m * 0.35);
        const radial = Math.min(MAX_R, 18 + leave * 24);
        const d = vec(p.result);

        const x = Number((d.x * radial).toFixed(1));
        const y = Number((d.y * radial).toFixed(1));
        const bucket = `${x}|${y}`;

        if (keyMap[bucket] === undefined) {
          keyMap[bucket] = dots.length;
          dots.push({ x, y, count: 1 });
        } else {
          dots[keyMap[bucket]].count += 1;
        }
      }
    }

    return dots;
  }, [putts, filter]);

  if (grouped.length === 0) {
    return (
      <View style={styles.emptyWrap}>
        <Text style={styles.emptyText}>Keine Miss-Daten fuer diesen Filter.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <TopSlopeArrow filter={filter} />

      <View style={styles.chartRow}>
        <View style={styles.plotBox}>
          <Text style={[styles.axisText, styles.axisLeft]}>LEFT</Text>
          <Text style={[styles.axisText, styles.axisRight]}>RIGHT</Text>
          <Text style={[styles.axisText, styles.axisTop]}>LONG</Text>
          <Text style={[styles.axisText, styles.axisBottom]}>SHORT</Text>

          <Svg width={SIZE} height={SIZE}>
            <Circle cx={C} cy={C} r={MAX_R} fill="#00000010" stroke={colors.border} strokeWidth={1} />
            <Circle cx={C} cy={C} r={MAX_R * 0.66} fill="none" stroke={colors.borderLight} strokeWidth={1} />
            <Circle cx={C} cy={C} r={MAX_R * 0.33} fill="none" stroke={colors.borderLight} strokeWidth={1} />

            <Line x1={C - MAX_R} y1={C} x2={C + MAX_R} y2={C} stroke="#ffffff30" strokeWidth={1} />
            <Line x1={C} y1={C - MAX_R} x2={C} y2={C + MAX_R} stroke="#ffffff30" strokeWidth={1} />

            <Circle cx={C} cy={C} r={7} fill={colors.primary} stroke="#FFFFFF" strokeWidth={2} />

            {grouped.map((d, idx) => {
              const r = Math.min(14, 5 + (d.count - 1) * 1.8);
              const alpha = Math.min(0.95, 0.45 + d.count * 0.08);
              return (
                <Circle
                  key={`dot-${idx}`}
                  cx={C + d.x}
                  cy={C + d.y}
                  r={r}
                  fill={colors.error}
                  fillOpacity={alpha}
                  stroke="#7A1111"
                  strokeWidth={1}
                />
              );
            })}
          </Svg>
        </View>

        <RightSlopeArrow filter={filter} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: 6 },
  chartRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  plotBox: {
    width: SIZE,
    height: SIZE,
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
  },
  axisText: {
    color: colors.textMuted,
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0.5,
    position: 'absolute',
  },
  axisLeft:   { left: -30, top: C - 8 },
  axisRight:  { right: -30, top: C - 8 },
  axisTop:    { top: C - MAX_R - 22, left: C - 16 },
  axisBottom: { bottom: C - MAX_R - 22, left: C - 18 },
  emptyWrap: {
    backgroundColor: colors.surfaceElevated,
    borderRadius: borderRadius.md,
    paddingVertical: 16,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 12,
    color: colors.textMuted,
  },
});