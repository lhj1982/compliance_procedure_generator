# mcp_client.py
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def call_say_hello(name: str) -> str:
    params = StdioServerParameters(command="python", args=["server.py"])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("say_hello", {"name": name})
            # Extract string(s) from the ToolResponse content
            texts = []
            for item in result.content:
                if item.type == "text":   # guaranteed by SDK
                    texts.append(item.text)
            return "\n".join(texts) if texts else str(result)

if __name__ == "__main__":
    out = asyncio.run(call_say_hello("Alice"))
    print("MCP said:", out)
