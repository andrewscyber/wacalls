package main

import (
	"net/http"
	"os"
	"strings"
)

// authToken returns the expected Bearer token from the environment.
// If WACALLS_TOKEN is empty, authentication is disabled.
func authToken() string {
	return strings.TrimSpace(os.Getenv("WACALLS_TOKEN"))
}

// withAuth wraps an http.Handler with optional Bearer token authentication.
// When WACALLS_TOKEN env var is set, every /api/* request must include:
//
//	Authorization: Bearer <token>
//
// If the env var is empty, the middleware is a no-op (no auth required).
func withAuth(next http.Handler) http.Handler {
	token := authToken()
	if token == "" {
		// Auth disabled — pass through
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			header := r.Header.Get("Authorization")
			bearer := strings.TrimPrefix(header, "Bearer ")
			if strings.TrimSpace(bearer) != token {
				writeJSON(w, http.StatusUnauthorized, map[string]string{
					"error": "unauthorized — provide a valid Bearer token",
				})
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
