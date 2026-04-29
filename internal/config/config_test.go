package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
)

type testLogger struct{}

func (t *testLogger) Info(string, ...any)  {}
func (t *testLogger) Error(string, ...any) {}
func (t *testLogger) Warn(string, ...any)  {}
func (t *testLogger) Debug(string, ...any) {}
func (t *testLogger) Close()               {}
func (t *testLogger) CleanOldLogs()        {}
func (t *testLogger) SetDebugMode(bool)    {}
func (t *testLogger) GetLogDir() string    { return "" }

// isolateConfigDir redirects XDG_CONFIG_HOME to a temp dir so tests don't
// touch the real user config.
func isolateConfigDir(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	configHome := filepath.Join(tmp, ".config")
	if err := os.MkdirAll(configHome, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", configHome)
	return configHome
}

func TestNewManager(t *testing.T) {
	m := NewManager("/tmp/test-install", &testLogger{})
	if m == nil {
		t.Fatal("NewManager returned nil")
	}
}

func TestLoadDefaultConfig(t *testing.T) {
	isolateConfigDir(t)
	m := NewManager("/tmp/test-install", &testLogger{})
	cfg := m.Load(false)
	if cfg.TempUpdateRate != 2 {
		t.Errorf("TempUpdateRate = %d, want 2", cfg.TempUpdateRate)
	}
	if cfg.AutoStart {
		t.Error("AutoStart should default to false")
	}
	if cfg.ConfigPath == "" {
		t.Error("ConfigPath should be set")
	}
}

func TestSaveAndLoad(t *testing.T) {
	isolateConfigDir(t)
	m := NewManager("/tmp/test-install", &testLogger{})

	cfg := types.GetDefaultConfig(false)
	cfg.AutoControl = true
	cfg.TempUpdateRate = 5
	m.Set(cfg)

	if err := m.Save(); err != nil {
		t.Fatal("Save failed:", err)
	}

	m2 := NewManager("/tmp/test-install", &testLogger{})
	loaded := m2.Load(false)

	if loaded.AutoControl != true {
		t.Error("AutoControl not persisted")
	}
	if loaded.TempUpdateRate != 5 {
		t.Errorf("TempUpdateRate = %d, want 5", loaded.TempUpdateRate)
	}
}

func TestLoadWithAutoStart(t *testing.T) {
	isolateConfigDir(t)
	m := NewManager("/tmp/test-install", &testLogger{})
	cfg := m.Load(true)
	if cfg.TempUpdateRate == 0 {
		t.Error("should get valid config with isAutoStart=true")
	}
}

func TestGetDefaultConfigDir(t *testing.T) {
	configHome := isolateConfigDir(t)
	m := NewManager("/tmp/install", &testLogger{})
	dir := m.GetDefaultConfigDir()
	if dir == "" {
		t.Error("GetDefaultConfigDir returned empty string")
	}
	if !filepath.IsAbs(dir) {
		t.Error("config dir should be absolute path")
	}
	if filepath.Dir(dir) != configHome {
		t.Errorf("config dir parent = %s, want %s", filepath.Dir(dir), configHome)
	}
}

func TestUpdate(t *testing.T) {
	isolateConfigDir(t)
	m := NewManager("/tmp/test-install", &testLogger{})
	_ = m.Load(false)

	cfg := m.Get()
	cfg.DebugMode = true
	if err := m.Update(cfg); err != nil {
		t.Fatal("Update failed:", err)
	}
}
