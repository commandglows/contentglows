import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APPROVED_PYDANTIC_AI_IMPORTS = {
    Path("api/services/pydantic_ai_runtime.py"),
}
APPROVED_CHROMADB_IMPORTS: set[Path] = set()


def _python_files() -> list[Path]:
    ignored_parts = {".git", ".flox", ".venv", "venv", "__pycache__", ".pytest_cache"}
    return [
        path
        for path in ROOT.rglob("*.py")
        if not ignored_parts.intersection(path.relative_to(ROOT).parts)
    ]


def test_pydantic_ai_imports_stay_behind_runtime_adapter():
    violations: list[str] = []
    for path in _python_files():
        rel = path.relative_to(ROOT)
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            if any(name == "pydantic_ai" or name.startswith("pydantic_ai.") for name in names):
                if rel not in APPROVED_PYDANTIC_AI_IMPORTS:
                    violations.append(str(rel))

    assert violations == []


def test_pydantic_ai_requirement_uses_supported_v1_floor():
    requirements = (ROOT / "requirements.txt").read_text(encoding="utf-8")
    assert "pydantic-ai>=0.1.0,<1.0" not in requirements
    line = next(
        line.strip()
        for line in requirements.splitlines()
        if line.startswith("pydantic-ai")
    )
    assert ">=1.56.0" in line
    assert "<2.0" in line
    assert (ROOT / "api/services/pydantic_ai_runtime.py").is_file()


def test_runtime_install_documentation_uses_lockfile():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    assert "pip install -r requirements.lock" in readme


def test_clerk_jwt_runtime_dependency_is_explicit():
    requirements = (ROOT / "requirements.txt").read_text(encoding="utf-8").lower()
    lock = (ROOT / "requirements.lock").read_text(encoding="utf-8").lower()

    assert "pyjwt[crypto]>=" in requirements
    assert "pyjwt[crypto]==" in lock


def test_hashed_runtime_lock_includes_unsafe_build_dependencies():
    lock = (ROOT / "requirements.lock").read_text(encoding="utf-8").lower()

    assert "pip-compile --allow-unsafe --generate-hashes" in lock
    assert "setuptools==" in lock


def test_dependabot_tracks_lab_python_dependencies():
    dependabot = (ROOT.parent / ".github/dependabot.yml").read_text(encoding="utf-8")
    assert 'package-ecosystem: "pip"' in dependabot
    assert 'directory: "/lab"' in dependabot
    assert 'prefix: "deps(lab)"' in dependabot


def test_mem0_runtime_imports_and_requirements_are_removed():
    violations: list[str] = []
    for path in _python_files():
        rel = path.relative_to(ROOT)
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            if any(name == "mem0" or name.startswith("mem0.") or name == "memory" or name.startswith("memory.") for name in names):
                violations.append(str(rel))

    requirement_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in ROOT.glob("requirements*.txt")
        if path.name != "requirements-memory.txt"
    )
    lock_text = (ROOT / "requirements.lock").read_text(encoding="utf-8")

    assert violations == []
    assert "mem0ai" not in requirement_text.lower()
    assert "mem0ai" not in lock_text.lower()
    assert not (ROOT / "requirements-memory.txt").exists()


def test_composio_runtime_imports_and_requirements_are_removed():
    violations: list[str] = []
    for path in _python_files():
        rel = path.relative_to(ROOT)
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            if any(name == "composio" or name.startswith("composio_") for name in names):
                violations.append(str(rel))

    requirement_text = "\n".join(
        path.read_text(encoding="utf-8")
        for path in ROOT.glob("requirements*.txt")
    )
    lock_text = (ROOT / "requirements.lock").read_text(encoding="utf-8")

    assert violations == []
    assert "composio" not in requirement_text.lower()
    assert "composio" not in lock_text.lower()


def test_chromadb_is_only_crewai_transitive_residual_and_not_project_memory_runtime():
    violations: list[str] = []
    for path in _python_files():
        rel = path.relative_to(ROOT)
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(rel))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [alias.name for alias in node.names]
            elif isinstance(node, ast.ImportFrom):
                names = [node.module or ""]
            else:
                continue
            if any(name == "chromadb" or name.startswith("chromadb.") for name in names):
                if rel not in APPROVED_CHROMADB_IMPORTS:
                    violations.append(str(rel))

    lock_lines = (ROOT / "requirements.lock").read_text(encoding="utf-8").splitlines()
    chroma_line = next((idx for idx, line in enumerate(lock_lines) if line.startswith("chromadb==")), None)
    assert violations == []
    assert chroma_line is not None
    assert any("via crewai" in line for line in lock_lines[chroma_line : chroma_line + 12])
