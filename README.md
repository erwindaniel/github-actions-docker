# Github Actions Self-hosted Runner (Docker)

Descripción
: Imagen ligera que instala un GitHub Actions runner y herramientas comunes (oc, argocd, helm, s2i, yq). Diseñada para ejecutarse en un servidor privado y conectarse a una organización de GitHub.

Resumen rápido
- Base: Ubuntu 22.04
- Incluye: acciones runner, oc, argocd, helm, s2i, yq, docker CLI
- Recomendado: montar el socket Docker del host para usar el daemon del host (/var/run/docker.sock)
- Entrypoint: `start.sh` (configura y arranca el runner)

Construir la imagen
```bash
cd <path-to-repo>/iguacorp/github-actions-docker
docker build -t iguacorp/runner:latest .
```

Ejecutar (recomendado: usar socket Docker del host)
```bash
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/$(whoami)/actions-runner:/home/docker/actions-runner \
  -e ORGANIZATION=<GITHUB_ORG> \
  -e ACCESS_TOKEN=<ACCESS_TOKEN> \
  -e RUNNER_LABELS="runner-docker,env-low" \
  -e RUNNER_GROUP="<RUNNER_GROUP>" \
  --name github-runner \
  iguacorp/runner:latest
```

Variables de entorno importantes
- ORGANIZATION: nombre de la organización GitHub (ej. my-org)
- ACCESS_TOKEN: Personal Access Token o token con permisos para crear runners en la organización
- RUNNER_LABELS: etiquetas separadas por comas para el runner
- RUNNER_GROUP: grupo de runners dentro de la organización (opcional)

Montajes recomendados
- /var/run/docker.sock:/var/run/docker.sock — permite usar docker del host
- /home/<usuario>/actions-runner:/home/docker/actions-runner — persistir configuración del runner entre reinicios

Notas sobre ACCESS_TOKEN y SAML
- Si la organización tiene SAML SSO habilitado, el PAT debe estar autorizado para la organización (Settings → SAML SSO → autorizar token). Alternativa recomendada: usar un GitHub App con permisos adecuados y generar installation tokens programáticamente.
- El token necesita permisos para administrar runners en la organización (admin actions).

Persistencia y actualizaciones
- Se recomienda persistir la carpeta `/home/docker/actions-runner` fuera del contenedor para mantener la configuración.
- Para actualizar la imagen: reconstruir (`docker build`) y reiniciar el contenedor.

Arrancar/Parar
- Parar: `docker stop github-runner`
- Si el runner quedó registrado en GitHub y no fue removido, elimina la configuración desde la UI de la organización o ejecuta el script de limpieza dentro del contenedor antes de eliminarlo.

Problemas comunes
- `403 SAML enforcement`: autorizar el PAT para la organización o usar GitHub App.
- Permisos Docker: si el socket del host tiene distinto GID, ajustar el GID del grupo `docker` en el contenedor o ejecutar con `--group-add`.
- Comandos faltan: verificar que `start.sh` exista y sea ejecutable en la ruta `/home/docker/start.sh`.

Licencia
: Usa la licencia del repositorio.  

Fin.