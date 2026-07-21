package main

import (
	"encoding/json"
	"net/http"
	"os"
)

// A minimal service standing in for a commissioned fleet vessel. It reports
// that the vessel is seaworthy, identifies itself by name, and declares the
// cargo it is carrying, read from its CARGO environment variable (falling back
// to the standard ration when that is unset).
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// The cargo this vessel is carrying. Fall back to the standard ration
		// when unset, so a vessel always reports a manifest rather than a blank.
		cargo := os.Getenv("CARGO")
		if cargo == "" {
			cargo = "salt-pork"
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status":     "seaworthy",
			"vessel":     "${{ values.name }}",
			"provisions": cargo,
		})
	})
	http.ListenAndServe(":8080", nil)
}
