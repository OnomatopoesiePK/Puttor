import React, { useRef, useState } from 'react';
import {
  View, Text, PanResponder, StyleSheet,
  LayoutChangeEvent,
} from 'react-native';
import Svg, { Path, Circle, Line, Defs, LinearGradient, Stop, Rect } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { colors } from '../constants/theme';

// Same snap range as break slider: -5 (">4% uphill"), -4…0…4, +5 (">4% downhill")
const SNAP_VALUES = [
  -5, -4, -3.5, -3, -2.5, -2, -1.5, -1, -0.5,
  0,
  0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5,
];
const N = SNAP_VALUES.length - 1;

const SLOPE_H = 44;
const PAD = 6;

// Ski-slope (S-curve): uphill (left) is high, flat in middle, downhill (right) is low.
// Uses smooth Hermite S-curve: y = H * (3t² − 2t³)
function slopeY(t: number): number {
  const ease = 3 * t * t - 2 * t * t * t; // 0 at t=0, 0.5 at t=0.5, 1 at t=1
  return PAD + (SLOPE_H - 2 * PAD) * ease;
}

function valueToT(v: number): number {
  const i = SNAP_VALUES.indexOf(v);
  return i === -1 ? 0.5 : i / N;
}

function tToSnap(t: number): number {
  const i = Math.round(t * N);
  return SNAP_VALUES[Math.max(0, Math.min(N, i))];
}

function formatValue(v: number): string {
  if (v === -5) return '>4% Uphill';
  if (v ===  5) return '>4% Downhill';
  if (v ===  0) return 'Flat';
  return `${Math.abs(v)}% ${v < 0 ? 'Uphill' : 'Downhill'}`;
}

interface Props {
  value: number;
  onChange: (v: number) => void;
}

export function HillSlider({ value, onChange }: Props) {
  const [w, setW] = useState(300);
  const startT   = useRef(valueToT(value));
  const lastSnap = useRef(value);

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder:  () => true,
      onPanResponderGrant: () => {
        startT.current = valueToT(value);
        lastSnap.current = value;
      },
      onPanResponderMove: (_, gs) => {
        const newT    = Math.max(0, Math.min(1, startT.current + gs.dx / w));
        const snapped = tToSnap(newT);
        if (snapped !== lastSnap.current) {
          lastSnap.current = snapped;
          Haptics.selectionAsync().catch(() => {});
          onChange(snapped);
        }
      },
    })
  ).current;

  const t      = valueToT(value);
  const thumbX = t * w;
  const thumbY = slopeY(t);

  // Build slope polyline path
  const slopePath = Array.from({ length: 101 }, (_, i) => {
    const ti = i / 100;
    return `${i === 0 ? 'M' : 'L'} ${(ti * w).toFixed(1)},${slopeY(ti).toFixed(1)}`;
  }).join(' ');

  const thumbFill =
    value < 0 ? colors.uphill :
    value > 0 ? colors.downhill :
    '#FFFFFF';

  const onLayout = (e: LayoutChangeEvent) => setW(e.nativeEvent.layout.width);

  return (
    <View style={styles.container}>
      <View
        style={[styles.track, { height: SLOPE_H + 28 }]}
        onLayout={onLayout}
        {...pan.panHandlers}
      >
        <Svg width={w} height={SLOPE_H + 28}>
          <Defs>
            <LinearGradient id="hillGrad" x1="0" y1="0" x2="1" y2="0">
              <Stop offset="0"   stopColor={colors.uphill}   stopOpacity="0.28" />
              <Stop offset="0.5" stopColor="#888888"         stopOpacity="0.08" />
              <Stop offset="1"   stopColor={colors.downhill} stopOpacity="0.28" />
            </LinearGradient>
          </Defs>
          <Rect x={0} y={0} width={w} height={SLOPE_H} fill="url(#hillGrad)" rx={8} />

          {/* Slope track */}
          <Path
            d={slopePath}
            stroke="#3A5570"
            strokeWidth={2.5}
            fill="none"
            strokeLinecap="round"
          />

          {/* Tick marks */}
          {SNAP_VALUES.map((sv, i) => {
            const ti   = i / N;
            const tx   = ti * w;
            const ty   = slopeY(ti);
            const isBig = sv === 0 || Math.abs(sv) === 2 || Math.abs(sv) === 4 || Math.abs(sv) === 5;
            const half = isBig ? 5 : 3;
            return (
              <Line
                key={sv}
                x1={tx} y1={ty - half}
                x2={tx} y2={ty + half}
                stroke={sv === 0 ? '#FFFFFFAA' : '#FFFFFF44'}
                strokeWidth={isBig ? 1.5 : 1}
              />
            );
          })}

          {/* Thumb */}
          <Circle
            cx={thumbX}
            cy={thumbY}
            r={11}
            fill={thumbFill}
            stroke="#FFFFFF"
            strokeWidth={2}
          />
        </Svg>

        <View style={styles.labelsRow} pointerEvents="none">
          <Text style={[styles.labelEdge, { color: colors.uphill }]}>⬆ UPHILL</Text>
          <Text style={styles.labelCenter}>FLAT</Text>
          <Text style={[styles.labelEdge, { color: colors.downhill }]}>DOWNHILL ⬇</Text>
        </View>
      </View>

      <Text style={styles.valueText}>{formatValue(value)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 4 },
  track:     { position: 'relative' },
  labelsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
    marginTop: 2,
  },
  labelEdge: {
    fontSize: 11,
    fontWeight: '600',
    letterSpacing: 0.4,
  },
  labelCenter: {
    fontSize: 11,
    color: '#FFFFFF60',
    fontWeight: '500',
  },
  valueText: {
    textAlign: 'center',
    fontSize: 13,
    fontWeight: '700',
    color: colors.text,
    letterSpacing: 0.3,
  },
});
