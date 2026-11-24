# Flujo de trabajo con Git

Cada integrante trabaja en **su propia rama** y sube sus avances a `main` mediante un **Pull Request** en GitHub. Así nadie sobrescribe el trabajo de otro y queda un historial de commits ordenado.

| Integrante | Rama | Archivos que edita |
|---|---|---|
| Luis | `luis` | `sql/01`, `sql/02`, `sql/07`, `docs/modelo_logico.md`, DER, `entrega/` |
| Winston | `winston` | `sql/03`, `sql/04`, `sql/06`, `sql/08` |
| Vinicio | `vinicio` | `sql/05`, `sql/09`, documento técnico |

**Regla principal: cada quien edita solo sus archivos.** Si necesitás un cambio en el archivo de otro (por ejemplo, una columna nueva en el DDL), pedíselo al dueño. Así casi no hay conflictos.

## 1. Configuración (una sola vez por computadora)

En PowerShell:

```powershell
git config --global user.name "Tu Nombre"
git config --global user.email "tucorreo@ejemplo.com"
git config --global pull.rebase false
```

Ubicarse en la carpeta donde va a vivir el proyecto y clonar:

```powershell
git clone https://github.com/eledrano/Proyecto-3-Bases-de-Datos.git
cd Proyecto-3-Bases-de-Datos
```

Crear la rama propia y subirla (cambiar `winston` por la rama que corresponda):

```powershell
git checkout -b winston
git push -u origin winston
```

## 2. Cada vez que se va a trabajar

```powershell
git checkout winston         # asegurarse de estar en la rama propia
git pull origin main         # traer lo que los demás ya integraron
```

Trabajar normalmente y, cada vez que se termina algo pequeño:

```powershell
git add .
git commit -m "Descripción corta de lo que se hizo"
git push
```

## 3. Integrar a `main` (Pull Request)

1. En GitHub, entrar a **Pull requests → New pull request**.
2. Elegir **base: `main`** y **compare: `winston`** (la rama propia).
3. Ponerle un título claro (por ejemplo, "RBAC: roles y permisos") y **Create pull request**.
4. Si GitHub no marca conflictos, **Merge pull request**.
5. Avisar en el grupo, para que los demás hagan `git pull origin main`.

Si GitHub marca conflictos, no resolverlos a ciegas: avisar al dueño del archivo.

## 4. Probar los scripts en DBeaver

1. Crear la base `petit_monde` (una sola vez).
2. Abrir los scripts de `sql/` en orden (01 → 09) y ejecutar cada uno completo con **Alt + X**.
3. Para empezar de cero: conectarse a la base `postgres`, ejecutar `DROP DATABASE petit_monde;` y crearla de nuevo. Los roles son globales del servidor, por eso `03_roles_rbac.sql` debe poder correrse varias veces sin error.
