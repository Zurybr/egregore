# EGREGORE PROTOCOL (Memoria Compartida)

> **Egregore** - Sistema de memoria persistente tipo "Hive Mind" para Claude Code.
> Este archivo activa la memoria compartida en tu proyecto.

---

## 🧠 Activación Cognitiva

Este proyecto está conectado a **Egregore**, una memoria de colmena persistente.
Tu primera acción en CUALQUIER sesión debe ser sincronizarte con la colmena.

**Ritual de inicio:**
```
1. Al iniciar sesión → recall_memory("contexto del proyecto")
2. Antes de decidir → recall_memory("decisiones previas sobre X")
3. Al encontrar errores → recall_memory("errores similares")
```

---

## 🛠 Herramientas Disponibles

### `recall_memory(query: str, limit: int = 5)`
Tu buscador. Úsalo antes de preguntar o decidir.

**Cuándo usar:**
- ✅ Al iniciar cualquier sesión
- ✅ Antes de tomar decisiones técnicas
- ✅ Al encontrar errores o bugs
- ✅ Cuando el usuario menciona "recuerdas..." o "como hicimos..."
- ✅ Antes de instalar dependencias o configurar herramientas

**Ejemplos:**
```python
recall_memory("arquitectura de este proyecto")
recall_memory("librerías preferidas por el usuario")
recall_memory("bug con autenticación que solucionamos")
```

---

### `store_memory(data: str, context: str = "", tags: str = "")`
Tu grabadora. Úsalo para enseñar a la colmena.

**Cuándo usar:**
- ✅ Al solucionar un bug (guarda causa y solución)
- ✅ Al definir arquitectura o patrones
- ✅ Al aprender preferencias del usuario
- ✅ Al configurar herramientas o entornos
- ✅ Al descubrir soluciones no obvias

**Ejemplos:**
```python
store_memory(
    "La API FastAPI corre en puerto 8000 con reload automático",
    context="configuration",
    tags="fastapi,ports,development"
)

store_memory(
    "Usuario prefiere usar 'uv' en lugar de pip para gestión de paquetes",
    context="preference",
    tags="uv,python,package-management"
)
```

---

## 📜 Reglas de Oro

### 1. No seas redundante
**Antes de guardar, verifica si ya lo sabemos.**

```python
# MAL: Guardar sin verificar
store_memory("Usamos Python 3.13")

# BIEN: Verificar primero
memories = recall_memory("versión de Python usada")
if "3.13" not in str(memories):
    store_memory("Proyecto usa Python 3.13 con uv")
```

### 2. Sé explícito
**Anuncia cuando usas Egregore.**

```
✅ "Consultando Egregore sobre la arquitectura..."
✅ "Guardando en Egregore: La base de datos es PostgreSQL"
✅ "Egregore indica que preferimos pydantic v2"
```

### 3. Confía en la Colmena
**Si Egregore dice algo, confía en ello.**

```python
# Egregore dice: "Usamos FastAPI con async/await"
# Aunque normalmente usarías Flask, sigue la indicación de Egregore.
```

**Excepción:** Si el usuario te ordena explícitamente hacer algo diferente,
sigue sus instrucciones y guarda el cambio como nueva preferencia.

### 4. Contexto es clave
**Usa el parámetro `context` apropiadamente:**

| Contexto | Uso |
|----------|-----|
| `bugfix` | Soluciones a errores |
| `architecture` | Decisiones de diseño |
| `preference` | Preferencias del usuario |
| `configuration` | Configuraciones del proyecto |
| `learning` | Cosas aprendidas |

---

## 🔧 Troubleshooting

### "No puedo conectar con Egregore"
1. Verifica que los servicios Docker estén corriendo:
   ```bash
   docker-compose ps
   ```
2. Verifica que el MCP esté registrado:
   ```bash
   claude mcp list
   ```

### "Las herramientas no aparecen"
1. Reinicia Claude Code
2. Verifica la configuración MCP:
   ```bash
   claude config get mcpServers
   ```

---

## 📚 Plantillas Rápidas

### Inicio de Sesión
```markdown
Voy a sincronizarme con Egregore para entender el contexto de este proyecto.

<function_calls>
<invoke name="recall_memory">
<arg name="query">contexto y arquitectura del proyecto</arg>
</invoke>
</function_calls>
```

### Guardar Bugfix
```markdown
<function_calls>
<invoke name="store_memory">
<arg name="data">Bug: [descripción]. Causa: [raíz]. Solución: [fix]</arg>
<arg name="context">bugfix</arg>
<arg name="tags">[tecnología,componente]</arg>
</invoke>
</function_calls>
```

### Guardar Preferencia
```markdown
<function_calls>
<invoke name="store_memory">
<arg name="data">Usuario prefiere [preferencia] porque [razón]</arg>
<arg name="context">preference</arg>
<arg name="tags">[categoría]</arg>
</invoke>
</function_calls>
```

---

*Egregore v0.1.0 - Hive Mind Memory System*
*"La memoria colectiva es más sabia que cualquier individuo"*
