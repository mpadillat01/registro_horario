from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional

class NotificacionBase(BaseModel):
    titulo: str
    mensaje: str
    tipo: str
    origen: Optional[str] = "sistema"

class NotificacionCreate(NotificacionBase):
    usuario_id: UUID
    empresa_id: UUID

class NotificacionResponse(NotificacionBase):
    id: UUID
    usuario_id: UUID
    empresa_id: UUID
    leida: bool
    fecha_envio: datetime

    class Config:
        orm_mode = True 