package server

import (
	"html/template"
	"log"
	"net/http"
)

const indexHTML = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShellCraft - UNIX Shell RPG</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #0a0a0a;
            color: #00ff00;
            font-family: 'Courier New', monospace;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            padding: 40px;
            text-align: center;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 10px;
            text-shadow: 0 0 10px #00ff00;
        }
        .subtitle {
            font-size: 1.2em;
            color: #00aa00;
            margin-bottom: 30px;
        }
        .info {
            background: rgba(0, 255, 0, 0.05);
            border: 1px solid #00ff00;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
            text-align: left;
        }
        .button {
            display: inline-block;
            background: #00ff00;
            color: #000;
            padding: 15px 40px;
            margin: 10px;
            text-decoration: none;
            font-weight: bold;
            border-radius: 5px;
            transition: all 0.3s;
            cursor: pointer;
            border: none;
            font-family: 'Courier New', monospace;
            font-size: 1.1em;
        }
        .button:hover {
            background: #00aa00;
            box-shadow: 0 0 20px #00ff00;
        }
        .status {
            margin-top: 30px;
            padding: 15px;
            background: rgba(0, 255, 0, 0.1);
            border-radius: 5px;
        }
        .session-info {
            display: none;
            margin-top: 20px;
            padding: 20px;
            background: rgba(0, 255, 0, 0.15);
            border: 2px solid #00ff00;
            border-radius: 5px;
        }
        .session-info.active {
            display: block;
        }
        code {
            background: rgba(0, 255, 0, 0.1);
            padding: 2px 6px;
            border-radius: 3px;
        }
        a {
            color: #00ff00;
        }
        .metrics {
            margin-top: 20px;
            font-size: 0.9em;
            color: #00aa00;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚔️ ShellCraft ⚔️</h1>
        <div class="subtitle">A UNIX Shell RPG</div>

        <div class="info">
            <p><strong>Welcome, Adventurer!</strong></p>
            <p>ShellCraft is a fantasy-themed RPG where you learn UNIX commands by playing a game.</p>
            <ul>
                <li>Execute commands to gain XP</li>
                <li>Level up to unlock new commands</li>
                <li>Fight file-based enemies in /sewer</li>
                <li>Progress from Level 0 to Level 20</li>
            </ul>
        </div>

        <button class="button" onclick="createSession()">🎮 Start New Game</button>
        <a href="/metrics" class="button" style="background: #333; color: #00ff00;">📊 Server Metrics</a>

        <div class="session-info" id="sessionInfo">
            <h3>✅ Session Created!</h3>
            <p>Session ID: <code id="sessionId"></code></p>
            <p>Container ID: <code id="containerId"></code></p>
            <br>
            <a href="#" id="playLink" class="button">▶️ Play Now</a>
        </div>

        <div class="status" id="status">
            <div class="metrics">
                Active Sessions: <span id="activeSessions">-</span> / <span id="maxSessions">-</span>
                | Capacity: <span id="capacity">-</span>%
                | Status: <span id="serverStatus">-</span>
            </div>
        </div>
    </div>

    <script>
        // Fetch server metrics on load
        async function updateMetrics() {
            try {
                const response = await fetch('/metrics');
                const data = await response.json();

                document.getElementById('activeSessions').textContent = data.active_sessions;
                document.getElementById('maxSessions').textContent = data.max_sessions;
                document.getElementById('capacity').textContent = data.capacity_percent;
                document.getElementById('serverStatus').textContent = data.status;
            } catch (err) {
                console.error('Failed to fetch metrics:', err);
            }
        }

        async function createSession() {
            const button = event.target;
            button.disabled = true;
            button.textContent = '⏳ Creating...';

            try {
                const response = await fetch('/session', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

                if (response.status === 503) {
                    const error = await response.json();
                    alert('Server at capacity! ' + error.message);
                    button.disabled = false;
                    button.textContent = '🎮 Start New Game';
                    return;
                }

                const data = await response.json();

                // Show session info
                document.getElementById('sessionId').textContent = data.session_id;
                document.getElementById('containerId').textContent = data.container_id;
                document.getElementById('playLink').href = '/session/' + data.session_id + '/connect';
                document.getElementById('sessionInfo').classList.add('active');

                // Update metrics
                updateMetrics();

                // Auto-redirect after 2 seconds
                setTimeout(() => {
                    window.location.href = '/session/' + data.session_id + '/connect';
                }, 2000);

            } catch (err) {
                alert('Failed to create session: ' + err);
                button.disabled = false;
                button.textContent = '🎮 Start New Game';
            }
        }

        // Update metrics every 5 seconds
        updateMetrics();
        setInterval(updateMetrics, 5000);
    </script>
</body>
</html>
`

var indexTemplate = template.Must(template.New("index").Parse(indexHTML))

// handleIndex serves the landing page
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	if err := indexTemplate.Execute(w, nil); err != nil {
		log.Printf("Failed to render index: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}
