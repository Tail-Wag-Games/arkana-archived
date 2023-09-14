import std/[macros, os, strformat, tables],
       cglm, sokol/log as slog, sokol/app as sapp, sokol/gfx as sg, sokol/fetch as sf,
           sokol/glue as sglue, sokol/shape as sshape, sokol/time as stime,
               nbnet,
           cfg, ecs, mat4, ozz, vec3, msg, net, shd_shapes

const
  tickDt = 1.0'f64 / 60.0'f64

type
  Shape = object
    pos: vec3.Vec3
    scale: vec3.Vec3
    draw: sshape.ElementRange

var
  deltaTick: uint64
  lastTick: uint64
  frameTime: float64
  accumulator: float64
  localClientState: ClientState

  world: ptr World

  localPlayerId: string

  ozzInst: ptr ozz.Instance

  skinningTime: float64

  skeletonIoBuffer: array[32 * 1024, uint8]
  animationIoBuffer: array[96 * 1024, uint8]
  meshIoBuffer: array[3 * 1024 * 1024, uint8]
  vBuf: sg.Buffer
  iBuf: sg.Buffer
  jointTex: sg.Image
  jointSmp: sg.Sampler

  verts: ptr UncheckedArray[ozz.Vertex]
  vertexCount: uint

  indices: ptr UncheckedArray[uint16]
  indexCount: uint

proc jointTexture*(): sg.Image {.exportc: "joint_texture", cdecl.} =
  result = jointTex
proc jointSampler*(): sg.Sampler {.exportc: "joint_sampler", cdecl.} =
  result = jointSmp

proc jointPixelWidth*(): float32 {.exportc: "joint_pixel_width", cdecl.} =
  result = ozz.joinTexturePixelWidth()

proc jointTextureU*(): float32 {.exportc: "joint_texture_u", cdecl.} =
  result = ozz.jointTextureU(ozzInst)

proc jointTextureV*(): float32 {.exportc: "joint_texture_v", cdecl.} =
  result = ozz.jointTextureV(ozzInst)

proc input(ev: ptr sapp.Event; userData: pointer) {.cdecl.} =
  block early:
    if not isSpawned():
      break early

    let
      world = cast[ptr World](userData)
      localPlayer = lookup(world, localPlayerId)

    if localPlayer != 0:
      let pos = cast[ptr EcsPosition3](getMutId(world, localPlayer,
          FLECS_EEcsPosition3))

      if ev.type == eventTypeKeyDown:
        case ev.keyCode:
        of keyCodeW:
          pos.z = pos.z + 1
        of keyCodeS:
          pos.z = pos.z - 1
        of keyCodeA:
          pos.x = pos.x - 1
        of keyCodeD:
          pos.x = pos.x + 1
        else: break early

        modified(world, localPlayer, EcsPosition3)

      if sendPositionUpdate(pos.x.int32, pos.y.int32, pos.z.int32) < 0:
        echo "failed sending position update!"
        break early

proc updateNet(dt: float64) =
  block early:
    addGameClientTime(dt)

    var ev = pollGameClient()
    while ev != evNone:
      if ev < 0:
        logWarning("client network event polling error", VarArgList())
        break

      handleGameClientEvent(ev)
      ev = pollGameClient()

    if not isDisconnected():
      if sendGameClientPackets() < 0:
        echo "error occurred while flushing client send queue"
        break early

proc tick(world: ptr World; dt: float64) =
  block early:
    discard

proc render(world: ptr World; dt: float64) =
  ecs.run(world, FLECS_ESokolInitMaterials, dt, nil)
  ecs.run(world, FLECS_ESokolRegisterMaterial, dt, nil)
  ecs.run(world, FLECS_ESokolPopulateGeometry, dt, nil)
  ecs.run(world, FLECS_ESokolRender, dt, nil)
  ecs.run(world, FLECS_ESokolCommit, dt, nil)

proc frame(userData: pointer) {.cdecl.} =
  block early:
    sf.doWork()
    when defined(server):
      net.updateServer(tickDt)

    let world = cast[ptr World](userData)

    deltaTick = laptime(addr(lastTick))
    frameTime = sec(deltaTick)
    if frameTime > 0.25'f32:
      frameTime = 0.25'f32

    accumulator += frameTime
    while accumulator >= tickDt:
      if isGameClientStarted():
        updateNet(frameTime)
      tick(world, tickDt)
      accumulator -= tickDt

    skinningTime += frameTime
    ozz.updateInstance(ozzInst, skinningTime)
    ozz.updateJointTexture()

    var imgData: ImageData
    imgData.subimage[0][0].`addr` = ozz.jointUploadBuffer()
    imgData.subimage[0][0].size = ozz.jointTexturePitch() * ozz.jointTextureHeight() * sizeof(float32)
    sg.updateImage(jointTex, imgData)
    
    ecs.progress(world, frameTime)

    render(world, frameTime)

proc initUi(w: ptr World) =
  var cameraData: EcsCamera
  cameraData.up = [0.0'f32, 1.0'f32, 0.0'f32]
  cameraData.fov = 20.0'f32
  cameraData.near = 0.1'f32
  cameraData.far = 255.0'f32
  let camera: Entity = set(w, 0, FLECS_EEcsCamera, EcsCamera, cameraData)
  set(w, camera, FLECS_EEcsPosition3, EcsPosition3, EcsPosition3(x: 0.0'f32,
      y: 50.0'f32, z: -100.0'f32))
  set(w, camera, FLECS_EEcsRotation3, EcsRotation3, EcsRotation3(x: -0.5'f32))
  add(w, camera, EcsCameraController)

  var lightData: EcsDirectionalLight
  lightData.direction = [0.3'f32, -1.0'f32, 0.5'f32]
  lightData.color = [0.98'f32, 0.95'f32, 0.8'f32]
  lightData.intensity = 1.0'f32
  let directionalLight = setEntityname(w, 0, "Sun")
  set(w, directionalLight, FLECS_EEcsDirectionalLight, EcsDirectionalLight, lightData)

  var canvasData: EcsCanvas
  canvasData.width = 640
  canvasData.height = 480
  canvasData.title = "Foo"
  canvasData.directionalLight = directionalLight
  canvasData.camera = camera
  canvasData.ambientLight = EcsRgb(r: 0.06'f32, g: 0.05'f32, b: 0.18'f32)
  canvasData.backgroundColor = EcsRgb(r: 0.15'f32, g: 0.4'f32, b: 0.6'f32)
  canvasData.fogDensity = 0.5'f32
  set(w, 0, FLECS_EEcsCanvas, EcsCanvas, canvasData)

proc populateMesh(transforms: ptr cglm.Mat4; data: pointer; count: int32; self: bool) {.cdecl.} =
  echo "populating mesh!!!!"

proc createVBufCb(p: ptr UncheckedArray[ozz.Vertex]; numVerts: uint) {.cdecl.} =
  verts = p
  vertexCount = numVerts

proc createIBufCb(p: ptr UncheckedArray[uint16]; numIndices: uint) {.cdecl.} =
  indices = p
  indexCount = numIndices

  # ecs.run(world, FLECS_ESokolInitRenderer, 0, nil)

  var vbDesc: sg.BufferDesc
  vbDesc.`type` = bufferTypeVertexBuffer
  vbDesc.data.`addr` = verts
  vbDesc.data.size = int(vertexCount) * sizeof(ozz.Vertex)

  var ibDesc: sg.BufferDesc
  ibDesc.`type` = bufferTypeIndexBuffer
  ibDesc.data.`addr` = indices
  ibDesc.data.size = int(indexCount) * sizeof(uint16)

  vBuf = sg.makeBuffer(vbDesc)
  iBuf = sg.makeBuffer(ibDesc)

proc meshVertices*(): sg.Buffer {.exportc: "mesh_vertices", cdecl.} =
  result = vBuf

proc meshIndices*(): sg.Buffer {.exportc: "mesh_indices", cdecl.} =
  result = iBuf

proc meshIndexCount*(): int32 {.exportc: "mesh_index_count", cdecl.} =
  echo "mesh index count: ", indexCount
  int32(indexCount)

proc initApp(userData: pointer) {.cdecl.} =
  block early:
    let world = cast[ptr World](userData)

    var ctx = sglue.context()
    ctx.depthFormat = int32(pixelFormatNone)
    sg.setup(sg.Desc(
      context: ctx,
      bufferPoolSize: 16384,
      logger: sg.Logger(fn: slog.fn),
    ))

    sf.setup(
      sf.Desc(
        maxRequests: 3,
        numChannels: 1,
        numLanes: 3,
        logger: sf.Logger(fn: slog.fn),
      )
    )

    var ozzCtxDesc: ozz.Desc
    ozzCtxDesc.maxInstances = 1
    ozzCtxDesc.maxPaletteJoints = 64
    ozz.setup(addr(ozzCtxDesc))

    var imgDesc: sg.ImageDesc
    imgDesc.width = jointTextureWidth()
    imgDesc.height = jointTextureHeight()
    imgDesc.numMipmaps = 1
    imgDesc.pixelFormat = pixelFormatRGBA32F
    imgDesc.usage = usageStream
    
    var smpDesc: sg.SamplerDesc
    smpDesc.minFilter = filterNearest
    smpDesc.magFilter = filterNearest
    smpDesc.wrapU = wrapClampToEdge
    smpDesc.wrapV = wrapClampToEdge

    jointTex = makeImage(imgDesc)
    jointSmp = makeSampler(smpDesc)

    ozzInst = ozz.createInstance(0)

    let
      skel = open("./etc/assets/skeletons/skeleton.ozz", FileMode.fmRead)
      skelSize = getFileSize("./etc/assets/skeletons/skeleton.ozz")
      skelBytesRead = readBuffer(skel, addr(skeletonIoBuffer[0]), skelSize)

      anim = open("./etc/assets/animations/animation.ozz", FileMode.fmRead)
      animSize = getFileSize("./etc/assets/animations/animation.ozz")
      animBytesRead = readBuffer(anim, addr(animationIoBuffer[0]), animSize)

      mesh = open("./etc/assets/meshes/mesh.ozz", FileMode.fmRead)
      meshSize = getFileSize("./etc/assets/meshes/mesh.ozz")
      meshBytesRead = readBuffer(mesh, addr(meshIoBuffer[0]), meshSize)

    ozz.loadSkeleton(ozzInst, addr(skeletonIoBuffer[0]), uint(skelBytesRead))
    ozz.loadAnimation(ozzInst, addr(animationIoBuffer[0]), uint(animBytesRead))
    ozz.loadMesh(ozzInst, addr(meshIoBuffer[0]), uint(meshBytesRead),
        createVBufCb, createIBufCb)

    initUi(world)

    let ground = newId(world)
    set(world, ground, FLECS_EEcsPosition3, EcsPosition3, EcsPosition3(
        x: 0.0'f32, y: 0.0'f32, z: 0.0'f32))
    set(world, ground, FLECS_EEcsBox, EcsBox, EcsBox(width: 100.0'f32,
        height: 1.0'f32, depth: 100.0'f32))
    set(world, ground, FLECS_EEcsRgb, EcsRgb, EcsRgb(r: 0.13725490196078433,
        g: 0.5647058823529412, b: 0.38823529411764707))
    
    var skinData: SokolSkin
    # skinData.xxxx[0] = 1.0'f32
    # skinData.yyyy[0] = 0.0'f32
    # skinData.zzzz[0] = 0.0'f32
    # skinData.xxxx[1] = 0.0'f32
    # skinData.yyyy[1] = 1.0'f32
    # skinData.zzzz[1] = 0.0'f32
    # skinData.yyyy[2] = 0.0'f32
    # skinData.yyyy[2] = 0.0'f32
    # skinData.yyyy[2] = 1.0'f32
    # skinData.xxxx[3] = 0.0'f32
    # skinData.yyyy[3] = 0.0'f32
    # skinData.zzzz[3] = 0.0'f32

    skinData.jointUv[0] = 0.5'f32 / ozz.jointTextureWidth().float32
    skinData.jointUv[1] = 0.5'f32 / ozz.jointTextureHeight().float32
    set(world, ground, FLECS_ESokolSkin, SokolSkin, skinData)

proc cleanup() {.cdecl.} =
  if not isDisconnected():
    disconnectGameClient()

  stopGameClient()

  sg.shutdown()

proc localClientSpawned(id: string; x, y, z: int32) =
  localPlayerId = &"player:{id}"

  echo &"spawning local player at {x}, {y}, {z}"

  let p = setEntityName(world, 0, localPlayerId)
  set(world, p, FLECS_EEcsPosition3, EcsPosition3, EcsPosition3(x: 0.0'f32,
      y: 0.0'f32, z: 0.0'f32))
  # set(world, p, FLECS_EEcsRotation3, EcsRotation3, EcsRotation3(x: 1.0'f32))
  set(world, p, FLECS_EEcsMesh, EcsMesh, EcsMesh())
  set(world, p, FLECS_EEcsRgb, EcsRgb, EcsRgb(r: 0.9764705882352941,
      g: 0.7607843137254902, b: 0.16862745098039217))
  
  var skinData: SokolSkin
  # skinData.xxxx[0] = 1.0'f32
  # skinData.yyyy[0] = 0.0'f32
  # skinData.zzzz[0] = 0.0'f32
  # skinData.xxxx[1] = 0.0'f32
  # skinData.yyyy[1] = 1.0'f32
  # skinData.zzzz[1] = 0.0'f32
  # skinData.yyyy[2] = 0.0'f32
  # skinData.yyyy[2] = 0.0'f32
  # skinData.yyyy[2] = 1.0'f32
  # skinData.xxxx[3] = 0.0'f32
  # skinData.yyyy[3] = 0.0'f32
  # skinData.zzzz[3] = 0.0'f32

  skinData.jointUv[0] = 0.5'f32 / ozz.jointTextureWidth().float32
  skinData.jointUv[1] = 0.5'f32 / ozz.jointTextureHeight().float32
  set(world, p, FLECS_ESokolSkin, SokolSkin, skinData)

proc remoteClientSpawned(id: string; x, y, z: int32) =
  echo "spawning remote player with id: ", id, &"at {x}, {y}, {z}"
  let p = setEntityName(world, 0, &"remotePlayer:{id}")
  set(world, p, FLECS_EEcsPosition3, EcsPosition3, EcsPosition3(x: 50 -
      x.float32, y: y.float32, z: 50 - z.float32))
  set(world, p, FLECS_EEcsBox, EcsBox, EcsBox(width: 2.5'f32, height: 2.5'f32,
      depth: 2.5'f32))
  set(world, p, FLECS_EEcsRgb, EcsRgb, EcsRgb(r: 0.9764705882352941,
      g: 0.7607843137254902, b: 0.16862745098039217))

proc remoteClientUpdated(id: string; x, y, z: int32) =
  let remotePlayer = lookup(world, &"remotePlayer:{id}")

  if remotePlayer != 0:
    echo "upating remote player with id: ", id, &"to {x}, {y}, {z}"
    let pos = cast[ptr EcsPosition3](getMutId(world, remotePlayer,
        FLECS_EEcsPosition3))
    pos.x = x.float32
    pos.y = y.float32
    pos.z = z.float32

    modified(world, remotePlayer, EcsPosition3)

when isMainModule:
  stime.setup()

  net.init(localClientSpawned, remoteClientSpawned, remoteClientUpdated)

  world = ecs.init()

  ecs.setLogLevel(2)

  sapp.run(sapp.Desc(
    initUserdataCb: initApp,
    frameUserdataCb: frame,
    eventUserdataCb: input,
    cleanupCb: cleanup,
    userData: world,
    windowTitle: "clear.nim",
    width: 640,
    height: 480,
    icon: IconDesc(sokol_default: true),
    logger: sapp.Logger(fn: slog.fn)
  ))
