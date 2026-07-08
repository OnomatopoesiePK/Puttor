import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import Svg, { Circle, Path, Text as SvgText } from 'react-native-svg';
import * as Haptics from 'expo-haptics';
import { colors } from '../constants/theme';
import { PuttResult } from '../db/queries';

const SIZE  = 280;
const CX    = SIZE / 2;
const CY    = SIZE / 2;
const R     = SIZE / 2 - 4;

const R_HOLED = 0.20;
const R_LIP   = 0.35;
const R_INNER = 0.35;
const R_OUTER = 1.0;

// Rotated -90° vs original so LONG is at top, SHORT is at bottom
const SECTORS: Array<{
  result: PuttResult;
  label: string;
  startDeg: number;
  fillA: string;
  fillB: string;
}> = [
  { result: 'long',        label: 'LONG',  startDeg: -112.5, fillA: '#3A5060', fillB: '#2E3F50' },
  { result: 'long_right',  label: '↗',     startDeg:  -67.5, fillA: '#3E3040', fillB: '#322635' },
  { result: 'right',       label: 'RIGHT', startDeg:  -22.5, fillA: '#3A2A20', fillB: '#2E201A' },
  { result: 'short_right', label: '↘',     startDeg:   22.5, fillA: '#3E3040', fillB: '#322635' },
  { result: 'short',       label: 'SHORT', startDeg:   67.5, fillA: '#3A5060', fillB: '#2E3F50' },
  { result: 'short_left',  label: '↙',     startDeg:  112.5, fillA: '#3E3040', fillB: '#322635' },
  { result: 'left',        label: 'LEFT',  startDeg:  157.5, fillA: '#3A2A20', fillB: '#2E201A' },
  { result: 'long_left',   label: '↖',     startDeg:  202.5, fillA: '#3E3040', fillB: '#322635' },
];

// Convert degrees to radians
function deg2rad(d: number) { return (d * Math.PI) / 180; }

// Point on circle
function pt(angle: number, r: number, cx = CX, cy = CY) {
  return {
    x: cx + r * Math.cos(deg2rad(angle)),
    y: cy + r * Math.sin(deg2rad(angle)),
  };
}

// SVG arc path for a sector (annular wedge)
function sectorPath(startDeg: number, endDeg: number, r1: number, r2: number): string {
  const s1 = pt(startDeg, r1);
  const e1 = pt(endDeg,   r1);
  const s2 = pt(startDeg, r2);
  const e2 = pt(endDeg,   r2);

  return [
    `M ${s1.x} ${s1.y}`,
    `A ${r1} ${r1} 0 0 1 ${e1.x} ${e1.y}`,
    `L ${e2.x} ${e2.y}`,
    `A ${r2} ${r2} 0 0 0 ${s2.x} ${s2.y}`,
    'Z',
  ].join(' ');
}

// Label position (midpoint of sector at mid-radius)
function labelPt(startDeg: number, endDeg: number, r: number) {
  const midDeg = (startDeg + endDeg) / 2;
  return pt(midDeg, r);
}

interface Props {
  value: PuttResult | null;
  lipOut: boolean;
  onChange: (result: PuttResult) => void;
  onLipOutChange: (lipOut: boolean) => void;
}

export function DartboardMiss({ value, lipOut, onChange, onLipOutChange }: Props) {
  const outerR   = R;
  const lipOutR  = R * R_LIP;
  const holedR   = R * R_HOLED;
  const sectorR1 = R * R_INNER;
  const sectorR2 = R * R_OUTER;

  const handlePress = (result: PuttResult) => {
    Haptics.impactAsync(
      result === 'holed'
        ? Haptics.ImpactFeedbackStyle.Heavy
        : Haptics.ImpactFeedbackStyle.Light
    ).catch(() => {});
    onChange(result);
  };

  // Compute tap zone from touch coordinates
  const handleTouchOnSvg = (pageX: number, pageY: number, svgOrigin: { x: number; y: number }) => {
    // handled via individual TouchableOpacity overlays
  };

  return (
    <View style={styles.container}>
      <Text style={styles.label}>MISS BOARD</Text>
      <View style={styles.board}>
        {/* SVG base layer — non-interactive, purely visual */}
        <Svg width={SIZE} height={SIZE} style={StyleSheet.absoluteFill}>
          {/* Outer ring shadow */}
          <Circle cx={CX} cy={CY} r={outerR + 2} fill="#00000060" />

          {/* 8 directional sectors */}
          {SECTORS.map((s, i) => {
            const endDeg = s.startDeg + 45;
            const isSelected = value === s.result;
            return (
              <Path
                key={s.result}
                d={sectorPath(s.startDeg, endDeg, sectorR1, sectorR2)}
                fill={isSelected ? colors.error + 'DD' : (i % 2 === 0 ? s.fillA : s.fillB)}
                stroke={colors.border}
                strokeWidth={0.5}
              />
            );
          })}

          {/* Lip-out ring (drawn as circle to avoid seam at -180/180) */}
          <Circle
            cx={CX}
            cy={CY}
            r={lipOutR}
            fill={lipOut ? colors.lipOut + 'DD' : '#2A3D2A'}
            stroke={lipOut ? colors.lipOut : colors.border}
            strokeWidth={lipOut ? 2 : 1}
          />

          {/* Holed centre */}
          <Circle
            cx={CX}
            cy={CY}
            r={holedR}
            fill={value === 'holed' ? colors.holed : '#1E3A28'}
            stroke={value === 'holed' ? colors.primaryLight : '#3DBA6F88'}
            strokeWidth={2}
          />

          {/* Sector label text */}
          {SECTORS.map((s) => {
            const endDeg = s.startDeg + 45;
            const lp = labelPt(s.startDeg, endDeg, (sectorR1 + sectorR2) / 2);
            const isShort = s.label.length <= 2;
            return (
              <SvgText
                key={s.result}
                x={lp.x}
                y={lp.y + 4}
                textAnchor="middle"
                fill={value === s.result ? '#FFFFFF' : '#FFFFFF88'}
                fontSize={isShort ? 14 : 9}
                fontWeight="600"
              >
                {s.label}
              </SvgText>
            );
          })}

          {/* Lip-out label */}
          <SvgText
            x={CX}
            y={CY - (holedR + lipOutR) / 2 + 3}
            textAnchor="middle"
            fill={lipOut ? '#FFF' : '#FFFFFF66'}
            fontSize={7}
            fontWeight="600"
          >
            LIP
          </SvgText>

          {/* Holed label */}
          <SvgText
            x={CX}
            y={CY + 4}
            textAnchor="middle"
            fill={value === 'holed' ? '#FFFFFF' : '#3DBA6FCC'}
            fontSize={8}
            fontWeight="700"
          >
            ⬤
          </SvgText>

          {/* Outer ring border */}
          <Circle cx={CX} cy={CY} r={outerR} fill="none" stroke={colors.border} strokeWidth={1.5} />
        </Svg>

        {/* Touch overlay — transparent hit targets for each region */}
        <View style={StyleSheet.absoluteFill}>
          {/* 8 sector buttons */}
          {SECTORS.map((s) => (
            <SectorHitArea
              key={s.result}
              result={s.result}
              startDeg={s.startDeg}
              r1={sectorR1}
              r2={sectorR2}
              cx={CX}
              cy={CY}
              onPress={handlePress}
            />
          ))}

          {/* Lip-out ring touch */}
          <CircleRingHit
            r1={holedR}
            r2={lipOutR}
            cx={CX}
            cy={CY}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
              onLipOutChange(!lipOut);
            }}
          />

          {/* Holed centre touch */}
          <CircleRingHit
            r1={0}
            r2={holedR}
            cx={CX}
            cy={CY}
            onPress={() => handlePress('holed')}
          />
        </View>
      </View>

      {(value || lipOut) && (
        <Text style={styles.resultText}>
          {lipOut && value && value !== 'holed' ? `🔄 Lip + ${
            value === 'short'       ? 'Short' :
            value === 'long'        ? 'Long' :
            value === 'left'        ? 'Left' :
            value === 'right'       ? 'Right' :
            value === 'short_left'  ? 'Short Left' :
            value === 'short_right' ? 'Short Right' :
            value === 'long_left'   ? 'Long Left' : 'Long Right'
          }` :
           lipOut                ? '🕳 Lip Out' :
           value === 'holed'     ? '✅ Holed!' :
           value === 'short'     ? '⬇ Short' :
           value === 'long'      ? '⬆ Long' :
           value === 'left'      ? '⬅ Left' :
           value === 'right'     ? '➡ Right' :
           value === 'short_left'  ? '↙ Short Left' :
           value === 'short_right' ? '↘ Short Right' :
           value === 'long_left'   ? '↖ Long Left' :
                                    '↗ Long Right'}
        </Text>
      )}
    </View>
  );
}

// ─── Sector hit area ──────────────────────────────────────────────────────────
// Uses a TouchableOpacity positioned over the sector's bounding box.
// For simplicity we use the full SVG as one touchable and compute the angle.

function SectorHitArea({
  result, startDeg, r1, r2, cx, cy, onPress,
}: {
  result: PuttResult; startDeg: number; r1: number; r2: number;
  cx: number; cy: number;
  onPress: (r: PuttResult) => void;
}) {
  const endDeg = startDeg + 45;
  const mid    = ((startDeg + endDeg) / 2 * Math.PI) / 180;
  const rMid   = (r1 + r2) / 2;
  const bx     = cx + rMid * Math.cos(mid) - 24;
  const by     = cy + rMid * Math.sin(mid) - 24;

  return (
    <TouchableOpacity
      style={[styles.hitArea, { left: bx, top: by, width: 48, height: 48 }]}
      onPress={() => onPress(result)}
      activeOpacity={0.5}
    />
  );
}

function CircleRingHit({
  r1, r2, cx, cy, onPress,
}: {
  r1: number; r2: number;
  cx: number; cy: number;
  onPress: () => void;
}) {
  const d = r2 * 2;
  return (
    <TouchableOpacity
      style={[styles.hitArea, { left: cx - r2, top: cy - r2, width: d, height: d, borderRadius: r2 }]}
      onPress={onPress}
      activeOpacity={0.5}
    />
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: 8 },

  label: {
    fontSize: 10,
    fontWeight: '600',
    color: colors.textMuted,
    letterSpacing: 1.2,
  },

  board: {
    width: SIZE,
    height: SIZE,
    position: 'relative',
  },

  hitArea: {
    position: 'absolute',
    backgroundColor: 'transparent',
  },

  resultText: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text,
    letterSpacing: 0.3,
  },
});
