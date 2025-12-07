package network

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"

	"github.com/alireza0/x-ui/logger"
	"github.com/alireza0/x-ui/xray"
)

// WSJWTProxy is a WebSocket proxy that validates JWT tokens before forwarding connections
type WSJWTProxy struct {
	targetAddr string
	listener   net.Listener
	mu         sync.RWMutex
}

// NewWSJWTProxy creates a new WebSocket JWT proxy
func NewWSJWTProxy(targetAddr string) *WSJWTProxy {
	return &WSJWTProxy{
		targetAddr: targetAddr,
	}
}

// Start starts the proxy listener
func (p *WSJWTProxy) Start(listenAddr string) error {
	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return err
	}

	p.mu.Lock()
	p.listener = listener
	p.mu.Unlock()

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				logger.Debug("WSJWTProxy accept error:", err)
				return
			}
			go p.handleConnection(conn)
		}
	}()

	return nil
}

// Stop stops the proxy
func (p *WSJWTProxy) Stop() error {
	p.mu.RLock()
	listener := p.listener
	p.mu.RUnlock()

	if listener != nil {
		return listener.Close()
	}
	return nil
}

// handleConnection handles incoming connections
func (p *WSJWTProxy) handleConnection(clientConn net.Conn) {
	defer clientConn.Close()

	// Read HTTP request using bufio.Reader
	reader := bufio.NewReader(clientConn)
	req, err := http.ReadRequest(reader)
	if err != nil {
		logger.Debug("Failed to read HTTP request:", err)
		return
	}

	// Check if it's a WebSocket upgrade request
	if !isWebSocketUpgrade(req) {
		// Not a WebSocket request, forward directly
		p.forwardConnection(clientConn, req)
		return
	}

	// Extract token from query string
	tokenStr := req.URL.Query().Get("token")
	
	// Validate JWT token if present
	if tokenStr != "" {
		// Extract token from path for validation
		path := req.URL.Path
		if req.URL.RawQuery != "" {
			path += "?" + req.URL.RawQuery
		}
		
		if !xray.ValidateJWTInPath(path) {
			logger.Warning("JWT token validation failed or expired for connection from:", clientConn.RemoteAddr())
			// Send unauthorized response
			resp := &http.Response{
				StatusCode: http.StatusUnauthorized,
				Status:     "401 Unauthorized",
				Proto:      "HTTP/1.1",
				ProtoMajor: 1,
				ProtoMinor: 1,
				Header:     make(http.Header),
				Body:       http.NoBody,
			}
			resp.Header.Set("Content-Type", "text/plain")
			resp.Write(clientConn)
			return
		}
	}

	// Token is valid or not present, forward connection
	p.forwardConnection(clientConn, req)
}

// forwardConnection forwards the connection to the target
func (p *WSJWTProxy) forwardConnection(clientConn net.Conn, req *http.Request) {
	// Connect to target
	targetConn, err := net.Dial("tcp", p.targetAddr)
	if err != nil {
		logger.Debug("Failed to connect to target:", err)
		return
	}
	defer targetConn.Close()

	// Write request to target
	err = req.Write(targetConn)
	if err != nil {
		logger.Debug("Failed to write request to target:", err)
		return
	}

	// Copy data bidirectionally
	go io.Copy(targetConn, clientConn)
	io.Copy(clientConn, targetConn)
}

// isWebSocketUpgrade checks if the request is a WebSocket upgrade request
func isWebSocketUpgrade(req *http.Request) bool {
	upgrade := strings.ToLower(req.Header.Get("Upgrade"))
	connection := strings.ToLower(req.Header.Get("Connection"))
	return upgrade == "websocket" && strings.Contains(connection, "upgrade")
}


