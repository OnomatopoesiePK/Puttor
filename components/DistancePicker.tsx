import React, { useRef, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, borderRadius } from '../constants/theme';
import { getDistanceList } from '../utils/unitConverter';
import { useSettingsStore } from '../store/settingsStore';

const ITEM_W = 70;
const ITEM_H = 52;
const { width: SW } = Dimensions.get('window');
const SIDE_PAD = SW / 2 - ITEM_W / 2;

interface Props {
  value: number; // metres (0 = <0.5 m)
  onChange: (metres: number) => void;
}

export function DistancePicker({ value, onChange }: Props) {
  const { units } = useSettingsStore();
  const useFeet   = units === 'imperial';
  const items     = getDistanceList(useFeet);

  // Simple horizontal scroll using ScrollView-like FlatList pattern
  const listRef = useRef<any>(null);

  const selectedIdx = items.findIndex((d) => d.value === value);
  const safeIdx     = selectedIdx >= 0 ? selectedIdx : 0;

  const scrollTo = (idx: number) => {
    listRef.current?.scrollToOffset({
      offset: idx * ITEM_W,
      animated: true,
    });
  };

  return (
    <View style={styles.container}>
      <Text style={styles.label}>DISTANCE TO HOLE</Text>

      <View style={styles.wrapper}>
        {/* Highlight box behind selected item */}
        <View style={styles.highlight} pointerEvents="none" />

        <View style={styles.listOuter}>
          {/* Rendered as a simple ScrollView-backed flat list */}
          <FlatListScroll
            ref={listRef}
            items={items}
            itemWidth={ITEM_W}
            itemHeight={ITEM_H}
            sidePad={SIDE_PAD}
            selectedValue={value}
            onSelect={(v, idx) => {
              Haptics.selectionAsync().catch(() => {});
              onChange(v);
              scrollTo(idx);
            }}
          />
        </View>
      </View>
    </View>
  );
}

// ─── Inner flat list ──────────────────────────────────────────────────────────

import { ScrollView } from 'react-native';

interface FlatListScrollProps {
  items: Array<{ value: number; label: string }>;
  itemWidth: number;
  itemHeight: number;
  sidePad: number;
  selectedValue: number;
  onSelect: (v: number, idx: number) => void;
}

const FlatListScroll = React.forwardRef<ScrollView, FlatListScrollProps>(
  ({ items, itemWidth, itemHeight, sidePad, selectedValue, onSelect }, ref) => {
    const selIdx = items.findIndex((d) => d.value === selectedValue);

    return (
      <ScrollView
        ref={ref}
        horizontal
        showsHorizontalScrollIndicator={false}
        snapToInterval={itemWidth}
        decelerationRate="fast"
        contentContainerStyle={{ paddingHorizontal: sidePad }}
        contentOffset={{ x: Math.max(0, selIdx * itemWidth), y: 0 }}
        onMomentumScrollEnd={(e) => {
          const idx = Math.round(e.nativeEvent.contentOffset.x / itemWidth);
          if (items[idx] && items[idx].value !== selectedValue) {
            Haptics.selectionAsync().catch(() => {});
            onSelect(items[idx].value, idx);
          }
        }}
      >
        {items.map((item, idx) => {
          const selected = item.value === selectedValue;
          return (
            <TouchableOpacity
              key={item.value}
              style={[styles.item, { width: itemWidth, height: itemHeight }]}
              onPress={() => onSelect(item.value, idx)}
              activeOpacity={0.7}
            >
              <Text style={[styles.itemText, selected && styles.itemTextSel]}>
                {item.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    );
  }
);

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
    marginLeft: -(ITEM_W / 2),
    top: 4,
    bottom: 4,
    width: ITEM_W,
    backgroundColor: colors.primary + '1A',
    borderRadius: borderRadius.md,
    borderWidth: 1.5,
    borderColor: colors.primary,
    zIndex: 0,
  },

  listOuter: {
    flex: 1,
    zIndex: 1,
  },

  item: {
    alignItems: 'center',
    justifyContent: 'center',
  },

  itemText: {
    fontSize: 14,
    color: colors.textSecondary,
    fontWeight: '500',
  },

  itemTextSel: {
    fontSize: 16,
    color: colors.primary,
    fontWeight: '800',
  },
});
