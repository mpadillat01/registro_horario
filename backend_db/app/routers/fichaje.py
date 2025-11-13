from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from fastapi.responses import JSONResponse
from app.database import get_db
from app.models.fichaje import Fichaje
from app.schemas.fichaje import FichajeResponse
from app.security import get_current_user


router = APIRouter(tags=["Fichajes"])

VALID_TIPOS = ["entrada", "salida", "inicio_pausa", "fin_pausa"]

@router.post("/{tipo}", response_model=FichajeResponse)
def marcar_fichaje(tipo: str, db: Session = Depends(get_db), user=Depends(get_current_user)):

    if tipo not in VALID_TIPOS:
        raise HTTPException(status_code=400, detail="Tipo de fichaje inválido")

    fichaje = Fichaje(
        usuario_id=user.id,
        empresa_id=user.empresa_id,
        tipo=tipo,
        fecha_hora=datetime.now(timezone.utc)
    )

    db.add(fichaje)
    db.commit()
    db.refresh(fichaje)

    return fichaje


@router.get("/", response_model=None)
def historial(db: Session = Depends(get_db), user=Depends(get_current_user)):
    fichajes = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == user.id)
        .order_by(Fichaje.fecha_hora.desc())
        .all()
    )

    data = []
    for f in fichajes:
        if f.fecha_hora:
            fecha_iso = (
                f.fecha_hora.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
            )
        else:
            fecha_iso = None

        data.append({
            "id": str(f.id),
            "usuario_id": str(f.usuario_id),
            "empresa_id": str(f.empresa_id),
            "tipo": f.tipo,
            "fecha_hora": fecha_iso,
            "fecha_creacion": f.fecha_creacion.isoformat() if f.fecha_creacion else None,
        })

    return JSONResponse(content=data)
@router.get("/empleado/{usuario_id}/horas")
def obtener_horas_empleado(usuario_id: str, db: Session = Depends(get_db), user=Depends(get_current_user)):
    registros = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == usuario_id)
        .order_by(Fichaje.fecha_hora.asc())
        .all()
    )

    if not registros:
        return []

    dias = {}
    for r in registros:
        fecha = r.fecha_hora.date()
        dias.setdefault(fecha, []).append(r)

    resultado = []

    for fecha, eventos in dias.items():
        total = 0
        pausa_total = 0
        entrada = None
        pausa_ini = None
        en_pausa = False

        for e in eventos:
            if e.tipo == "entrada":
                if entrada:
                    total += (e.fecha_hora - entrada).total_seconds() - pausa_total
                entrada = e.fecha_hora
                pausa_ini = None
                pausa_total = 0
                en_pausa = False

            elif e.tipo == "inicio_pausa" and entrada and not en_pausa:
                pausa_ini = e.fecha_hora
                en_pausa = True

            elif e.tipo == "fin_pausa" and pausa_ini and en_pausa:
                pausa_total += (e.fecha_hora - pausa_ini).total_seconds()
                pausa_ini = None
                en_pausa = False

            elif e.tipo == "salida" and entrada:
                if en_pausa and pausa_ini:
                    pausa_total += (e.fecha_hora - pausa_ini).total_seconds()
                    en_pausa = False
                total += (e.fecha_hora - entrada).total_seconds() - pausa_total
                entrada = None
                pausa_ini = None
                pausa_total = 0

        if entrada:
            fin_jornada = eventos[-1].fecha_hora
            total += (fin_jornada - entrada).total_seconds() - pausa_total

        horas = round(total / 3600, 2)
        resultado.append({"fecha": str(fecha), "horas": horas})

    return sorted(resultado, key=lambda x: x["fecha"], reverse=True)

@router.get("/ultimo/{usuario_id}")
def ultimo_fichaje(usuario_id: str, db: Session = Depends(get_db), user=Depends(get_current_user)):

    fichaje = (
        db.query(Fichaje)
        .filter(Fichaje.usuario_id == usuario_id)
        .order_by(Fichaje.fecha_hora.desc())
        .first()
    )

    if not fichaje:
        return {"estado": "sin_registro"}

    return {
        "estado": fichaje.tipo,
        "hora": fichaje.fecha_hora.isoformat()
    }
