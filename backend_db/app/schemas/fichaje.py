from pydantic import BaseModel, UUID4
from datetime import datetime

class FichajeCreate(BaseModel):
    tipo: str


class FichajeResponse(BaseModel):
    id: UUID4
    usuario_id: UUID4
    empresa_id: UUID4
    tipo: str
    fecha_hora: datetime
    fecha_creacion: datetime

    class Config:
        from_attributes = True


