import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Svg, { Rect, Line, Text as SvgText } from 'react-native-svg';
import { colors } from '../constants/theme';
import { DistanceBracket } from '../db/queries';

interface Props {
  data: DistanceBracket[];
  width?: number;
}

const BAR_H   = 140;
const LABEL_H = 28;
const PAD_L   = 6;
const PAD_R   = 6;
const GAP     = 6;

export function StrokesGainedChart({ data, width = 340 }: Props) {
  const nonEmpty = data.filter((d) => d.total > 0);
  if (nonEmpty.length === 0) return null;

  const barW = (width - PAD_L - PAD_R - GAP * (nonEmpty.length - 1)) / nonEmpty.length;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>MAKE % vs TOUR</Text>
      <Svg width={width} height={BAR_H + LABEL_H + 16}>
        {nonEmpty.map((d, i) => {
          const x       = PAD_L + i * (barW + GAP);
          const yourPct = d.total > 0 ? (d.made / d.total) * 100 : 0;
          const tourPct = d.tourMakePct;

          const yourH = (yourPct / 100) * BAR_H;
          const tourH = (tourPct / 100) * BAR_H;

          const yourY = BAR_H - yourH;
          const tourY = BAR_H - tourH;

          const ahead = yourPct >= tourPct;

          return (
            <React.Fragment key={d.bracket}>
              {/* Tour bar (background) */}
              <Rect
                x={x}
                y={tourY}
                width={barW}
                height={tourH}
                fill="#2A4055"
                rx={3}
              />
              {/* Your bar */}
              <Rect
                x={x + barW * 0.15}
                y={yourY}
                width={barW * 0.7}
                height={yourH}
                fill={ahead ? colors.primary : colors.error}
                rx={3}
                opacity={0.9}
              />

              {/* % labels */}
              {d.total > 0 && (
                <SvgText
                  x={x + barW / 2}
                  y={Math.max(yourY - 4, 10)}
                  textAnchor="middle"
                  fill={colors.text}
                  fontSize={9}
                  fontWeight="700"
                >
                  {Math.round(yourPct)}%
                </SvgText>
              )}

              {/* Bracket label */}
              <SvgText
                x={x + barW / 2}
                y={BAR_H + LABEL_H - 4}
                textAnchor="middle"
                fill={colors.textMuted}
                fontSize={9}
              >
                {d.bracket}
              </SvgText>

              {/* Tour % label */}
              <SvgText
                x={x + barW / 2}
                y={tourY - 3}
                textAnchor="middle"
                fill="#FFFFFF44"
                fontSize={8}
              >
                {Math.round(tourPct)}%
              </SvgText>
            </React.Fragment>
          );
        })}

        {/* Baseline */}
        <Line
          x1={PAD_L}
          y1={BAR_H}
          x2={width - PAD_R}
          y2={BAR_H}
          stroke={colors.border}
          strokeWidth={1}
        />
      </Svg>

      <View style={styles.legend}>
        <View style={styles.legendItem}>
          <View style={[styles.dot, { backgroundColor: colors.primary }]} />
          <Text style={styles.legendText}>You</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.dot, { backgroundColor: '#2A4055' }]} />
          <Text style={styles.legendText}>PGA Tour baseline</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: 8 },

  title: {
    fontSize: 10,
    fontWeight: '600',
    color: colors.textMuted,
    letterSpacing: 1.2,
  },

  legend: {
    flexDirection: 'row',
    gap: 16,
  },

  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },

  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },

  legendText: {
    fontSize: 11,
    color: colors.textSecondary,
  },
});
