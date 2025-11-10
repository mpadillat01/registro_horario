from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta
from app.database import get_db
from app.models.usuario import Usuario
from app.security import get_current_user

from app.security import verify_password, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES, hash_password

# 👇 ESTE router es el que faltaba
router = APIRouter(prefix="/auth", tags=["Autenticación"])

@router.post("/login")
def login(data: dict, db: Session = Depends(get_db)):
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email y contraseña requeridos")

    user = db.query(Usuario).filter(Usuario.email == email).first()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    token = create_access_token(
        data={"sub": str(user.id), "rol": user.rol, "empresa_id": str(user.empresa_id)},
        expires_delta=access_token_expires,
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "usuario": {
            "id": str(user.id),
            "nombre": user.nombre,
            "email": user.email,
            "rol": user.rol,
            "empresa_id": str(user.empresa_id),
        },
    }


@router.post("/register")
def register(data: dict, db: Session = Depends(get_db)):
    email = data.get("email")
    password = data.get("password")
    nombre = data.get("nombre")

    if not all([email, password, nombre]):
        raise HTTPException(status_code=400, detail="Campos requeridos faltantes")

    if db.query(Usuario).filter(Usuario.email == email).first():
        raise HTTPException(status_code=400, detail="El email ya está registrado")

    hashed = hash_password(password)
    nuevo = Usuario(email=email, password_hash=hashed, nombre=nombre)
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)

    return {"message": "Usuario registrado correctamente", "id": str(nuevo.id)}

@router.get("/me")
def get_me(current_user=Depends(get_current_user)):
    """Devuelve los datos del usuario autenticado actual"""
    return {
        "id": str(current_user.id),
        "nombre": current_user.nombre,
        "email": current_user.email,
        "rol": current_user.rol,
        "empresa_id": str(current_user.empresa_id),
    }