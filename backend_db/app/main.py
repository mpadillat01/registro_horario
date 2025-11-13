from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import Base, engine
from app.security import get_current_user

from app.routers import (
    auth,
    empresa,
    fichaje,
    usuario as usuario_router,
    notification,
    invitacion,  
)

print("✅ Creando tablas si no existen...")
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Registro Horario API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(empresa.router)
app.include_router(fichaje.router, prefix="/fichajes")
app.include_router(usuario_router.router)
app.include_router(notification.router)
app.include_router(invitacion.router)
@app.get("/")
def root():
    return {"status": "API funcionando ✅"}
