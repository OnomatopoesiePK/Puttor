import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity, Alert,
} from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { addPutt, updatePutt, getPuttsForRound, completeRound, deletePuttsAfterOnHole, PuttResult } from '../../db/queries';
import { useRoundStore } from '../../store/roundStore';
import { SlopeGridPicker } from '../../components/SlopeGridPicker';
import { DoubleBreakButtons } from '../../components/DoubleBreakButtons';
import { DistancePicker } from '../../components/DistancePicker';
import { DartboardMiss } from '../../components/DartboardMiss';
import { colors, spacing, borderRadius } from '../../constants/theme';

export default function InputScreen() {
  const { roundId: roundIdStr } = useLocalSearchParams<{ roundId: string }>();
  const roundId = Number(roundIdStr);

  const store = useRoundStore();
  const {
    currentHole, allPutts, reviewIndex,
    draft, setDraft, resetDraft, resetAfterMiss,
    addPutt: storePutt, updatePuttInStore, removePuttsAfterOnHole,
    goNextHole, setReviewIndex, setRound, setCurrentHole,
  } = store;

  const [saving, setSaving] = useState(false);

  // Load any previously saved putts if resuming
  useEffect(() => {
    setRound(roundId);
    getPuttsForRound(roundId).then((existing) => {
      if (existing.length > 0) {
        existing.forEach((p) => storePutt(p));
        const lastHole = existing[existing.length - 1].hole_number;
        // Determine current hole state
        const lastResult = existing[existing.length - 1].result;
        if (lastResult === 'holed') {
          store.goNextHole();
          // override: set to correct hole
          // goNextHole only increments once; manually set if needed
        }
      }
    });
  }, [roundId]);

  const puttsOnCurrentHole = allPutts.filter((p) => p.hole_number === currentHole);
  const totalPutts      = allPutts.length;

  const isReviewing  = reviewIndex !== null;
  const reviewedPutt = isReviewing ? allPutts[reviewIndex!] : null;
  const displayHole  = reviewedPutt?.hole_number ?? currentHole;
  const puttsOnDisplayHole = allPutts.filter((p) => p.hole_number === displayHole);

  const canRecord = draft.result !== null || draft.lipOut;

  const normalizeDistance = (distanceM: number) => (distanceM < 0.5 ? 0.3 : distanceM);

  const savePutt = async (overrideDraft?: typeof draft) => {
    const workingDraft = overrideDraft ?? draft;
    const effectiveResult = (workingDraft.result ?? (workingDraft.lipOut ? 'hole_high' : null)) as PuttResult;
    const effectiveDistance = normalizeDistance(workingDraft.distanceM);

    if (isReviewing && reviewedPutt) {
      const previousResult = reviewedPutt.result;

      await updatePutt(reviewedPutt.id, {
        distance_m:     effectiveDistance,
        side_slope_pct: workingDraft.sideSlopePct,
        hill_slope_pct: workingDraft.hillSlopePct,
        double_break:   workingDraft.doubleBreak,
        result:         effectiveResult,
        lip_out:        workingDraft.lipOut,
        miss_read:      workingDraft.missRead,
        bad_strike:     workingDraft.badStrike,
      });

      if (effectiveResult === 'holed') {
        await deletePuttsAfterOnHole(roundId, reviewedPutt.hole_number, reviewedPutt.putt_number);
        removePuttsAfterOnHole(reviewedPutt.hole_number, reviewedPutt.putt_number);
      }

      updatePuttInStore({
        ...reviewedPutt,
        distance_m:     effectiveDistance,
        side_slope_pct: workingDraft.sideSlopePct,
        hill_slope_pct: workingDraft.hillSlopePct,
        double_break:   workingDraft.doubleBreak,
        result:         effectiveResult,
        lip_out:        workingDraft.lipOut ? 1 : 0,
        miss_read:      workingDraft.missRead ? 1 : 0,
        bad_strike:     workingDraft.badStrike ? 1 : 0,
      });

      if (effectiveResult === 'holed' && reviewedPutt.hole_number === currentHole) {
        if (currentHole === 18) {
          Alert.alert(
            '⛳ Hole 18 Complete!',
            'Do you want to end the round?',
            [
              {
                text: 'End Round',
                onPress: async () => {
                  await completeRound(roundId);
                  router.replace(`/round/summary?roundId=${roundId}`);
                },
              },
              {
                text: 'Continue (Hole 1)',
                onPress: () => store.restartFromHoleOne(),
              },
            ]
          );
        } else {
          goNextHole();
        }
        setReviewIndex(null);
        resetDraft();
        return;
      }

      if (previousResult === 'holed' && effectiveResult !== 'holed') {
        setCurrentHole(reviewedPutt.hole_number);
        setReviewIndex(null);
        resetAfterMiss();
        return;
      }

      setReviewIndex(null);
      resetDraft();
      return;
    }

    const puttNum = puttsOnCurrentHole.length + 1;
    const saved = await addPutt({
      round_id:      roundId,
      hole_number:   currentHole,
      putt_number:   puttNum,
      distance_m:    effectiveDistance,
      side_slope_pct: workingDraft.sideSlopePct,
      hill_slope_pct: workingDraft.hillSlopePct,
      double_break:  workingDraft.doubleBreak,
      result:        effectiveResult,
      lip_out:       workingDraft.lipOut,
      miss_read:     workingDraft.missRead,
      bad_strike:    workingDraft.badStrike,
    });
    storePutt(saved);

    Haptics.notificationAsync(
      effectiveResult === 'holed'
        ? Haptics.NotificationFeedbackType.Success
        : Haptics.NotificationFeedbackType.Warning
    ).catch(() => {});

    if (effectiveResult === 'holed') {
      if (currentHole === 18) {
        Alert.alert(
          '⛳ Hole 18 Complete!',
          'Do you want to end the round?',
          [
            {
              text: 'End Round',
              onPress: async () => {
                await completeRound(roundId);
                router.replace(`/round/summary?roundId=${roundId}`);
              },
            },
            {
              text: 'Continue (Hole 1)',
              onPress: () => store.restartFromHoleOne(),
            },
          ]
        );
      } else {
        goNextHole();
      }
    } else {
      resetAfterMiss();
    }
  };

  const handleRecord = async () => {
    if (!canRecord || saving) return;
    setSaving(true);

    try {
      await savePutt();
    } finally {
      setSaving(false);
    }
  };

  const handleTapIn = async () => {
    if (saving) return;
    setSaving(true);
    try {
      await savePutt({
        ...draft,
        distanceM: 0.3,
        result: 'holed',
        lipOut: false,
        missRead: false,
        badStrike: false,
      });
    } finally {
      setSaving(false);
    }
  };

  const handleEndRound = () => {
    const playedHoles = new Set(allPutts.map((p) => p.hole_number)).size;
    const defaultHoleCount = playedHoles === 9 ? 9 : 18;

    const finishRound = async (holeCount: number) => {
      await completeRound(roundId, holeCount);
      router.replace(`/round/summary?roundId=${roundId}`);
    };

    Alert.alert(
      'End Round',
      `End round after ${totalPutts} putts across ${playedHoles} hole(s)?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'End Round',
          style: 'destructive',
          onPress: () => {
            if (playedHoles === 9) {
              Alert.alert(
                'Save as 9-hole round?',
                'Do you want to save this round as 9 holes or as a full 18-hole round?',
                [
                  { text: 'Cancel', style: 'cancel' },
                  {
                    text: 'Save 9 Holes',
                    onPress: () => {
                      finishRound(9).catch(() => {});
                    },
                  },
                  {
                    text: 'Save 18 Holes',
                    style: 'destructive',
                    onPress: () => {
                      finishRound(18).catch(() => {});
                    },
                  },
                ]
              );
              return;
            }

            finishRound(defaultHoleCount).catch(() => {});
          },
        },
      ]
    );
  };

  const puttsForNav = allPutts; // all putts for back/forward nav

  return (
    <SafeAreaView style={styles.safe}>
      {/* Top bar */}
      <View style={styles.topBar}>
        <View style={styles.holeInfo}>
          <Text style={styles.holeLabel}>HOLE</Text>
          <Text style={styles.holeNum}>{displayHole}</Text>
        </View>

        {/* Putt boxes for current hole */}
        <View style={styles.puttBoxRow}>
          {puttsOnDisplayHole.map((p, i) => {
            const globalIdx = allPutts.indexOf(p);
            const isActive = reviewIndex === globalIdx;
            const isHoled  = p.result === 'holed';
            return (
              <TouchableOpacity
                key={p.id}
                style={[styles.puttBox, isActive && styles.puttBoxActive, isHoled && styles.puttBoxHoled]}
                onPress={() => setReviewIndex(globalIdx)}
                activeOpacity={0.7}
              >
                <Text style={[styles.puttBoxText, isHoled && styles.puttBoxTextHoled]}>
                  {isHoled ? '⛳' : String(i + 1)}
                </Text>
              </TouchableOpacity>
            );
          })}
          {/* New putt indicator (not reviewing) */}
          {!isReviewing && (
            <View style={[styles.puttBox, styles.puttBoxNew]}>
              <Text style={styles.puttBoxNewText}>{puttsOnDisplayHole.length + 1}</Text>
            </View>
          )}
        </View>

        <View style={styles.totalBadge}>
          <Text style={styles.totalNum}>{totalPutts}</Text>
          <Text style={styles.totalLabel}>TOTAL</Text>
        </View>

        <TouchableOpacity style={styles.endBtn} onPress={handleEndRound}>
          <Text style={styles.endBtnText}>End</Text>
        </TouchableOpacity>
      </View>

      {isReviewing && (
        <View style={styles.reviewBanner}>
          <Text style={styles.reviewText}>BEARBEITUNG</Text>
        </View>
      )}

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* Distance Picker */}
        <Section>
          <DistancePicker
            value={draft.distanceM}
            onChange={(v) => setDraft({ distanceM: v })}
          />
        </Section>

        {/* Slope grid */}
        <Section>
          <SlopeGridPicker
            sideValue={draft.sideSlopePct}
            hillValue={draft.hillSlopePct}
            onChange={({ sideSlopePct, hillSlopePct }) => setDraft({ sideSlopePct, hillSlopePct })}
          />
          <DoubleBreakButtons
            value={draft.doubleBreak as any}
            onChange={(v) => setDraft({ doubleBreak: v })}
          />
        </Section>

        {/* Dartboard */}
        <Section>
          <DartboardMiss
            value={draft.result as PuttResult | null}
            lipOut={draft.lipOut}
            onChange={(r) => setDraft({ result: r })}
            onLipOutChange={(v) => setDraft({ lipOut: v })}
          />
          {/* Miss reason toggles */}
          <View style={missStyles.row}>
            <TouchableOpacity
              style={[missStyles.btn, draft.missRead && missStyles.btnActive]}
              onPress={() => setDraft({ missRead: !draft.missRead })}
              activeOpacity={0.8}
            >
              <Text style={[missStyles.btnText, draft.missRead && missStyles.btnTextActive]}>
                📖 Miss Read
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[missStyles.btn, draft.badStrike && missStyles.btnActive]}
              onPress={() => setDraft({ badStrike: !draft.badStrike })}
              activeOpacity={0.8}
            >
              <Text style={[missStyles.btnText, draft.badStrike && missStyles.btnTextActive]}>
                🏌️ Bad Strike
              </Text>
            </TouchableOpacity>
          </View>
        </Section>

        <Section>
          <TouchableOpacity
            style={[styles.tapInBtn, saving && styles.tapInBtnDisabled]}
            onPress={handleTapIn}
            disabled={saving}
            activeOpacity={0.85}
          >
            <Text style={styles.tapInText}>Tap-In (0.3 m)</Text>
          </TouchableOpacity>
        </Section>

        <View style={{ height: 20 }} />
      </ScrollView>

      {/* Bottom bar: navigation + record */}
      <View style={styles.bottomBar}>
        {/* Back/Forward through putt history */}
        <View style={styles.navArrows}>
          <TouchableOpacity
            style={[styles.arrowBtn, puttsForNav.length === 0 && styles.arrowBtnDisabled]}
            disabled={puttsForNav.length === 0}
            onPress={() => {
              const idx = reviewIndex !== null ? reviewIndex - 1 : puttsForNav.length - 1;
              if (idx >= 0) setReviewIndex(idx);
            }}
          >
            <Text style={styles.arrowText}>‹</Text>
          </TouchableOpacity>
          <Text style={styles.navHint}>
            {isReviewing
              ? `${reviewIndex! + 1} / ${puttsForNav.length}`
              : `${puttsForNav.length} recorded`}
          </Text>
          <TouchableOpacity
            style={[styles.arrowBtn, (!isReviewing || reviewIndex === puttsForNav.length - 1) && styles.arrowBtnDisabled]}
            disabled={!isReviewing || reviewIndex === puttsForNav.length - 1}
            onPress={() => {
              if (reviewIndex !== null && reviewIndex < puttsForNav.length - 1) {
                setReviewIndex(reviewIndex + 1);
              } else {
                setReviewIndex(null);
                resetDraft();
              }
            }}
          >
            <Text style={styles.arrowText}>›</Text>
          </TouchableOpacity>
        </View>

        <TouchableOpacity
          style={[styles.recordBtn, !canRecord && styles.recordBtnDisabled]}
          onPress={handleRecord}
          disabled={!canRecord || saving}
          activeOpacity={0.85}
        >
          <Text style={styles.recordText}>
            {isReviewing ? '✓  Save Edit' : (draft.result === 'holed') ? '⛳  Holed! Next Hole' : '→  Record Putt'}
          </Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

function Section({ label, children }: { label?: string; children: React.ReactNode }) {
  return (
    <View style={sectionStyles.wrap}>
      {label && <Text style={sectionStyles.label}>{label}</Text>}
      <View style={sectionStyles.inner}>{children}</View>
    </View>
  );
}
const sectionStyles = StyleSheet.create({
  wrap:  { marginBottom: spacing.md },
  label: {
    fontSize: 10, fontWeight: '700', color: colors.textMuted,
    letterSpacing: 1.4, marginBottom: 8,
  },
  inner: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.lg,
    padding: spacing.md,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 12,
  },
});

const missStyles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 4,
  },
  btn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: borderRadius.md,
    alignItems: 'center',
    backgroundColor: colors.surfaceElevated,
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  btnActive: {
    backgroundColor: colors.accent + '22',
    borderColor: colors.accent,
  },
  btnText: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.textSecondary,
  },
  btnTextActive: {
    color: colors.accent,
  },
});

function CountBadge({ label, value }: { label: string; value: number }) {
  return (
    <View style={badgeStyles.wrap}>
      <Text style={badgeStyles.value}>{value}</Text>
      <Text style={badgeStyles.label}>{label}</Text>
    </View>
  );
}
const badgeStyles = StyleSheet.create({
  wrap:  { alignItems: 'center' },
  value: { fontSize: 20, fontWeight: '800', color: colors.text },
  label: { fontSize: 9, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8 },
});

const styles = StyleSheet.create({
  safe:   { flex: 1, backgroundColor: colors.background },

  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    gap: 8,
  },

  holeInfo:  { alignItems: 'center', minWidth: 40 },
  holeLabel: { fontSize: 9, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },
  holeNum:   { fontSize: 30, fontWeight: '900', color: colors.primary, lineHeight: 32 },

  puttBoxRow: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap' },
  puttBox: {
    width: 32, height: 32, borderRadius: borderRadius.sm,
    backgroundColor: colors.surfaceElevated,
    borderWidth: 1.5, borderColor: colors.border,
    alignItems: 'center', justifyContent: 'center',
  },
  puttBoxActive:   { borderColor: colors.accent, backgroundColor: colors.accent + '22' },
  puttBoxHoled:    { borderColor: colors.primary, backgroundColor: colors.primary + '33' },
  puttBoxText:     { fontSize: 13, fontWeight: '700', color: colors.textSecondary },
  puttBoxTextHoled:{ fontSize: 11 },
  puttBoxNew:      { borderColor: colors.primary, borderStyle: 'dashed', backgroundColor: 'transparent' },
  puttBoxNewText:  { fontSize: 13, fontWeight: '700', color: colors.primary },

  totalBadge: { alignItems: 'center' },
  totalNum:   { fontSize: 18, fontWeight: '800', color: colors.text },
  totalLabel: { fontSize: 8, color: colors.textMuted, fontWeight: '600', letterSpacing: 0.8 },

  puttCounters: { flex: 1, flexDirection: 'row', justifyContent: 'center', gap: 24 },

  endBtn:     { paddingHorizontal: 12, paddingVertical: 8, borderRadius: borderRadius.sm, borderWidth: 1.5, borderColor: colors.error },
  endBtnText: { fontSize: 12, fontWeight: '700', color: colors.error },

  reviewBanner: {
    backgroundColor: colors.accent + '22',
    borderBottomWidth: 1,
    borderBottomColor: colors.accent + '44',
    paddingHorizontal: spacing.lg,
    paddingVertical: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  reviewText:   { fontSize: 13, fontWeight: '600', color: colors.accent },

  scroll:        { flex: 1 },
  scrollContent: { padding: spacing.md },

  tapInBtn: {
    borderRadius: borderRadius.md,
    paddingVertical: 11,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: colors.primary,
    backgroundColor: colors.primary + '22',
  },
  tapInBtnDisabled: { opacity: 0.5 },
  tapInText: {
    color: colors.primary,
    fontSize: 14,
    fontWeight: '800',
    letterSpacing: 0.3,
  },

  bottomBar: {
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: 10,
    backgroundColor: colors.surface,
  },

  navArrows: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  arrowBtn: {
    width: 44, height: 36,
    backgroundColor: colors.surfaceElevated,
    borderRadius: borderRadius.sm,
    alignItems: 'center', justifyContent: 'center',
    borderWidth: 1, borderColor: colors.border,
  },
  arrowBtnDisabled: { opacity: 0.3 },
  arrowText: { fontSize: 22, color: colors.text, lineHeight: 26 },
  navHint:   { fontSize: 12, color: colors.textSecondary },

  recordBtn: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.lg,
    paddingVertical: 14,
    alignItems: 'center',
    shadowColor: colors.primary,
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.4,
    shadowRadius: 8,
    elevation: 4,
  },
  recordBtnDisabled: { backgroundColor: colors.border, shadowOpacity: 0 },
  recordText: { fontSize: 16, fontWeight: '800', color: '#FFFFFF', letterSpacing: 0.3 },
});
