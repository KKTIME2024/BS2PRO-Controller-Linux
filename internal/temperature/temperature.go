package temperature

import (
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/TIANLI0/BS2PRO-Controller/internal/bridge"
	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
	"github.com/shirou/gopsutil/v4/sensors"
)

type Reader struct {
	bridgeManager *bridge.Manager
	logger        types.Logger
}

func NewReader(bridgeManager *bridge.Manager, logger types.Logger) *Reader {
	return &Reader{
		bridgeManager: bridgeManager,
		logger:        logger,
	}
}

func (r *Reader) Read() types.TemperatureData {
	temp := types.TemperatureData{
		UpdateTime: time.Now().Unix(),
		BridgeOk:   true,
	}

	bridgeTemp := r.bridgeManager.GetTemperature()
	if bridgeTemp.Success {
		if bridgeTemp.CpuTemp == 0 && bridgeTemp.GpuTemp == 0 {
			temp.BridgeOk = false
			temp.BridgeMsg = "温度读取返回空数据，使用备用方法"
			r.logger.Warn("桥接程序返回空温度数据，使用备用方法")

			temp.CPUTemp = r.readCPUTemperature()
			temp.GPUTemp = r.readGPUTemperature()
			temp.MaxTemp = max(temp.CPUTemp, temp.GPUTemp)
			return temp
		}

		temp.CPUTemp = bridgeTemp.CpuTemp
		temp.GPUTemp = bridgeTemp.GpuTemp
		temp.MaxTemp = bridgeTemp.MaxTemp
		temp.BridgeOk = true
		temp.BridgeMsg = ""
		return temp
	}

	r.logger.Warn("桥接程序读取温度失败: %s, 使用备用方法", bridgeTemp.Error)
	temp.BridgeOk = false
	temp.BridgeMsg = bridgeTemp.Error
	if strings.TrimSpace(temp.BridgeMsg) == "" {
		temp.BridgeMsg = "CPU/GPU 温度读取失败"
	}

	temp.CPUTemp = r.readCPUTemperature()

	temp.GPUTemp = r.readGPUTemperature()

	temp.MaxTemp = max(temp.CPUTemp, temp.GPUTemp)

	return temp
}

func (r *Reader) readCPUTemperature() int {
	sensorTemps, err := sensors.SensorsTemperatures()
	if err == nil {
		for _, sensor := range sensorTemps {
			if strings.Contains(strings.ToLower(sensor.SensorKey), "cpu") ||
				strings.Contains(strings.ToLower(sensor.SensorKey), "core") ||
				strings.Contains(strings.ToLower(sensor.SensorKey), "tz00") ||
				strings.Contains(strings.ToLower(sensor.SensorKey), "package") {
				return int(sensor.Temperature)
			}
		}
		if len(sensorTemps) > 0 {
			return int(sensorTemps[0].Temperature)
		}
	}

	output, err := execCommandHidden("sensors", "-u")
	if err == nil {
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.Contains(line, "temp1_input") {
				parts := strings.Split(line, " ")
				if len(parts) == 2 {
					if temp, err := strconv.ParseFloat(parts[1], 64); err == nil {
						return int(temp)
					}
				}
			}
		}
	}

	return 0
}

func (r *Reader) readGPUTemperature() int {
	vendor := r.detectGPUVendor()
	return r.readGPUTempByVendor(vendor)
}

func (r *Reader) detectGPUVendor() string {
	if _, err := execCommandHidden("nvidia-smi", "--version"); err == nil {
		return "nvidia"
	}

	return "unknown"
}

func (r *Reader) readGPUTempByVendor(vendor string) int {
	switch vendor {
	case "nvidia":
		return r.readNvidiaGPUTemp()
	default:
		return 0
	}
}

func (r *Reader) readNvidiaGPUTemp() int {
	output, err := execCommandHidden("nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits")
	if err != nil {
		r.logger.Debug("读取NVIDIA GPU温度失败: %v", err)
		return 0
	}

	tempStr := strings.TrimSpace(string(output))
	lines := strings.Split(tempStr, "\n")

	if len(lines) > 0 && lines[0] != "" {
		if temp, err := strconv.Atoi(lines[0]); err == nil {
			return temp
		}
	}

	return 0
}

func execCommandHidden(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	return cmd.Output()
}

func CalculateTargetRPM(temperature int, fanCurve []types.FanCurvePoint) int {
	if len(fanCurve) < 2 {
		return 0
	}

	if temperature <= fanCurve[0].Temperature {
		return fanCurve[0].RPM
	}

	lastPoint := fanCurve[len(fanCurve)-1]
	if temperature >= lastPoint.Temperature {
		return lastPoint.RPM
	}

	for i := 0; i < len(fanCurve)-1; i++ {
		p1 := fanCurve[i]
		p2 := fanCurve[i+1]

		if temperature >= p1.Temperature && temperature <= p2.Temperature {
			ratio := float64(temperature-p1.Temperature) / float64(p2.Temperature-p1.Temperature)
			rpm := float64(p1.RPM) + ratio*float64(p2.RPM-p1.RPM)
			return int(rpm)
		}
	}

	return 0
}
