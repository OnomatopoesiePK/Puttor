import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, spacing, borderRadius } from '../constants/theme';
import { DistanceBracket } from '../db/queries';

interface Props {
  data: DistanceBracket[];
  hideNoMakes?: boolean;
  sgDivisor?: number;
}

export function DistanceMakeChart({ data, hideNoMakes = false, sgDivisor = 1 }: Props) {
  const visible = data.filter((b) => b.total > 0 && (!hideNoMakes || b.made > 0));
  if (visible.length === 0) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>MAKE % VS TOUR</Text>

      {/* Header row */}
      <View style={styles.headerRow}>
        <Text style={[styles.labelCell, styles.headerText]}>Dist</Text>
        <Text style={[styles.barsCell, styles.headerText]}>Tour → You</Text>
        <Text style={[styles.madeCell, styles.headerText]}>Made</Text>
        <Text style={[styles.pctCell, styles.headerText]}>You</Text>
        <Text style={[styles.tourCell, styles.headerText]}>Tour</Text>
        <Text style={[styles.sgCell, styles.headerText]}>SG</Text>
      </View>

      {visible.map((b) => {
        const playerPct = b.total > 0 ? (b.made / b.total) * 100 : 0;
        const tourPct   = b.tourMakePct;
        const ahead     = playerPct >= tourPct;
        const playerColor = ahead ? colors.primary : colors.error;
        const sg        = b.sgTotal / Math.max(1, sgDivisor);
        const sgColor   = sg > 0 ? colors.primary : sg < 0 ? colors.error : colors.textSecondary;
        const noData    = b.total === 0;

        return (
          <View key={b.bracket} style={styles.row}>
            {/* Distance label */}
            <Text style={[styles.labelCell, noData && styles.dimText]}>{b.bracket}</Text>

            {/* Bars area */}
            <View style={styles.barsCell}>
              {/* Tour bar */}
              <View style={styles.barTrack}>
                <View
                  style={[
                    styles.bar,
                    {
                      width: `${tourPct}%` as any,
                      backgroundColor: noData ? colors.border : '#3A5570',
                    },
                  ]}
                />
                <Text style={styles.tourPctText}>{Math.round(tourPct)}%</Text>
              </View>
              {/* Player bar */}
              <View style={[styles.barTrack, { marginTop: 4 }]}>
                {noData ? (
                  <Text style={styles.noDataText}>no data</Text>
                ) : (
                  <View
                    style={[
                      styles.bar,
                      {
                        width: `${playerPct}%` as any,
                        backgroundColor: playerColor,
                      },
                    ]}
                  />
                )}
              </View>
            </View>

            {/* Made/Taken */}
            <Text style={[styles.madeCell, noData && styles.dimText]}>
              {noData ? '–' : `${b.made}/${b.total}`}
            </Text>

            {/* Player % */}
            <Text style={[styles.pctCell, { color: noData ? colors.textMuted : playerColor }]}>
              {noData ? '–' : `${Math.round(playerPct)}%`}
            </Text>

            {/* Tour % */}
            <Text style={[styles.tourCell, { color: noData ? colors.textMuted : colors.textSecondary }]}> 
              {noData ? '–' : `${Math.round(tourPct)}%`}
            </Text>

            {/* SG */}
            <Text style={[styles.sgCell, { color: noData ? colors.textMuted : sgColor }]}>
              {noData ? '–' : `${sg >= 0 ? '+' : ''}${sg.toFixed(1)}`}
            </Text>
          </View>
        );
      })}

      {/* Legend */}
      <View style={styles.legend}>
        <LegendSwatch color="#3A5570" label="Tour" />
        <LegendSwatch color={colors.primary} label="You (≥ tour)" />
        <LegendSwatch color={colors.error}   label="You (< tour)" />
      </View>
    </View>
  );
}

function LegendSwatch({ color, label }: { color: string; label: string }) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.legendDot, { backgroundColor: color }]} />
      <Text style={styles.legendText}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 2 },

  title: {
    fontSize: 10, fontWeight: '700', color: colors.textMuted,
    letterSpacing: 1.2, textAlign: 'center', marginBottom: 6,
  },

  headerRow: {
    flexDirection: 'row', alignItems: 'center',
    paddingBottom: 4, borderBottomWidth: 1, borderBottomColor: colors.border,
    marginBottom: 2,
  },
  headerText: { fontSize: 9, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8 },

  row: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 5,
  },

  labelCell: { width: 52, fontSize: 11, color: colors.textSecondary, fontWeight: '600' },
  barsCell:  { flex: 1, justifyContent: 'center' },
  madeCell:  { width: 52, textAlign: 'right', fontSize: 11, fontWeight: '700', color: colors.textSecondary },
  pctCell:   { width: 38, textAlign: 'right', fontSize: 12, fontWeight: '800' },
  tourCell:  { width: 42, textAlign: 'right', fontSize: 11, fontWeight: '700', color: colors.textSecondary },
  sgCell:    { width: 46, textAlign: 'right', fontSize: 11, fontWeight: '600' },

  barTrack: {
    height: 8,
    backgroundColor: colors.borderLight,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
    justifyContent: 'center',
  },
  bar: { height: 8, borderRadius: borderRadius.sm },
  tourPctText: {
    position: 'absolute',
    right: 4,
    top: -1,
    fontSize: 8,
    color: '#FFFFFF88',
    fontWeight: '700',
  },

  dimText:    { color: colors.textMuted },
  noDataText: { fontSize: 9, color: colors.textMuted, paddingLeft: 4 },

  legend: {
    flexDirection: 'row', gap: 12, justifyContent: 'center',
    marginTop: 8, flexWrap: 'wrap',
  },
  legendItem: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  legendDot:  { width: 8, height: 8, borderRadius: 4 },
  legendText: { fontSize: 10, color: colors.textSecondary },
});
