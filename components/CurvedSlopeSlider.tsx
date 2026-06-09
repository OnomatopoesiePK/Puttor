import React, { useRef, useState } from 'react';
import {
  View, Text, PanResponder, StyleSheet,
  LayoutChangeEvent,
} from 'react-native';
import Svg, {
  Path, Circle, Line, Defs, LinearGradient, Stop, Rect,
} from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { colors } from '../constants/theme';

// Snap values: -5 = ">4% R→L", -4…0…4, +5 = ">4% L→R"
const SNAP_VALUES = [
  -5, -4, -3.5, -3, -2.5, -2, -1.5, -1, -0.5,
  0,
  0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5,
];
const N = SNAP_VALUES.length - 1; // 18

const ARCH_H = 44;  // height of arch component
const PAD_TOP = 8;  // space above arch peak

// y-position on the arch for a given normalised position t ∈ [0,1]
// Parabola: y=0 at centre, y=(ARCH_H-PAD_TOP) at edges
function archY(t: number): number {
  return PAD_TOP + (ARCH_H - PAD_TOP) * Math.pow(2 * t - 1, 2);
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
  if (v === -5) return '>4% R→L';
  if (v ===  5) return '>4% L→R';
  if (v ===  0) return 'Straight';
  return `${Math.abs(v)}% ${v < 0 ? 'R→L' : 'L→R'}`;
}

interface Props {
  value: number;
  onChange: (v: number) => void;
  disabled?: boolean;
}

export function CurvedSlopeSlider({ value, onChange, disabled = false }: Props) {
  const [w, setW] = useState(300);
  const startT    = useRef(valueToT(value));
  const lastSnap  = useRef(value);

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => !disabled,
      onMoveShouldSetPanResponder:  () => !disabled,
      onPanResponderGrant: () => {
        startT.current = valueToT(value);
        lastSnap.current = value;
      },
      onPanResponderMove: (_, gs) => {
        const newT   = Math.max(0, Math.min(1, startT.current + gs.dx / w));
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
  const thumbY = archY(t);

  // Build arch polyline path
  const archPath = Array.from({ length: 101 }, (_, i) => {
    const ti = i / 100;
    return `${i === 0 ? 'M' : 'L'} ${(ti * w).toFixed(1)},${archY(ti).toFixed(1)}`;
  }).join(' ');

  // Thumb colour
  const thumbFill =
    disabled ? '#444' :
    value < 0 ? colors.breakLeft :
    value > 0 ? colors.breakRight :
    '#FFFFFF';

  const onLayout = (e: LayoutChangeEvent) => setW(e.nativeEvent.layout.width);

  return (
    <View style={styles.container}>
      <View
        style={[styles.track, { height: ARCH_H + 28 }]}
        onLayout={onLayout}
        {...pan.panHandlers}
      >
        <Svg width={w} height={ARCH_H + 28}>
          <Defs>
            <LinearGradient id="bkGrad" x1="0" y1="0" x2="1" y2="0">
              <Stop offset="0"   stopColor={colors.breakLeft}  stopOpacity="0.25" />
              <Stop offset="0.5" stopColor="#888888"           stopOpacity="0.08" />
              <Stop offset="1"   stopColor={colors.breakRight} stopOpacity="0.25" />
            </LinearGradient>
          </Defs>
          <Rect x={0} y={0} width={w} height={ARCH_H} fill="url(#bkGrad)" rx={8} />

          {/* Arch track line */}
          <Path
            d={archPath}
            stroke={disabled ? '#333' : '#3A5570'}
            strokeWidth={2.5}
            fill="none"
            strokeLinecap="round"
          />

          {/* Tick marks at each snap */}
          {SNAP_VALUES.map((sv, i) => {
            const ti   = i / N;
            const tx   = ti * w;
            const ty   = archY(ti);
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
            opacity={disabled ? 0.4 : 1}
            stroke={disabled ? '#666' : '#FFFFFF'}
            strokeWidth={2}
          />

          {/* Side labels */}
          <Svg x={0} y={ARCH_H + 4} width={w} height={22}>
            <Path d="" />
          </Svg>
        </Svg>

        {/* Text labels below slider */}
        <View style={styles.labelsRow} pointerEvents="none">
          <Text style={[styles.labelEdge, { color: colors.breakLeft }]}>R→L</Text>
          <Text style={styles.labelCenter}>STRAIGHT</Text>
          <Text style={[styles.labelEdge, { color: colors.breakRight }]}>L→R</Text>
        </View>
      </View>

      <Text style={[styles.valueText, disabled && styles.valueDimmed]}>
        {formatValue(value)}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 4 },

  track: {
    position: 'relative',
  },

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
  valueDimmed: {
    color: colors.textMuted,
  },
});
