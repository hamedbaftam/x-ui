package middleware

import (
	"net/http"
	"strings"

	"github.com/alireza0/x-ui/logger"
	"github.com/alireza0/x-ui/xray"
)

// ValidateJWTToken validates a JWT token from query string and checks if it's expired
// This function can be called when processing VLESS WebSocket connections
func ValidateJWTToken(tokenStr string) bool {
	if tokenStr == "" {
		// No token provided, allow connection (token is optional)
		return true
	}

	// Use xray's ValidateJWTInPath function which handles secret key
	path := "/?token=" + tokenStr
	return xray.ValidateJWTInPath(path)
}

// ExtractTokenFromPath extracts JWT token from WebSocket path/query string
// Example: /?token=jwt_token&other=params
func ExtractTokenFromPath(path string) string {
	// Check if path contains token parameter
	if strings.Contains(path, "token=") {
		parts := strings.Split(path, "?")
		if len(parts) > 1 {
			query := parts[1]
			params := strings.Split(query, "&")
			for _, param := range params {
				if strings.HasPrefix(param, "token=") {
					return strings.TrimPrefix(param, "token=")
				}
			}
		}
	}
	return ""
}

// JWTValidatorMiddleware validates JWT tokens in WebSocket query strings for HTTP connections
func JWTValidatorMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Only check for WebSocket upgrade requests
		if isWebSocketUpgrade(r) {
			// Parse query string to check for token parameter
			tokenStr := r.URL.Query().Get("token")
			
			// Validate JWT token if present
			if tokenStr != "" && !ValidateJWTToken(tokenStr) {
				logger.Warning("JWT token validation failed or expired for connection from:", r.RemoteAddr)
				http.Error(w, "Token expired or invalid", http.StatusUnauthorized)
				return
			}
		}

		// Proceed with connection
		next.ServeHTTP(w, r)
	})
}

// isWebSocketUpgrade checks if the request is a WebSocket upgrade request
func isWebSocketUpgrade(r *http.Request) bool {
	upgrade := strings.ToLower(r.Header.Get("Upgrade"))
	connection := strings.ToLower(r.Header.Get("Connection"))
	return upgrade == "websocket" && strings.Contains(connection, "upgrade")
}

