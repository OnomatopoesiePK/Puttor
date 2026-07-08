import React, { useRef, useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, LayoutChangeEvent } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, borderRadius } from '../constants/theme';
import { getDistanceList } from '../utils/unitConverter';
import { useSettingsStore } from '../store/settingsStore';

const VISIBLE = 5;
const ITEM_H  = 56;

interface Props {
  value: number;
  onChange: (metres: number) => void;
}

export function DistancePicker({ value, onChange }: Props) {
  const { units } = useSettingsStore();
  const useFeet   = units === 'imperial';
  const items     = getDistanceList(useFeet);
  const scrollRef = useRef<ScrollView>(null);
  const syncingRef = useRef(false);
  const lastSyncedIdxRef = useRef<number | null>(null);

  const selectedIdx = items.findIndex((d) => Math.abs(d.value - value) < 0.001);
  const safeIdx     = selectedIdx >= 0 ? selectedIdx : 0;
  const [pickerWidth, setPickerWidth] = useState(300);
  const [layoutReady, setLayoutReady] = useState(false);

  const itemWidth = useMemo(
    () => Math.max(52, Math.floor(pickerWidth / VISIBLE)),
    [pickerWidth]
  );
  const sidePad = Math.floor(pickerWidth / 2) - Math.floor(itemWidth / 2);

  const onWrapLayout = (e: LayoutChangeEvent) => {
    const nextWidth = e.nativeEvent.layout.width;
    if (Math.abs(nextWidth - pickerWidth) > 1) {
      setPickerWidth(nextWidth);
    }
    if (!layoutReady) setLayoutReady(true);
  };

  useEffect(() => {
    // Keep the scroll position in sync with external value changes.
    if (!layoutReady) return;
    if (lastSyncedIdxRef.current === safeIdx) return;
    lastSyncedIdxRef.current = safeIdx;
    syncingRef.current = true;
    const offset = Math.max(0, safeIdx * itemWidth);
    requestAnimationFrame(() => {
      scrollRef.current?.scrollTo({ x: offset, animated: false });
    });
    setTimeout(() => {
      syncingRef.current = false;
    }, 20);
  }, [safeIdx, itemWidth, layoutReady]);

  return (
    <View style={styles.container}>
      <Text style={styles.label}>DISTANCE TO HOLE</Text>

      <View style={styles.wrapper} onLayout={onWrapLayout}>
        {/* Highlight box behind centre item */}
        <View
          style={[styles.highlight, { width: itemWidth, marginLeft: -(itemWidth / 2) }]}
          pointerEvents="none"
        />

        <ScrollView
          ref={scrollRef}
          horizontal
          showsHorizontalScrollIndicator={false}
          snapToInterval={itemWidth}
          decelerationRate="fast"
          contentContainerStyle={{ paddingHorizontal: sidePad }}
          onMomentumScrollEnd={(e) => {
            if (syncingRef.current) return;
            const idx = Math.round(e.nativeEvent.contentOffset.x / itemWidth);
            const item = items[Math.max(0, Math.min(items.length - 1, idx))];
            if (item && Math.abs(item.value - value) >= 0.001) {
              Haptics.selectionAsync().catch(() => {});
              onChange(item.value);
            }
          }}
        >
          {items.map((item) => {
            const selected = Math.abs(item.value - value) < 0.001;
            return (
              <TouchableOpacity
                key={item.value}
                style={[styles.item, { width: itemWidth, height: ITEM_H }]}
                onPress={() => {
                  const idx = items.indexOf(item);
                  lastSyncedIdxRef.current = idx;
                  scrollRef.current?.scrollTo({ x: idx * itemWidth, animated: true });
                  Haptics.selectionAsync().catch(() => {});
                  onChange(item.value);
                }}
                activeOpacity={0.7}
              >
                <Text style={[styles.itemText, selected && styles.itemTextSel]}>
                  {item.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 6 },

  label: {
    fontSize: 10,
    fontWeight: '600',
    color: colors.textMuted,
    letterSpacing: 1.2,
    textAlign: 'center',
  },

  wrapper: {
    height: ITEM_H + 8,
    justifyContent: 'center',
    position: 'relative',
  },

  highlight: {
    position: 'absolute',
    left: '50%',
    top: 4,
    bottom: 4,
    backgroundColor: colors.primary + '22',
    borderRadius: borderRadius.md,
    borderWidth: 2,
    borderColor: colors.primary,
    zIndex: 0,
  },

  item: {
    alignItems: 'center',
    justifyContent: 'center',
  },

  itemText: {
    fontSize: 13,
    color: colors.textSecondary,
    fontWeight: '500',
  },

  itemTextSel: {
    fontSize: 17,
    color: colors.primary,
    fontWeight: '800',
  },
});

