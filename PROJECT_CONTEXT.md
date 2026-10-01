PROJECT_CONTEXT.md
Visión General
OurWorld es un RPG / Action-RPG multijugador desarrollado para Roblox Studio. El juego cuenta con una arquitectura modular basada en Knit y sincronizada vía Rojo. Permite a los jugadores gestionar múltiples personajes (sistema multiranura de hasta 4 slots por jugador con persistencia mediante ProfileService), elegir entre varias clases (Guerrero con subtipos de Espada o Arco, Mago y Gigante), equipar herramientas e ítems en un inventario/hotbar personalizado con UI temática de fantasía oscura/oro, participar en combates en tiempo real contra enemigos inteligentes con IA avanzada (visión en línea de vista, combate táctico y curación), y realizar misiones entregadas por NPCs interactivos.

Arquitectura y Flujo
Estructura del Proyecto
El proyecto está estructurado siguiendo las convenciones de Rojo (default.project.json) y Wally:
Server (src/server/) $\rightarrow$ ServerScriptService.ServerCore (src/server/Core/): Módulos centrales como PlayerDataManager y el vendor local ProfileService.
Systems (src/server/Systems/): Servicios del servidor (ClassService, CombatService, InventoryService, EnemyService, EnemyAIService, QuestService).
Entrypoint & Testing: Runtime.server.luau (arranca Knit y requiere módulos dinámicamente) y SystemTester.server.luau (suite de pruebas automatizadas post-Knit).
Client (src/client/) $\rightarrow$ StarterPlayer.StarterPlayerScripts.Client
Systems (src/client/Systems/): Controladores Knit (ClassController, ClassAppearanceController, CombatController, InventoryController, QuestController, QuestNPCManager, MenuController).
UI (src/client/UI/): Framework (UITheme.luau, UIDragService.luau, ClassViewportService.luau) y Vistas (ClassSelectionView, HotbarView, InventoryView, QuestDialogView, QuestTrackerView, MenuView).
Shared (src/shared/) $\rightarrow$ ReplicatedStorage.SharedConfig (src/shared/Config/): Configuraciones globales.
Systems (src/shared/Systems/): Datos y definiciones compartidas (ClassData, PersonalityData, ItemData, QuestData, QuestTypes, Quests/Zone1_Beginner, EnemyAIData).

Librerías Utilizadas (wally.toml / wally.lock / Vendor)
Knit (sleitnick/knit@1.7.0): Framework de arquitectura Cliente-Servidor.
Signal (sleitnick/signal@2.0.3): Gestión de eventos y señales personalizadas.
ProfileService (loleris/profile-service): Persistencia de datos. Nota: Aunque se declara en wally.toml y wally.lock, la implementación real en código consume la copia vendor local ubicada en src/server/Core/ProfileService.luau.
Promise (evaera/promise@4.0.0): Gestión de operaciones asíncronas utilizada internamente por Knit y llamadas a servicios.

Flujo de Comunicación
Inicialización: Runtime.server.luau y Runtime.client.luau cargan automáticamente todos los módulos que terminen en Service, Manager o Controller, y llaman a Knit.Start().
Carga de Datos de Jugador: Al unirse un jugador, PlayerDataManager carga su perfil mediante ProfileService (WhishGo_MultiSlot_v6) que almacena hasta 4 slots de personajes.
Flujo de Selección de Personaje: El cliente abre ClassSelectionView (bloqueando el movimiento mediante ContextActionService). Al seleccionar o crear personaje, ClassService activa la ranura, equipa el arma inicial y ClassAppearanceService aplica la apariencia visual.
Sistema de Combate e IA de Enemigos:
Jugador $\rightarrow$ Enemigo: CombatController dispara CombatService.AttackRequested. El servidor valida cooldowns, genera hitboxes en 3D (GetPartBoundsInBox), aplica daño y notifica a EnemyAIService y QuestService.
Enemigo $\rightarrow$ Jugador (IA Inteligente): EnemyAIService evalúa con ticks optimizados por distancia la Visión en Línea de Vista (LoS mediante Cono de Visión de ángulo/distancia y Raycasting). Si el jugador está dentro del ángulo y no hay obstáculos/muros intermediando, pasa a estado Combat. De lo contrario, permite sigilo por la espalda o cobertura tras muros. En combate, la FSM ejecuta ataques, curación táctica si la salud cae del umbral y preparación para parry/defensa.
Sistema de UI Arrastrable: UIDragService.luau permite envolver cualquier ventana o Header de la interfaz para posibilitar arrastre táctil/ratón en tiempo real con límites de pantalla y posicionamiento dinámico personalizable.
Sistema de Inventario: InventoryService gestiona datos de la Hotbar (slots 1-5) y Mochila (slots 6-29). Notifica cambios al cliente mediante la señal InventoryUpdated. El cliente desactiva la mochila nativa de Roblox (CoreGuiType.Backpack) y renderiza sus propias vistas personalizadas.
Misiones y NPCs: QuestNPCManager en el cliente añade ProximityPrompt a los NPCs en Workspace.NPCs. Al interactuar, abre QuestDialogView. Al derrotar enemigos, EnemyService notifica a QuestService para avanzar los objetivos de misiones activas.
Menú de Acceso Rápido y Desconexión: MenuView y MenuController gestionan la UI del botón hamburguesa desplegable (con accesos directos a Mochila, Misiones y Salir) e integran un modal de confirmación con autodesconexión/relogueo al flujo de selección de personaje.

Índice de Módulos
Servidor (src/server/)
Runtime.server.luau: Punto de entrada del servidor. Carga recursivamente los servicios/managers de Core/ y Systems/ e inicia Knit.
SystemTester.server.luau: Suite de pruebas integradas post-Knit para verificar servicios, datos, combate, sistemas de IA/Npc y componentes del sistema.
Core/PlayerDataManager.luau: Servicio central de datos multiranura utilizando ProfileService. Gestiona perfiles, creación/selección de slots e inventarios.
Core/ProfileService.luau: Módulo vendor local de ProfileService para la persistencia en DataStores.
Systems/Classes/ClassService.luau: Servicio Knit que expone métodos de cliente para obtener slots, seleccionar y crear personajes.
Systems/Classes/ClassAppearanceService.luau: Aplica color, ropa y accesorios visuales al personaje en Workspace según la clase elegida.
Systems/Combat/CombatService.luau: Valida cooldowns, genera hitboxes en 3D, aplica daño a humanoides y marca el atacante con la etiqueta creator.
Systems/Inventory/InventoryService.luau: Gestiona el almacenamiento de ítems, movimiento entre Hotbar/Mochila y la creación de Tool físicas en Backpack.
Systems/Npc/EnemyService.luau: Escanea Workspace.NPCs, registra enemigos, detecta su muerte, notifica bajas a QuestService y maneja su respawn desde ServerStorage.
Systems/Npc/EnemyAIService.luau: Servicio central de IA táctica. Gestiona la FSM (Idle, Patrol, Alert, Combat, Heal), cálculo de línea de vista (Raycasting + Conos de visión por raza/clase), toma de decisiones (ataque/curación/parry) y abstracción modular de animaciones con logs de depuración detallados.

Cliente (src/client/)
Runtime.client.luau: Punto de entrada del cliente. Carga controladores de src/client/Systems/ e inicia Knit.
Systems/Classes/ClassController.luau: Controla el flujo de selección de personaje, congelamiento del jugador y precarga de assets (ContentProvider).
Systems/Classes/ClassAppearanceController.luau: Proporciona previsualizaciones de animaciones/personalidad para modelos/viewports de UI.
Systems/Combat/CombatController.luau: Escucha entradas del ratón/pantalla táctil y solicita ataques al servidor enviando el arma equipada.
Systems/Inventory/InventoryController.luau: Desactiva el inventario por defecto de Roblox, procesa atajos de teclado (E, B, I, 1..5), gestiona Drag & Drop y sincroniza la UI con el servidor.
Systems/Menu/MenuController.luau: [NUEVO] Controlador Knit que gestiona el menú de accesos rápidos (Mochila, Misiones, Salir) y la reconexión al flujo de selección de personaje.
Systems/Quest/QuestController.luau: Controla la interfaz de misiones (Tecla M), diálogos con NPCs y reclamo de recompensas.
Systems/Quest/QuestNPCManager.luau: Vincula automáticamente ProximityPrompt a modelos de NPCs detectados por tag (QuestNPC), nombre o carpeta.
UI/Framework/UITheme.luau: Sistema de diseño visual (colores de fantasía oscura/oro, degradados, bordes ornamentados y creadores de UI).
UI/Framework/Components/UIDragService.luau: Servicio de interacción cliente que otorga comportamiento arrastrable (Drag & Drop) a cualquier Frame o Header de la interfaz de usuario con contención de pantalla.
UI/Framework/Components/ClassViewportService.luau: Renderiza personajes 3D en ViewportFrame con rotación automática para la UI de selección.
UI/Views/ClassSelectionView.luau: Vista de la interfaz de selección y creación de personajes (multiranura).
UI/Views/HotbarView.luau: Vista de la barra de acceso rápido (Slots 1 a 5).
UI/Views/InventoryView.luau: Vista de la mochila principal de 24 casillas.
UI/Views/MenuView.luau: [NUEVO] Vista de la interfaz del menú desplegable de accesos rápidos (hamburguesa) y ventana modal de confirmación para cerrar sesión/volver al menú principal.
UI/Views/QuestDialogView.luau: Vista para diálogos de aceptación y entrega de misiones con NPCs.
UI/Views/QuestTrackerView.luau: Vista desplegable para el seguimiento de misiones activas en pantalla.

Compartido (src/shared/)
Systems/Classes/ClassData.luau: Definición de clases (Guerrero, Mago, Gigante), descripciones y armas iniciales.
Systems/Classes/PersonalityData.luau: Definición de personalidades de animación (Heroico, Sigiloso, Arrogante, Frenético, etc.).
Systems/Inventory/ItemData.luau: Base de datos de ítems (Espada, Arco, Báculo, Mazo) con daño, tamaño de hitbox y cooldowns.
Systems/Npc/EnemyAIData.luau: Configuración estática de razas/clases enemigas (ángulos de visión, distancias de detección LoS, rangos de ataque, umbrales de curación y probabilidades de parry).
Systems/Quest/QuestTypes.luau: Definición de tipos Luau para Objetivos, Recompensas y Misiones.
QuestData.luau: Carga dinámicamente los módulos de misiones ubicados en Quests/.
Quests/Zone1_Beginner.luau: Definición de misiones iniciales de la Zona 1 (Ej: "El Despertar", "Limpieza de Plagas").

Estrategia de Optimizaciones Integradas
Línea de Vista (LoS) & Visión 3D:
RaycastParams reutilizables: Evita instanciar objetos RaycastParams dentro de bucles.
Conos de Ángulo de Visión Vectorial: Vector3:Dot() para validar el ángulo frontal del enemigo antes de realizar Raycasting físico costoso.
Escaneo de Ticks Dinámico (Throttling):
En Combate / Cerca (< 30 studs): Frecuencia de actualización de 0.1 a 0.15s.
En Patrulla / Distancia Media (< 100 studs): Frecuencia de actualización de 0.5s.
Inactivo / Sin Jugadores Cerca (> 100 studs): Frecuencia suspendida o reducida a 2.0s para evitar el impacto de rendimiento en el servidor ($O(N)$ escalable).
Abstracción de Animaciones:
La lógica de IA utiliza wrappers de animación seguros. Si no existe una animación cargada o un AnimationId, ejecuta las acciones de combate y curación numéricamente sin interrumpir el flujo.

Estrategia de Tests / Calidad
El proyecto contiene un test runner automático integrado en el servidor:
Ubicación: src/server/SystemTester.server.luau
Ejecución: Se inicia automáticamente al arrancar el servidor a través del evento Knit.OnStart() con un retardo de 2 segundos (task.wait(2)).
Pruebas Incluidas:
ClassService & API de Cliente: Valida que ClassService esté registrado en Knit y exponga métodos a la tabla .Client.
Inventory - Mapeo Estricto de Datos: Test defensivo contra cargas de inventario.
CombatService - Integridad: Confirma la carga del servicio de combate.
QuestService & Interacción NPC: Verifica la existencia del servicio de misiones y la carpeta Workspace.NPCs.
EnemyService & EnemyAIService: Valida la carga del registro de enemigos y la presencia del gestor de IA táctica (visión LoS y FSM).
Sistema de Menú de Acceso Rápido (MenuView / MenuController): Valida la existencia y carga en el árbol de módulos del cliente.

---

## Historial de Cambios Relevantes

* **[2026-10-01] Integración del Menú de Acceso Rápido y Desconexión**:
  * Adición de `MenuView.luau` (desplegable con layout vertical ajustado por `AutomaticSize.XY`, sin contenedores sobrantes y modal con timer).
  * Adición de `MenuController.luau` (controlador Knit que conecta las opciones con `InventoryController`, `QuestController` y `ClassController`).
  * Actualización de `PROJECT_CONTEXT.md` y suite de pruebas en `SystemTester.server.luau`.

[2026-09-30] Diseño e Integración de Sistemas de IA Táctica de Enemigos y UI Arrastrable:

Actualización de PROJECT_CONTEXT.md para incluir el diseño modular de EnemyAIService, EnemyAIData y UIDragService.

Puntos Clave del Diseño:

Visión LoS y Sigilo: Detección por ángulo frontal y comprobación de paredes mediante Raycast, permitiendo ataques por la espalda y cobertura física.

Combate Inteligente y Curación: Toma de decisiones dinámicas (atacar, curar cuando baja la salud, parry).

FSM y Animaciones Modulares: Estructura desacoplada de animaciones con fallbacks defensivos.

UI Arrastrable: Framework de arrastre genérico con soporte para mouse y pantallas táctiles.

* **[2026-09-29] Auditoría Inicial y Creación de Contexto**:
  * Creación del archivo `PROJECT_CONTEXT.md` tras análisis completo del código fuente del proyecto.
  * **Hallazgos Arquitectónicos Críticos Identificados**:
    1. *Discrepancia en ProfileService*: El proyecto incluye `ProfileService.luau` en `src/server/Core/`, ignorando el paquete Wally instalado en `ServerPackages`.
    2. *Inconsistencia de Personalidad / Animaciones*: `ClassService.luau` intenta invocar `ApplyPersonalityAnimations` en `ClassAppearanceService`, pero dicha función no existe en el servidor. `PlayerDataManager` tampoco guarda `personalityKey` en los datos de la ranura.
    3. *Dependencia de Jerarquía en Workspace*: `EnemyService` y `QuestNPCManager` requieren carpetas y atributos específicos en `Workspace` (`Workspace.NPCs`, `Workspace.NPCs.Zone1`, etiquetas `QuestNPC`, atributos `EnemyId`/`NPCId`) para funcionar correctamente.

## Promt Rules:

**Rol:** Dev experto en Roblox Studio, Luau y arquitectura Rojo/Knit (10 años exp).

**Reglas de Operación y Eficiencia (Ahorro de Tokens y Cero Colapsos):**

3. **Ejecución Incremental (Paso a Paso):** Si la solicitud involucra modificar varios archivos o realizar múltiples tareas, **procesa UN SOLO archivo a la vez**. Aplica el cambio en el primer archivo y espera antes de pasar al siguiente. NUNCA intentes modificar o generar múltiples archivos en la misma respuesta para evitar la truncación del JSON.
4. **Edición Mínima:** Trabaja solo sobre la función o bloque que requiere cambios. Respeta todas las líneas que ya funcionan y NO las reescribas.
5. **Respuestas Precisas:** Devuelve ÚNICAMENTE la función o bloque modificado. NUNCA entregues un archivo completo a menos que te lo pida explícitamente.
6. **Mantenimiento de `PROJECT_CONTEXT.md`:** Actualiza este archivo SOLO si la tarea agrega nuevos módulos, altera la arquitectura o cambia el flujo global. Si es una corrección menor de código, NO lo edites.
7. **Cero Invención:** No asumas ni inventes funciones, tipos o servicios. Cíñete a las interfaces e instancias reales del proyecto.
8. **Contexto del chat:** El contexto del chat es el contexto actual del proyecto de OurWorld.

Tarea Actual:
