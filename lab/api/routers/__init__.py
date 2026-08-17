"""API routers (organized by domain)"""

from .mesh import router as mesh_router
from .research import router as research_router
from .health import router as health_router
from .projects import router as projects_router
from .newsletter import router as newsletter_router
from .deployment import router as deployment_router
from .images import router as images_router
from .status import router as status_router
from .reels import router as reels_router
from .psychology import router as psychology_router
from .me import router as me_router
from .settings import router as settings_router
from .creator_profile import router as creator_profile_router
from .personas import router as personas_router
from .idea_pool import router as idea_pool_router
from .affiliations import router as affiliations_router
from .links import public_links_router, links_router
from .activity import router as activity_router
from .work_domains import router as work_domains_router
from .preview import router as preview_router
from .analytics import analytics_public_router, analytics_router
from .auth_web import router as auth_web_router, webhook_router as webhook_router
from .feedback import router as feedback_router
from .integrations import router as integrations_router
from .settings_integrations import router as settings_integrations_router
from .search_console import router as search_console_router
from .project_intelligence import router as project_intelligence_router
from .assets import router as assets_router
from .placement_registry import router as placement_registry_router
from .social_placements import router as social_placements_router
from .reel_renders import router as reel_renders_router
from .video_timelines import router as video_timelines_router
from .brand_profiles import router as brand_profiles_router
from .brand_video_blueprints import router as brand_video_blueprints_router
from .video_source_intake import router as video_source_intake_router

__all__ = [
    "mesh_router",
    "research_router",
    "health_router",
    "projects_router",
    "newsletter_router",
    "deployment_router",
    "images_router",
    "status_router",
    "reels_router",
    "psychology_router",
    "me_router",
    "settings_router",
    "creator_profile_router",
    "personas_router",
    "idea_pool_router",
    "affiliations_router",
    "public_links_router",
    "links_router",
    "activity_router",
    "work_domains_router",
    "preview_router",
    "analytics_public_router",
    "analytics_router",
    "auth_web_router",
    "webhook_router",
    "feedback_router",
    "integrations_router",
    "settings_integrations_router",
    "search_console_router",
    "project_intelligence_router",
    "assets_router",
    "placement_registry_router",
    "social_placements_router",
    "reel_renders_router",
    "video_timelines_router",
    "brand_profiles_router",
    "brand_video_blueprints_router",
    "video_source_intake_router",
]
