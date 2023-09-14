import std/[macros, posix, strformat, tables],
       nbnet, flecs,
       msg

type
  WrtcPeer = object
    id: uint32
    conn: ptr Connection
  
  Client = object
    connection: ptr Connection
    state: ClientState

  ClientSpawnedCallback* = proc(id: string; x, y, z: int32)
  ClientUpdatedCallback* = ClientSpawnedCallback

const
  cServerFull = 42
  maxClients = 4

  mkUpdateState = 0'i32
  mkGameState = 1'i32

  tickDt = 1.0'f64 / 60.0'f64

  windowWidth = 640
  windowHeight = 480

var
  wrtcServer: ptr Connection
  connectedToWrtcServer = false
  # serverThread: Thread[tuple[a, b: cstring]]

  connected = false
  disconnected = false
  spawned = false
  gameClientStarted = false
  gameServerStarted = false
  serverCloseCode: int32
  localClientState: ClientState

  remoteClients: array[maxClients - 1, ptr ClientState]
  remoteClientCount: int32
  updatedIds: array[maxClients, int32]

  localClientSpawnedCb: ClientSpawnedCallback
  remoteClientSpawnedCb: ClientSpawnedCallback
  remoteClientUpdatedCb: ClientUpdatedCallback


macro EMSCRIPTEN_KEEPALIVE*(someProc: untyped): typed =
  result = someProc
  #[
    Ident !"exportc"
    ExprColonExpr
      Ident !"codegenDecl"
      StrLit __attribute__((used)) $# $#$#
  ]#
  result.addPragma(newIdentNode("exportc"))
  result.addPragma(newNimNode(nnkExprColonExpr).add(
          newIdentNode("codegenDecl"),
          newLit("__attribute__((used)) $# $#$#")))

when defined(server):
  var
    lobbyId {.threadvar.}: cstring
    userToken {.threadvar.}: cstring
    wrtcPeers: tables.Table[uint32, ptr WrtcPeer]
    
    clientCount = 0'u32
    clients: array[maxClients, ptr Client]

    signalingAndPresenceServers: pointer

proc emSleep*(ms: float64) {.importc: "emscripten_sleep", header: "emscripten.h", cdecl.}
proc detachThread(t: PThread): int32 {.importc: "pthread_detach", header: "pthread.h", cdecl, discardable.}

proc getUserToken(): cstring {.importc: "__js_get_user_token".}
proc getLobbyId(): cstring {.importc: "__js_get_lobby_id".}

proc initJsGameClient(protocolId: uint32;
    useHttps: bool) {.importc: "__js_init_game_client".}
proc startJsGameClient(host: cstring; port: uint16): int32 {.importc: "__js_start_game_client".}
proc dequeueJsGameClientPacket(size: ptr uint32): ptr uint8 {.importc: "__js_dequeue_game_client_packet".}
proc sendJsGameClientPacket(packet: ptr uint8;
    packetSize: uint32): int32 {.importc: "__js_send_game_client_packet".}
proc shutdownJsGameClient() {.importc: "__js_shutdown_game_client".}

proc initJsGameServer() {.importc: "__js_init_game_server".}
proc startJsGameServer(port: uint16; userToken, lobbyId: cstring): int32 {.importc: "__js_start_game_server".}
proc dequeueJsGameServerPacket(peerId, size: ptr uint32): ptr uint8 {.importc: "__js_dequeue_game_server_packet".}
proc sendGameServerPacketTo(packet: ptr uint8; packetSize,
    peerId: uint32): int32 {.importc: "__js_send_game_server_packet_to".}
proc closeGameServerClientPeer(connectionId: uint32) {.importc: "__js_close_game_server_client_peer".}
proc stopJsGameServer(){.importc: "__js_stop_game_server".}

proc isGameClientStarted*(): bool =
  result = gameClientStarted

proc isGameServerStarted*(): bool =
  result = gameServerStarted

proc clientRecvPackets(): int32 {.cdecl.} =
  var
    data: ptr uint8
    len: uint32

  data = dequeueJsGameClientPacket(addr(len))
  while data != nil:
    var packet: Packet

    if initPacketRead(addr(packet), wrtcServer, data, len) < 0:
      continue

    if not connectedToWrtcServer:
      raiseDriverEvent(deClientConnected, nil)
      connectedToWrtcServer = true

    raiseDriverEvent(deClientPacketReceived, addr(packet))

    data = dequeueJsGameClientPacket(addr(len))

proc clientSendPacket(packet: ptr Packet): int32 {.cdecl.} =
  result = sendJsGameClientPacket(addr(packet.buffer[0]), packet.size)

proc spawnLocalClient(x, y, z: int32; clientId: uint32) =
  localClientState.clientId = clientId
  localClientState.x = x
  localClientState.y = y
  localClientState.z = z

  localClientSpawnedCb($clientId, x, y, z)

  spawned = true

proc handleConnection() =
  let rs = getAcceptDataReadStream()

  var
    x = 0'i32
    y = 0'i32
    z = 0'i32
    clientId = 0'u32

  serializeInt(rs, x, -100, 100)
  serializeInt(rs, y, -100, 100)
  serializeInt(rs, z, -100, 100)
  serializeU32(rs, clientId, 0, high(uint32))

  spawnLocalClient(x, y, z, clientId)

  connected = true

proc isSpawned*(): bool =
  result = spawned

proc isConnected*(): bool =
  result = connected

proc isDisconnected*(): bool =
  result = disconnected

proc handleDisconnection() =
  let code = getServerCloseCode()

  disconnected = true
  serverCloseCode = code
  echo &"disconnected from server with code: {serverCloseCode}"

proc clientExists(clientId: uint32): bool =
  for i in 0 ..< maxClients - 1:
    if remoteClients[i] != nil and remoteClients[i].clientId == clientId:
      result = true
      break

proc createClient(state: ClientState) =
  assert remoteClientCount < maxClients - 1

  var c: ptr ClientState
  for i in 0 ..< maxClients - 1:
    if remoteClients[i].isNil:
      c = cast[ptr ClientState](allocShared0(sizeof(ClientState)))
      remoteClients[i] = c
      break

  assert c != nil

  copyMem(c, addr(state), sizeof(ClientState))

  inc(remoteClientCount)

proc updateClient(state: ClientState) =
  var c: ptr ClientState

  for i in 0 ..< maxClients - 1:
    if remoteClients[i] != nil and remoteClients[i].clientId == state.clientId:
      c = remoteClients[i]
      break

  assert c != nil

  copyMem(c, addr(state), sizeof(ClientState))

proc destroyClient(clientId: uint32) =
  for i in 0 ..< maxClients - 1:
    let c = remoteClients[i]

    if c != nil and c.clientId == clientId:
      deallocShared(c)
      remoteClients[i] = nil
      dec(remoteClientCount)
      break

proc destroyDisconnectedClients() =
  for i in 0 ..< maxClients - 1:
    if remoteClients[i].isNil:
      continue

    let clientId = remoteClients[i].clientId

    var clientDisconnected = true
    for j in 0 ..< maxClients:
      if int32(clientId) == updatedIds[j]:
        clientDisconnected = false
        break

    if clientDisconnected:
      destroyClient(clientId)

proc handleGameStateMessage(msg: ptr GameStateMessage) =
  block early:
    if not spawned:
      break early

    for i in 0 ..< maxClients:
      updatedIds[i] = -1

    for i in 0 ..< msg.clientCount:
      let state = msg.clientStates[i]

      if state.clientId != localClientState.clientId:
        if clientExists(state.clientId):
          updateClient(state)
          remoteClientUpdatedCb($state.clientId, state.x, state.y, state.z)
        else:
          createClient(state)
          remoteClientSpawnedCb($state.clientId, state.x, state.y, state.z)

        updatedIds[i] = int32(state.clientId)

    destroyDisconnectedClients()
    destroyGameStateMessage(msg)

proc handleReceivedMessage() =
  let msgInfo = getGameClientMessageInfo()

  case msgInfo.kind.int32
  of mkGameState:
    handleGameStateMessage(cast[ptr GameStateMessage](msgInfo.data))
  else:
    discard

proc handleGameClientEvent*(ev: int32) =
  echo "handling game client event!!!"
  case ev
  of evConnected:
    handleConnection()
  of evDisconnected:
    handleDisconnection()
  of evMessageReceived:
    handleReceivedMessage()
  else:
    discard

proc sendPositionUpdate*(x, y, z: int32): int32 =
  let msg = cast[ptr UpdateStateMessage](createUpdateStateMessage())

  msg.x = x
  msg.y = y
  msg.z = z

  if sendUnreliableGameClientMessage(mkUpdateState.uint8, msg) < 0:
    result = -1

proc serverRecvPackets(): int32 {.cdecl.} =
  when defined(server):
    var
      data: ptr uint8
      peerId: uint32
      len: uint32

    data = dequeueJsGameServerPacket(addr(peerId), addr(len))
    while data != nil:
      var packet: Packet

      var peer = wrtcPeers.getOrDefault(peerId, nil)
      if peer.isNil:
        if getGameServerClientCount() >= maxClients:
          continue

        peer = cast[ptr WrtcPeer](allocShared0(sizeof(WrtcPeer)))

        peer.id = peerId
        peer.conn = createGameServerClientConnection(1, peer)

        wrtcPeers[peerId] = peer
        raiseDriverEvent(deServerClientConnected, peer.conn)

      if initPacketRead(addr(packet), peer.conn, data, len) < 0:
        echo "failed initializing packet read"
        continue

      packet.sender = peer.conn

      raiseDriverEvent(deServerClientPacketReceived, addr(packet))

      data = dequeueJsGameServerPacket(addr(peerId), addr(len))

proc serverRemovedConnection(conn: ptr Connection) {.cdecl.} =
  when defined(server):
    assert conn != nil

    closeGameServerClientPeer(conn.id)

    var peer: ptr WrtcPeer
    discard pop(wrtcPeers, cast[ptr WrtcPeer](conn.driverData).id, peer)

    if peer != nil:
      deallocShared(peer)

proc serverSendPacketTo(packet: ptr Packet;
    conn: ptr Connection): int32 {.cdecl.} =
  when defined(server):
    result = sendGameServerPacketTo(addr(packet.buffer[0]), packet.size, conn.id)

proc findClientById(clientId: uint32): ptr Client =
  when defined(server):
    block early:
      for i in 0 ..< maxClients:
        if clients[i] != nil and clients[i].state.clientId == clientId:
          result = clients[i]
          break early

proc destroyClient(client: ptr Client) =
  when defined(server):
    block early:
      for i in 0 ..< maxClients:
        if clients[i] != nil and clients[i].state.clientId ==
            client.state.clientId:
          clients[i] = nil
          break early

      deallocShared(client)

proc handleNewConnection(): int32 {.gcsafe.} =
  when defined(server):
    var spawns {.global.} = [
      (x: -45'i32, y: 3'i32, z: 45'i32),
      (x: -45'i32, y: 3'i32, z: -45'i32),
      (x: 45'i32, y: 3'i32, z: 45'i32),
      (x: 45'i32, y: 3'i32, z: -45'i32)
    ]

    block early:
      if clientCount == maxClients:
        echo "rejecting new connection - server full"
        rejectIncomingConnectionWithCode(cServerFull)
        break early

      let
        conn = getIncomingConnection()
        spawn = spawns[conn.id mod maxClients]
        ws = getConnectionAcceptDataWriteStream(conn)

      serializeInt(ws, spawn.x, -100, 100)
      serializeInt(ws, spawn.y, -100, 100)
      serializeInt(ws, spawn.z, -100, 100)
      serializeU32(ws, conn.id, 0, high(uint32))

      acceptIncomingConnection()

      var client: ptr Client
      for i in 0 ..< maxClients:
        if clients[i].isNil:
          client = cast[ptr Client](allocShared0(sizeof(Client)))
          clients[i] = client
          break

      assert client != nil

      client.connection = conn
      client.state.clientId = conn.id
      client.state.x = 0
      client.state.y = 1
      client.state.z = 0

      inc(clientCount)

proc handleClientDisconnection() =
  when defined(server):
    let clientConn = getDisconnectedClient()

    let client = findClientById(clientConn.id)

    assert client != nil

    destroyClient(client)
    destroyConnection(clientConn)

    dec(clientCount)

proc broadcastGameState(): int32 =
  when defined(server):
    var
      cStates: array[maxClients, ClientState]
      clientIdx = 0'u32

    for i in 0 ..< maxClients:
      let client = clients[i]

      if client.isNil:
        continue

      cStates[clientIdx].clientId = client.state.clientId
      cStates[clientIdx].x = client.state.x
      cStates[clientIdx].y = client.state.y
      cStates[clientIdx].z = client.state.z

      inc(clientIdx)
    
    assert clientIdx == clientCount

    for i in 0 ..< maxClients:
      let client = clients[i]

      if client.isNil:
        continue

      let msg = cast[ptr GameStateMessage](createGameStateMessage())

      msg.clientCount = clientIdx
      copyMem(addr(msg.clientStates[0]), addr(cStates[0]), sizeof(ClientState) * maxClients)

      sendUnreliableMessageTo(client.connection, mkGameState.uint8, msg)

proc handleUpdateStateMessage(msg: ptr UpdateStateMessage;
    sender: ptr Client) =
  sender.state.x = msg.x
  sender.state.y = msg.y
  sender.state.z = msg.z

  destroyUpdateStateMessage(msg)

proc handleReceivedServerMessage() =
  when defined(server):
    let
      msgInfo = getGameServerMessageInfo()
      sender = findClientById(msgInfo.sender.id)

    assert sender != nil

    case msgInfo.kind.int32
    of mkUpdateState:
      handleUpdateStateMessage(cast[ptr UpdateStateMessage](msgInfo.data), sender)
    else:
      discard

proc handleGameServerEvent(ev: int32): int32 =
  when defined(server):
    case ev
    of evNewConnection:
      if handleNewConnection() < 0:
        echo "failed handling new connection!"
        result = -1
    of evClientDisconnected:
      handleClientDisconnection()
    of evClientMessageReceived:
      handleReceivedServerMessage()
    else:
      discard

proc updateServer*(dt: float32) {.thread.} =
  when defined(server):
    block early:
      if gameServerStarted:
        # while true:
        addGameServerTime(dt)

        var ev = pollGameServer()
        while ev != evNone:
          if ev < 0:
            logError("server network event polling error", VarArgList())
            break

          if handleGameServerEvent(ev) < 0:
            echo "failed handling game server event"
            break

          ev = pollGameServer()

        if broadcastGameState() < 0:
          echo "error occurred while broadcasting game states"
          break

        if sendGameServerPackets() < 0:
          echo "error occurred while flushing game server send queue"
          break

        # let stats = getGameServerStats()
        # emSleep(tickDt * 1000)

      # stopGameServer()

proc serverStarted(protocolId: uint32; port: uint16): int32 {.cdecl.} =
  when defined(server):
    block early:
      initJsGameServer()

      if startJsGameServer(port, getUserToken(), getLobbyId()) < 0:
        result = -1
        break early

proc jsGameServerStarted() {.EMSCRIPTEN_KEEPALIVE.} =
  echo "JS GAME SERVER STARTED!!!!"
  gameServerStarted = true

proc serverStopped() {.cdecl.} =
  when defined(server):
    stopJsGameServer()
    for pid, p in wrtcPeers.mpairs:
      if p != nil:
        deallocShared(p)

proc clientStarted(protocolId: uint32; host: cstring;
    port: uint16): int32 {.cdecl.} =
  block early:
    initJsGameClient(protocolId, false)

    wrtcServer = createServerConnection(1, nil)

    if startJsGameClient(host, port) < 0:
      echo "failed starting game client!"
      break early

proc clientStopped() {.cdecl.} =
  shutdownJsGameClient()


proc jsGameClientStarted() {.EMSCRIPTEN_KEEPALIVE.} =
  echo "JS GAME CLIENT STARTED!!!!"
  gameClientStarted = true

proc init*(localClientSpawned, remoteClientSpawned: ClientSpawnedCallback; remoteClientUpdated: ClientUpdatedCallback) {.cdecl.} =
  block early:
    localClientSpawnedCb = localClientSpawned
    remoteClientSpawnedCb = remoteClientSpawned
    remoteClientUpdatedCb = remoteClientUpdated

    registerDriver(1, "WebRTC", DriverImplementation(
        clientStartCb: clientStarted,
        clientStopCb: clientStopped,
        clientRecvPacketsCb: clientRecvPackets,
        clientSendPacketCb: clientSendPacket,
        serverStartCb: serverStarted,
        serverStopCb: serverStopped,
        serverRecvPacketsCb: serverRecvPackets,
        serverSendPacketToCb: serverSendPacketTo,
        serverRemoveConnectionCb: serverRemovedConnection,
      ))

    when defined(server):
      initGameServer("arkana", 42042, false)

      if startGameServer() < 0:
        logError("failed starting game server", VarArgList())
        break early

      registerGameServerMesssage(mkUpdateState.uint8, createUpdateStateMessage,
          destroyUpdateStateMessage, serializeUpdateStateMessage)
      registerGameServerMesssage(mkGameState.uint8, createGameStateMessage,
          destroyGameStateMessage, serializeGameStateMessage)
      
      # createThread(serverThread, serverWorker, (getUserToken(), getLobbyId()))

      # detachThread(serverThread.handle())

    initGameClient("arkana", "127.0.0.1", 42042, false, nil)
      
    if startGameClient() < 0:
      logWarning("failed starting game client", VarArgList())
      break early

    registerGameClientMessage(mkUpdateState.uint8, createUpdateStateMessage,
        destroyUpdateStateMessage, serializeUpdateStateMessage)
    registerGameClientMessage(mkGameState.uint8, createGameStateMessage,
        destroyGameStateMessage, serializeGameStateMessage)
