/* global module */
module.exports = {
  apps: [{
    name: "contentglows_worker",
    cwd: "/home/claude/contentglows/worker",
    script: "bash",
    args: ["-lc", "export PORT=3018 && flox activate -- bash -lc 'pnpm dev'"],
    env: {
      PORT: 3018
    },
    autorestart: true,
    max_restarts: 3,
    min_uptime: "10s",
    restart_delay: 2000,
    watch: false
  }]
};
