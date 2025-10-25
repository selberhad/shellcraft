package server

import (
	"html/template"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
)

const terminalHTML = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShellCraft Terminal - Session {{.SessionID}}</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #000;
            font-family: monospace;
        }
        #terminal-container {
            width: 100vw;
            height: 100vh;
        }
        #status {
            position: fixed;
            top: 10px;
            right: 10px;
            padding: 8px 12px;
            background: rgba(0, 255, 0, 0.2);
            color: #0f0;
            border: 1px solid #0f0;
            border-radius: 4px;
            font-size: 12px;
            font-family: monospace;
        }
        #status.disconnected {
            background: rgba(255, 0, 0, 0.2);
            color: #f00;
            border-color: #f00;
        }
    </style>
</head>
<body>
    <div id="status">CONNECTED</div>
    <div id="terminal-container"></div>

    <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js"></script>
    <script>
        const sessionId = '{{.SessionID}}';
        const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        // Extract base path from current URL (e.g., "/shellcraft" or "")
        // Skip if path starts with /session (that's our own path, not a base)
        const pathParts = window.location.pathname.split('/');
        const basePath = (pathParts.length > 3 && pathParts[1] !== 'session') ? '/' + pathParts[1] : '';
        const wsUrl = wsProtocol + '//' + window.location.host + basePath + '/session/' + sessionId + '/ws';

        console.log('WebSocket setup:', {
            pathname: window.location.pathname,
            pathParts: pathParts,
            basePath: basePath,
            wsUrl: wsUrl
        });

        // Initialize terminal
        const term = new Terminal({
            cursorBlink: true,
            fontSize: 14,
            fontFamily: 'Menlo, Monaco, "Courier New", monospace',
            theme: {
                background: '#000000',
                foreground: '#ffffff',
                cursor: '#00ff00',
                cursorAccent: '#000000',
                selection: 'rgba(255, 255, 255, 0.3)',
            }
        });

        const fitAddon = new FitAddon.FitAddon();
        term.loadAddon(fitAddon);
        term.open(document.getElementById('terminal-container'));
        fitAddon.fit();

        // Handle window resize
        window.addEventListener('resize', () => {
            fitAddon.fit();
        });

        // WebSocket connection
        let ws;
        let reconnectAttempts = 0;
        const maxReconnectAttempts = 5;

        function connect() {
            const statusEl = document.getElementById('status');
            statusEl.textContent = 'CONNECTING...';
            statusEl.classList.remove('disconnected');

            ws = new WebSocket(wsUrl);

            ws.onopen = () => {
                console.log('WebSocket connected');
                statusEl.textContent = 'CONNECTED';
                reconnectAttempts = 0;
            };

            ws.onmessage = (event) => {
                if (typeof event.data === 'string') {
                    term.write(event.data);
                } else if (event.data instanceof Blob) {
                    event.data.arrayBuffer().then(buffer => {
                        term.write(new Uint8Array(buffer));
                    });
                } else if (event.data instanceof ArrayBuffer) {
                    term.write(new Uint8Array(event.data));
                }
            };

            ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                statusEl.textContent = 'ERROR';
                statusEl.classList.add('disconnected');
            };

            ws.onclose = () => {
                console.log('WebSocket closed');
                statusEl.textContent = 'DISCONNECTED';
                statusEl.classList.add('disconnected');

                // Attempt reconnection
                if (reconnectAttempts < maxReconnectAttempts) {
                    reconnectAttempts++;
                    console.log('Reconnecting in 2 seconds... (attempt ' + reconnectAttempts + ')');
                    setTimeout(connect, 2000);
                } else {
                    term.write('\r\n\x1b[31mConnection lost. Refresh the page to reconnect.\x1b[0m\r\n');
                }
            };

            // Send terminal input to WebSocket
            term.onData(data => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(data);
                }
            });
        }

        // Initial connection
        connect();

        // Welcome message
        term.write('\x1b[32m=== ShellCraft Terminal ===\x1b[0m\r\n');
        term.write('Session: ' + sessionId + '\r\n');
        term.write('Connecting to container...\r\n\r\n');
    </script>
</body>
</html>
`

var terminalTemplate = template.Must(template.New("terminal").Parse(terminalHTML))

// handleSessionConnect serves the web terminal interface
func (s *Server) handleSessionConnect(w http.ResponseWriter, r *http.Request) {
	sessionID := chi.URLParam(r, "id")

	// Verify session exists
	_, exists := s.sessionManager.GetSession(sessionID)
	if !exists {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	// Render template
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := map[string]string{
		"SessionID": sessionID,
	}

	if err := terminalTemplate.Execute(w, data); err != nil {
		log.Printf("Failed to render template: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}
