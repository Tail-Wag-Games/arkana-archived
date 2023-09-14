import flecs,
       mesh

export 
  flecs

var w: ptr World

proc init*(): ptr World =
  w = initWorld()

  load(w, FlecsComponentsTransform)
  load(w, FlecsComponentsGraphics)
  load(w, FlecsComponentsGeometry)
  load(w, FlecsComponentsGui)
  load(w, FlecsComponentsPhysics)
  load(w, FlecsComponentsInput)
  load(w, FlecsSystemsTransform)
  load(w, FlecsSystemsPhysics)
  load(w, FlecsGame)
  load(w, FlecsSystemsSokol)
  # load(w, MeshSystems)

  setSingleton(w, EcsInput, EcsInput())

  # setTargetFps(w, 60.0'f32)

  result = w