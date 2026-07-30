from typing import Dict, List

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from sqlalchemy.orm import Session

from . import models
from .db import Base, engine, get_db

app = FastAPI(title="분신 backend")


@app.on_event("startup")
def create_tables():
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}


class SignupRequest(BaseModel):
    invite_code: str
    display_name: str


@app.post("/auth/signup")
def signup(req: SignupRequest, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter_by(invite_code=req.invite_code).first()
    if existing:
        raise HTTPException(status_code=409, detail="invite_code already used")
    user = models.User(invite_code=req.invite_code, display_name=req.display_name)
    db.add(user)
    db.commit()
    db.refresh(user)
    db.add(models.TwinSettings(user_id=user.id))
    db.commit()
    return {"id": user.id, "display_name": user.display_name}


class SendMessageRequest(BaseModel):
    sender_id: int
    text: str
    sender_mode: models.SenderMode = models.SenderMode.HUMAN


@app.post("/conversations/{conversation_id}/messages")
async def send_message(conversation_id: int, req: SendMessageRequest, db: Session = Depends(get_db)):
    conversation = db.query(models.Conversation).get(conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="conversation not found")
    message = models.Message(
        conversation_id=conversation_id,
        sender_id=req.sender_id,
        sender_mode=req.sender_mode,
        text=req.text,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    await relay.broadcast(conversation_id, {
        "id": message.id,
        "sender_id": message.sender_id,
        "sender_mode": message.sender_mode.value,
        "text": message.text,
    })
    return {"id": message.id}


class ConnectionManager:
    """In-memory WebSocket fan-out per conversation. Fine for a small closed
    beta (roadmap.md Phase 1); revisit if the relay needs to scale past one
    process."""

    def __init__(self):
        self.connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, conversation_id: int, websocket: WebSocket):
        await websocket.accept()
        self.connections.setdefault(conversation_id, []).append(websocket)

    def disconnect(self, conversation_id: int, websocket: WebSocket):
        conns = self.connections.get(conversation_id, [])
        if websocket in conns:
            conns.remove(websocket)

    async def broadcast(self, conversation_id: int, payload: dict):
        for ws in self.connections.get(conversation_id, []):
            await ws.send_json(payload)


relay = ConnectionManager()


@app.websocket("/ws/conversations/{conversation_id}")
async def conversation_socket(websocket: WebSocket, conversation_id: int):
    await relay.connect(conversation_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        relay.disconnect(conversation_id, websocket)
