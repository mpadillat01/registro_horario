from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class DocumentoSchema(BaseModel):
    id: UUID
    usuario_id: UUID
    nombre: str
    ruta: str
    tipo: str | None
    fecha_subida: datetime

    class Config:
        orm_mode = True
