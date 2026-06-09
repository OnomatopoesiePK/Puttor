import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity, TextInput,
} from 'react-native';
import { router } from 'expo-router';
import Svg, { Path, Circle } from 'react-native-svg';
import { getPutters, Putter, createRound } from '../../db/queries';
import { useRoundStore } from '../../store/roundStore';
import { colors, spacing, borderRadius } from '../../constants/theme';

type Wind    = 'none' | 'medium' | 'high';
type Weather = 'cold' | 'warm' | 'hot';

const STIMP_MIN  = 6.5;
const STIMP_MAX  = 13.5;
const STIMP_RANGE = STIMP_MAX - STIMP_MIN;
const STIMP_SNAP  = [6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5];

const SLOW_MAX   = 8.5;
const FAST_MIN   = 11.0;

function stimpLabel(v: number): string {
  if (v <= SLOW_MAX) return 'SLOW';
  if (v >= FAST_MIN) return 'FAST';
  return 'MEDIUM';
}
function stimpLabelColor(v: number): string {
  if (v <= SLOW_MAX) return colors.uphill;
  if (v >= FAST_MIN) return colors.accent;
  return colors.primary;
}

export default function RoundSetupScreen() {
  const setRound    = useRoundStore((s) => s.setRound);

  const [courseName, setCourseName] = useState('');
  const [putters, setPutters]       = useState<Putter[]>([]);
  const [putterId, setPutterId]     = useState<number | null>(null);
  const [stimp, setStimp]           = useState(10);
  const [wind, setWind]             = useState<Wind>('none');
  const [weather, setWeather]       = useState<Weather>('warm');
  const [sliderW, setSliderW]       = useState(280);

  useEffect(() => { getPutters().then(setPutters); }, []);

  // Stimp slider helpers
  const stimpT  = (stimp - STIMP_MIN) / STIMP_RANGE;

  const handleStimpDrag = (dx: number) => {
    const t   = Math.max(0, Math.min(1, stimpT + dx / sliderW));
    const raw = STIMP_MIN + t * STIMP_RANGE;
    const nearest = STIMP_SNAP.reduce((a, b) =>
      Math.abs(b - raw) < Math.abs(a - raw) ? b : a
    );
    setStimp(nearest);
  };

  const handleStart = async () => {
    const id = await createRound({
      course_name: courseName.trim(),
      putter_id:   putterId,
      stimp,
      wind,
      weather,
    });
    setRound(id);
    router.replace(`/round/input?roundId=${id}`);
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.navBar}>
        <TouchableOpacity onPress={() => router.back()} hitSlop={12}>
          <Text style={styles.backBtn}>✕</Text>
        </TouchableOpacity>
        <Text style={styles.navTitle}>New Round</Text>
        <View style={{ width: 32 }} />
      </View>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">

        {/* Course name */}
        <Label>COURSE</Label>
        <TextInput
          style={styles.input}
          placeholder="Course name (optional)"
          placeholderTextColor={colors.textMuted}
          value={courseName}
          onChangeText={setCourseName}
          returnKeyType="done"
        />

        {/* Putter */}
        <Label>PUTTER</Label>
        {putters.length === 0 ? (
          <View style={styles.hint}>
            <Text style={styles.hintText}>Add putters in Settings → My Putters</Text>
          </View>
        ) : (
          <View style={styles.chipRow}>
            {putters.map((p) => (
              <TouchableOpacity
                key={p.id}
                style={[styles.chip, putterId === p.id && styles.chipActive]}
                onPress={() => setPutterId(putterId === p.id ? null : p.id)}
              >
                <Text style={[styles.chipText, putterId === p.id && styles.chipTextActive]}>
                  {p.name}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* Stimp */}
        <Label>STIMPMETER</Label>
        <View style={styles.card}>
          <View style={styles.stimpSpeedRow}>
            <Text style={[styles.stimpSpeedLabel, { opacity: stimp <= SLOW_MAX ? 1 : 0.3 }]}>SLOW</Text>
            <Text style={[styles.stimpSpeedLabel, { opacity: stimp > SLOW_MAX && stimp < FAST_MIN ? 1 : 0.3 }]}>MEDIUM</Text>
            <Text style={[styles.stimpSpeedLabel, { opacity: stimp >= FAST_MIN ? 1 : 0.3 }]}>FAST</Text>
          </View>

          {/* Stimp slider */}
          <View
            style={styles.stimpTrack}
            onLayout={(e) => setSliderW(e.nativeEvent.layout.width)}
          >
            {/* Track */}
            <View style={styles.stimpBar} />
            {/* Snap tick marks */}
            {STIMP_SNAP.map((sv) => {
              const tx = ((sv - STIMP_MIN) / STIMP_RANGE) * sliderW;
              return (
                <TouchableOpacity
                  key={sv}
                  style={[styles.stimpTick, { left: tx - 12 }]}
                  onPress={() => setStimp(sv)}
                >
                  <View style={[styles.tickMark, stimp === sv && styles.tickMarkActive]} />
                </TouchableOpacity>
              );
            })}
            {/* Thumb */}
            <View style={[styles.stimpThumb, { left: stimpT * sliderW - 14 }]}>
              <Text style={styles.stimpValue}>{stimp}</Text>
            </View>
          </View>

          <View style={styles.stimpScaleRow}>
            <Text style={styles.stimpScaleText}>{'<7'}</Text>
            <Text style={[styles.stimpScaleValue, { color: stimpLabelColor(stimp) }]}>
              {stimpLabel(stimp)}
            </Text>
            <Text style={styles.stimpScaleText}>{'>13'}</Text>
          </View>
        </View>

        {/* Wind */}
        <Label>WIND</Label>
        <ThreeToggle
          options={[
            { value: 'none',   label: 'None',   emoji: '🌤' },
            { value: 'medium', label: 'Medium', emoji: '💨' },
            { value: 'high',   label: 'High',   emoji: '🌬' },
          ]}
          value={wind}
          onChange={(v) => setWind(v as Wind)}
        />

        {/* Weather */}
        <Label>WEATHER</Label>
        <ThreeToggle
          options={[
            { value: 'cold', label: 'Cold', emoji: '🥶' },
            { value: 'warm', label: 'Warm', emoji: '😊' },
            { value: 'hot',  label: 'Hot',  emoji: '🥵' },
          ]}
          value={weather}
          onChange={(v) => setWeather(v as Weather)}
        />

        <View style={{ height: 20 }} />

        <TouchableOpacity style={styles.startBtn} onPress={handleStart} activeOpacity={0.85}>
          <Text style={styles.startText}>⛳  Start Round</Text>
        </TouchableOpacity>

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return <Text style={labelStyles.text}>{children}</Text>;
}
const labelStyles = StyleSheet.create({
  text: {
    fontSize: 10, fontWeight: '700', color: colors.textMuted,
    letterSpacing: 1.4, marginTop: 16, marginBottom: 6,
  },
});

function ThreeToggle({
  options, value, onChange,
}: {
  options: Array<{ value: string; label: string; emoji: string }>;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <View style={ttStyles.row}>
      {options.map((o) => (
        <TouchableOpacity
          key={o.value}
          style={[ttStyles.btn, value === o.value && ttStyles.btnActive]}
          onPress={() => onChange(o.value)}
          activeOpacity={0.7}
        >
          <Text style={ttStyles.emoji}>{o.emoji}</Text>
          <Text style={[ttStyles.label, value === o.value && ttStyles.labelActive]}>
            {o.label}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );
}
const ttStyles = StyleSheet.create({
  row:    { flexDirection: 'row', gap: 8 },
  btn:    {
    flex: 1, alignItems: 'center', paddingVertical: 12,
    borderRadius: borderRadius.md, borderWidth: 1.5, borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  btnActive: { borderColor: colors.primary, backgroundColor: colors.primary + '22' },
  emoji:     { fontSize: 20, marginBottom: 4 },
  label:     { fontSize: 12, fontWeight: '600', color: colors.textSecondary },
  labelActive: { color: colors.primary },
});

const styles = StyleSheet.create({
  safe:    { flex: 1, backgroundColor: colors.background },
  navBar:  {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: spacing.lg, paddingVertical: spacing.md,
    borderBottomWidth: 1, borderBottomColor: colors.border,
  },
  backBtn:   { fontSize: 20, color: colors.textSecondary },
  navTitle:  { fontSize: 18, fontWeight: '800', color: colors.text },

  scroll:  { flex: 1 },
  content: { paddingHorizontal: spacing.lg, paddingTop: 8 },

  input: {
    backgroundColor: colors.surface, borderRadius: borderRadius.md,
    borderWidth: 1, borderColor: colors.border,
    padding: spacing.md, color: colors.text, fontSize: 15,
  },

  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    paddingHorizontal: 16, paddingVertical: 8,
    borderRadius: borderRadius.full, borderWidth: 1.5, borderColor: colors.border,
    backgroundColor: colors.surface,
  },
  chipActive:   { borderColor: colors.primary, backgroundColor: colors.primary + '22' },
  chipText:     { fontSize: 13, fontWeight: '600', color: colors.textSecondary },
  chipTextActive: { color: colors.primary },

  hint:     { paddingVertical: 10 },
  hintText: { fontSize: 13, color: colors.textMuted, fontStyle: 'italic' },

  card: {
    backgroundColor: colors.surface, borderRadius: borderRadius.md,
    borderWidth: 1, borderColor: colors.border,
    padding: spacing.md, gap: 10,
  },

  stimpSpeedRow: {
    flexDirection: 'row', justifyContent: 'space-between',
  },
  stimpSpeedLabel: {
    fontSize: 11, fontWeight: '700', color: colors.textSecondary, letterSpacing: 1,
  },

  stimpTrack: {
    height: 44, position: 'relative', justifyContent: 'center', marginHorizontal: 14,
  },
  stimpBar: {
    height: 4, backgroundColor: colors.border, borderRadius: 2,
    position: 'absolute', left: 0, right: 0, top: 20,
  },
  stimpTick: {
    position: 'absolute', width: 24, alignItems: 'center',
    paddingVertical: 10,
  },
  tickMark: {
    width: 2, height: 8, backgroundColor: colors.border, borderRadius: 1,
  },
  tickMarkActive: { backgroundColor: colors.primary, height: 12 },
  stimpThumb: {
    position: 'absolute', width: 28, height: 28, borderRadius: 14,
    backgroundColor: colors.primary, top: 8,
    alignItems: 'center', justifyContent: 'center',
    shadowColor: colors.primary, shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.5, shadowRadius: 6, elevation: 4,
  },
  stimpValue: { fontSize: 10, fontWeight: '800', color: '#FFF' },

  stimpScaleRow: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
  },
  stimpScaleText:  { fontSize: 11, color: colors.textMuted },
  stimpScaleValue: { fontSize: 13, fontWeight: '800', letterSpacing: 0.5 },

  startBtn: {
    backgroundColor: colors.primary, borderRadius: borderRadius.lg,
    paddingVertical: spacing.lg, alignItems: 'center',
    shadowColor: colors.primary, shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4, shadowRadius: 12, elevation: 6,
  },
  startText: { fontSize: 18, fontWeight: '800', color: '#FFFFFF', letterSpacing: 0.3 },
});
