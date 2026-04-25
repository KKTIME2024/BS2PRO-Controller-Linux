package ipc

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"github.com/TIANLI0/BS2PRO-Controller/internal/types"
)

const (
	PipeName   = "bs2pro-controller-ipc.sock"
	SockDir    = "/tmp"
	SocketPath = SockDir + "/" + PipeName
)

type RequestType string

const (
	ReqConnect           RequestType = "Connect"
	ReqDisconnect        RequestType = "Disconnect"
	ReqGetDeviceStatus   RequestType = "GetDeviceStatus"
	ReqGetCurrentFanData RequestType = "GetCurrentFanData"

	ReqGetConfig                RequestType = "GetConfig"
	ReqUpdateConfig             RequestType = "UpdateConfig"
	ReqSetFanCurve              RequestType = "SetFanCurve"
	ReqGetFanCurve              RequestType = "GetFanCurve"
	ReqGetFanCurveProfiles      RequestType = "GetFanCurveProfiles"
	ReqSetActiveFanCurveProfile RequestType = "SetActiveFanCurveProfile"
	ReqSaveFanCurveProfile      RequestType = "SaveFanCurveProfile"
	ReqDeleteFanCurveProfile    RequestType = "DeleteFanCurveProfile"
	ReqExportFanCurveProfiles   RequestType = "ExportFanCurveProfiles"
	ReqImportFanCurveProfiles   RequestType = "ImportFanCurveProfiles"

	ReqSetAutoControl    RequestType = "SetAutoControl"
	ReqSetManualGear     RequestType = "SetManualGear"
	ReqGetAvailableGears RequestType = "GetAvailableGears"
	ReqSetCustomSpeed    RequestType = "SetCustomSpeed"
	ReqSetGearLight      RequestType = "SetGearLight"
	ReqSetPowerOnStart   RequestType = "SetPowerOnStart"
	ReqSetSmartStartStop RequestType = "SetSmartStartStop"
	ReqSetBrightness     RequestType = "SetBrightness"
	ReqSetLightStrip     RequestType = "SetLightStrip"

	ReqGetTemperature         RequestType = "GetTemperature"
	ReqTestTemperatureReading RequestType = "TestTemperatureReading"
	ReqTestBridgeProgram      RequestType = "TestBridgeProgram"
	ReqGetBridgeProgramStatus RequestType = "GetBridgeProgramStatus"

	ReqSetLinuxAutoStart      RequestType = "SetLinuxAutoStart"
	ReqCheckLinuxAutoStart    RequestType = "CheckLinuxAutoStart"
	ReqIsRunningAsAdmin       RequestType = "IsRunningAsAdmin"
	ReqGetAutoStartMethod     RequestType = "GetAutoStartMethod"
	ReqSetAutoStartWithMethod RequestType = "SetAutoStartWithMethod"

	ReqShowWindow RequestType = "ShowWindow"
	ReqHideWindow RequestType = "HideWindow"
	ReqQuitApp    RequestType = "QuitApp"

	ReqGetDebugInfo          RequestType = "GetDebugInfo"
	ReqSetDebugMode          RequestType = "SetDebugMode"
	ReqUpdateGuiResponseTime RequestType = "UpdateGuiResponseTime"

	ReqPing              RequestType = "Ping"
	ReqIsAutoStartLaunch RequestType = "IsAutoStartLaunch"
	ReqSubscribeEvents   RequestType = "SubscribeEvents"
	ReqUnsubscribeEvents RequestType = "UnsubscribeEvents"
)

type Request struct {
	Type RequestType     `json:"type"`
	Data json.RawMessage `json:"data,omitempty"`
}

type Response struct {
	IsResponse bool            `json:"isResponse"`
	Success    bool            `json:"success"`
	Error      string          `json:"error,omitempty"`
	Data       json.RawMessage `json:"data,omitempty"`
}

type Event struct {
	IsEvent bool            `json:"isEvent"`
	Type    string          `json:"type"`
	Data    json.RawMessage `json:"data,omitempty"`
}

const (
	EventFanDataUpdate      = "fan-data-update"
	EventTemperatureUpdate  = "temperature-update"
	EventDeviceConnected    = "device-connected"
	EventDeviceDisconnected = "device-disconnected"
	EventDeviceError        = "device-error"
	EventConfigUpdate       = "config-update"
	EventHotkeyTriggered    = "hotkey-triggered"
	EventHealthPing         = "health-ping"
	EventHeartbeat          = "heartbeat"
)

type Server struct {
	listener net.Listener
	clients  map[net.Conn]bool
	mutex    sync.RWMutex
	handler  RequestHandler
	logger   types.Logger
	running  bool
}

type RequestHandler func(req Request) Response

func NewServer(handler RequestHandler, logger types.Logger) *Server {
	return &Server{
		clients: make(map[net.Conn]bool),
		handler: handler,
		logger:  logger,
	}
}

func (s *Server) Start() error {
	os.Remove(SocketPath)

	listener, err := net.Listen("unix", SocketPath)
	if err != nil {
		return fmt.Errorf("创建 Unix 域套接字失败: %v", err)
	}

	if err := os.Chmod(SocketPath, 0666); err != nil {
		s.logError("设置套接字权限失败: %v", err)
	}

	s.listener = listener
	s.running = true
	s.logInfo("IPC 服务器已启动: %s", SocketPath)

	go s.acceptConnections()

	return nil
}

func (s *Server) acceptConnections() {
	for s.running {
		conn, err := s.listener.Accept()
		if err != nil {
			if s.running {
				s.logError("接受连接失败: %v", err)
			}
			continue
		}

		s.mutex.Lock()
		s.clients[conn] = true
		s.mutex.Unlock()

		s.logInfo("新的 IPC 客户端已连接")
		go s.handleClient(conn)
	}
}

func (s *Server) handleClient(conn net.Conn) {
	defer func() {
		s.mutex.Lock()
		delete(s.clients, conn)
		s.mutex.Unlock()
		conn.Close()
		s.logInfo("IPC 客户端已断开")
	}()

	reader := bufio.NewReader(conn)

	for s.running {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			s.logDebug("读取客户端请求失败: %v", err)
			return
		}

		var req Request
		if err := json.Unmarshal(line, &req); err != nil {
			s.logError("解析请求失败: %v", err)
			continue
		}
		resp := s.handler(req)
		resp.IsResponse = true

		respBytes, err := json.Marshal(resp)
		if err != nil {
			s.logError("序列化响应失败: %v", err)
			continue
		}

		_, err = conn.Write(append(respBytes, '\n'))
		if err != nil {
			s.logError("发送响应失败: %v", err)
			return
		}
	}
}

func (s *Server) BroadcastEvent(eventType string, data any) {
	dataBytes, err := json.Marshal(data)
	if err != nil {
		s.logError("序列化事件数据失败: %v", err)
		return
	}

	event := Event{
		IsEvent: true,
		Type:    eventType,
		Data:    dataBytes,
	}

	eventBytes, err := json.Marshal(event)
	if err != nil {
		s.logError("序列化事件失败: %v", err)
		return
	}

	s.mutex.RLock()
	defer s.mutex.RUnlock()

	for conn := range s.clients {
		go func(c net.Conn) {
			_, err := c.Write(append(eventBytes, '\n'))
			if err != nil {
				s.logDebug("发送事件失败: %v", err)
			}
		}(conn)
	}
}

func (s *Server) Stop() {
	s.running = false
	if s.listener != nil {
		s.listener.Close()
	}

	s.mutex.Lock()
	for conn := range s.clients {
		conn.Close()
	}
	s.clients = make(map[net.Conn]bool)
	s.mutex.Unlock()

	os.Remove(SocketPath)

	s.logInfo("IPC 服务器已停止")
}

func (s *Server) HasClients() bool {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return len(s.clients) > 0
}

func (s *Server) logInfo(format string, v ...any) {
	if s.logger != nil {
		s.logger.Info(format, v...)
	}
}

func (s *Server) logError(format string, v ...any) {
	if s.logger != nil {
		s.logger.Error(format, v...)
	}
}

func (s *Server) logDebug(format string, v ...any) {
	if s.logger != nil {
		s.logger.Debug(format, v...)
	}
}

type Client struct {
	conn         net.Conn
	mutex        sync.Mutex
	reader       *bufio.Reader
	logger       types.Logger
	eventHandler func(Event)
	responseChan chan *Response
	connected    bool
	connMutex    sync.RWMutex
}

func NewClient(logger types.Logger) *Client {
	return &Client{
		logger:       logger,
		responseChan: make(chan *Response, 1),
	}
}

func (c *Client) Connect() error {
	c.connMutex.Lock()
	defer c.connMutex.Unlock()

	if c.connected {
		return nil
	}

	conn, err := net.DialTimeout("unix", SocketPath, 5*time.Second)
	if err != nil {
		return fmt.Errorf("连接 IPC 服务器失败: %v", err)
	}

	c.conn = conn
	c.reader = bufio.NewReader(conn)
	c.connected = true
	c.logInfo("已连接到 IPC 服务器")

	go c.readLoop()

	return nil
}

func (c *Client) readLoop() {
	for {
		c.connMutex.RLock()
		if !c.connected || c.reader == nil {
			c.connMutex.RUnlock()
			return
		}
		reader := c.reader
		c.connMutex.RUnlock()

		line, err := reader.ReadBytes('\n')
		if err != nil {
			c.logDebug("读取消息失败: %v", err)
			c.connMutex.Lock()
			c.connected = false
			c.connMutex.Unlock()
			return
		}

		var msg struct {
			IsResponse bool `json:"isResponse"`
			IsEvent    bool `json:"isEvent"`
		}
		if err := json.Unmarshal(line, &msg); err != nil {
			c.logDebug("解析消息类型失败: %v", err)
			continue
		}

		if msg.IsResponse {
			var resp Response
			if err := json.Unmarshal(line, &resp); err == nil {
				select {
				case c.responseChan <- &resp:
				default:
					c.logDebug("响应通道已满，丢弃响应")
				}
			}
		} else if msg.IsEvent {
			var event Event
			if err := json.Unmarshal(line, &event); err == nil && event.Type != "" {
				if c.eventHandler != nil {
					go c.eventHandler(event)
				}
			}
		}
	}
}

func (c *Client) SetEventHandler(handler func(Event)) {
	c.eventHandler = handler
}

func (c *Client) SendRequest(reqType RequestType, data any) (*Response, error) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.connMutex.RLock()
	if !c.connected || c.conn == nil {
		c.connMutex.RUnlock()
		return nil, fmt.Errorf("未连接到服务器")
	}
	conn := c.conn
	c.connMutex.RUnlock()

	var dataBytes json.RawMessage
	if data != nil {
		var err error
		dataBytes, err = json.Marshal(data)
		if err != nil {
			return nil, fmt.Errorf("序列化请求数据失败: %v", err)
		}
	}

	req := Request{
		Type: reqType,
		Data: dataBytes,
	}

	reqBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("序列化请求失败: %v", err)
	}

	select {
	case <-c.responseChan:
	default:
	}

	_, err = conn.Write(append(reqBytes, '\n'))
	if err != nil {
		return nil, fmt.Errorf("发送请求失败: %v", err)
	}

	select {
	case resp := <-c.responseChan:
		return resp, nil
	case <-time.After(10 * time.Second):
		return nil, fmt.Errorf("等待响应超时")
	}
}

func (c *Client) Close() {
	c.connMutex.Lock()
	defer c.connMutex.Unlock()

	c.connected = false
	if c.conn != nil {
		c.conn.Close()
		c.conn = nil
	}
}

func (c *Client) IsConnected() bool {
	c.connMutex.RLock()
	defer c.connMutex.RUnlock()
	return c.connected
}

func (c *Client) logInfo(format string, v ...any) {
	if c.logger != nil {
		c.logger.Info(format, v...)
	}
}

func (c *Client) logDebug(format string, v ...any) {
	if c.logger != nil {
		c.logger.Debug(format, v...)
	}
}

func CheckCoreServiceRunning() bool {
	conn, err := net.DialTimeout("unix", SocketPath, 1*time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func GetCoreLockFilePath() string {
	return "/tmp/bs2pro-core.lock"
}

type StartCoreRequestParams struct {
	ShowGUI bool `json:"showGUI"`
}

type SetAutoControlParams struct {
	Enabled bool `json:"enabled"`
}

type SetManualGearParams struct {
	Gear  string `json:"gear"`
	Level string `json:"level"`
}

type SetCustomSpeedParams struct {
	Enabled bool `json:"enabled"`
	RPM     int  `json:"rpm"`
}

type SetBoolParams struct {
	Enabled bool `json:"enabled"`
}

type SetStringParams struct {
	Value string `json:"value"`
}

type SetIntParams struct {
	Value int `json:"value"`
}

type SetAutoStartWithMethodParams struct {
	Enable bool   `json:"enable"`
	Method string `json:"method"`
}

type SetLightStripParams struct {
	Config types.LightStripConfig `json:"config"`
}

type SetActiveFanCurveProfileParams struct {
	ID string `json:"id"`
}

type SaveFanCurveProfileParams struct {
	ID        string                `json:"id"`
	Name      string                `json:"name"`
	Curve     []types.FanCurvePoint `json:"curve"`
	SetActive bool                  `json:"setActive"`
}

type DeleteFanCurveProfileParams struct {
	ID string `json:"id"`
}

type ImportFanCurveProfilesParams struct {
	Code string `json:"code"`
}
