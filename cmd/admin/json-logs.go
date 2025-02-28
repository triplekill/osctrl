package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	"github.com/jmpsec/osctrl/pkg/settings"
	"github.com/jmpsec/osctrl/pkg/utils"
)

// Define log types to be used
var (
	LogTypes = map[string]bool{
		"result": true,
		"status": true,
	}
)

// ReturnedLogs to return a JSON with status/result logs
type ReturnedLogs struct {
	Data []LogJSON `json:"data"`
}

// CreationTimes to hold creation times
type CreationTimes struct {
	Display   string `json:"display"`
	Timestamp string `json:"timestamp"`
}

// LogJSON to be used to populate JSON data for a status/result log
type LogJSON struct {
	Created CreationTimes `json:"created"`
	First   string        `json:"first"`
	Second  string        `json:"second"`
}

// ReturnedQueryLogs to return a JSON with query logs
type ReturnedQueryLogs struct {
	Data []QueryLogJSON `json:"data"`
}

// QueryLogJSON to be used to populate JSON data for a query log
type QueryLogJSON struct {
	Created CreationTimes `json:"created"`
	Data    string        `json:"data"`
}

// Handler GET requests for JSON status/result logs by node and environment
func jsonLogsHandler(w http.ResponseWriter, r *http.Request) {
	incMetric(metricAdminReq)
	utils.DebugHTTPDump(r, settingsmgr.DebugHTTP(settings.ServiceAdmin), false)
	vars := mux.Vars(r)
	// Extract type
	logType, ok := vars["type"]
	if !ok {
		incMetric(metricAdminErr)
		log.Println("error getting log type")
		return
	}
	// Verify log type
	if !LogTypes[logType] {
		incMetric(metricAdminErr)
		log.Printf("invalid log type %s", logType)
		return
	}
	// Extract environment
	env, ok := vars["environment"]
	if !ok {
		incMetric(metricAdminErr)
		log.Println("environment is missing")
		return
	}
	// Check if environment is valid
	if !envs.Exists(env) {
		incMetric(metricAdminErr)
		log.Printf("error unknown environment (%s)", env)
		return
	}
	// Extract UUID
	// FIXME verify UUID
	UUID, ok := vars["uuid"]
	if !ok {
		incMetric(metricAdminErr)
		log.Println("error getting UUID")
		return
	}
	// Extract parameter for seconds
	// If parameter is not present or invalid, it defaults to 6 hours back
	secondsBack := int64(sixHours)
	seconds, ok := r.URL.Query()["seconds"]
	if ok {
		s, err := strconv.ParseInt(seconds[0], 10, 64)
		if err == nil {
			secondsBack = s
		}
	}
	// Get logs
	logJSON := []LogJSON{}
	if logType == "status" {
		statusLogs, err := postgresStatusLogs(UUID, env, secondsBack)
		if err != nil {
			incMetric(metricAdminErr)
			log.Printf("error getting logs %v", err)
			return
		}
		// Prepare data to be returned
		for _, s := range statusLogs {
			_c := CreationTimes{
				Display:   pastTimeAgo(s.CreatedAt),
				Timestamp: pastTimestamp(s.CreatedAt),
			}
			_l := LogJSON{
				Created: _c,
				First:   s.Message,
				Second:  s.Severity,
			}
			logJSON = append(logJSON, _l)
		}
	} else if logType == "result" {
		resultLogs, err := postgresResultLogs(UUID, env, secondsBack)
		if err != nil {
			incMetric(metricAdminErr)
			log.Printf("error getting logs %v", err)
			return
		}
		// Prepare data to be returned
		for _, r := range resultLogs {
			_l := LogJSON{
				Created: CreationTimes{
					Display:   pastTimeAgo(r.CreatedAt),
					Timestamp: pastTimestamp(r.CreatedAt),
				},
				First:  r.Name,
				Second: string(r.Columns),
			}
			logJSON = append(logJSON, _l)
		}
	}
	returned := ReturnedLogs{
		Data: logJSON,
	}
	// Serialize JSON
	returnedJSON, err := json.Marshal(returned)
	if err != nil {
		incMetric(metricAdminErr)
		log.Printf("error serializing JSON %v", err)
		return
	}
	incMetric(metricAdminOK)
	// Header to serve JSON
	w.Header().Set("Content-Type", JSONApplicationUTF8)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(returnedJSON)
}

// Handler for JSON query logs by query name
func jsonQueryLogsHandler(w http.ResponseWriter, r *http.Request) {
	incMetric(metricAdminReq)
	utils.DebugHTTPDump(r, settingsmgr.DebugHTTP(settings.ServiceAdmin), false)
	vars := mux.Vars(r)
	// Extract query name
	// FIXME verify name
	name, ok := vars["name"]
	if !ok {
		incMetric(metricAdminErr)
		log.Println("error getting name")
		return
	}
	// Get logs
	queryLogs, err := postgresQueryLogs(name)
	if err != nil {
		incMetric(metricAdminErr)
		log.Printf("error getting logs %v", err)
		return
	}
	// Prepare data to be returned
	queryLogJSON := []QueryLogJSON{}
	for _, q := range queryLogs {
		_c := CreationTimes{
			Display:   pastTimeAgo(q.CreatedAt),
			Timestamp: pastTimestamp(q.CreatedAt),
		}
		_l := QueryLogJSON{
			Created: _c,
			Data:    string(q.Data),
		}
		queryLogJSON = append(queryLogJSON, _l)
	}
	returned := ReturnedQueryLogs{
		Data: queryLogJSON,
	}
	// Serialize JSON
	returnedJSON, err := json.Marshal(returned)
	if err != nil {
		incMetric(metricAdminErr)
		log.Printf("error serializing JSON %v", err)
		return
	}
	incMetric(metricAdminOK)
	// Header to serve JSON
	w.Header().Set("Content-Type", JSONApplicationUTF8)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(returnedJSON)
}
