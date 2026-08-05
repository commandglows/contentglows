module.exports = {
  apps: [{
    name: "contentglows_app",
    cwd: "/home/claude/contentglows/app",
    script: "bash",
    args: ["-lc", "export PORT=3023 && flox activate -- bash -lc 'export CONTENTGLOWS_DEVSERVER_API_BASE_URL=\"http://localhost:3002\" && export CONTENTGLOWS_DEVSERVER_APP_WEB_URL=\"http://localhost:3023\" && export CONTENTGLOWS_DEVSERVER_SITE_URL=\"http://localhost:3023\" && export BUILD_ENVIRONMENT=development && export CONTENTGLOWS_DEV_AUTH_BYPASS=true && doppler run --project contentglows_app --config dev -- ./pm2-web.sh'"],
    env: {
      PORT: 3023
    },
    autorestart: true,
    max_restarts: 3,
    min_uptime: "10s",
    restart_delay: 2000,
    watch: false
  }]
};
