# import std/[os], 
#        cglm, flecs, ozz, sokol/gfx as sg, sokol/fetch as sf

# declareSystem(InitMeshRenderer)

# struct(Mesh):
#   idxCount: int32_t

# var 
#   inst: ptr ozz.Instance
#   jointTexture: sg.Image
#   skeletonIoBuffer: array[32 * 1024, uint8]
#   animationIoBuffer: array[96 * 1024, uint8]
#   meshIoBuffer: array[3 * 1024 * 1024, uint8]

#   world: ptr World

# proc importMeshComponents*(w: ptr World) {.exportc: "MeshComponentsImport", cdecl.} =
#   module(w, MeshComponents)
#   metaComponent(w, Mesh)
#   addPair(w, FLECS_EMesh, With, Geometry)

# proc createVBufCb(p: ptr UncheckedArray[Vertex]; numVerts: uint) {.cdecl.} =
#   var desc: sg.BufferDesc
#   desc.`type` = bufferTypeVertexBuffer
#   desc.data.`addr` = p
#   desc.data.size = int(numVerts) * sizeof(ozz.Vertex)

#   let g = getMut(world, FLECS_ESokolMeshGeometry, SokolGeometry)
#   assert g != nil, "unable to find mutable MeshGeometry component"
#   g.vertices = sg.makeBuffer(desc)

# proc createIBufCb(p: ptr UncheckedArray[uint16]; numIndices: uint) {.cdecl.} =
#   var desc: sg.BufferDesc
#   desc.`type` = bufferTypeIndexBuffer
#   desc.data.`addr` = p
#   desc.data.size = int(numIndices) * sizeof(uint16)

#   let g = getMut(world, FLECS_ESokolMeshGeometry, SokolGeometry)
#   assert g != nil, "unable to find mutable MeshGeometry component"
#   g.indexCount = numIndices.int32
#   g.indices = sg.makeBuffer(desc)

# proc populateMesh(transforms: ptr Mat4; data: pointer; count: int32;
#       self: bool) {.cdecl.} =
#   discard

# proc InitMeshRenderer(it: ptr Iter) {.exportc: "InitMeshRenderer", cdecl.} =
#   var ozzCtxDesc: ozz.Desc
#   ozzCtxDesc.maxInstances = 1
#   ozzCtxDesc.maxPaletteJoints = 64
#   ozz.setup(addr(ozzCtxDesc))

#   var imgDesc: sg.ImageDesc
#   imgDesc.width = jointTextureWidth()
#   imgDesc.height = jointTextureHeight()
#   imgDesc.numMipmaps = 1
#   imgDesc.pixelFormat = pixelFormatRGBA32F
#   imgDesc.usage = usageStream
#   imgDesc.minFilter = filterNearest
#   imgDesc.magFilter = filterNearest
#   imgDesc.wrapU = wrapClampToEdge
#   imgDesc.wrapV = wrapClampToEdge
#   jointTexture = makeImage(imgDesc)

#   inst = ozz.createInstance(0)

#   let 
#     skel = open("./etc/assets/skeletons/skeleton.ozz", FileMode.fmRead)
#     skelSize = getFileSize("./etc/assets/skeletons/skeleton.ozz")
#     skelBytesRead = readBuffer(skel, addr(skeletonIoBuffer[0]), skelSize)

#     anim = open("./etc/assets/animations/animation.ozz", FileMode.fmRead)
#     animSize = getFileSize("./etc/assets/animations/animation.ozz")
#     animBytesRead = readBuffer(anim, addr(animationIoBuffer[0]), animSize)

#     mesh = open("./etc/assets/meshes/mesh.ozz", FileMode.fmRead)
#     meshSize = getFileSize("./etc/assets/meshes/mesh.ozz")
#     meshBytesRead = readBuffer(mesh, addr(meshIoBuffer[0]), meshSize)

#   ozz.loadSkeleton(inst, addr(skeletonIoBuffer[0]), uint(skelBytesRead))
#   ozz.loadAnimation(inst, addr(animationIoBuffer[0]), uint(animBytesRead))
#   ozz.loadMesh(inst, addr(meshIoBuffer[0]), uint(meshBytesRead), createVBufCb, createIBufCb)

#   close(skel)
#   close(anim)
#   close(mesh)

#   let g = getMut(it.world, FLECS_ESokolMeshGeometry, SokolGeometry)
#   assert g != nil, "unable to find mutable MeshGeometry component"

#   g.populate = populateMesh

# proc importMeshSystems*(w: ptr World) {.exportc: "MeshSystemsImport", cdecl.} =
#   module(w, MeshSystems)
#   # defineEntity(w, MeshGeometry, "flecs.components.geometry.Geometry")
#   # flecs.set(w, MeshGeometry, FLECS_ESokolGeometryQuery, SokolGeometryQuery, SokolGeometryQuery(component: FLECS_EMesh))
#   defineSystem(w, InitMeshRenderer, 0)

#   world = w

#   echo "mesh systems imported!"
