from pydantic import BaseModel, EmailStr
from typing import Optional

class UsuarioUpdate(BaseModel):
    nombre: Optional[str] = None
    email: Optional[EmailStr] = None
