# Casos de Uso – App de Biblioteca de Mangas Compartida

## Arquitectura General

La aplicación consta de dos componentes principales:

- **Servidor (Python):** Gestiona la lógica de negocio, almacena los datos de mangas (títulos, cantidad de tomos, tomos adquiridos por cada usuario) y sincroniza el estado entre los distintos dispositivos. No almacena imágenes de portada.
- **App cliente (Flutter):** Interfaz de usuario para dispositivos móviles. Almacena localmente las portadas de los mangas, vinculadas por ID. Se comunica con el servidor para obtener y enviar datos.

Todos los usuarios tienen los mismos permisos (sin roles): pueden agregar, editar, renombrar mangas y marcar tomos adquiridos. La biblioteca es compartida entre varias personas.

---

## CU-01: Dar de Alta un Manga

**Actor(es):** Usuario de la app (cualquiera, sin restricción de roles)

**Precondiciones:**
- El usuario tiene la app instalada y conectada al servidor.
- El manga que desea agregar no existe previamente en el servidor (aunque la validación se hará en el paso correspondiente).

**Descripción:**  
El usuario añade un nuevo manga a la biblioteca compartida proporcionando título, cantidad total de tomos y una portada que se almacenará solo en su dispositivo.

**Flujo principal:**

1. El usuario selecciona la opción "Agregar manga".
2. El sistema muestra un formulario con los campos:
   - Título (texto obligatorio)
   - Cantidad total de tomos (numérico obligatorio, ≥1)
   - Portada (selector de imagen desde galería o cámara, opcional)
3. El usuario completa los campos y presiona "Guardar".
4. La app genera un identificador único temporal y asigna la portada seleccionada (si la hay) al almacenamiento local vinculado a ese ID.
5. La app envía al servidor: `{ título, cantidadTomos }`.
6. El servidor valida que no exista un manga con el mismo título (consulta insensible a mayúsculas/minúsculas y espacios).
   - **6a. Si ya existe**, retorna un mensaje de error con el ID del manga existente.
     1. La app muestra el error: "Ya existe un manga con este título".
     2. Si el usuario lo desea, la portada local se puede reasignar manualmente al manga existente (ver CU-06). Fin del CU.
7. El servidor crea el manga con el título, la cantidad de tomos especificada y una lista de tomos vacía (ningún tomo adquirido inicialmente). Le asigna un ID único (UUID).
8. El servidor retorna a la app: `{ id, título, cantidadTomos, tomosAdquiridos: [] }`.
9. La app actualiza el almacenamiento local: asocia la portada al ID definitivo del manga.
10. La app muestra el nuevo manga en la lista de la biblioteca con la portada local y todos los tomos en estado "no adquirido".
11. **Fin del CU.**

**Flujos alternativos:**
- **Campos incompletos:** Si el título está vacío o la cantidad de tomos es 0 o negativa, la app muestra un mensaje de validación y no permite guardar hasta que se corrijan.
- **Sin conexión al servidor:** La app muestra un mensaje de error indicando que no se puede completar la operación sin conexión.

**Postcondiciones:**
- El manga queda registrado en el servidor con 0 tomos adquiridos.
- La portada queda almacenada localmente en el dispositivo que realizó el alta, vinculada al ID del manga.
- La biblioteca se actualiza para todos los usuarios (los demás verán el manga sin portada o deberán asignar una propia localmente).

---

## CU-02: Consultar Mangas con Filtros

**Actor(es):** Usuario de la app

**Precondiciones:** La app está conectada al servidor y existen mangas en la biblioteca.

**Descripción:**  
El usuario visualiza la lista de mangas disponibles en la biblioteca compartida y puede aplicar filtros para encontrar mangas específicos (por título, por tomos faltantes, etc.).

**Flujo principal:**

1. El usuario accede a la pantalla principal de la biblioteca.
2. La app solicita al servidor la lista completa de mangas.
3. El servidor retorna un arreglo con todos los mangas: `[{ id, título, cantidadTomos, tomosAdquiridos: [1, 2, 5] }, ...]`.
4. La app muestra cada manga en una lista/tarjeta con:
   - Portada (cargada desde almacenamiento local si existe; si no, un placeholder genérico)
   - Título
   - Progreso visual de tomos (ej. "3/12 tomos" o indicador gráfico)
5. El usuario puede activar la barra de filtros/búsqueda.
   - **5a. Filtrar por título:** El usuario escribe texto. La app filtra en tiempo real los mangas cuyo título contenga el texto ingresado (insensible a mayúsculas/minúsculas). Este filtro se aplica del lado del cliente sobre los datos ya obtenidos (o puede ser delegado al servidor si se desea optimizar).
   - **5b. Filtrar por tomos faltantes:** El usuario activa un checkbox/switch "Solo pendientes". La app muestra únicamente mangas donde `tomosAdquiridos.length < cantidadTomos`.
   - **5c. Combinación de filtros:** Ambos filtros pueden aplicarse simultáneamente (AND lógico).
6. La lista se actualiza dinámicamente según los filtros activos.
7. **Fin del CU.**

**Flujos alternativos:**
- **Biblioteca vacía:** Si no hay mangas, se muestra un mensaje: "La biblioteca está vacía. ¡Agrega tu primer manga!"
- **Sin conexión:** Si no hay conexión al servidor, la app muestra un mensaje de error o los últimos datos cacheados (si se implementa caché offline).

**Postcondiciones:** El usuario visualiza la lista filtrada de mangas según sus criterios.

---

## CU-03: Marcar Tomo como Adquirido / Desmarcar

**Actor(es):** Usuario de la app

**Precondiciones:**
- Existe al menos un manga en la biblioteca.
- El manga tiene una cantidad de tomos > 0.

**Descripción:**  
El usuario, desde la vista de detalle de un manga, puede marcar con un solo toque un tomo como adquirido ("ya lo tengo") o desmarcarlo si se equivoca. El cambio se refleja visualmente de inmediato en la app y se sincroniza con el servidor para que los demás usuarios lo vean.

**Flujo principal:**

1. El usuario selecciona un manga de la lista para ver su detalle.
2. La app muestra la información del manga:
   - Portada (local o placeholder)
   - Título
   - Total de tomos (ej. "12 tomos")
   - Representación visual de cada tomo como un elemento interactivo (botones numerados: 1, 2, 3, …, 12) donde:
     - **Tomos adquiridos:** Color resaltado (ej. verde o con un icono de check), indicando que el usuario lo tiene.
     - **Tomos no adquiridos:** Color neutro (ej. gris o borde punteado), indicando que falta.
   - Leyenda clara que distingue ambos estados.
3. El usuario toca un tomo no adquirido (ej. número 7).
4. La app cambia inmediatamente el estado visual del tomo 7 a "adquirido" (animación rápida, cambio de color/icono).
5. La app envía al servidor una petición: `POST /mangas/{id}/tomos/{numeroTomo}/adquirir` con el ID del usuario que lo marcó.
6. El servidor registra que el tomo 7 ha sido adquirido por ese usuario (lo agrega a la lista `tomosAdquiridos` del manga).
7. El servidor retorna confirmación: `{ id, tomo: 7, estado: "adquirido" }`.
8. La app mantiene el estado visual actualizado (ya estaba en adquirido desde el paso 4, no requiere cambio adicional).
9. **Fin del CU.**

**Flujo alternativo – Desmarcar tomo:**
- En el paso 3, si el usuario toca un tomo que ya estaba marcado como adquirido:
  - La app cambia el estado visual a "no adquirido".
  - Envía al servidor: `DELETE /mangas/{id}/tomos/{numeroTomo}/adquirir`.
  - El servidor elimina ese tomo de la lista de adquiridos del manga.
  - Retorna confirmación: `{ id, tomo: 7, estado: "no_adquirido" }`.

**Flujos alternativos – Error:**
- **Error de sincronización:** Si el servidor falla al registrar el cambio (timeout, error de red), la app revierte el cambio visual y muestra un mensaje: "No se pudo sincronizar. Intenta de nuevo."
- **Conflicto por modificación concurrente:** Si otro usuario desmarca el mismo tomo antes de que el servidor procese esta solicitud, el servidor aplica la última operación recibida (última escritura gana). La app reflejará el estado real en la próxima consulta de detalle.

**Postcondiciones:**
- El tomo queda marcado/desmarcado en el servidor.
- Todos los usuarios que consulten ese manga verán el estado actualizado del tomo (los cambios se reflejan en sus apps cuando recarguen o consulten el detalle).

---

## CU-04: Agregar Más Tomos a un Manga Existente

**Actor(es):** Usuario de la app

**Precondiciones:**
- Existe un manga en la biblioteca.
- El manga está en emisión o se necesita actualizar su cantidad de tomos porque salieron nuevos volúmenes.

**Descripción:**  
El usuario incrementa la cantidad total de tomos de un manga (por ejemplo, pasa de 12 a 14 tomos porque salieron dos volúmenes nuevos). Los tomos adicionales aparecerán como "no adquiridos" para todos los usuarios.

**Flujo principal:**

1. El usuario, desde la vista de detalle de un manga, selecciona la opción "Editar manga".
2. La app muestra los campos editables:
   - Título (precargado, modificable)
   - Cantidad actual de tomos (precargado, modificable)
   - Opción para cambiar portada local (opcional)
3. El usuario modifica el campo "Cantidad de tomos" al nuevo valor (ej. de 12 a 14) y presiona "Guardar cambios".
4. La app valida que el nuevo valor sea mayor o igual a la cantidad actual de tomos.
   - **4a. Si el valor es menor:** La app muestra un error: "La cantidad de tomos no puede ser menor a la actual. Si necesitas reducirla, contacta al administrador del servidor." (o se permite si se define así, pero por lógica de emisión, se asume que solo aumenta).
   - **4b. Si el valor es igual:** No hay cambios; se cierra la edición sin modificar nada.
5. La app envía al servidor: `PUT /mangas/{id} { cantidadTomos: 14 }`.
6. El servidor actualiza el campo `cantidadTomos` del manga a 14.
   - Los tomos del 13 y 14 no existen en la lista `tomosAdquiridos` de nadie; se consideran automáticamente "no adquiridos".
7. El servidor retorna el manga actualizado: `{ id, título, cantidadTomos: 14, tomosAdquiridos: [...] }`.
8. La app actualiza la vista de detalle: ahora se muestran 14 tomos, los dos nuevos en estado "no adquirido".
9. **Fin del CU.**

**Postcondiciones:**
- El manga tiene una nueva cantidad total de tomos.
- Los nuevos tomos están disponibles para que cualquier usuario los marque como adquiridos.
- La portada local no se ve afectada.

---

## CU-05: Renombrar un Manga

**Actor(es):** Usuario de la app (cualquiera, incluso si no fue quien lo creó)

**Precondiciones:** Existe un manga en la biblioteca.

**Descripción:**  
El usuario cambia el título de un manga. El cambio se propaga al servidor y todos los demás usuarios verán el nuevo título. La portada local vinculada por ID no se pierde.

**Flujo principal:**

1. El usuario, desde la vista de detalle de un manga, selecciona "Editar manga".
2. La app muestra el formulario de edición con el título actual precargado.
3. El usuario modifica el título y presiona "Guardar cambios".
4. La app valida que el nuevo título no esté vacío.
5. La app envía al servidor: `PUT /mangas/{id} { título: "Nuevo Título" }`.
6. El servidor valida que no exista otro manga con el mismo título (excluyendo el actual por ID).
   - **6a. Si ya existe otro manga con ese título:** El servidor retorna error: "Ya existe un manga con este título". La app muestra el mensaje y el cambio no se aplica.
7. El servidor actualiza el título del manga y retorna el objeto actualizado: `{ id, título: "Nuevo Título", cantidadTomos, tomosAdquiridos }`.
8. La app actualiza la vista de detalle y la lista de biblioteca con el nuevo título.
9. **La portada local se mantiene vinculada porque el ID del manga no cambió**.
10. **Fin del CU.**

**Postcondiciones:**
- El manga tiene un nuevo título en el servidor.
- Todos los usuarios ven el nuevo título al consultar la biblioteca.
- Las portadas locales de cada dispositivo siguen asociadas correctamente.

---

## CU-06: Gestionar Portada Local

**Actor(es):** Usuario de la app

**Precondiciones:** Existe un manga en la biblioteca (con o sin portada local previa).

**Descripción:**  
El usuario puede agregar, cambiar o eliminar la portada de un manga en su dispositivo. Esta operación es completamente local y no afecta al servidor ni a otros usuarios. La portada se vincula al manga mediante su ID único.

**Flujo principal – Agregar/Cambiar portada:**

1. El usuario, desde la vista de detalle de un manga, selecciona la opción "Cambiar portada" (o toca el placeholder/portada actual).
2. La app abre el selector de imágenes (galería o cámara).
3. El usuario selecciona una imagen.
4. La app guarda la imagen en el almacenamiento local del dispositivo, asociada al ID del manga (ej. `portadas/{id_manga}.jpg`).
5. La app actualiza inmediatamente la vista de detalle y la miniatura en la lista de la biblioteca con la nueva portada.
6. **Fin del CU.**

**Flujo alternativo – Eliminar portada:**
- Si el usuario elige "Eliminar portada", la app borra el archivo local asociado al ID del manga y muestra el placeholder genérico.

**Flujo alternativo – Sincronización inicial:**
- Cuando un usuario instala la app en un nuevo dispositivo, la biblioteca se carga desde el servidor con todos los mangas (IDs, títulos, tomos) pero sin portadas. El usuario deberá asignar manualmente las portadas que desee en ese dispositivo (o importarlas desde una copia de seguridad local, si se implementa).

**Postcondiciones:**
- La portada del manga en el dispositivo actual se agrega, actualiza o elimina.
- Ningún otro dispositivo se ve afectado.
- El servidor no tiene conocimiento de esta operación.

---

## CU-07: Eliminar un Manga

**Actor(es):** Usuario de la app (cualquiera, sin restricción de roles)

**Precondiciones:**
- Existe al menos un manga en la biblioteca.
- El usuario se encuentra en la vista de detalle del manga que desea eliminar, o en la lista de biblioteca con una acción de eliminación disponible.

**Descripción:**  
El usuario elimina un manga de la biblioteca compartida. Debido a que esta acción afecta a todos los usuarios y no se puede deshacer fácilmente, el sistema solicita una doble confirmación antes de proceder. La eliminación borra el manga del servidor; las portadas locales en cada dispositivo deberán limpiarse manualmente o mediante una limpieza periódica.

**Flujo principal:**

1. El usuario, desde la vista de detalle de un manga, selecciona la opción "Eliminar manga" (representada con un icono de papelera o botón rojo).
2. El sistema muestra el **primer diálogo de confirmación**:
   - Título: "¿Eliminar manga?"
   - Mensaje: "¿Estás seguro de que deseas eliminar **{título del manga}** de la biblioteca compartida? Esta acción afectará a todos los usuarios."
   - Botones:
     - "Cancelar" (cierra el diálogo, no se realiza ninguna acción).
     - "Sí, quiero eliminarlo" (avanza al paso 3).
3. Si el usuario presiona "Cancelar", el diálogo se cierra y el manga **no se elimina**. Fin del CU.
4. Si el usuario presiona "Sí, quiero eliminarlo", el sistema muestra el **segundo diálogo de confirmación** (más enfático):
   - Título: "⚠️ Confirmación final"
   - Mensaje: "Esta acción **no se puede deshacer**. Se eliminará el manga **{título del manga}** y todo el registro de tomos adquiridos para todos los usuarios. ¿Confirmas?"
   - Botones:
     - "No, conservar manga" (cierra ambos diálogos, no se realiza ninguna acción).
     - "Sí, eliminar definitivamente" (avanza al paso 5).
5. Si el usuario presiona "Sí, eliminar definitivamente", la app envía al servidor: `DELETE /mangas/{id}`.
6. El servidor verifica que el manga existe por ID.
   - **6a. Si el manga no existe (posible eliminación concurrente):** El servidor retorna `404 Not Found`. La app muestra un mensaje: "Este manga ya fue eliminado por otro usuario." y regresa a la lista de biblioteca actualizada.
7. El servidor elimina el manga de la base de datos (título, cantidad de tomos, registros de tomos adquiridos por todos los usuarios). Retorna `200 OK` con confirmación.
8. La app:
   - Muestra un mensaje breve de confirmación: "Manga eliminado correctamente".
   - **Opcionalmente, pregunta si desea eliminar también la portada local:** "¿Deseas eliminar también la portada guardada en este dispositivo?"
     - Si el usuario acepta, se borra el archivo de portada asociado al ID del manga.
     - Si el usuario rechaza o ignora, la portada queda huérfana en el dispositivo (podrá ser limpiada más adelante por una función de mantenimiento).
   - Redirige al usuario a la lista principal de la biblioteca.
9. La lista de biblioteca se actualiza (el manga ya no aparece).
10. **Fin del CU.**

**Flujos alternativos:**
- **Cancelación en el primer diálogo (paso 3):** El manga permanece intacto. Fin del CU sin cambios.
- **Cancelación en el segundo diálogo (paso 4, botón "No, conservar manga"):** Ambos diálogos se cierran. El manga permanece intacto. Fin del CU sin cambios.
- **Error de conexión al eliminar (paso 5):** Si la app no puede comunicarse con el servidor, muestra un mensaje de error: "No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo." El manga **no se elimina**.
- **Eliminación concurrente (paso 6a):** Si otro usuario eliminó el manga antes de que se procesara esta solicitud, la app lo detecta y muestra el mensaje correspondiente. No se aplican cambios locales adicionales.

**Postcondiciones:**
- El manga deja de existir en el servidor.
- Todos los registros de tomos adquiridos asociados a ese manga se eliminan para todos los usuarios.
- En el dispositivo actual, la portada local puede ser eliminada (según elección del usuario) o permanecer huérfana.
- En otros dispositivos, las portadas locales asociadas a ese ID quedarán huérfanas. Se recomienda implementar una rutina de limpieza automática o manual que, al cargar la biblioteca, detecte IDs de mangas que ya no existen en el servidor y ofrezca eliminar sus portadas.

**Nota sobre UX de doble confirmación:**
- El primer diálogo (paso 2) actúa como advertencia inicial y menciona el impacto en todos los usuarios.
- El segundo diálogo (paso 4) es más enfático, usa lenguaje visual de advertencia (⚠️) y frases como "no se puede deshacer" y "definitivamente" para evitar eliminaciones accidentales.
- Ambos diálogos deben tener el botón destructivo en rojo o con estilo diferenciado, y el botón seguro en estilo neutro o primario.

---

## Resumen de Interacciones Cliente ↔ Servidor

| Operación | Método HTTP | Endpoint | Datos enviados | Respuesta |
|-----------|-------------|----------|----------------|-----------|
| Alta de manga | POST | `/mangas` | `{ título, cantidadTomos }` | `{ id, título, cantidadTomos, tomosAdquiridos }` |
| Consultar biblioteca | GET | `/mangas` | — | `[{ id, título, cantidadTomos, tomosAdquiridos }]` |
| Marcar tomo adquirido | POST | `/mangas/{id}/tomos/{num}/adquirir` | `{ usuarioId }` | `{ id, tomo, estado }` |
| Desmarcar tomo | DELETE | `/mangas/{id}/tomos/{num}/adquirir` | — | `{ id, tomo, estado }` |
| Editar manga (título/tomos) | PUT | `/mangas/{id}` | `{ título?, cantidadTomos? }` | `{ id, título, cantidadTomos, tomosAdquiridos }` |
| Eliminar manga | DELETE | `/mangas/{id}` | — | `200 OK` / `404 Not Found` |
| Portada | — | Solo local | — | — |