import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView,
  ScrollView, TouchableOpacity, Alert,
} from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { addPutt, updatePutt, getPuttsForRound, completeRound, PuttResult } from '../../db/queries';
import { useRoundStore } from '../../store/roundStore';
import { CurvedSlopeSlider } from '../../components/CurvedSlopeSlider';
import { HillSlider } from '../../components/HillSlider';
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
    draft, setDraft, resetDraft,
    addPutt: storePutt, updatePuttInStore,
    goNextHole, setReviewIndex, setRound,
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

  const puttsOnThisHole = allPutts.filter((p) => p.hole_number === currentHole);
  const totalPutts      = allPutts.length;

  const isReviewing  = reviewIndex !== null;
  const reviewedPutt = isReviewing ? allPutts[reviewIndex!] : null;

  const canRecord = draft.result !== null;

  const handleRecord = async () => {
    if (!canRecord || saving) return;
    setSaving(true);

    try {
      if (isReviewing && reviewedPutt) {
        // Update existing putt
        await updatePutt(reviewedPutt.id, {
          distance_m:     draft.distanceM,
          side_slope_pct: draft.sideSlopePct,
          hill_slope_pct: draft.hillSlopePct,
          double_break:   draft.doubleBreak,
          result:         draft.result as PuttResult,
        });
        updatePuttInStore({
          ...reviewedPutt,
          distance_m:     draft.distanceM,
          side_slope_pct: draft.sideSlopePct,
          hill_slope_pct: draft.hillSlopePct,
          double_break:   draft.doubleBreak,
          result:         draft.result as PuttResult,
        });
        setReviewIndex(null);
        resetDraft();
      } else {
        // New putt
        const puttNum = puttsOnThisHole.length + 1;
        const saved = await addPutt({
          round_id:      roundId,
          hole_number:   currentHole,
          putt_number:   puttNum,
          distance_m:    draft.distanceM,
          side_slope_pct: draft.sideSlopePct,
          hill_slope_pct: draft.hillSlopePct,
          double_break:  draft.doubleBreak,
          result:        draft.result as PuttResult,
        });
        storePutt(saved);

        Haptics.notificationAsync(
          draft.result === 'holed'
            ? Haptics.NotificationFeedbackType.Success
            : Haptics.NotificationFeedbackType.Warning
        ).catch(() => {});

        if (draft.result === 'holed') {
          goNextHole();
        } else {
          resetDraft();
        }
      }
    } finally {
      setSaving(false);
    }
  };

  const handleEndRound = () => {
    Alert.alert(
      'End Round',
      `End round after ${totalPutts} putts across ${currentHole - 1 + (puttsOnThisHole.length > 0 ? 1 : 0)} hole(s)?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'End Round',
          style: 'destructive',
          onPress: async () => {
            await completeRound(roundId);
            router.replace(`/round/summary?roundId=${roundId}`);
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
          <Text style={styles.holeNum}>{currentHole}</Text>
        </View>
        <View style={styles.puttCounters}>
          <CountBadge label="This hole" value={puttsOnThisHole.length} />
          <CountBadge label="Total" value={totalPutts} />
        </View>
        <TouchableOpacity style={styles.endBtn} onPress={handleEndRound}>
          <Text style={styles.endBtnText}>End</Text>
        </TouchableOpacity>
      </View>

      {isReviewing && (
        <View style={styles.reviewBanner}>
          <Text style={styles.reviewText}>
            Editing · H{reviewedPutt?.hole_number} Putt {reviewedPutt?.putt_number}
          </Text>
          <TouchableOpacity onPress={() => { setReviewIndex(null); resetDraft(); }}>
            <Text style={styles.reviewCancel}>Cancel edit</Text>
          </TouchableOpacity>
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

        {/* Break slider */}
        <Section label="SIDE SLOPE / BREAK">
          <CurvedSlopeSlider
            value={draft.sideSlopePct}
            onChange={(v) => setDraft({ sideSlopePct: v })}
            disabled={draft.doubleBreak !== null}
          />
          <DoubleBreakButtons
            value={draft.doubleBreak as any}
            onChange={(v) => setDraft({ doubleBreak: v })}
          />
        </Section>

        {/* Hill slider */}
        <Section label="UPHILL / DOWNHILL">
          <HillSlider
            value={draft.hillSlopePct}
            onChange={(v) => setDraft({ hillSlopePct: v })}
          />
        </Section>

        {/* Dartboard */}
        <Section label="RESULT">
          <DartboardMiss
            value={draft.result as PuttResult | null}
            onChange={(r) => setDraft({ result: r })}
          />
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
            {isReviewing ? '✓  Save Edit' : draft.result === 'holed' ? '⛳  Holed! Next Hole' : '→  Record Putt'}
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
    gap: 12,
  },

  holeInfo:  { alignItems: 'center' },
  holeLabel: { fontSize: 9, fontWeight: '700', color: colors.textMuted, letterSpacing: 1.2 },
  holeNum:   { fontSize: 32, fontWeight: '900', color: colors.primary, lineHeight: 34 },

  puttCounters: { flex: 1, flexDirection: 'row', justifyContent: 'center', gap: 24 },

  endBtn:     { paddingHorizontal: 14, paddingVertical: 8, borderRadius: borderRadius.sm, borderWidth: 1.5, borderColor: colors.error },
  endBtnText: { fontSize: 13, fontWeight: '700', color: colors.error },

  reviewBanner: {
    backgroundColor: colors.accent + '22',
    borderBottomWidth: 1,
    borderBottomColor: colors.accent + '44',
    paddingHorizontal: spacing.lg,
    paddingVertical: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  reviewText:   { fontSize: 13, fontWeight: '600', color: colors.accent },
  reviewCancel: { fontSize: 12, color: colors.textSecondary },

  scroll:        { flex: 1 },
  scrollContent: { padding: spacing.md },

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
