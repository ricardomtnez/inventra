-- Migration: Vales Multi-herramienta y Simplificación de Motivo de Movimiento
-- Date: 2026-07-18
-- Description: Agrega grupo_id para préstamos agrupados, actualiza el constraint de movimientos a 'PRESTAMO' y migra históricos.

-- 1. Agregar columnas de agrupación a préstamos y movimientos
ALTER TABLE public.prestamos ADD COLUMN IF NOT EXISTS grupo_id UUID;
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS grupo_id UUID;

-- 2. Modificar la restricción check de motivos para aceptar 'PRESTAMO'
ALTER TABLE public.movimientos DROP CONSTRAINT IF EXISTS movimientos_motivo_check;
ALTER TABLE public.movimientos ADD CONSTRAINT movimientos_motivo_check 
  CHECK (motivo IN ('COMPRA_NUEVA', 'DEVOLUCION_PRESTAMO', 'PRESTAMO', 'PRESTAMO_ALUMNO_PROFESOR', 'BAJA_DESCOMPOSTURA', 'BAJA_PERDIDA', 'INVENTARIO_INICIAL'));

-- 3. Actualizar registros históricos en movimientos de 'PRESTAMO_ALUMNO_PROFESOR' a 'PRESTAMO'
UPDATE public.movimientos 
SET motivo = 'PRESTAMO' 
WHERE motivo = 'PRESTAMO_ALUMNO_PROFESOR';
