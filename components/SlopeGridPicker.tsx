import React, { useState } from 'react';
import { View, Text, StyleSheet, Image, TouchableOpacity } from 'react-native';
import Svg, { Circle, Path } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { colors, borderRadius } from '../constants/theme';

const AXIS_VALUES = [-3.5, -3, -2, -1, 0, 1, 2, 3, 3.5];
const HILL_VALUES = [...AXIS_VALUES].reverse();
const GRID_SIZE = AXIS_VALUES.length;
const MESH = GRID_SIZE + 1;
const IMG_W = 1743;
const IMG_H = 1120;

// Pixel-extracted intersections from slopegrid_color.png (10x10 boundaries).
const INTERSECTION_POINTS: Array<Array<{ x: number; y: number }>> = [
  [{ x: 485.0, y: 75.0 }, { x: 579.0, y: 40.0 }, { x: 668.0, y: 21.0 }, { x: 753.0, y: 10.0 }, { x: 829.0, y: 5.0 }, { x: 913.0, y: 5.0 }, { x: 990.0, y: 11.0 }, { x: 1077.0, y: 23.0 }, { x: 1164.0, y: 42.0 }, { x: 1258.0, y: 74.0 }],
  [{ x: 447.0, y: 219.0 }, { x: 555.0, y: 173.0 }, { x: 651.0, y: 151.0 }, { x: 740.0, y: 139.0 }, { x: 826.0, y: 135.0 }, { x: 922.0, y: 134.0 }, { x: 1001.0, y: 141.0 }, { x: 1094.0, y: 156.0 }, { x: 1194.0, y: 178.0 }, { x: 1296.0, y: 215.0 }],
  [{ x: 411.0, y: 306.0 }, { x: 518.0, y: 268.0 }, { x: 627.0, y: 248.0 }, { x: 721.0, y: 237.0 }, { x: 820.0, y: 233.0 }, { x: 926.0, y: 231.0 }, { x: 1023.0, y: 240.0 }, { x: 1122.0, y: 254.0 }, { x: 1231.0, y: 275.0 }, { x: 1333.0, y: 305.0 }],
  [{ x: 344.0, y: 415.0 }, { x: 467.0, y: 373.0 }, { x: 585.0, y: 347.0 }, { x: 695.0, y: 333.0 }, { x: 804.0, y: 325.0 }, { x: 941.0, y: 325.0 }, { x: 1050.0, y: 334.0 }, { x: 1166.0, y: 349.0 }, { x: 1276.0, y: 372.0 }, { x: 1400.0, y: 416.0 }],
  [{ x: 292.0, y: 480.0 }, { x: 421.0, y: 441.0 }, { x: 543.0, y: 417.0 }, { x: 663.0, y: 401.0 }, { x: 792.0, y: 392.0 }, { x: 949.0, y: 393.0 }, { x: 1077.0, y: 403.0 }, { x: 1207.0, y: 420.0 }, { x: 1325.0, y: 444.0 }, { x: 1451.0, y: 479.0 }],
  [{ x: 212.0, y: 578.0 }, { x: 364.0, y: 529.0 }, { x: 497.0, y: 500.0 }, { x: 637.0, y: 481.0 }, { x: 783.0, y: 469.0 }, { x: 962.0, y: 473.0 }, { x: 1103.0, y: 482.0 }, { x: 1255.0, y: 504.0 }, { x: 1381.0, y: 532.0 }, { x: 1533.0, y: 580.0 }],
  [{ x: 142.0, y: 678.0 }, { x: 315.0, y: 619.0 }, { x: 458.0, y: 588.0 }, { x: 613.0, y: 568.0 }, { x: 774.0, y: 556.0 }, { x: 970.0, y: 560.0 }, { x: 1132.0, y: 573.0 }, { x: 1289.0, y: 594.0 }, { x: 1432.0, y: 624.0 }, { x: 1601.0, y: 676.0 }],
  [{ x: 92.0, y: 788.0 }, { x: 256.0, y: 735.0 }, { x: 411.0, y: 700.0 }, { x: 586.0, y: 676.0 }, { x: 762.0, y: 664.0 }, { x: 979.0, y: 666.0 }, { x: 1164.0, y: 682.0 }, { x: 1333.0, y: 707.0 }, { x: 1491.0, y: 744.0 }, { x: 1652.0, y: 790.0 }],
  [{ x: 43.0, y: 950.0 }, { x: 212.0, y: 884.0 }, { x: 376.0, y: 850.0 }, { x: 558.0, y: 823.0 }, { x: 755.0, y: 809.0 }, { x: 990.0, y: 811.0 }, { x: 1186.0, y: 826.0 }, { x: 1372.0, y: 854.0 }, { x: 1534.0, y: 891.0 }, { x: 1696.0, y: 943.0 }],
  [{ x: 9.0, y: 1106.0 }, { x: 177.0, y: 1043.0 }, { x: 349.0, y: 1004.0 }, { x: 534.0, y: 977.0 }, { x: 742.0, y: 961.0 }, { x: 1001.0, y: 963.0 }, { x: 1211.0, y: 982.0 }, { x: 1404.0, y: 1011.0 }, { x: 1568.0, y: 1050.0 }, { x: 1735.0, y: 1108.0 }],
];

function labelFor(v: number): string {
  if (Math.abs(v) === 3.5) return '3+';
  return String(Math.abs(v));
}

function meshPoint(col: number, row: number) {
  return INTERSECTION_POINTS[row][col];
}

function cellPath(c: number, r: number) {
  const p1 = meshPoint(c, r);
  const p2 = meshPoint(c + 1, r);
  const p3 = meshPoint(c + 1, r + 1);
  const p4 = meshPoint(c, r + 1);
  return `M ${p1.x} ${p1.y} L ${p2.x} ${p2.y} L ${p3.x} ${p3.y} L ${p4.x} ${p4.y} Z`;
}

function valueToRow(v: number) {
  return HILL_VALUES.findIndex((n) => n === v);
}

function valueToCol(v: number) {
  return AXIS_VALUES.findIndex((n) => n === v);
}

interface Props {
  sideValue: number;
  hillValue: number;
  onChange: (values: { sideSlopePct: number; hillSlopePct: number }) => void;
}

export function SlopeGridPicker({ sideValue, hillValue, onChange }: Props) {
  const selectedCol = valueToCol(sideValue);
  const selectedRow = valueToRow(hillValue);
  const [showDebug, setShowDebug] = useState(false);

  return (
    <View style={styles.container}>
      <Text style={styles.label}>SLOPE GRID</Text>
      <Text style={styles.hintTop}>UPHILL</Text>

      <View style={styles.gridWrap}>
        <Image source={require('../assets/slopegrid_color.png')} style={styles.image} resizeMode="contain" />
        <Svg width="100%" height="100%" viewBox={`0 0 ${IMG_W} ${IMG_H}`} style={styles.overlay}>
          {Array.from({ length: GRID_SIZE }).map((_, r) =>
            Array.from({ length: GRID_SIZE }).map((__, c) => {
              const side = AXIS_VALUES[c];
              const hill = HILL_VALUES[r];
              const selected = selectedCol === c && selectedRow === r;
              return (
                <Path
                  key={`cell-${r}-${c}`}
                  d={cellPath(c, r)}
                  fill={selected ? '#22C55E33' : 'transparent'}
                  stroke={selected ? '#22C55E' : 'transparent'}
                  strokeWidth={selected ? 4 : 1}
                  onPress={() => {
                    Haptics.selectionAsync().catch(() => {});
                    onChange({ sideSlopePct: side, hillSlopePct: hill });
                  }}
                />
              );
            })
          )}
        </Svg>
      </View>

      <View style={styles.axisTextRow}>
        <Text style={styles.axisText}>LEFT</Text>
        <Text style={styles.axisText}>STRAIGHT</Text>
        <Text style={styles.axisText}>RIGHT</Text>
      </View>
      <Text style={styles.hintBottom}>DOWNHILL</Text>
      <Text style={styles.selectionText}>
        {sideValue === 0 ? 'Flat' : `${labelFor(sideValue)}° ${sideValue < 0 ? 'R-L' : 'L-R'}`} /
        {' '}{hillValue === 0 ? 'Flat' : `${labelFor(hillValue)}° ${hillValue > 0 ? 'U' : 'D'}`}
      </Text>

      <TouchableOpacity onPress={() => setShowDebug((v) => !v)} style={styles.debugBtn}>
        <Text style={styles.debugBtnText}>{showDebug ? 'Debug Grid: ON' : 'Debug Grid: OFF'}</Text>
      </TouchableOpacity>

      {showDebug && (
        <View style={styles.gridWrap}>
          <Image source={require('../assets/slopegrid_color.png')} style={styles.image} resizeMode="contain" />
          <Svg width="100%" height="100%" viewBox={`0 0 ${IMG_W} ${IMG_H}`} style={styles.overlay}>
            {Array.from({ length: GRID_SIZE }).map((_, r) =>
              Array.from({ length: GRID_SIZE }).map((__, c) => (
                <Path
                  key={`dbg-cell-${r}-${c}`}
                  d={cellPath(c, r)}
                  fill="transparent"
                  stroke="#00D1FF"
                  strokeWidth={1.5}
                />
              ))
            )}

            {Array.from({ length: MESH }).map((_, r) =>
              Array.from({ length: MESH }).map((__, c) => {
                const p = meshPoint(c, r);
                return (
                  <Circle
                    key={`dbg-node-${r}-${c}`}
                    cx={p.x}
                    cy={p.y}
                    r={4}
                    fill="#FF00C8"
                    stroke="#FFFFFF"
                    strokeWidth={1}
                  />
                );
              })
            )}
          </Svg>
        </View>
      )}

    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 8 },

  label: {
    fontSize: 10,
    fontWeight: '600',
    color: colors.textMuted,
    letterSpacing: 1.2,
    textAlign: 'center',
  },

  hintTop: {
    textAlign: 'center',
    fontSize: 11,
    color: colors.uphill,
    fontWeight: '700',
    letterSpacing: 0.6,
  },

  hintBottom: {
    textAlign: 'center',
    fontSize: 11,
    color: colors.downhill,
    fontWeight: '700',
    letterSpacing: 0.6,
  },

  gridWrap: {
    borderWidth: 0,
    borderColor: 'transparent',
    borderRadius: 0,
    overflow: 'visible',
    backgroundColor: 'transparent',
    width: '120%',
    aspectRatio: IMG_W / IMG_H,
    position: 'relative',
    alignSelf: 'center',
  },

  image: {
    width: '100%',
    height: '100%',
  },

  overlay: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  },

  axisTextRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
  },

  axisText: {
    fontSize: 10,
    color: colors.textMuted,
    fontWeight: '700',
    letterSpacing: 0.7,
  },

  selectionText: {
    textAlign: 'center',
    fontSize: 12,
    color: colors.text,
    fontWeight: '700',
  },

  debugBtn: {
    alignSelf: 'center',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.surfaceElevated,
  },
  debugBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: colors.textSecondary,
  },
});