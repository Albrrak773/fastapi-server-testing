from fastapi import FastAPI
from fastapi.responses import Response
import json
import httpx
from wordfreq import random_words
import uvicorn
import aiofiles

app = FastAPI()


@app.get("/")
async def root():
    return Response(status_code=200)


@app.get("/words")
async def get_words():
    result = {}
    for i in range(10):
        result[f"list_{i+1}"] = list(random_words('en', nwords=10))
    return result


@app.get("/data")
async def get_data():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://jsonplaceholder.typicode.com/comments")
        return response.json()


@app.get("/users")
async def get_users():
    async with aiofiles.open("users.json", "r") as f:
        content = await f.read()
        data = json.loads(content)
    return data


if __name__ == "__main__":
    uvicorn.run("async:app", host="0.0.0.0", port=8000, workers=2)
