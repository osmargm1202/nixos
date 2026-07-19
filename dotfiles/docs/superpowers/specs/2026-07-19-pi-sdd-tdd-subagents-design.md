# Diseño de subagentes globales SDD y TDD para Pi

**Fecha:** 2026-07-19

**Estado:** Corregido para nueva aprobación

**Repositorio:** `/home/osmarg/Hobby/nixos`

**Fuente de dotfiles:** `/home/osmarg/Hobby/nixos/dotfiles`

## 1. Objetivo

Crear un catálogo global de subagentes para Pi que permita delegar planificación, construcción, SDD y TDD mediante `pi-subagents-j0k3r`. Los agentes deben aparecer en `subagent_list_agents` desde cualquier proyecto después de desplegar dotfiles y recargar Pi.

## 2. Situación observada

- `pi-subagents-j0k3r` está instalado globalmente desde `~/.pi/agent/settings.json`.
- `subagent_list_agents` devuelve `No subagents available`.
- Existen agentes heredados en `dotfiles/config/shared/.pi/agent/agents/`, pero:
  - la ruta no está registrada en `nixos/common-dotfiles.nix` bajo `sharedPaths`;
  - las definiciones están anidadas en subdirectorios, mientras la extensión carga archivos Markdown directos;
  - varios prompts usan herramientas y campos de otro orquestador, como `query_team`, `deploy_agent`, `glob` e `inheritProjectContext`;
  - contienen supuestos específicos de ORGM/OpenSpec que no deben heredarse al catálogo general.
- `dotfiles/config/dotfiles.json` no controla el despliegue de rutas compartidas: sus secciones `shared` y `hosts` son legado. El despliegue real usa Home Manager y `mkOutOfStoreSymlink` desde `nixos/common-dotfiles.nix`.

## 3. Alcance

### Incluido

- Crear 14 definiciones globales y planas en `dotfiles/config/shared/.pi/agent/subagents/`.
- Crear configuración global `dotfiles/config/shared/.pi/agent/subagents.json`.
- Registrar `.pi/agent/subagents` y `.pi/agent/subagents.json` en `nixos/common-dotfiles.nix` bajo `sharedPaths`.
- Definir responsabilidades, herramientas, estados y handoffs por fase.
- Configurar aislamiento `lean`, logging desactivado y esfuerzo por rol.
- Validar estructura, configuración, despliegue y descubrimiento después de `/reload`.

### No incluido

- Modificar o eliminar los agentes heredados en `dotfiles/config/shared/.pi/agent/agents/`.
- Modificar las secciones legadas `shared` o `hosts` de `dotfiles/config/dotfiles.json`.
- Implementar una extensión nueva o modificar `pi-subagents-j0k3r`.
- Crear delegación entre subagentes.
- Ocultar o mostrar agentes dinámicamente según la fase.
- Fijar un modelo específico por agente.
- Añadir persistencia de memoria directa a los subagentes.

## 4. Arquitectura

### 4.1 Ubicación y carga

Las definiciones se almacenarán como archivos directos:

```text
dotfiles/config/shared/.pi/agent/subagents/*.md
```

Dotfiles desplegará:

```text
~/.pi/agent/subagents/
~/.pi/agent/subagents.json
```

La extensión cargará las definiciones al iniciar Pi o después de `/reload`. Todos los agentes aparecerán en el listado; la selección por fase dependerá de nombres prefijados, descripciones de activación y el campo `next_recommended` del resultado anterior.

### 4.2 Catálogo

| Agente | Responsabilidad | Puede editar producto |
|---|---|---:|
| `planner` | Explorar requisitos y producir un plan concreto para trabajo general | No |
| `builder` | Ejecutar una tarea general delimitada y verificarla | Sí |
| `sdd-explorer` | Levantar estado actual, restricciones, riesgos y preguntas | No |
| `sdd-spec` | Escribir requisitos normativos y criterios observables | Solo artefacto solicitado |
| `sdd-design` | Definir arquitectura, contratos, datos, errores y pruebas | Solo artefacto solicitado |
| `sdd-plan` | Crear estrategia, mapa de archivos, dependencias y verificaciones | Solo artefacto solicitado |
| `sdd-tasks` | Convertir el plan en tareas pequeñas, ordenadas y verificables | Solo artefacto solicitado |
| `sdd-builder` | Implementar una tarea SDD aprobada con evidencia | Sí |
| `sdd-reviewer` | Revisar cumplimiento de spec y calidad de código | No |
| `sdd-verifier` | Ejecutar gates finales contra criterios aprobados | No |
| `tdd-planner` | Convertir requisitos en ciclos y comandos RED/GREEN | Solo artefacto solicitado |
| `tdd-builder` | Ejecutar el ciclo completo RED→GREEN→REFACTOR | Sí |
| `tdd-reviewer` | Auditar pruebas, evidencia test-first y calidad | No |
| `tdd-verifier` | Ejecutar pruebas y gates finales sin corregir | No |

## 5. Flujos

### 5.1 SDD

```text
sdd-explorer
  → sdd-spec
  → sdd-design
  → sdd-plan
  → sdd-tasks
  → sdd-builder
  → sdd-reviewer
  → sdd-builder, cuando existan hallazgos bloqueantes
  → sdd-reviewer, después de cada corrección
  → sdd-verifier, cuando la revisión quede limpia
```

El orquestador principal debe delegar una tarea de implementación a la vez. No se ejecutarán builders SDD en paralelo sobre el mismo checkout.

### 5.2 TDD

```text
tdd-planner
  → tdd-builder: RED → GREEN → REFACTOR
  → tdd-reviewer
  → tdd-builder, cuando existan hallazgos bloqueantes
  → tdd-reviewer, después de cada corrección
  → tdd-verifier, cuando la revisión quede limpia
```

`tdd-builder` conservará el ciclo completo. No se crearán agentes separados para escribir pruebas o refactorizar porque el handoff rompería continuidad y debilitaría evidencia test-first.

### 5.3 Trabajo general

```text
planner → builder
```

Este flujo se usará cuando el trabajo no justifique ceremonia SDD/TDD. El orquestador principal conserva responsabilidad por revisión y cierre.

## 6. Contrato común de handoff

Cada delegación debe incluir únicamente:

1. objetivo y tarea exacta;
2. ruta del artefacto de entrada;
3. restricciones globales aplicables;
4. directorio de trabajo;
5. ruta de salida o reporte esperada;
6. comandos de validación conocidos.

Cada agente debe devolver:

```text
status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
executive_summary: resultado breve
artifacts: rutas creadas, actualizadas o revisadas
verification: comandos y evidencia disponible
risks: dudas, fallos o desviaciones
next_recommended: siguiente agente o decisión requerida
```

Reglas:

- El agente no debe delegar a otros subagentes.
- `NEEDS_CONTEXT` requiere datos adicionales antes de reintentar.
- `BLOCKED` requiere cambiar contexto, capacidad, alcance o decisión humana.
- `DONE_WITH_CONCERNS` no habilita verificación final hasta resolver dudas de corrección o alcance.
- Reviewer y verifier son read-only y nunca corrigen hallazgos.

## 7. Herramientas y aislamiento

### 7.1 Configuración global

`subagents.json` debe preservar:

```json
{
  "mode": "opencode",
  "timeout_ms": 1200000,
  "stall_timeout_ms": 240000,
  "max_concurrency": 5,
  "debug": false,
  "session_resources": "lean",
  "history_panel_shortcut": "ctrl+,",
  "detail_cancel_shortcut": "x",
  "background_handoff_shortcut": "ctrl+h",
  "model_profiles": {
    "planner": { "effort": "high" },
    "builder": { "effort": "high" },
    "sdd-explorer": { "effort": "medium" },
    "sdd-spec": { "effort": "high" },
    "sdd-design": { "effort": "high" },
    "sdd-plan": { "effort": "high" },
    "sdd-tasks": { "effort": "medium" },
    "sdd-builder": { "effort": "high" },
    "sdd-reviewer": { "effort": "high" },
    "sdd-verifier": { "effort": "medium" },
    "tdd-planner": { "effort": "high" },
    "tdd-builder": { "effort": "high" },
    "tdd-reviewer": { "effort": "high" },
    "tdd-verifier": { "effort": "medium" }
  }
}
```

Los perfiles fijarán solo `effort`; al omitir `model`, cada agente heredará el modelo del orquestador activo.

### 7.2 Esfuerzo por rol

| Esfuerzo | Agentes |
|---|---|
| `medium` | `sdd-explorer`, `sdd-tasks`, `sdd-verifier`, `tdd-verifier` |
| `high` | `planner`, `builder`, `sdd-spec`, `sdd-design`, `sdd-plan`, `sdd-builder`, `sdd-reviewer`, `tdd-planner`, `tdd-builder`, `tdd-reviewer` |

### 7.3 Allowlist por clase

| Clase | Herramientas exactas |
|---|---|
| `planner` | `read`, `grep`, `find`, `ls`, `bash`, `symbol_search`, `module_report`, `read_symbol`, `read_enclosing` |
| `sdd-explorer` | Herramientas de `planner` más `context7_resolve-library-id`, `context7_query-docs` |
| Productores de artefactos: `sdd-spec`, `sdd-design`, `sdd-plan`, `sdd-tasks`, `tdd-planner` | Herramientas de `planner` más `write`, `edit` |
| Builders: `builder`, `sdd-builder`, `tdd-builder` | `read`, `grep`, `find`, `ls`, `bash`, `write`, `edit`, `symbol_search`, `module_report`, `read_symbol`, `read_enclosing`, `lsp_diagnostics`, `lens_diagnostics` |
| Reviewers/verifiers | `read`, `grep`, `find`, `ls`, `bash`, `symbol_search`, `module_report`, `read_symbol`, `read_enclosing`, `lsp_diagnostics`, `lens_diagnostics` |

`bash` será de inspección para planners y productores de artefactos. Reviewers y verifiers podrán ejecutar comandos de lectura y validación, pero no comandos que muten archivos, índice Git o ramas. Los productores de artefactos limitarán `write` y `edit` a la ruta solicitada por el orquestador.

Ninguna allowlist puede incluir `subagent_*`. Los subagentes no recibirán herramientas de memoria; el orquestador entregará contexto y rutas de artefactos de forma explícita.

## 8. Manejo de errores

- Definición inválida: bloquear despliegue hasta corregir frontmatter.
- Herramienta no disponible: agente devuelve `BLOCKED` o usa alternativa permitida sin ampliar alcance.
- Requisito ambiguo: agente devuelve `NEEDS_CONTEXT`; no inventa comportamiento.
- RED incorrecto: `tdd-builder` corrige prueba hasta obtener fallo esperado antes de producción.
- GREEN fallido: corregir producción, no cambiar prueba para acomodar implementación.
- Hallazgo Critical/Important: volver al builder y repetir revisión.
- Gate final fallido: `verifier` reporta comando y salida; no corrige.
- Tarea background que requiere interacción humana: reejecutar en modo `task`.

## 9. Validación y aceptación

### 9.1 Validación estática

- `subagents.json` parsea como JSON.
- Existen exactamente 14 archivos Markdown directos.
- Cada archivo contiene `name`, `description` y `tools` válidos.
- Los nombres son únicos, lowercase y kebab-case.
- Ninguna allowlist contiene herramientas `subagent_*`.
- Reviewers y verifiers no incluyen `write` ni `edit`.
- Builders incluyen herramientas de edición y validación.
- El catálogo no usa campos o herramientas heredadas incompatibles.

### 9.2 Despliegue

Añadir estas entradas a `sharedPaths` en `nixos/common-dotfiles.nix`, junto a las rutas globales existentes de Pi:

```nix
".pi/agent/subagents"
".pi/agent/subagents.json"
```

No modificar `dotfiles/config/dotfiles.json`: sus listas `shared` y `hosts` ya no participan en el despliegue. Como se registrarán rutas nuevas de Home Manager, ejecutar:

```bash
nh os switch
```

El cambio no debe incluir ni sobrescribir modificaciones ajenas ya presentes en el repositorio. Después del switch, `readlink -f ~/.pi/agent/subagents` y `readlink -f ~/.pi/agent/subagents.json` deben resolver dentro de `/home/osmarg/Hobby/nixos/dotfiles/config/shared/`.

### 9.3 Validación en Pi

Después del despliegue:

1. ejecutar `/reload` o reiniciar Pi;
2. ejecutar `subagent_list_agents`;
3. confirmar presencia de los 14 nombres;
4. ejecutar opcionalmente una tarea read-only con `planner`;
5. no ejecutar builders solo para probar descubrimiento.

### 9.4 Criterios de aceptación

El trabajo queda aceptado cuando:

- las 14 definiciones están versionadas y desplegadas;
- `nixos/common-dotfiles.nix` registra las dos rutas nuevas y `dotfiles/config/dotfiles.json` permanece sin cambios por esta iniciativa;
- los symlinks desplegados resuelven hacia `dotfiles/config/shared/.pi/agent/`;
- Pi las lista después de recargar;
- nombres y descripciones permiten seleccionar fase correcta;
- SDD y TDD tienen handoffs explícitos;
- `tdd-builder` conserva ciclo completo RED→GREEN→REFACTOR;
- reviewers/verifiers permanecen read-only;
- modelo se hereda y esfuerzo se aplica por perfil;
- JSON, frontmatter y allowlists pasan validación.

## 10. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Listado muestra todos los agentes y no solo fase actual | Prefijos, descripciones de activación y `next_recommended` explícito |
| Prompts amplios causan scope creep | Una tarea por builder y contratos de salida obligatorios |
| Bash permite mutaciones en roles read-only | Allowlist sin edit/write y prohibición explícita; revisar comandos reportados |
| Herramientas de extensión no están cargadas en sesión anidada | `session_resources: lean` conserva extensiones en modo tools-only; validar nombres disponibles |
| Modelo activo no tiene capacidad suficiente | Agente devuelve `BLOCKED`; orquestador puede reintentar con modelo más capaz |
| Rutas heredadas generan confusión futura | Mantener nuevo catálogo en `subagents/`; migración del legado queda fuera de alcance |
| Cambios ajenos presentes en el monorepo | Stage y commit solo de archivos pertenecientes a esta iniciativa |
| Registro accidental en manifiesto legado | Cambiar únicamente `nixos/common-dotfiles.nix`; mantener `dotfiles/config/dotfiles.json` fuera del diff |

## 11. Próximo paso

Crear un plan de implementación detallado que defina archivos, contenido de cada agente, cambios de manifest, validaciones y secuencia de despliegue sin tocar el legado existente.
