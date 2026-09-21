package crowdsec_bouncer_traefik_plugin

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
)

func TestDroppedLogReportsSurviveSaturation(t *testing.T) {
	queue := make(chan string, 1)
	queue <- "blocked"
	var counter uint64 = 50
	var producers sync.WaitGroup
	for i := 0; i < 100; i++ {
		producers.Add(1)
		go func() {
			defer producers.Done()
			if !enqueueLogEvent(queue, "security event") {
				atomic.AddUint64(&counter, 1)
			}
			reportDroppedLogEvents(queue, &counter)
		}()
	}
	producers.Wait()
	if got := atomic.LoadUint64(&counter); got != 150 {
		t.Fatalf("lost accumulated drops: got %d, want 150", got)
	}
	<-queue
	reportDroppedLogEvents(queue, &counter)
	var report struct {
		Event string `json:"event"`
		Count uint64 `json:"count"`
	}
	if err := json.Unmarshal([]byte(<-queue), &report); err != nil {
		t.Fatal(err)
	}
	if report.Event != "crowdsec_remediation_log_drop" || report.Count != 150 || atomic.LoadUint64(&counter) != 0 {
		t.Fatalf("incorrect recovery report: %+v, pending %d", report, counter)
	}
	reportDroppedLogEvents(queue, &counter)
	if len(queue) != 0 {
		t.Fatal("reported losses twice")
	}
}

type optionalResponseWriter struct {
	*httptest.ResponseRecorder
	connection net.Conn
	flushed    bool
}

func (w *optionalResponseWriter) Flush() {
	w.flushed = true
}

func (w *optionalResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	return w.connection, bufio.NewReadWriter(bufio.NewReader(w.connection), bufio.NewWriter(w.connection)), nil
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

func jsonResponse(req *http.Request, status int, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Body:       io.NopCloser(strings.NewReader(body)),
		Header:     make(http.Header),
		Request:    req,
	}
}

// Exercise the real stream -> cache -> request -> usage-metrics path.
func TestAttributedReporting(t *testing.T) {
	var payload map[string]interface{}
	failReport := false
	oldStreamTicker, oldMetricsTicker := streamTicker, metricsTicker
	oldStreamHealthy := isCrowdsecStreamHealthy
	streamTicker = make(chan bool)
	metricsTicker = nil
	isCrowdsecStreamHealthy = true
	defer func() {
		streamTicker = oldStreamTicker
		metricsTicker = oldMetricsTicker
		isCrowdsecStreamHealthy = oldStreamHealthy
	}()
	telemetry.Lock()
	telemetry.Counts = make(map[metricKey]int64)
	telemetry.Unlock()
	cfg := CreateConfig()
	cfg.Enabled = true
	cfg.CrowdsecMode = "stream"
	cfg.CrowdsecLapiHost = "fixture"
	cfg.CrowdsecLapiKey = "fixture"
	cfg.MetricsUpdateIntervalSeconds = 0
	cfg.UpdateIntervalSeconds = 3600
	h, err := New(context.Background(), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(403) }), cfg, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	b := h.(*Bouncer)
	b.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		if strings.Contains(r.URL.Path, "usage-metrics") {
			if failReport {
				return jsonResponse(r, 503, `{}`), nil
			}
			if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
				t.Error(err)
			}
			return jsonResponse(r, 200, `{}`), nil
		}
		return jsonResponse(r, 200, `{"new":[{"id":42,"origin":"lists","scenario":"test-list","type":"ban","scope":"Ip","value":"198.51.100.42","duration":"1h"}],"deleted":[]}`), nil
	})
	if err := handleStreamCache(b); err != nil {
		t.Fatal(err)
	}
	blocked := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "http://example.test/admin?token=SECRET", nil)
	req.RemoteAddr = "198.51.100.42:1234"
	h.ServeHTTP(blocked, req)
	if blocked.Code != 403 {
		t.Fatalf("ban failed: %d", blocked.Code)
	}
	failReport = true
	if err := reportMetrics(b); err == nil {
		t.Fatal("expected failed metrics submission")
	}
	failReport = false
	if err := reportMetrics(b); err != nil {
		t.Fatal(err)
	}
	encoded, _ := json.Marshal(payload)
	if !strings.Contains(string(encoded), `"origin":"lists:test-list"`) {
		t.Fatalf("missing origin: %s", encoded)
	}
	if strings.Contains(string(encoded), "198.51.100.42") {
		t.Fatal("IP leaked into aggregate metrics")
	}
	// An application 403 must not be counted as a CrowdSec drop.
	req.RemoteAddr = "198.51.100.43:1234"
	h.ServeHTTP(httptest.NewRecorder(), req)
	if err := reportMetrics(b); err != nil {
		t.Fatal(err)
	}
	encoded, _ = json.Marshal(payload)
	if strings.Contains(string(encoded), `"name":"dropped"`) {
		t.Fatalf("counted application denial or resent old counters: %s", encoded)
	}
}

func TestTelemetryPure(t *testing.T) {
	if encodeDecision("", Decision{ID: 42}) != "" {
		t.Fatal("unsupported decision became enforceable")
	}
	d := Decision{ID: 123, Origin: "crowdsec", Scenario: "ssh-bf"}
	remedy, restored := decodeDecision(encodeDecision("t", d))
	if remedy != "t" || restored.ID != 123 || restored.Scenario != "ssh-bf" {
		t.Fatal("lost decision metadata")
	}
	telemetry.Lock()
	telemetry.Counts = make(map[metricKey]int64)
	telemetry.Unlock()
	key := metricKey{"CAPI", "ban", "ipv6"}
	telemetry.Counts[key] = 2
	snapshot, items := metricSnapshot()
	if len(items) != 2 {
		t.Fatal("missing processed/dropped counters")
	}
	telemetry.Lock()
	telemetry.Counts[key]++
	telemetry.Unlock()
	acknowledgeMetrics(snapshot)
	if telemetry.Counts[key] != 1 {
		t.Fatal("concurrent request lost during acknowledgement")
	}
	telemetry.Counts = make(map[metricKey]int64)
}

func TestResponseWriterInterfaces(t *testing.T) {
	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()
	underlying := &optionalResponseWriter{
		ResponseRecorder: httptest.NewRecorder(),
		connection:       server,
	}
	wrapped := &securityWriter{ResponseWriter: underlying}

	if originalWriter(wrapped) != underlying {
		t.Fatal("original response writer was not restored")
	}
	flusher, ok := http.ResponseWriter(wrapped).(http.Flusher)
	if !ok {
		t.Fatal("response writer lost http.Flusher")
	}
	flusher.Flush()
	if !underlying.flushed {
		t.Fatal("flush was not forwarded")
	}
	hijacker, ok := http.ResponseWriter(wrapped).(http.Hijacker)
	if !ok {
		t.Fatal("response writer lost http.Hijacker")
	}
	connection, _, err := hijacker.Hijack()
	if err != nil || connection != server {
		t.Fatalf("hijack was not forwarded: %v", err)
	}
}

func TestSafeAppsecHeaders(t *testing.T) {
	safe := safeAppsecHeaders(http.Header{
		"Accept":                  []string{"text/html"},
		"Authorization":           []string{"Bearer secret"},
		"Cookie":                  []string{"session=secret"},
		"Cf-Access-Jwt-Assertion": []string{"secret"},
		"User-Agent":              []string{"fixture"},
	})
	if safe.Get("Accept") != "text/html" || safe.Get("User-Agent") != "fixture" {
		t.Fatalf("safe headers were not preserved: %#v", safe)
	}
	for _, name := range []string{"Authorization", "Cookie", "Cf-Access-Jwt-Assertion"} {
		if safe.Get(name) != "" {
			t.Fatalf("sensitive header was copied: %s", name)
		}
	}
}
