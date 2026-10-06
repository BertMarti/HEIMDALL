from fastapi import FastAPI
import os

app = FastAPI(title="HEIMDALL - VPN")

@app.get("/health")
def health():
    return {"status": "ok", "service": "heimdall"}

@app.post("/api/vpn/connect")
def connect_vpn(client_name: str):
    # TODO: Generar WireGuard config
    return {"message": f"Config generated for {client_name}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
