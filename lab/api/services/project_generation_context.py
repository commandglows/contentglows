from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass
from typing import Any, Protocol

from api.models.project_intelligence import (
    ProjectGenerationContextBudget,
    ProjectGenerationContextItem,
    ProjectGenerationContextProvenanceRef,
    ProjectGenerationContextResult,
)
from api.services.project_intelligence_store import ProjectIntelligenceStore, project_intelligence_store
from api.services.user_data_store import user_data_store


def _estimate_tokens(text: str) -> int:
    return max(1, int(math.ceil(len(text) / 4)))


def _bounded_text(text: Any, *, max_chars: int = 700) -> str:
    clean = " ".join(str(text or "").split())
    if len(clean) <= max_chars:
        return clean
    return clean[: max_chars - 1].rstrip() + "..."


def _hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class ProjectGenerationContextStoreError(RuntimeError):
    code = "generation_context_unavailable"

    def __init__(self, message: str = "generation_context_unavailable") -> None:
        super().__init__("generation_context_unavailable")
        self.detail = message


class ProjectContextRetriever(Protocol):
    async def retrieve(
        self,
        *,
        user_id: str,
        project_id: str,
        query: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        ...

    def explain(self) -> dict[str, Any]:
        ...


@dataclass
class RelationalProjectContextRetriever:
    store: ProjectIntelligenceStore

    async def retrieve(
        self,
        *,
        user_id: str,
        project_id: str,
        query: str,
        limit: int,
    ) -> list[dict[str, Any]]:
        return await self.store.list_generation_context_chunks(
            user_id=user_id,
            project_id=project_id,
            query=query,
            limit=limit,
        )

    def explain(self) -> dict[str, Any]:
        return {
            "provider": "project_intelligence_relational",
            "canonical": "ProjectIntelligence relational rows",
            "vectorIndex": None,
        }


class ProjectGenerationContextBuilder:
    def __init__(
        self,
        *,
        store: ProjectIntelligenceStore | None = None,
        retriever: ProjectContextRetriever | None = None,
    ) -> None:
        self.store = store or project_intelligence_store
        self.retriever = retriever or RelationalProjectContextRetriever(self.store)

    async def build(
        self,
        *,
        user_id: str,
        project_id: str,
        generation_type: str,
        route_id: str,
        content_type: str | None = None,
        content_record_id: str | None = None,
        query: str | None = None,
        title: str | None = None,
        topics: list[str] | None = None,
        max_tokens: int = 6000,
    ) -> ProjectGenerationContextResult:
        budget = ProjectGenerationContextBudget(maxTokens=max_tokens)
        query_text = query or title or " ".join(topics or []) or generation_type
        try:
            facts = await self.store.list_generation_context_facts(
                user_id=user_id,
                project_id=project_id,
                limit=120,
            )
            chunks = await self.retriever.retrieve(
                user_id=user_id,
                project_id=project_id,
                query=query_text,
                limit=80,
            )
            signals = await self.store.list_generation_signals(
                user_id=user_id,
                project_id=project_id,
                generation_type=generation_type,
                limit=30,
            )
        except Exception as exc:  # noqa: BLE001 - sanitize storage/provider details.
            raise ProjectGenerationContextStoreError(str(exc)) from exc

        selected: list[ProjectGenerationContextItem] = []
        provenance: list[ProjectGenerationContextProvenanceRef] = []
        exclusions: list[dict[str, Any]] = []
        truncated_counts = {"fact": 0, "source_excerpt": 0, "past_generation": 0}
        used_tokens = min(budget.reserved_tokens, max(0, budget.max_tokens // 10))

        def add_item(item: ProjectGenerationContextItem, *, bucket_limit: int, bucket_used: int) -> int:
            nonlocal used_tokens
            if used_tokens + item.token_estimate > budget.max_tokens or bucket_used + item.token_estimate > bucket_limit:
                truncated_counts[item.item_type] = truncated_counts.get(item.item_type, 0) + 1
                exclusions.append(
                    {
                        "itemId": item.id,
                        "itemType": item.item_type,
                        "reason": "budget_exceeded",
                        "tokenEstimate": item.token_estimate,
                    }
                )
                return bucket_used
            selected.append(item)
            provenance.append(item.provenance)
            used_tokens += item.token_estimate
            return bucket_used + item.token_estimate

        fact_used = 0
        for fact in self._sort_facts(facts):
            text = f"{fact.get('subject')}: {fact.get('statement')}"
            item = self._build_item(
                user_id=user_id,
                project_id=project_id,
                item_type="fact",
                item_id=str(fact["id"]),
                title=str(fact.get("subject") or fact.get("category") or "Project fact"),
                text=_bounded_text(text, max_chars=900),
                category=str(fact.get("category") or ""),
                priority=int(fact.get("priority") or 3),
                selected_reason="required_project_fact",
                source_id=fact.get("sourceId"),
                document_id=fact.get("documentId"),
                chunk_id=fact.get("chunkId"),
                fact_id=fact.get("id"),
                score=float(fact.get("confidence") or 0),
            )
            fact_used = add_item(item, bucket_limit=budget.required_fact_tokens, bucket_used=fact_used)

        excerpt_used = 0
        for chunk in chunks:
            item = self._build_item(
                user_id=user_id,
                project_id=project_id,
                item_type="source_excerpt",
                item_id=str(chunk["id"]),
                title=f"Source excerpt {chunk.get('orderIndex', 0)}",
                text=_bounded_text(chunk.get("snippet") or chunk.get("text"), max_chars=700),
                category="source_excerpt",
                priority=3,
                selected_reason="deterministic_relational_retrieval",
                source_id=chunk.get("sourceId"),
                document_id=chunk.get("documentId"),
                chunk_id=chunk.get("id"),
                score=float(chunk.get("retrievalScore") or 0),
            )
            excerpt_used = add_item(item, bucket_limit=budget.excerpt_tokens, bucket_used=excerpt_used)

        signal_used = 0
        for signal in signals:
            summary = _bounded_text(signal.get("summary") or signal.get("title"), max_chars=500)
            item = self._build_item(
                user_id=user_id,
                project_id=project_id,
                item_type="past_generation",
                item_id=str(signal["id"]),
                title=str(signal.get("title") or "Past generation"),
                text=summary,
                category=str(signal.get("contentType") or generation_type),
                priority=4,
                selected_reason="past_generation_signal",
                generation_signal_id=signal.get("id"),
                score=0,
            )
            signal_used = add_item(item, bucket_limit=budget.past_generation_tokens, bucket_used=signal_used)

        empty_reason = "empty_project_context" if not selected else None
        if selected:
            selected = self._fit_items_to_prompt_budget(
                items=selected,
                empty_reason=empty_reason,
                retriever_explanation=self.retriever.explain(),
                max_tokens=budget.max_tokens,
            )
            provenance = [item.provenance for item in selected]
        prompt_text = self.render_prompt(
            items=selected,
            empty_reason=empty_reason,
            retriever_explanation=self.retriever.explain(),
        )

        try:
            affiliations = await user_data_store.list_affiliations(
                user_id=user_id,
                project_id=project_id,
            )
        except Exception:
            affiliations = []

        active_affiliations = [
            link for link in affiliations if link.get("status") == "active" and link.get("url")
        ]

        if active_affiliations:
            lines = ["", "## Active Affiliate Links", ""]
            for link in active_affiliations[:20]:
                name = link.get("name") or "Unnamed link"
                url = link.get("url") or ""
                slug = link.get("slug")
                keywords = link.get("keywords") or []
                category = link.get("category")
                parts = [f"- {name}: {url}"]
                if slug:
                    parts.append(f"  short slug: /r/{slug}")
                if keywords:
                    parts.append(f"  keywords: {', '.join(keywords)}")
                if category:
                    parts.append(f"  category: {category}")
                lines.append("\n".join(parts))
            prompt_text = prompt_text.rstrip() + "\n\n" + "\n".join(lines)

        prompt_hash = _hash_text(prompt_text)
        token_estimate = _estimate_tokens(prompt_text)

        try:
            log = await self.store.write_generation_context_log(
                user_id=user_id,
                project_id=project_id,
                generation_type=generation_type,
                route_id=route_id,
                content_record_id=content_record_id,
                request={
                    "generationType": generation_type,
                    "routeId": route_id,
                    "contentType": content_type,
                    "contentRecordId": content_record_id,
                    "queryHash": _hash_text(query_text),
                    "topics": list(topics or []),
                },
                budget=budget.model_dump(by_alias=True),
                items=[
                    {
                        "id": item.id,
                        "itemType": item.item_type,
                        "title": item.title,
                        "tokenEstimate": item.token_estimate,
                        "selectedReason": item.selected_reason,
                        "textHash": _hash_text(item.text),
                        "textLength": len(item.text),
                    }
                    for item in selected
                ],
                provenance=[ref.model_dump(by_alias=True, mode="json") for ref in provenance],
                exclusions=exclusions,
                prompt_hash=prompt_hash,
                prompt_char_count=len(prompt_text),
                token_estimate=token_estimate,
                degraded=False,
                empty_reason=empty_reason,
            )
        except Exception as exc:  # noqa: BLE001
            raise ProjectGenerationContextStoreError(str(exc)) from exc

        return ProjectGenerationContextResult(
            userId=user_id,
            projectId=project_id,
            generationType=generation_type,
            contextLogId=log["id"],
            degraded=False,
            emptyReason=empty_reason,
            items=selected,
            provenance=provenance,
            budget=budget,
            tokenEstimate=token_estimate,
            truncatedCounts=truncated_counts,
            exclusions=exclusions,
            promptText=prompt_text,
        )

    def _build_item(
        self,
        *,
        user_id: str,
        project_id: str,
        item_type: str,
        item_id: str,
        title: str,
        text: str,
        category: str,
        priority: int,
        selected_reason: str,
        source_id: str | None = None,
        document_id: str | None = None,
        chunk_id: str | None = None,
        fact_id: str | None = None,
        generation_signal_id: str | None = None,
        score: float | None = None,
    ) -> ProjectGenerationContextItem:
        full_id = f"{item_type}:{item_id}"
        ref = ProjectGenerationContextProvenanceRef(
            userId=user_id,
            projectId=project_id,
            itemType=item_type,
            itemId=full_id,
            sourceId=source_id,
            documentId=document_id,
            chunkId=chunk_id,
            factId=fact_id,
            generationSignalId=generation_signal_id,
            category=category,
            score=score,
            selectedReason=selected_reason,
        )
        return ProjectGenerationContextItem(
            id=full_id,
            itemType=item_type,
            title=title,
            text=text,
            tokenEstimate=_estimate_tokens(text),
            priority=priority,
            category=category,
            selectedReason=selected_reason,
            provenance=ref,
        )

    @staticmethod
    def _sort_facts(facts: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return sorted(
            facts,
            key=lambda fact: (
                int(fact.get("priority") or 3),
                -float(fact.get("confidence") or 0),
                str(fact.get("updatedAt") or ""),
                str(fact.get("category") or ""),
                str(fact.get("sourceId") or ""),
                str(fact.get("documentId") or ""),
                str(fact.get("chunkId") or ""),
                str(fact.get("id") or ""),
            ),
        )

    @staticmethod
    def render_prompt(
        *,
        items: list[ProjectGenerationContextItem],
        empty_reason: str | None,
        retriever_explanation: dict[str, Any],
    ) -> str:
        lines = [
            "--- PROJECT INTELLIGENCE CONTEXT ---",
            "Use bounded tenant-scoped context. Do not create durable facts silently.",
            f"retrieval: {retriever_explanation.get('provider')}",
        ]
        if empty_reason:
            lines.append(f"empty_context: {empty_reason}")
            lines.append("--- END PROJECT INTELLIGENCE CONTEXT ---")
            return "\n".join(lines)
        for item in items:
            lines.append(f"[{item.item_type}] {item.title} ({item.selected_reason})")
            lines.append(item.text)
        lines.append("--- END PROJECT INTELLIGENCE CONTEXT ---")
        return "\n".join(lines)

    def _fit_items_to_prompt_budget(
        self,
        *,
        items: list[ProjectGenerationContextItem],
        empty_reason: str | None,
        retriever_explanation: dict[str, Any],
        max_tokens: int,
    ) -> list[ProjectGenerationContextItem]:
        prompt_text = self.render_prompt(
            items=items,
            empty_reason=empty_reason,
            retriever_explanation=retriever_explanation,
        )
        if _estimate_tokens(prompt_text) <= max_tokens:
            return items

        overhead_text = self.render_prompt(
            items=[
                item.model_copy(update={"text": ""})
                for item in items
            ],
            empty_reason=empty_reason,
            retriever_explanation=retriever_explanation,
        )
        available_chars = max(40, (max_tokens - _estimate_tokens(overhead_text)) * 4)
        per_item_chars = max(40, available_chars // max(1, len(items)))
        fitted: list[ProjectGenerationContextItem] = []
        for item in items:
            text = _bounded_text(item.text, max_chars=per_item_chars)
            fitted.append(
                item.model_copy(
                    update={
                        "text": text,
                        "token_estimate": _estimate_tokens(text),
                    }
                )
            )
        return fitted
