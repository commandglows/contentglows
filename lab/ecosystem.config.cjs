module.exports = {
  apps: [{
    name: "contentglows_lab",
    cwd: "/home/claude/contentglows/lab",
    script: "bash",
    args: ["-lc", "export PORT=45000 && flox activate -- bash -lc './venv/bin/python main.py'"],
    env: {
      PORT: 45000
    },
    autorestart: true,
    max_restarts: 3,
    min_uptime: "10s",
    restart_delay: 2000,
    watch: false
  }]
};
