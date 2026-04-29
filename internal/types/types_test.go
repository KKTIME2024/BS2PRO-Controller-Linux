package types

import (
	"encoding/json"
	"testing"
)

func TestGetDefaultFanCurve(t *testing.T) {
	curve := GetDefaultFanCurve()
	if len(curve) < 2 {
		t.Fatal("default fan curve should have at least 2 points")
	}
	for i, p := range curve {
		if i > 0 && p.Temperature <= curve[i-1].Temperature {
			t.Errorf("fan curve temps must increase: %d -> %d", curve[i-1].Temperature, p.Temperature)
		}
		if p.RPM < 0 {
			t.Errorf("fan curve RPM must be non-negative, got %d", p.RPM)
		}
	}
}

func TestGetDefaultConfig(t *testing.T) {
	cfg := GetDefaultConfig(false)
	if cfg.AutoStart {
		t.Error("AutoStart should default to false")
	}
	if cfg.AutoControl {
		t.Error("AutoControl should default to false")
	}
	if cfg.TempUpdateRate < 1 {
		t.Error("TempUpdateRate should be >= 1")
	}
	if len(cfg.FanCurveProfiles) == 0 {
		t.Error("should have at least one fan curve profile")
	}
	if cfg.FanCurveProfiles[0].ID != "default" {
		t.Error("default profile should have ID 'default'")
	}
	if cfg.LightStrip.Mode != "smart_temp" {
		t.Errorf("default light strip mode got %q", cfg.LightStrip.Mode)
	}
	if cfg.SmartControl.TargetTemp != 68 {
		t.Errorf("default target temp got %d", cfg.SmartControl.TargetTemp)
	}
}

func TestGetDefaultLightStripConfig(t *testing.T) {
	cfg := GetDefaultLightStripConfig()
	if cfg.Mode != "smart_temp" {
		t.Errorf("mode got %q", cfg.Mode)
	}
	if cfg.Brightness != 100 {
		t.Errorf("brightness got %d", cfg.Brightness)
	}
	if len(cfg.Colors) != 3 {
		t.Errorf("colors count got %d", len(cfg.Colors))
	}
}

func TestGetDefaultSmartControlConfig(t *testing.T) {
	curve := GetDefaultFanCurve()
	cfg := GetDefaultSmartControlConfig(curve)
	if !cfg.Enabled {
		t.Error("should be enabled by default")
	}
	if cfg.Aggressiveness < 1 || cfg.Aggressiveness > 10 {
		t.Errorf("aggressiveness out of range: %d", cfg.Aggressiveness)
	}
	if len(cfg.LearnedOffsets) != len(curve) {
		t.Errorf("LearnedOffsets length %d != curve length %d", len(cfg.LearnedOffsets), len(curve))
	}
}

func TestBS1Checksum(t *testing.T) {
	tests := []struct {
		data     []byte
		expected byte
	}{
		{[]byte{0x5a, 0xa5, 0x08, 0x03, 0x01}, 0x0c},
		{[]byte{0x5a, 0xa5, 0x08, 0x03, 0x02}, 0x0d},
		{[]byte{0x5a, 0xa5, 0x08, 0x03, 0x03}, 0x0e},
		{[]byte{0x5a, 0xa5, 0x08, 0x03, 0x04}, 0x0f},
	}
	for _, tc := range tests {
		result := BS1Checksum(tc.data)
		if result != tc.expected {
			t.Errorf("BS1Checksum(%x) = 0x%02x, want 0x%02x", tc.data, result, tc.expected)
		}
	}
}

func TestBuildBS1RPMCommand(t *testing.T) {
	// BS1 RPM command: 5AA5 21 04 rpm_lo rpm_hi checksum
	cmd := BuildBS1RPMCommand(1300)
	if len(cmd) != 7 {
		t.Fatalf("expected 7 bytes, got %d", len(cmd))
	}
	if cmd[0] != 0x5a || cmd[1] != 0xa5 {
		t.Error("wrong header")
	}
	// Verify checksum
	payload := cmd[:6]
	expectedChecksum := BS1Checksum(payload)
	if cmd[6] != expectedChecksum {
		t.Errorf("checksum 0x%02x, want 0x%02x", cmd[6], expectedChecksum)
	}
}

func TestBS1GearCommands(t *testing.T) {
	gears := []string{"静音", "标准", "强劲", "超频"}
	for _, name := range gears {
		cmd, ok := BS1GearCommands[name]
		if !ok {
			t.Errorf("missing gear: %s", name)
			continue
		}
		if len(cmd.Command) != 6 {
			t.Errorf("%s command length %d, want 6", name, len(cmd.Command))
		}
	}
}

func TestGearCommands(t *testing.T) {
	gears := []string{"静音", "标准", "强劲", "超频"}
	for _, name := range gears {
		levels, ok := GearCommands[name]
		if !ok {
			t.Errorf("missing gear: %s", name)
			continue
		}
		if len(levels) != 3 {
			t.Errorf("%s has %d levels, want 3", name, len(levels))
		}
		for _, l := range levels {
			if len(l.Command) != 23 {
				t.Errorf("%s/%s command length %d, want 23", name, l.Name, len(l.Command))
			}
		}
	}
}

func TestAppConfigJSONRoundtrip(t *testing.T) {
	cfg := GetDefaultConfig(false)
	b, err := json.Marshal(cfg)
	if err != nil {
		t.Fatal(err)
	}
	var restored AppConfig
	if err := json.Unmarshal(b, &restored); err != nil {
		t.Fatal(err)
	}
	if restored.AutoStart != cfg.AutoStart {
		t.Error("AutoStart mismatch")
	}
	if restored.TempUpdateRate != cfg.TempUpdateRate {
		t.Error("TempUpdateRate mismatch")
	}
	if len(restored.FanCurve) != len(cfg.FanCurve) {
		t.Errorf("FanCurve length %d != %d", len(restored.FanCurve), len(cfg.FanCurve))
	}
}

func TestBridgeTemperatureData(t *testing.T) {
	data := BridgeTemperatureData{
		CpuTemp: 50,
		GpuTemp: 40,
		Success: true,
	}
	b, _ := json.Marshal(data)
	var restored BridgeTemperatureData
	json.Unmarshal(b, &restored)
	if restored.CpuTemp != 50 || restored.GpuTemp != 40 {
		t.Error("roundtrip mismatch")
	}
}
