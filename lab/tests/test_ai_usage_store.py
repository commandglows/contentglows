import pytest

from api.services.ai_usage_store import AIUsageStore
from api.services.libsql_ai_usage_store import LibsqlAIUsageStore
from tests.ai_usage_store_contract import AIUsageStoreContract
from utils.libsql_async import create_client


class TestLibsqlAIUsageStore(AIUsageStoreContract):
    async def make_store(self) -> AIUsageStore:
        store = LibsqlAIUsageStore(db_client=create_client(url=":memory:"))
        await store.ensure_schema()
        return store

    @pytest.mark.asyncio
    async def test_adapter_satisfies_port_and_schema_is_idempotent(self):
        store = await self.make_store()
        assert isinstance(store, LibsqlAIUsageStore)
        await store.ensure_schema()
        assert isinstance(store, AIUsageStore)
