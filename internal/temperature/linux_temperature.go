package temperature

import (
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
	"github.com/shirou/gopsutil/v4/sensors"
)

// LinuxTempReader Linux原生温度读取器
type LinuxTempReader struct {
	logger types.Logger
}

// NewLinuxTempReader 创建Linux温度读取器
func NewLinuxTempReader(logger types.Logger) *LinuxTempReader {
	return &LinuxTempReader{
		logger: logger,
	}
}

// GetTemperature 读取温度数据（模拟bridge.Manager.GetTemperature接口）
func (l *LinuxTempReader) GetTemperature() types.BridgeTemperatureData {
	cpuTemp := l.readCPUTemperature()
	gpuTemp := l.readGPUTemperature()
	maxTemp := max(cpuTemp, gpuTemp)

	return types.BridgeTemperatureData{
		CpuTemp:    cpuTemp,
		GpuTemp:    gpuTemp,
		MaxTemp:    maxTemp,
		UpdateTime: time.Now().Unix(),
		Success:    true,
		Error:      "",
	}
}

// readCPUTemperature 读取CPU温度
func (l *LinuxTempReader) readCPUTemperature() int {
	// 1. 优先使用gopsutil库
	sensorTemps, err := sensors.SensorsTemperatures()
	if err == nil {
		for _, sensor := range sensorTemps {
			sensorKey := strings.ToLower(sensor.SensorKey)
			if strings.Contains(sensorKey, "cpu") ||
				strings.Contains(sensorKey, "core") ||
				strings.Contains(sensorKey, "tz00") ||
				strings.Contains(sensorKey, "package") {
				l.logger.Debug("使用gopsutil读取CPU温度: %s = %.1f°C", sensor.SensorKey, sensor.Temperature)
				return int(sensor.Temperature)
			}
		}
		if len(sensorTemps) > 0 {
			l.logger.Debug("使用gopsutil读取CPU温度: %s = %.1f°C", sensorTemps[0].SensorKey, sensorTemps[0].Temperature)
			return int(sensorTemps[0].Temperature)
		}
	}

	// 2. 使用sensors命令
	if l.isCommandAvailable("sensors") {
		output, err := exec.Command("sensors", "-u").Output()
		if err == nil {
			lines := strings.Split(string(output), "\n")
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if strings.Contains(line, "temp1_input") || strings.Contains(line, "Core") {
					parts := strings.Fields(line)
					if len(parts) >= 2 {
						for _, part := range parts {
							if strings.Contains(part, ".") {
								temp, err := strconv.ParseFloat(part, 64)
								if err == nil {
									l.logger.Debug("使用sensors命令读取CPU温度: %.1f°C", temp)
									return int(temp)
								}
							}
						}
					}
				}
			}
		}
	}

	// 3. 读取/sys/class/thermal接口
	sysPaths := []string{
		"/sys/class/thermal/thermal_zone0/temp",
		"/sys/class/thermal/thermal_zone1/temp",
		"/sys/class/thermal/thermal_zone2/temp",
		"/sys/class/hwmon/hwmon0/temp1_input",
		"/sys/class/hwmon/hwmon1/temp1_input",
	}

	for _, path := range sysPaths {
		if data, err := os.ReadFile(path); err == nil {
			tempStr := strings.TrimSpace(string(data))
			if tempInt, err := strconv.Atoi(tempStr); err == nil && tempInt > 0 && tempInt < 100000 {
				tempCelsius := tempInt / 1000
				l.logger.Debug("使用%s读取CPU温度: %d°C", path, tempCelsius)
				return tempCelsius
			}
		}
	}

	l.logger.Warn("无法读取CPU温度")
	return 0
}

// readGPUTemperature 读取GPU温度
func (l *LinuxTempReader) readGPUTemperature() int {
	// 1. NVIDIA显卡
	if l.isCommandAvailable("nvidia-smi") {
		output, err := exec.Command("nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits").Output()
		if err == nil {
			tempStr := strings.TrimSpace(string(output))
			if temp, err := strconv.Atoi(strings.Split(tempStr, "\n")[0]); err == nil {
				l.logger.Debug("使用nvidia-smi读取GPU温度: %d°C", temp)
				return temp
			}
		}
	}

	// 2. AMD显卡 (使用roc-smi或radeontop)
	if l.isCommandAvailable("roc-smi") {
		output, err := exec.Command("roc-smi", "--showtemp").Output()
		if err == nil {
			lines := strings.Split(string(output), "\n")
			for _, line := range lines {
				if strings.Contains(line, "Temperature") {
					parts := strings.Fields(line)
					for _, part := range parts {
						if strings.Contains(part, ".") {
							temp, err := strconv.ParseFloat(part, 64)
							if err == nil {
								l.logger.Debug("使用roc-smi读取GPU温度: %.1f°C", temp)
								return int(temp)
							}
						}
					}
				}
			}
		}
	}

	// 3. Intel显卡
	if l.isCommandAvailable("intel_gpu_top") {
		output, err := exec.Command("intel_gpu_top", "-J", "1", "1").Output()
		if err == nil {
			lines := strings.Split(string(output), "\n")
			for _, line := range lines {
				if strings.Contains(line, "temperature") {
					parts := strings.Fields(line)
					for _, part := range parts {
						if strings.Contains(part, "C") {
							tempStr := strings.TrimSuffix(strings.TrimSuffix(part, "C"), "°")
							temp, err := strconv.Atoi(tempStr)
							if err == nil {
								l.logger.Debug("使用intel_gpu_top读取GPU温度: %d°C", temp)
								return temp
							}
						}
					}
				}
			}
		}
	}

	l.logger.Warn("无法读取GPU温度")
	return 0
}

// isCommandAvailable 检查命令是否可用
func (l *LinuxTempReader) isCommandAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

// GetStatus 获取状态（模拟bridge.Manager.GetStatus接口）
func (l *LinuxTempReader) GetStatus() map[string]any {
	status := map[string]any{
		"exists":         true,
		"implementation": "Linux Native",
		"available": map[string]bool{
			"gopsutil":      true,
			"sensors":       l.isCommandAvailable("sensors"),
			"nvidia-smi":    l.isCommandAvailable("nvidia-smi"),
			"roc-smi":       l.isCommandAvailable("roc-smi"),
			"intel_gpu_top": l.isCommandAvailable("intel_gpu_top"),
		},
		"cpu_temp": l.readCPUTemperature(),
		"gpu_temp": l.readGPUTemperature(),
	}

	return status
}

// EnsureRunning 确保运行（模拟bridge.Manager.EnsureRunning接口）
func (l *LinuxTempReader) EnsureRunning() error {
	// Linux原生实现始终可用
	return nil
}

// Stop 停止（模拟bridge.Manager.Stop接口）
func (l *LinuxTempReader) Stop() {
	// Linux原生实现无需清理
}