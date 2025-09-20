# openai_bridge.py
import os
import json
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from openai import OpenAI
from dotenv import load_dotenv
load_dotenv()
client = OpenAI()

OPENAI_MODEL = "gpt-4o-mini"
client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

async def call_mcp_tool(tool_name: str, args: dict) -> str:
    params = StdioServerParameters(command="python", args=["server.py"])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool(tool_name, args)
            texts = []
            for item in result.content:
                if getattr(item, "type", None) == "text":
                    texts.append(item.text)
            return "\n".join(texts) if texts else str(result)

def main():
    # 1) First request: let the model decide whether to call the tool
    messages = [
        {"role": "system", "content": "You can call external tools via MCP when needed."},
        {"role": "user", "content": "Please say hello to Bob."}
    ]

    tools = [{
        "type": "function",
        "function": {
            "name": "say_hello",
            "description": "Return a friendly greeting",
            "parameters": {
                "type": "object",
                "properties": {"name": {"type": "string"}},
                "required": ["name"]
            }
        }
    }]

    first = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=messages,
        tools=tools
    )

    choice = first.choices[0].message
    tool_calls = getattr(choice, "tool_calls", None)

    if not tool_calls:
        # Model answered without tool use
        print("Model answer:", choice.content)
        return

    # 2) Add the assistant message that contains tool_calls
    messages.append({
        "role": "assistant",
        "content": choice.content or "",
        "tool_calls": [tc.model_dump() for tc in tool_calls]  # ensure serializable
    })

    # 3) Execute each requested tool call via MCP and add tool results
    for tc in tool_calls:
        if tc.type == "function" and tc.function.name == "say_hello":
            args = {}
            if tc.function.arguments:
                # arguments is JSON string per spec
                args = json.loads(tc.function.arguments)
            tool_result = asyncio.run(call_mcp_tool(tc.function.name, args))

            # Append the tool result message referencing tool_call_id
            messages.append({
                "role": "tool",
                "tool_call_id": tc.id,
                "name": tc.function.name,
                "content": tool_result
            })

    # 4) Ask the model for the final answer using the complete history
    final = client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=messages
    )
    print("Model final answer:", final.choices[0].message.content)

if __name__ == "__main__":
    main()