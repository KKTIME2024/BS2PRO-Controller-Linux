package ipc

import (
	"encoding/json"
	"sync"
	"testing"
	"time"

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

func echoHandler(req Request) Response {
	return Response{Success: true, Data: req.Data}
}

func TestNewServer(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if srv == nil {
		t.Fatal("NewServer returned nil")
	}
	if srv.HasClients() {
		t.Error("new server should have no clients")
	}
}

func TestServerStartStop(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal("Start failed:", err)
	}
	time.Sleep(50 * time.Millisecond)

	srv.Stop()
	time.Sleep(50 * time.Millisecond)
}

func TestClientConnectClose(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()
	time.Sleep(50 * time.Millisecond)

	client := NewClient(&testLogger{})
	if err := client.Connect(); err != nil {
		t.Fatal("Connect failed:", err)
	}
	time.Sleep(50 * time.Millisecond)

	if !srv.HasClients() {
		t.Error("server should have a client after Connect")
	}

	client.Close()
	time.Sleep(50 * time.Millisecond)

	if srv.HasClients() {
		t.Error("server should have no clients after Close")
	}
}

func TestRequestResponse(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()
	time.Sleep(50 * time.Millisecond)

	client := NewClient(&testLogger{})
	if err := client.Connect(); err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	reqData := map[string]string{"hello": "world"}
	resp, err := client.SendRequest(ReqPing, reqData)
	if err != nil {
		t.Fatal("SendRequest failed:", err)
	}
	if !resp.Success {
		t.Error("response should be successful")
	}
}

func TestEventBroadcast(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()
	time.Sleep(50 * time.Millisecond)

	client := NewClient(&testLogger{})
	var receivedEvent Event
	var mu sync.Mutex
	client.SetEventHandler(func(e Event) {
		mu.Lock()
		receivedEvent = e
		mu.Unlock()
	})

	if err := client.Connect(); err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	time.Sleep(50 * time.Millisecond)

	srv.BroadcastEvent(EventFanDataUpdate, map[string]int{"rpm": 2000})
	time.Sleep(100 * time.Millisecond)

	mu.Lock()
	defer mu.Unlock()
	if receivedEvent.Type != EventFanDataUpdate {
		t.Errorf("expected fan-data-update event, got %q", receivedEvent.Type)
	}
}

func TestMultipleClients(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()
	time.Sleep(50 * time.Millisecond)

	clients := make([]*Client, 3)
	for i := range clients {
		c := NewClient(&testLogger{})
		if err := c.Connect(); err != nil {
			t.Fatalf("client %d Connect failed: %v", i, err)
		}
		clients[i] = c
	}
	time.Sleep(50 * time.Millisecond)

	if !srv.HasClients() {
		t.Error("server should have clients")
	}

	for i, c := range clients {
		resp, err := c.SendRequest(ReqPing, nil)
		if err != nil {
			t.Errorf("client %d ping failed: %v", i, err)
			continue
		}
		if !resp.Success {
			t.Errorf("client %d ping not successful", i)
		}
	}

	for _, c := range clients {
		c.Close()
	}
	time.Sleep(50 * time.Millisecond)
	if srv.HasClients() {
		t.Error("server should have no clients after all close")
	}
}

func TestRequestTypeConstants(t *testing.T) {
	required := []RequestType{
		ReqConnect, ReqDisconnect, ReqGetConfig, ReqUpdateConfig,
		ReqSetFanCurve, ReqSetAutoControl, ReqSetManualGear,
		ReqSetLinuxAutoStart, ReqCheckLinuxAutoStart,
	}
	for _, rt := range required {
		if rt == "" {
			t.Errorf("RequestType is empty in required list")
			_ = rt
		}
	}
}

func TestEventTypeConstants(t *testing.T) {
	required := []string{
		EventFanDataUpdate, EventTemperatureUpdate,
		EventDeviceConnected, EventDeviceDisconnected,
		EventConfigUpdate, EventHeartbeat,
	}
	for _, et := range required {
		if et == "" {
			t.Errorf("EventType is empty in required list")
			_ = et
		}
	}
}

func TestRequestJSON(t *testing.T) {
	req := Request{Type: ReqPing, Data: json.RawMessage(`{}`)}
	b, err := json.Marshal(req)
	if err != nil {
		t.Fatal(err)
	}
	var parsed Request
	if err := json.Unmarshal(b, &parsed); err != nil {
		t.Fatal(err)
	}
	if parsed.Type != ReqPing {
		t.Errorf("type = %s", parsed.Type)
	}
}

func TestResponseJSON(t *testing.T) {
	resp := Response{Success: true, IsResponse: true}
	b, err := json.Marshal(resp)
	if err != nil {
		t.Fatal(err)
	}
	var parsed Response
	if err := json.Unmarshal(b, &parsed); err != nil {
		t.Fatal(err)
	}
	if !parsed.Success || !parsed.IsResponse {
		t.Error("roundtrip failed")
	}
}

func TestEventJSON(t *testing.T) {
	evt := Event{Type: EventFanDataUpdate, IsEvent: true}
	b, err := json.Marshal(evt)
	if err != nil {
		t.Fatal(err)
	}
	var parsed Event
	if err := json.Unmarshal(b, &parsed); err != nil {
		t.Fatal(err)
	}
	if parsed.Type != EventFanDataUpdate || !parsed.IsEvent {
		t.Error("roundtrip failed")
	}
}

func TestSendRequestNilData(t *testing.T) {
	srv := NewServer(echoHandler, &testLogger{})
	if err := srv.Start(); err != nil {
		t.Fatal(err)
	}
	defer srv.Stop()
	time.Sleep(50 * time.Millisecond)

	client := NewClient(&testLogger{})
	if err := client.Connect(); err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	resp, err := client.SendRequest(ReqGetConfig, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !resp.Success {
		t.Error("should succeed with nil data")
	}
}

func TestClientIsConnected(t *testing.T) {
	client := NewClient(&testLogger{})
	if client.IsConnected() {
		t.Error("client should not be connected before Connect")
	}
	_ = types.TemperatureData{} // ensure types import used
}
