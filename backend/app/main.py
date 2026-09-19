from fastapi import FastAPI

app = FastAPI(title="Major Project Backend")

@app.get("/health")
def health():
    return {"status": "ok"}
