import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { colors, borderRadius } from '../constants/theme';

type DoubleBreakType = 'rl_lr' | 'lr_rl' | null;

interface Props {
  value: DoubleBreakType;
  onChange: (v: DoubleBreakType) => void;
}

export function DoubleBreakButtons({ value, onChange }: Props) {
  const toggle = (type: 'rl_lr' | 'lr_rl') => {
    onChange(value === type ? null : type);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.label}>DOUBLE BREAK</Text>
      <View style={styles.row}>
        <TouchableOpacity
          style={[styles.btn, value === 'rl_lr' && styles.btnActive]}
          onPress={() => toggle('rl_lr')}
          activeOpacity={0.7}
        >
          <Text style={styles.btnIcon}>↩</Text>
          <Text style={[styles.btnText, value === 'rl_lr' && styles.btnTextActive]}>
            R→L then L→R
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.btn, value === 'lr_rl' && styles.btnActive]}
          onPress={() => toggle('lr_rl')}
          activeOpacity={0.7}
        >
          <Text style={styles.btnIcon}>↪</Text>
          <Text style={[styles.btnText, value === 'lr_rl' && styles.btnTextActive]}>
            L→R then R→L
          </Text>
        </TouchableOpacity>
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

  row: {
    flexDirection: 'row',
    gap: 10,
  },

  btn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    paddingHorizontal: 8,
    borderRadius: borderRadius.md,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.surface,
  },

  btnActive: {
    borderColor: colors.accent,
    backgroundColor: colors.accent + '22',
  },

  btnIcon: {
    fontSize: 18,
    color: colors.text,
  },

  btnText: {
    fontSize: 12,
    fontWeight: '600',
    color: colors.textSecondary,
  },

  btnTextActive: {
    color: colors.accent,
  },
});
