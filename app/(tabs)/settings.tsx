import React, { useEffect, useState } from 'react';
import {
  View, Text, StyleSheet, SafeAreaView, ScrollView,
  TouchableOpacity, TextInput, Alert, Switch,
} from 'react-native';
import {
  getPutters, addPutter, deletePutter, Putter,
} from '../../db/queries';
import { useSettingsStore } from '../../store/settingsStore';
import { colors, spacing, borderRadius } from '../../constants/theme';

export default function SettingsTab() {
  const { units, hapticsEnabled, setUnits, setHaptics } = useSettingsStore();
  const [putters, setPutters]     = useState<Putter[]>([]);
  const [newName, setNewName]     = useState('');
  const [adding, setAdding]       = useState(false);

  const loadPutters = () => getPutters().then(setPutters);
  useEffect(() => { loadPutters(); }, []);

  const handleAdd = async () => {
    if (!newName.trim()) return;
    await addPutter(newName.trim());
    setNewName('');
    setAdding(false);
    loadPutters();
  };

  const handleDelete = (p: Putter) => {
    Alert.alert('Delete Putter', `Remove "${p.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deletePutter(p.id).then(loadPutters) },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe}>
      <Text style={styles.header}>Settings</Text>

      <ScrollView style={styles.scroll} contentContainerStyle={styles.content}>

        {/* Units */}
        <SectionHeader title="UNITS" />
        <View style={styles.card}>
          <View style={styles.optRow}>
            <UnitButton
              label="Metres"
              emoji="📏"
              active={units === 'metric'}
              onPress={() => setUnits('metric')}
            />
            <UnitButton
              label="Feet"
              emoji="🦶"
              active={units === 'imperial'}
              onPress={() => setUnits('imperial')}
            />
          </View>
        </View>

        {/* Haptics */}
        <SectionHeader title="FEEDBACK" />
        <View style={[styles.card, styles.rowBetween]}>
          <View>
            <Text style={styles.settingLabel}>Haptic feedback</Text>
            <Text style={styles.settingDesc}>Vibrate on slider snaps</Text>
          </View>
          <Switch
            value={hapticsEnabled}
            onValueChange={setHaptics}
            trackColor={{ false: colors.border, true: colors.primary }}
            thumbColor="#FFFFFF"
          />
        </View>

        {/* Putters */}
        <SectionHeader title="MY PUTTERS" />
        <View style={styles.card}>
          {putters.map((p) => (
            <View key={p.id} style={styles.putterRow}>
              <Text style={styles.putterIcon}>🏌️</Text>
              <Text style={styles.putterName}>{p.name}</Text>
              <TouchableOpacity onPress={() => handleDelete(p)} hitSlop={8}>
                <Text style={styles.deleteBtn}>✕</Text>
              </TouchableOpacity>
            </View>
          ))}

          {adding ? (
            <View style={styles.addRow}>
              <TextInput
                style={styles.input}
                placeholder="Putter name…"
                placeholderTextColor={colors.textMuted}
                value={newName}
                onChangeText={setNewName}
                autoFocus
                returnKeyType="done"
                onSubmitEditing={handleAdd}
              />
              <TouchableOpacity style={styles.confirmBtn} onPress={handleAdd}>
                <Text style={styles.confirmText}>Add</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => { setAdding(false); setNewName(''); }}>
                <Text style={styles.cancelBtn}>✕</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <TouchableOpacity style={styles.addBtn} onPress={() => setAdding(true)}>
              <Text style={styles.addBtnText}>+ Add Putter</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* About */}
        <SectionHeader title="ABOUT" />
        <View style={styles.card}>
          <Text style={styles.aboutText}>PuttTrack v1.0</Text>
          <Text style={styles.aboutSub}>
            Strokes gained benchmarks based on PGA Tour data (Mark Broadie methodology).
          </Text>
        </View>

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <Text style={styles.sectionTitle}>{title}</Text>;
}

function UnitButton({ label, emoji, active, onPress }: {
  label: string; emoji: string; active: boolean; onPress: () => void;
}) {
  return (
    <TouchableOpacity
      style={[styles.unitBtn, active && styles.unitBtnActive]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <Text style={styles.unitEmoji}>{emoji}</Text>
      <Text style={[styles.unitLabel, active && styles.unitLabelActive]}>{label}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  safe:    { flex: 1, backgroundColor: colors.background },
  header:  { fontSize: 28, fontWeight: '800', color: colors.primary, padding: spacing.lg, paddingBottom: 4 },
  scroll:  { flex: 1 },
  content: { paddingHorizontal: spacing.lg, paddingTop: 8 },

  sectionTitle: {
    fontSize: 10, fontWeight: '700', color: colors.textMuted,
    letterSpacing: 1.4, paddingVertical: spacing.sm,
  },

  card: {
    backgroundColor: colors.surface,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    borderWidth: 1,
    borderColor: colors.border,
    marginBottom: spacing.md,
    gap: 8,
  },

  optRow: { flexDirection: 'row', gap: 10 },

  unitBtn: {
    flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    gap: 8, paddingVertical: 12,
    borderRadius: borderRadius.sm, borderWidth: 1.5, borderColor: colors.border,
  },
  unitBtnActive: { borderColor: colors.primary, backgroundColor: colors.primary + '22' },
  unitEmoji:     { fontSize: 18 },
  unitLabel:     { fontSize: 14, fontWeight: '700', color: colors.textSecondary },
  unitLabelActive: { color: colors.primary },

  rowBetween: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },

  settingLabel: { fontSize: 15, fontWeight: '600', color: colors.text },
  settingDesc:  { fontSize: 12, color: colors.textSecondary, marginTop: 2 },

  putterRow: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingVertical: 6, borderBottomWidth: 1, borderBottomColor: colors.borderLight,
  },
  putterIcon: { fontSize: 18 },
  putterName: { flex: 1, fontSize: 15, fontWeight: '600', color: colors.text },
  deleteBtn:  { fontSize: 16, color: colors.error, fontWeight: '700' },

  addRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  input: {
    flex: 1, height: 40, borderRadius: borderRadius.sm, borderWidth: 1,
    borderColor: colors.border, paddingHorizontal: 10, color: colors.text,
    backgroundColor: colors.card, fontSize: 14,
  },
  confirmBtn: {
    backgroundColor: colors.primary, borderRadius: borderRadius.sm,
    paddingHorizontal: 16, height: 40, alignItems: 'center', justifyContent: 'center',
  },
  confirmText: { color: '#FFF', fontWeight: '700', fontSize: 14 },
  cancelBtn:   { fontSize: 18, color: colors.textMuted, paddingHorizontal: 4 },

  addBtn: { alignItems: 'center', paddingVertical: 8 },
  addBtnText: { fontSize: 14, fontWeight: '700', color: colors.primary },

  aboutText: { fontSize: 16, fontWeight: '700', color: colors.text },
  aboutSub:  { fontSize: 12, color: colors.textSecondary, lineHeight: 18 },
});
