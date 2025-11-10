from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer
from jose import jwt
from app.database import get_db
from app.models.usuario import Usuario
from app.models.invitacion import Invitacion
from app.security import SECRET_KEY, ALGORITHM

router = APIRouter(prefix="/empresa", tags=["Empresa"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_user_from_token(token: str, db: Session):
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    email = payload.get("sub")

    user = db.query(Usuario).filter(Usuario.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return user

@router.get("/empleados")
def get_empleados(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    user = get_user_from_token(token, db)

    # ✅ ADMIN ve todos los usuarios
    if user.rol == "admin":
        empleados = db.query(Usuario).all()
    else:
        # ✅ Empleado solo ve los de su empresa
        empleados = db.query(Usuario).filter(Usuario.empresa_id == user.empresa_id).all()

    return [
        {
            "id": str(e.id),
            "nombre": e.nombre,
            "email": e.email,
            "rol": e.rol,
            "empresa_id": str(e.empresa_id)
        }
        for e in empleados
    ]
