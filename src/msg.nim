import cfg,
       nbnet

type
  ClientState* = object
    clientId*: uint32
    x*: int32
    y*: int32
    z*: int32

  GameStateMessage* = object
    clientCount*: uint32
    clientStates*: array[maxClients, ClientState]

  UpdateStateMessage* = object
    x*: int32
    y*: int32
    z*: int32

proc createGameStateMessage*(): pointer {.cdecl.} =
  result = allocShared0(sizeof(GameStateMessage))

proc destroyGameStateMessage*(msg: pointer) {.cdecl.} =
  deallocShared(msg)

proc serializeGameStateMessage*(msg: pointer;
    stream: ptr Stream): int32 {.cdecl.} =
  let gsm = cast[ptr GameStateMessage](msg)
  serializeU32(stream, gsm.clientCount, 0, maxClients)

  for i in 0 ..< gsm.clientCount:
    serializeU32(stream, gsm.clientStates[i].clientId, 0, high(uint32))
    serializeInt(stream, gsm.clientStates[i].x, -100, 100)
    serializeInt(stream, gsm.clientStates[i].y, -100, 100)
    serializeInt(stream, gsm.clientStates[i].z, -100, 100)

proc createUpdateStateMessage*(): pointer {.cdecl.} =
  result = allocShared0(sizeof(GameStateMessage))

proc destroyUpdateStateMessage*(msg: pointer) {.cdecl.} =
  deallocShared(msg)

proc serializeUpdateStateMessage*(msg: pointer;
    stream: ptr Stream): int32 {.cdecl.} =
  let usm = cast[ptr UpdateStateMessage](msg)
  serializeInt(stream, usm.x, -100, 100)
  serializeInt(stream, usm.y, -100, 100)
  serializeInt(stream, usm.z, -100, 100)