package main

import (
	"encoding/json"
	"net/http"
)

// A minimal service standing in for a commissioned fleet vessel. It reports
// that the vessel is seaworthy and identifies itself by name.
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status": "seaworthy",
			"vessel": "${{ values.name }}",
		})
	})
	http.ListenAndServe(":8080", nil)
}
