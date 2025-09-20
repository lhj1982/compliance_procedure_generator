from openai import OpenAI

api_key = 'b09fdcbb07d46c1922beddf21228519645a6cb31fecaad00a0b8d22e3ec10700'
base_url = 'https://aiplatform.dev51.cbf.dev.paypalinc.com/cosmosai/llm/v1'

client = OpenAI(
    api_key = api_key,
    base_url = base_url
)

messages = [{"role": "user", "content": "Hi, who are you."}]

response = client.chat.completions.create(
    model="llama33-70b",
    messages=messages,
    max_tokens=64,
    temperature=0
)
print(response.choices[0].message.content)

embedding = client.embeddings.create(input='San Francisco is a', model='embedding-bge-m3')
print("Embedding result:", embedding)
