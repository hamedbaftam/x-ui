package xray

import (
	"encoding/json"
	"strings"
	"sync"
	"time"

	"github.com/alireza0/x-ui/logger"
	"github.com/golang-jwt/jwt/v5"
)

var (
	jwtSecret     []byte
	jwtSecretOnce sync.Once
)

// SetJWTSecret sets the JWT secret key for token verification
func SetJWTSecret(secret []byte) {
	jwtSecretOnce.Do(func() {
		jwtSecret = secret
	})
}

// GetJWTSecret returns the current JWT secret key
func GetJWTSecret() []byte {
	return jwtSecret
}

// ValidateJWTInPath validates JWT token in WebSocket path for VLESS connections
// This function extracts token from path like "/?token=jwt_token&other=params"
// and checks if it's expired
func ValidateJWTInPath(path string) bool {
	// Extract token from path/query string
	tokenStr := ExtractTokenFromPath(path)
	if tokenStr == "" {
		// No token in path, allow connection (token is optional)
		return true
	}

	// Parse the token with signature verification if secret is set
	secret := GetJWTSecret()
	var token *jwt.Token
	var err error
	
	if len(secret) > 0 {
		// Verify signature with secret key
		token, err = jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
			// Check signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return secret, nil
		})
	} else {
		// No secret set, only check expiration without signature verification
		// Use ParseUnverified to skip signature verification in jwt/v5
		parser := jwt.NewParser()
		token, _, err = parser.ParseUnverified(tokenStr, jwt.MapClaims{})
		if err == nil {
			// Mark token as valid since we're not verifying signature
			token.Valid = true
		}
	}

	if err != nil {
		logger.Debug("Failed to parse JWT token from path:", err)
		return false
	}

	// Check if token is valid and not expired
	if !token.Valid {
		logger.Debug("JWT token is invalid")
		return false
	}

	// Check expiration claim
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		logger.Debug("Failed to extract claims from JWT token")
		return false
	}

	// Check exp claim (expiration time)
	if exp, exists := claims["exp"]; exists {
		var expTime int64
		switch v := exp.(type) {
		case float64:
			expTime = int64(v)
		case int64:
			expTime = v
		case int:
			expTime = int64(v)
		default:
			logger.Debug("Invalid exp claim type in JWT token")
			return false
		}

		// Check if token is expired
		if time.Now().Unix() > expTime {
			logger.Warning("JWT token in WebSocket path has expired")
			return false
		}
	}

	// Token is valid and not expired
	return true
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
					token := strings.TrimPrefix(param, "token=")
					// URL decode if needed (token might be URL encoded)
					return token
				}
			}
		}
	}
	return ""
}

// ValidateJWTInStreamSettings validates JWT token in WebSocket settings for VLESS connections
// This function checks the path in wsSettings and validates token if present
func ValidateJWTInStreamSettings(streamSettingsJSON []byte, protocol string) bool {
	// Only check for VLESS protocol with WebSocket
	if protocol != "vless" {
		return true
	}

	var stream map[string]interface{}
	err := json.Unmarshal(streamSettingsJSON, &stream)
	if err != nil {
		logger.Debug("Failed to unmarshal stream settings:", err)
		return true // Allow if we can't parse
	}

	// Check if it's WebSocket network
	network, ok := stream["network"].(string)
	if !ok || network != "ws" {
		return true // Not WebSocket, allow
	}

	// Get wsSettings
	wsSettings, ok := stream["wsSettings"].(map[string]interface{})
	if !ok {
		return true // No wsSettings, allow
	}

	// Get path
	path, ok := wsSettings["path"].(string)
	if !ok {
		return true // No path, allow
	}

	// Validate JWT token in path
	return ValidateJWTInPath(path)
}

