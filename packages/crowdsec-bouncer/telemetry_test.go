package crowdsec_bouncer_traefik_plugin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// Exercise the real stream -> cache -> request -> usage-metrics path.
func TestAttributedReporting(t *testing.T) {
	var payload map[string]interface{}
	failReport := false
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.Contains(r.URL.Path, "usage-metrics") {
			if failReport {
				w.WriteHeader(503)
				return
			}
			if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
				t.Error(err)
			}
			w.Write([]byte(`{}`))
			return
		}
		w.Write([]byte(`{"new":[{"id":42,"origin":"lists","scenario":"test-list","type":"ban","scope":"Ip","value":"198.51.100.42","duration":"1h"}],"deleted":[]}`))
	}))
	defer api.Close()
	cfg := CreateConfig()
	cfg.Enabled = true
	cfg.CrowdsecMode = "stream"
	cfg.CrowdsecLapiHost = strings.TrimPrefix(api.URL, "http://")
	cfg.CrowdsecLapiKey = "fixture"
	cfg.MetricsUpdateIntervalSeconds = 0
	cfg.UpdateIntervalSeconds = 3600
	h, err := New(context.Background(), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(403) }), cfg, "fixture")
	if err != nil {
		t.Fatal(err)
	}
	b := h.(*Bouncer)
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
