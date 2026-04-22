package autostart

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
)

type Manager struct {
	logger types.Logger
}

func NewManager(logger types.Logger) *Manager {
	return &Manager{
		logger: logger,
	}
}

func (m *Manager) IsRunningAsAdmin() bool {
	return os.Geteuid() == 0
}

func (m *Manager) SetWindowsAutoStart(enable bool) error {
	if enable {
		return m.createAutostartDesktopFile()
	} else {
		return m.removeAutostartDesktopFile()
	}
}

func (m *Manager) createAutostartDesktopFile() error {
	exePath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("获取程序路径失败: %v", err)
	}

	autostartDir := filepath.Join(os.Getenv("HOME"), ".config", "autostart")
	if err := os.MkdirAll(autostartDir, 0755); err != nil {
		return fmt.Errorf("创建 autostart 目录失败: %v", err)
	}

	desktopContent := fmt.Sprintf(`[Desktop Entry]
Type=Application
Name=BS2PRO Controller
Exec=%s --autostart
Terminal=false
X-GNOME-Autostart-enabled=true
`, exePath)

	desktopPath := filepath.Join(autostartDir, "bs2pro-controller.desktop")
	if err := os.WriteFile(desktopPath, []byte(desktopContent), 0644); err != nil {
		return fmt.Errorf("创建自启动桌面文件失败: %v", err)
	}

	m.logger.Info("已创建桌面自启动文件: %s", desktopPath)
	return nil
}

func (m *Manager) removeAutostartDesktopFile() error {
	desktopPath := filepath.Join(os.Getenv("HOME"), ".config", "autostart", "bs2pro-controller.desktop")
	if err := os.Remove(desktopPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("删除自启动桌面文件失败: %v", err)
	}
	m.logger.Info("已删除桌面自启动文件")
	return nil
}

func (m *Manager) GetAutoStartMethod() string {
	desktopPath := filepath.Join(os.Getenv("HOME"), ".config", "autostart", "bs2pro-controller.desktop")
	if _, err := os.Stat(desktopPath); err == nil {
		return "desktop"
	}
	return "none"
}

func (m *Manager) SetAutoStartWithMethod(enable bool, method string) error {
	if !enable {
		m.removeAutostartDesktopFile()
		return nil
	}

	switch method {
	case "desktop":
		return m.createAutostartDesktopFile()
	default:
		return fmt.Errorf("不支持的自启动方式: %s", method)
	}
}

func (m *Manager) CheckWindowsAutoStart() bool {
	return m.GetAutoStartMethod() != "none"
}

func (m *Manager) checkScheduledTask() bool {
	return false
}

func (m *Manager) checkRegistryAutoStart() bool {
	return false
}

func DetectAutoStartLaunch(args []string) bool {
	for _, arg := range args {
		if arg == "--autostart" || arg == "/autostart" || arg == "-autostart" {
			return true
		}
	}
	return false
}
