from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Query, Form
from sqlalchemy.orm import Session
import os
from fastapi.responses import Response, StreamingResponse
from datetime import datetime, timedelta
from app.models.fichaje import Fichaje
from app.database import get_db
from app.security import get_current_user
from app.models.documento import Documento
from io import BytesIO
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from collections import defaultdict

router = APIRouter(prefix="/documentos", tags=["Documentos"])

BASE_DIR = "uploads/documentos"


def guardar_archivo(usuario_id: str, nombre: str, contenido: bytes):
    ruta_dir = f"{BASE_DIR}/{usuario_id}/"
    os.makedirs(ruta_dir, exist_ok=True)

    ruta_archivo = os.path.join(ruta_dir, nombre)
    with open(ruta_archivo, "wb") as f:
        f.write(contenido)

    return ruta_archivo


@router.post("/subir")
async def subir_documento(
    usuario_id: str = Form(...),
    tipo: str | None = Form(None),
    archivo: UploadFile = File(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    if user.rol != "admin" and str(user.id) != usuario_id:
        raise HTTPException(status_code=403, detail="No autorizado")

    contenido = await archivo.read()
    guardar_archivo(usuario_id, archivo.filename, contenido)

    doc = Documento(
        usuario_id=usuario_id,
        nombre=archivo.filename,
        ruta=f"{BASE_DIR}/{usuario_id}/{archivo.filename}",
        tipo=tipo,
    )

    db.add(doc)
    db.commit()
    db.refresh(doc)

    return {"status": "ok", "archivo": archivo.filename}


@router.get("/descargar-semanal/{usuario_id}")
def descargar_informe_semanal(
    usuario_id: str,
    week: str = Query(..., description="Semana YYYY-MM-DD"),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    if user.rol != "admin" and str(user.id) != usuario_id:
        raise HTTPException(status_code=403, detail="No autorizado")

    try:
        inicio_semana = datetime.strptime(week, "%Y-%m-%d")
    except:
        raise HTTPException(status_code=400, detail="Formato inválido")

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
        csv_data += f"{f.fecha_hora.date()},{f.tipo},{f.fecha_hora.time()}\n"

    filename = f"informe_{week}.csv"

    guardar_archivo(usuario_id, filename, csv_data.encode())

    return StreamingResponse(
        iter([csv_data.encode()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

@router.get("/listar/{usuario_id}")
def listar_documentos(
    usuario_id: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
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
    user=Depends(get_current_user),
):
    ruta = f"{BASE_DIR}/{usuario_id}/{archivo}"

    if not os.path.exists(ruta):
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    with open(ruta, "rb") as f:
        contenido = f.read()

    return Response(
        content=contenido,
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename={archivo}"},
    )


@router.get("/descargar-mensual/{usuario_id}")
def descargar_informe_mensual(
    usuario_id: str,
    month: str = Query(..., description="Mes YYYY-MM"),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    try:
        inicio = datetime.strptime(month, "%Y-%m")
    except:
        raise HTTPException(status_code=400, detail="Formato inválido")

    fin = (inicio + timedelta(days=32)).replace(day=1)

    fichajes = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == usuario_id)
        .filter(Fichaje.fecha_hora >= inicio)
        .filter(Fichaje.fecha_hora < fin)
        .order_by(Fichaje.fecha_hora.asc())
        .all()
    )

    if not fichajes:
        raise HTTPException(status_code=404, detail="No hay fichajes este mes")

    csv_data = "Fecha,Tipo,Hora\n"
    for f in fichajes:
        csv_data += f"{f.fecha_hora.date()},{f.tipo},{f.fecha_hora.time()}\n"

    filename = f"informe_mensual_{month}.csv"

    guardar_archivo(usuario_id, filename, csv_data.encode())

    return StreamingResponse(
        iter([csv_data.encode()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.get("/descargar-semanal-pdf/{usuario_id}")
def descargar_informe_semanal_pdf(
    usuario_id: str,
    week: str = Query(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    try:
        inicio_semana = datetime.strptime(week, "%Y-%m-%d")
    except:
        raise HTTPException(status_code=400, detail="Formato inválido")

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

    fichajes_por_dia = defaultdict(list)
    for f in fichajes:
        fichajes_por_dia[f.fecha_hora.date()].append(f)

    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 60

    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(50, y, f"Informe semanal de fichajes - {week}")
    y -= 40

    pdf.setFont("Helvetica", 12)

    for dia, items in fichajes_por_dia.items():

        pdf.setFont("Helvetica-Bold", 14)
        pdf.drawString(40, y, dia.strftime("%A %d/%m/%Y"))
        y -= 20

        pdf.setStrokeColor(colors.grey)
        pdf.line(40, y, width - 40, y)
        y -= 20

        pdf.setFont("Helvetica", 12)

        for f in items:
            txt = f"- {f.tipo.capitalize()} a las {f.fecha_hora.strftime('%H:%M:%S')}"
            pdf.drawString(60, y, txt)
            y -= 18

            if y < 60:
                pdf.showPage()
                pdf.setFont("Helvetica", 12)
                y = height - 60

        y -= 15

    pdf.save()
    buffer.seek(0)

    filename = f"informe_{week}.pdf"
    guardar_archivo(usuario_id, filename, buffer.getvalue())

    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

@router.get("/descargar-mensual-pdf/{usuario_id}")
def descargar_informe_mensual_pdf(
    usuario_id: str,
    month: str = Query(...),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    try:
        inicio = datetime.strptime(month, "%Y-%m")
    except:
        raise HTTPException(status=400, detail="Formato inválido")

    fin = (inicio + timedelta(days=32)).replace(day=1)

    fichajes = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == usuario_id)
        .filter(Fichaje.fecha_hora >= inicio)
        .filter(Fichaje.fecha_hora < fin)
        .order_by(Fichaje.fecha_hora.asc())
        .all()
    )

    if not fichajes:
        raise HTTPException(404, detail="No hay fichajes este mes")

    fichajes_por_dia = defaultdict(list)
    for f in fichajes:
        fichajes_por_dia[f.fecha_hora.date()].append(f)

    buffer = BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=A4)
    width, height = A4
    y = height - 60

    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(50, y, f"Informe mensual de fichajes - {month}")
    y -= 40

    pdf.setFont("Helvetica", 12)

    for dia, items in fichajes_por_dia.items():

        pdf.setFont("Helvetica-Bold", 14)
        pdf.drawString(40, y, dia.strftime("%A %d/%m/%Y"))
        y -= 20

        pdf.setStrokeColor(colors.grey)
        pdf.line(40, y, width - 40, y)
        y -= 20

        pdf.setFont("Helvetica", 12)

        for f in items:
            txt = f"- {f.tipo.capitalize()} a las {f.fecha_hora.strftime('%H:%M:%S')}"
            pdf.drawString(60, y, txt)
            y -= 18

            if y < 60:
                pdf.showPage()
                pdf.setFont("Helvetica", 12)
                y = height - 60

        y -= 15

    pdf.save()
    buffer.seek(0)

    filename = f"informe_mensual_{month}.pdf"
    guardar_archivo(usuario_id, filename, buffer.getvalue())

    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

@router.get("/descargar-por-nombre/{archivo}")
def descargar_por_nombre(
    archivo: str,
    user=Depends(get_current_user)
):
    for root, dirs, files in os.walk(BASE_DIR):
        if archivo in files:
            ruta = os.path.join(root, archivo)
            with open(ruta, "rb") as f:
                contenido = f.read()

            return Response(
                content=contenido,
                media_type="application/octet-stream",
                headers={"Content-Disposition": f"attachment; filename={archivo}"}
            )

    raise HTTPException(status_code=404, detail="Archivo no encontrado")
