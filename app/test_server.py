"""
Minimal test server for ContentGlows Flutter app.
Simulates the FastAPI backend's status endpoints with in-memory data.

Run: python3 test_server.py
Serves on: http://localhost:8000
"""

import json
import uuid
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

DEMO_PROJECT_ID = "demo-project"
DEMO_PROJECT_NAME = "Tailwind Nextjs Starter Blog"
DEMO_REPO_URL = "https://github.com/timlrx/tailwind-nextjs-starter-blog"
DEMO_DESCRIPTION = "Public Next.js blog starter used as a fixed demo workspace."

# In-memory content store
CONTENT_DB: dict[str, dict] = {}
CONTENT_BODIES: dict[str, str] = {}
STATUS_HISTORY: list[dict] = []

VALID_TRANSITIONS = {
    "todo": ["in_progress", "archived"],
    "in_progress": ["generated", "failed"],
    "generated": ["pending_review", "in_progress"],
    "pending_review": ["approved", "rejected", "in_progress"],
    "approved": ["scheduled", "publishing", "archived"],
    "rejected": ["todo", "in_progress", "archived"],
    "scheduled": ["publishing", "approved"],
    "publishing": ["published", "failed"],
    "published": ["archived"],
    "failed": ["todo", "in_progress", "archived"],
}


def seed_data():
    """Create sample content in pending_review status."""
    now = datetime.utcnow()
    samples = [
        {
            "title": "10 Flutter Tips for Production Apps",
            "content_type": "article",
            "source_robot": "seo",
            "body": "# 10 Flutter Tips for Production Apps\n\nFlutter has become the go-to framework.\n\n## 1. Use Riverpod\n\nCompile-time safety and automatic disposal.\n\n## 2. Error Handling\n\nAlways wrap async operations in try-catch.\n\n## 3. Image Loading\n\nUse `cached_network_image`.\n\n## 4. Profile First\n\nUse DevTools before optimizing.\n\n## 5. Widget Tests\n\n80% coverage on your widget layer.",
            "tags": ["flutter", "production", "tips"],
            "priority": 4,
        },
        {
            "title": "AI is transforming software development",
            "content_type": "social_post",
            "source_robot": "seo",
            "body": "AI is transforming how we build software.\n\nIn 2026, the best devs direct AI, not write every line.\n\n3 skills that matter:\n→ Prompt engineering\n→ Code review (AI output)\n→ System architecture\n\n#AI #Dev",
            "tags": ["twitter", "linkedin"],
            "priority": 3,
        },
        {
            "title": "Weekly Tech Digest #42",
            "content_type": "newsletter",
            "source_robot": "newsletter",
            "body": "# Weekly Tech Digest #42\n\n## Top Stories\n\n**Flutter 3.41** — Hot reload on web.\n\n**Claude 4.6 Opus** — 1M context.\n\n## Tutorial\n\nReal-time dashboards with Flutter + WebSockets.",
            "tags": ["newsletter"],
            "priority": 3,
        },
        {
            "title": "How I Built a SaaS in 30 Days",
            "content_type": "video_script",
            "source_robot": "seo",
            "body": "HOOK: \"From idea to $2K MRR in 30 days.\"\n\nINTRO (0:00):\nRevenue dashboard on screen.\n\nSECTION 1 - The Idea:\n\"Started with my own problem...\"\n\nSECTION 2 - The Build:\n\"Flutter + Python backend...\"\n\nCTA:\n\"Template in bio.\"",
            "tags": ["youtube"],
            "priority": 2,
        },
        {
            "title": "Quick tip: Use sealed classes in Dart",
            "content_type": "reel",
            "source_robot": "seo",
            "body": "REEL (30s)\n\n\"Stop using if-else chains!\"\n\n[Bad code]\n\"Terrible.\"\n\n[Sealed class]\n\"Compiler catches every case.\"\n\n\"Follow for Flutter tips.\"\n\n#Flutter #Dart",
            "tags": ["instagram", "tiktok"],
            "priority": 2,
        },
    ]

    for s in samples:
        cid = str(uuid.uuid4())
        CONTENT_DB[cid] = {
            "id": cid,
            "title": s["title"],
            "content_type": s["content_type"],
            "source_robot": s["source_robot"],
            "status": "pending_review",
            "project_id": DEMO_PROJECT_ID,
            "content_path": None,
            "content_preview": s["body"][:200],
            "content_hash": None,
            "priority": s["priority"],
            "tags": s["tags"],
            "metadata": {},
            "target_url": None,
            "reviewer_note": None,
            "reviewed_by": None,
            "created_at": (now - timedelta(hours=len(samples))).isoformat(),
            "updated_at": now.isoformat(),
            "scheduled_for": None,
            "published_at": None,
            "synced_at": None,
        }
        CONTENT_BODIES[cid] = s["body"]
        now += timedelta(hours=1)

    # Add some published history
    for title, ct in [
        ("Getting Started with Riverpod 3.0", "article"),
        ("Cross-platform development trends", "social_post"),
    ]:
        cid = str(uuid.uuid4())
        CONTENT_DB[cid] = {
            "id": cid,
            "title": title,
            "content_type": ct,
            "source_robot": "seo",
            "status": "published",
            "project_id": DEMO_PROJECT_ID,
            "content_path": None,
            "content_preview": f"Published content: {title}",
            "content_hash": None,
            "priority": 3,
            "tags": [],
            "metadata": {},
            "target_url": None,
            "reviewer_note": None,
            "reviewed_by": None,
            "created_at": (now - timedelta(days=2)).isoformat(),
            "updated_at": now.isoformat(),
            "scheduled_for": None,
            "published_at": (now - timedelta(days=1)).isoformat(),
            "synced_at": None,
        }


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def do_OPTIONS(self):
        self._send_json({})

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        params = parse_qs(parsed.query)

        # Health
        if path == "/health":
            self._send_json({"status": "ok", "version": "test-server-1.0"})
            return

        # List content
        if path == "/api/status/content":
            status_filter = params.get("status", [None])[0]
            items = list(CONTENT_DB.values())
            if status_filter:
                # Support comma-separated statuses
                statuses = [s.strip() for s in status_filter.split(",")]
                items = [i for i in items if i["status"] in statuses]
            self._send_json({"items": items, "total": len(items)})
            return

        # Get single content
        if path.startswith("/api/status/content/") and path.count("/") == 4:
            cid = path.split("/")[-1]
            if cid in CONTENT_DB:
                self._send_json(CONTENT_DB[cid])
            else:
                self._send_json({"detail": "Not found"}, 404)
            return

        # Get content body
        if path.endswith("/body") and "/api/status/content/" in path:
            cid = path.split("/")[-2]
            body = CONTENT_BODIES.get(cid, "")
            self._send_json({
                "id": str(uuid.uuid4()),
                "content_id": cid,
                "body": body,
                "version": 1,
                "edited_by": None,
                "edit_note": None,
                "created_at": datetime.utcnow().isoformat(),
            })
            return

        # Stats
        if path == "/api/status/stats":
            by_status: dict[str, int] = {}
            for c in CONTENT_DB.values():
                by_status[c["status"]] = by_status.get(c["status"], 0) + 1
            self._send_json({"total": len(CONTENT_DB), "by_status": by_status})
            return

        # Projects
        if path == "/api/projects":
            self._send_json([{
                "id": DEMO_PROJECT_ID,
                "name": DEMO_PROJECT_NAME,
                "url": DEMO_REPO_URL,
                "description": DEMO_DESCRIPTION,
                "is_default": True,
                "settings": {
                    "tech_stack": {"framework": "nextjs", "framework_version": "latest", "confidence": 0.95},
                    "onboarding_status": "completed",
                },
                "last_analyzed_at": None,
                "created_at": datetime.utcnow().isoformat(),
            }])
            return

        # Personas
        if path == "/api/psychology/personas":
            self._send_json([{
                "id": "persona-1",
                "name": "Tech-Savvy Solopreneur",
                "avatar": "🚀",
                "confidence": 72,
                "demographics": {"role": "Indie developer", "industry": "SaaS", "age_range": "25-40", "experience_level": "3-8 years"},
                "pain_points": ["Overwhelmed by too many AI tools", "Analysis paralysis on tool selection"],
                "goals": ["Build profitable SaaS with minimal team", "Use AI to multiply productivity"],
                "language": {"vocabulary": ["ship it", "MVP"], "objections": ["too expensive", "not enough time"], "triggers": {}},
                "content_preferences": {"formats": ["article", "video"], "channels": ["twitter", "linkedin"], "frequency": "daily"},
            }])
            return

        # Scheduler jobs
        if path == "/api/scheduler/jobs":
            self._send_json([])
            return

        self._send_json({"detail": "Not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        body = self._read_body()

        # Transition
        if "/transition" in path and "/api/status/content/" in path:
            cid = path.split("/")[-2]
            if cid not in CONTENT_DB:
                self._send_json({"detail": "Not found"}, 404)
                return
            to_status = body.get("to_status")
            current = CONTENT_DB[cid]["status"]
            valid = VALID_TRANSITIONS.get(current, [])
            if to_status not in valid:
                self._send_json({"detail": f"Cannot transition from {current} to {to_status}"}, 400)
                return
            CONTENT_DB[cid]["status"] = to_status
            CONTENT_DB[cid]["updated_at"] = datetime.utcnow().isoformat()
            if to_status == "published":
                CONTENT_DB[cid]["published_at"] = datetime.utcnow().isoformat()
            CONTENT_DB[cid]["reviewer_note"] = body.get("reason")
            CONTENT_DB[cid]["reviewed_by"] = body.get("changed_by")
            STATUS_HISTORY.append({
                "id": str(uuid.uuid4()),
                "content_id": cid,
                "from_status": current,
                "to_status": to_status,
                "changed_by": body.get("changed_by", "unknown"),
                "reason": body.get("reason"),
                "timestamp": datetime.utcnow().isoformat(),
            })
            print(f"  ✓ Transition: {cid[:8]}... {current} → {to_status}")
            self._send_json(CONTENT_DB[cid])
            return

        # Psychology: synthesize narrative
        if path == "/api/psychology/synthesize-narrative":
            entries = body.get("entries", [])
            print(f"  ✓ Narrative synthesis: {len(entries)} entries received")
            self._send_json({
                "voice_delta": {"tone_shift": "More direct and opinionated", "new_vocabulary": ["ship it", "good enough"]},
                "positioning_delta": {"angle_shift": "From 'AI enthusiast' to 'pragmatic AI builder'"},
                "narrative_summary": f"This week's {len(entries)} entries reveal a shift toward pragmatism. The creator is moving from tool accumulation to tool mastery — choosing depth over breadth.",
                "chapter_transition": True,
                "suggested_chapter_title": "Radical Pragmatism",
            })
            return

        # Psychology: generate angles
        if path == "/api/psychology/generate-angles":
            count = body.get("count", 3)
            print(f"  ✓ Generating {count} angles")
            self._send_json({
                "angles": [
                    {"title": "The Filter: I tested 50 AI tools, here are the 3 worth your time", "hook": "Stop hoarding AI subscriptions.", "angle": "Pragmatic curation", "content_type": "blog_post", "narrative_thread": "Radical Pragmatism", "pain_point_addressed": "Too many AI tools", "confidence": 87},
                    {"title": "Your problem isn't the tools — it's clarity", "hook": "You don't need another AI tool.", "angle": "Confrontational mirror", "content_type": "social_post", "narrative_thread": "Radical Pragmatism", "pain_point_addressed": "Analysis paralysis", "confidence": 79},
                    {"title": "My 5-minute AI tool decision framework", "hook": "I've been paralyzed by tool choice too.", "angle": "Empathetic guide", "content_type": "video_script", "narrative_thread": "Radical Pragmatism", "pain_point_addressed": "Decision fatigue", "confidence": 82},
                ],
                "strategy_note": "Angles focused on the pragmatism narrative thread.",
            })
            return

        # Psychology: personas
        if path == "/api/psychology/personas":
            persona = body
            persona["id"] = persona.get("id") or str(uuid.uuid4())
            print(f"  ✓ Persona saved: {persona.get('name')}")
            self._send_json(persona)
            return

        # Create content
        if path == "/api/status/content":
            cid = str(uuid.uuid4())
            now = datetime.utcnow().isoformat()
            record = {
                "id": cid,
                "title": body.get("title", "Untitled"),
                "content_type": body.get("content_type", "article"),
                "source_robot": body.get("source_robot", "manual"),
                "status": body.get("status", "todo"),
                "project_id": body.get("project_id"),
                "content_path": body.get("content_path"),
                "content_preview": body.get("content_preview"),
                "content_hash": None,
                "priority": body.get("priority", 3),
                "tags": body.get("tags", []),
                "metadata": body.get("metadata", {}),
                "target_url": body.get("target_url"),
                "reviewer_note": None,
                "reviewed_by": None,
                "created_at": now,
                "updated_at": now,
                "scheduled_for": None,
                "published_at": None,
                "synced_at": None,
            }
            CONTENT_DB[cid] = record
            self._send_json(record, 201)
            return

        self._send_json({"detail": "Not found"}, 404)

    def do_PATCH(self):
        parsed = urlparse(self.path)
        path = parsed.path
        body = self._read_body()

        # Update content
        if path.startswith("/api/status/content/") and not path.endswith("/schedule"):
            cid = path.split("/")[-1]
            if cid in CONTENT_DB:
                for k, v in body.items():
                    if k in CONTENT_DB[cid] and v is not None:
                        CONTENT_DB[cid][k] = v
                CONTENT_DB[cid]["updated_at"] = datetime.utcnow().isoformat()
                self._send_json(CONTENT_DB[cid])
            else:
                self._send_json({"detail": "Not found"}, 404)
            return

        # Schedule content
        if path.endswith("/schedule"):
            cid = path.split("/")[-2]
            if cid in CONTENT_DB:
                CONTENT_DB[cid]["scheduled_for"] = body.get("scheduled_for")
                CONTENT_DB[cid]["status"] = "scheduled"
                CONTENT_DB[cid]["updated_at"] = datetime.utcnow().isoformat()
                self._send_json(CONTENT_DB[cid])
            else:
                self._send_json({"detail": "Not found"}, 404)
            return

        self._send_json({"detail": "Not found"}, 404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        body = self._read_body()

        # Save content body
        if path.endswith("/body") and "/api/status/content/" in path:
            cid = path.split("/")[-2]
            CONTENT_BODIES[cid] = body.get("body", "")
            print(f"  ✓ Body saved: {cid[:8]}... ({len(body.get('body', ''))} chars)")
            self._send_json({
                "id": str(uuid.uuid4()),
                "content_id": cid,
                "body": body.get("body", ""),
                "version": 2,
                "edited_by": body.get("edited_by"),
                "edit_note": body.get("edit_note"),
                "created_at": datetime.utcnow().isoformat(),
            })
            return

        self._send_json({"detail": "Not found"}, 404)

    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")


if __name__ == "__main__":
    seed_data()
    print(f"🚀 Test server running on http://localhost:8000")
    print(f"   {len(CONTENT_DB)} content items seeded ({sum(1 for c in CONTENT_DB.values() if c['status'] == 'pending_review')} pending review)")
    print(f"   Endpoints: /health, /api/status/content, /api/projects, /api/psychology/*")
    print()
    HTTPServer(("", 8000), Handler).serve_forever()
