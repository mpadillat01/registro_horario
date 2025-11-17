from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.orm import Session
import os
from fastapi.responses import Response
from fastapi.responses import StreamingResponse
from datetime import datetime, timedelta
from app.models.fichaje import Fichaje
from app.database import get_db
from app.security import get_current_user
from app.models.documento import Documento

router = APIRouter(prefix="/documentos", tags=["Documentos"])

BASE_DIR = "uploads/documentos"


@router.post("/subir")
async def subir_documento(
    usuario_id: str,
    tipo: str | None = None,
    archivo: UploadFile = File(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):

    if user.rol != "admin" and str(user.id) != usuario_id:
        raise HTTPException(status_code=403, detail="No autorizado")

    ruta_dir = f"{BASE_DIR}/{usuario_id}/"
    os.makedirs(ruta_dir, exist_ok=True)

    ruta_archivo = os.path.join(ruta_dir, archivo.filename)

    contenido = await archivo.read()

    with open(ruta_archivo, "wb") as f:
        f.write(contenido)

    doc = Documento(
        usuario_id=usuario_id,
        nombre=archivo.filename,
        ruta=ruta_archivo,
        tipo=tipo,
    )

    db.add(doc)
    db.commit()
    db.refresh(doc)

    return {"status": "ok", "archivo": archivo.filename}

from fastapi import Query

from sqlalchemy import func

@router.get("/descargar-semanal/{usuario_id}")
def descargar_informe_semanal(
    usuario_id: str,
    week: str = Query(..., description="Semana en formato YYYY-MM-DD"),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    print("📥 SOLICITUD RECIBIDA → informe semanal")
    print("👉 usuario_id:", usuario_id)
    print("👉 week:", week)

    if user.rol != "admin" and str(user.id) != usuario_id:
        raise HTTPException(status_code=403, detail="No autorizado")

    try:
        inicio_semana = datetime.strptime(week, "%Y-%m-%d")
    except:
        raise HTTPException(status_code=400, detail="Formato inválido. Ej: 2025-11-10")

    fin_semana = inicio_semana + timedelta(days=7)

    fichajes = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == usuario_id)
        .filter(Fichaje.fecha_hora >= inicio_semana)
        .filter(Fichaje.fecha_hora < fin_semana)
        .order_by(Fichaje.fecha_hora.asc())
        .all()
    )

    if not fichajes:
        raise HTTPException(status_code=404, detail="No hay fichajes esta semana")

    csv_data = "Fecha,Tipo,Hora\n"
    for f in fichajes:
        csv_data += (
            f"{f.fecha_hora.date()},"
            f"{f.tipo},"
            f"{f.fecha_hora.time()}\n"
        )

    filename = f"informe_{week}.csv"
    print("📄 CSV generado correctamente")

    return StreamingResponse(
        iter([csv_data.encode()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@router.get("/listar/{usuario_id}")
def listar_documentos(
    usuario_id: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    docs = (
        db.query(Documento)
        .filter(Documento.usuario_id == usuario_id)
        .order_by(Documento.fecha_subida.desc())
        .all()
    )
    return docs


@router.get("/descargar/{usuario_id}/{archivo}")
def descargar_documento(
    usuario_id: str,
    archivo: str,
    user=Depends(get_current_user)
):
    ruta = f"{BASE_DIR}/{usuario_id}/{archivo}"

    if not os.path.exists(ruta):
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    with open(ruta, "rb") as f:
        contenido = f.read()

    return Response(
        content=contenido,
        media_type="application/octet-stream",
        headers={
            "Content-Disposition": f"attachment; filename={archivo}"
        }
    )
