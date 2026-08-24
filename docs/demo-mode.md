# Modo Demo

AulaRaíz incluye un perfil de demostración aislado para capacitación, capturas, pruebas manuales y recorridos del producto sin utilizar información real de docentes o estudiantes.

## Iniciar el modo Demo

En Windows, inicia el ejecutable con:

```powershell
.\aularaiz.exe --demo
```

El argumento `--demo` abre exclusivamente el perfil de almacenamiento `demo`. La base de producción no se abre para el flujo normal de la aplicación y el bootstrap de restauración de producción no se ejecuta en esta sesión.

Si la base Demo está vacía, AulaRaíz carga automáticamente un conjunto ficticio y determinista con escuela, grupo, 12 estudiantes, asistencia reciente, proyectos NEM, actividades, evaluaciones y ejemplos de seguimiento pedagógico.

## Restablecer la demostración

Para descartar todos los cambios realizados durante una sesión Demo y recuperar los datos ficticios iniciales:

```powershell
.\aularaiz.exe --demo-reset
```

`--demo-reset` implica `--demo`. El borrado está protegido por el perfil de almacenamiento: el seeder rechaza explícitamente cualquier intento de ejecutarse sobre una base marcada como `production`.

## Separación de datos

Los perfiles utilizan nombres de almacenamiento diferentes:

- Producción: `aularaiz-production`
- Demo: `aularaiz-demo`

Los respaldos y restauraciones también conservan el perfil activo en sus metadatos. Una sesión Demo no se presenta como respaldo de producción.

Cerrar AulaRaíz y abrirlo normalmente, sin argumentos, regresa al perfil de producción.

## Identificación visual

Cuando la aplicación está en Demo:

- el título de la ventana termina en `· DEMO`;
- aparece una insignia `DEMO` visible sobre la interfaz;
- los datos de ejemplo usan nombres y contexto ficticios destinados únicamente a demostración.

La señal visual permanece durante toda la sesión para reducir el riesgo de confundir capturas, pruebas o cambios de demostración con datos reales.

## Comportamiento intencional

El modo Demo no es un respaldo ni una copia de la base real. No clona datos de producción, no necesita conectividad y no modifica el perfil de producción. Su finalidad es ofrecer un entorno desechable, reproducible y seguro para explorar AulaRaíz.
