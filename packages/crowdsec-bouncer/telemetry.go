package crowdsec_bouncer_traefik_plugin

// Local observability extension. Enforcement still uses upstream cache values.
import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

type decisionEnvelope struct {
	Remedy   string   `json:"remedy"`
	Decision Decision `json:"decision"`
}

func encodeDecision(remedy string, d Decision) string {
	// Preserve upstream handling of empty/unsupported actions and bypass values.
	if remedy != "t" && remedy != "c" {
		return remedy
	}
	data, _ := json.Marshal(decisionEnvelope{remedy, d})
	return "decision:" + string(data)
}
func decodeDecision(value string) (string, Decision) {
	if !strings.HasPrefix(value, "decision:") {
		return value, Decision{}
	}
	var e decisionEnvelope
	if json.Unmarshal([]byte(strings.TrimPrefix(value, "decision:")), &e) != nil {
		return value, Decision{}
	}
	return e.Remedy, e.Decision
}

type securityWriter struct {
	status int
	http.ResponseWriter
	request     *http.Request
	source      string
	decision    Decision
	blocked     bool
	remediation string
}

// Explicit methods are required by Traefik's Yaegi interpreter.
func (w *securityWriter) Header() http.Header            { return w.ResponseWriter.Header() }
func (w *securityWriter) WriteHeader(code int)           { w.status = code; w.ResponseWriter.WriteHeader(code) }
func (w *securityWriter) Write(data []byte) (int, error) { return w.ResponseWriter.Write(data) }
func (w *securityWriter) Unwrap() http.ResponseWriter    { return w.ResponseWriter }
func originalWriter(w http.ResponseWriter) http.ResponseWriter {
	if s, ok := w.(*securityWriter); ok {
		return s.ResponseWriter
	}
	return w
}
func markBlocked(w http.ResponseWriter, remediation string) {
	if s, ok := w.(*securityWriter); ok {
		s.blocked = true
		s.remediation = remediation
	}
}

type metricKey struct{ Origin, Remediation, IPType string }

var telemetry = struct {
	sync.Mutex
	Counts  map[metricKey]int64
	Started time.Time
}{Counts: make(map[metricKey]int64), Started: time.Now()}
var reportLock sync.Mutex
var eventLog = log.New(os.Stdout, "", 0)

func (w *securityWriter) finish() {
	origin, remediation := "clean", "bypass"
	ipType := "ipv4"
	if strings.Contains(w.source, ":") {
		ipType = "ipv6"
	}
	if w.blocked {
		kind := "enforcement_error"
		origin, remediation = "unknown", w.remediation
		if w.decision.ID != 0 {
			kind = "decision"
			origin = w.decision.Origin
			if origin == "lists" {
				origin += ":" + w.decision.Scenario
			}
		}
		// Only allowlisted fields. Query strings, cookies and authorization are absent.
		event := map[string]interface{}{
			"event": "crowdsec_remediation", "kind": kind, "source_ip": w.source,
			"target_host": bounded(w.request.Host, 256), "target_uri": bounded(w.request.URL.Path, 4096),
			"http_method": w.request.Method, "user_agent": bounded(w.request.UserAgent(), 1024), "http_status": w.status,
			"origin": origin, "scenario": w.decision.Scenario,
			"decision_id": w.decision.ID, "remediation": remediation,
			"time": time.Now().UTC().Format(time.RFC3339Nano),
		}
		data, _ := json.Marshal(event)
		eventLog.Print(string(data))
		// Fail-closed outages are operational errors, not prevented attacks.
		if kind == "enforcement_error" {
			return
		}
	}
	telemetry.Lock()
	telemetry.Counts[metricKey{origin, remediation, ipType}]++
	telemetry.Unlock()
}

func metricSnapshot() (map[metricKey]int64, []map[string]interface{}) {
	telemetry.Lock()
	defer telemetry.Unlock()
	snapshot := make(map[metricKey]int64)
	items := []map[string]interface{}{}
	for key, count := range telemetry.Counts {
		if count == 0 {
			continue
		}
		snapshot[key] = count
		labels := map[string]string{"origin": key.Origin, "remediation": key.Remediation, "ip_type": key.IPType}
		items = append(items, map[string]interface{}{"name": "processed", "value": count, "unit": "request", "labels": labels})
		if key.Remediation != "bypass" {
			items = append(items, map[string]interface{}{"name": "dropped", "value": count, "unit": "request", "labels": labels})
		}
	}
	return snapshot, items
}
func acknowledgeMetrics(snapshot map[metricKey]int64) {
	telemetry.Lock()
	defer telemetry.Unlock()
	for key, count := range snapshot {
		telemetry.Counts[key] -= count
		if telemetry.Counts[key] == 0 {
			delete(telemetry.Counts, key)
		}
	}
}

func bounded(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}
