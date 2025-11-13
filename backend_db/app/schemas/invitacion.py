from pydantic import BaseModel, EmailStr
from datetime import datetime
from uuid import UUID

class InvitacionCreate(BaseModel):
    empresa_id: UUID
    email: EmailStr


class InvitacionResponse(BaseModel):
    id: UUID
    empresa_id: UUID
    email: EmailStr
    token: UUID
    usada: bool
    fecha_creacion: datetime

    model_config = {
        "from_attributes": True     }

class RegistroEmpleado(BaseModel):
    nombre: str
    password: str
