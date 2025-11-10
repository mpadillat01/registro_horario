from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.usuario import Usuario

# --- CONFIGURACIÓN JWT ---
SECRET_KEY = "supersecretomuyseguro"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- FUNCIONES DE HASH ---
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

# --- CREACIÓN DE TOKEN ---
def create_access_token(data: dict, expires_delta: timedelta | None = None):
    """Genera un token JWT con expiración"""
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- DEPENDENCIA GLOBAL ---
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")
def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    """
    Obtiene el usuario autenticado desde el token JWT.
    Soporta 'sub' como UUID o email, con logs de depuración.
    """
    print("🪪 TOKEN RECIBIDO EN BACKEND →", token[:50], "..." if len(token) > 50 else "")

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print("📦 PAYLOAD DECODIFICADO:", payload)

        sub_value: str = payload.get("sub")
        if not sub_value:
            print("❌ El campo 'sub' no existe en el payload")
            raise credentials_exception

        # Intentar buscar por UUID primero
        user = db.query(Usuario).filter(Usuario.id == sub_value).first()

        # Si no lo encuentra, intentar por email (compatibilidad)
        if not user:
            user = db.query(Usuario).filter(Usuario.email == sub_value).first()

        if not user:
            print(f"❌ Usuario no encontrado para sub={sub_value}")
            raise credentials_exception

        print(f"✅ Usuario autenticado: {user.email} ({user.rol})")
        return user

    except JWTError as e:
        print(f"❌ Error JWT: {e}")
        raise credentials_exception
