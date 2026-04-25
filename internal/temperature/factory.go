package temperature

import (
	"runtime"

	"github.com/TIANLI0/BS2PRO-Controller/internal/bridge"
	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
)

// Factory 温度管理器工厂
func CreateTemperatureManager(logger types.Logger) TemperatureInterface {
	switch runtime.GOOS {
	case "linux":
		return NewLinuxTempReader(logger)
	case "windows":
		return bridge.NewManager(logger)
	default:
		// 对于其他系统，默认使用Linux实现
		return NewLinuxTempReader(logger)
	}
}

// CreateReaderWithDefaultManager 创建Reader并使用默认管理器
func CreateReaderWithDefaultManager(logger types.Logger) *Reader {
	tempManager := CreateTemperatureManager(logger)
	return NewReader(tempManager, logger)
}