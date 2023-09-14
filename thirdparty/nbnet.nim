type 
  VarArgList* {.importc: "va_list", header: "<stdarg.h>".} = object

proc vprintf(fmt: cstring; args: VarArgList) {.cdecl, importc, header: "stdio.h"}
proc vsprintf(buf, fmt: cstring; args: VarArgList) {.cdecl, importc, header: "stdio.h"}


proc logInfo*(fmt: cstring; args: VarArgList) {.exportc: "ARK_LogInfo", cdecl.} =
  # var buf = newString(128).cstring
  # vsprintf(buf, fmt, args)
  # echo buf
  discard

proc logError*(fmt: cstring; args: VarArgList) {.exportc: "ARK_LogError", cdecl.} =
  var buf = newString(128).cstring
  vsprintf(buf, fmt, args)
  echo buf

proc logWarning*(fmt: cstring; args: VarArgList) {.exportc: "ARK_LogWarning", cdecl.} =
  var buf = newString(128).cstring
  vsprintf(buf, fmt, args)
  echo buf

proc logDebug*(fmt: cstring; args: VarArgList) {.exportc: "ARK_LogDebug", cdecl.} =
  # var buf = newString(128).cstring
  # vsprintf(buf, fmt, args)
  # echo buf
  discard

proc logTrace*(fmt: cstring; args: VarArgList) {.exportc: "ARK_LogTrace", cdecl.} =
  # var buf = newString(128).cstring
  # vsprintf(buf, fmt, args)
  # echo buf
  discard

{.passC: "-IC:\\Users\\Zach\\dev\\arkana\\thirdparty\\nbnet".}
{.compile: "nbnet.c".}

const
  evNone* = 0'i32
  evSkip* = 1'i32
  
  evConnected* = 2'i32
  evDisconnected* = 3'i32
  evMessageReceived* = 4'i32

  maxChannels* = 8
  maxEvents* = 1024
  maxMessageKinds* = 255
  maxPacketSize* = 1400
  maxRpcs* = 32
  maxRpcParams* = 16
  maxRpcStringLength* = 256

type
  BitReader* = object
    size*: uint32
    buffer*: ptr uint8
    scratch*: uint64
    scratchBitsCount*: uint32
    byteCursor*: uint32
  
  BitWriter* = object
    size*: uint32
    buffer*: ptr uint8
    scratch*: uint64
    scratchBitsCount*: uint32
    byteCursor*: uint32

  StopCallback* = proc() {.cdecl.}
  
  RecvPacketsCallback* = proc(): int32 {.cdecl.}
  ClientStartCallback* = proc(protocolId: uint32; host: cstring; port: uint16): int32 {.cdecl.}
  ClientSendPacketCallback* = proc(packet: ptr Packet): int32 {.cdecl.}

  ServerStartCallback* = proc(a1: uint32; a2: uint16): int32 {.cdecl.}
  ServerSendPacketToCallback* = proc(packet: ptr Packet; a2: ptr Connection): int32 {.cdecl.}
  ServerRemoveConnectionCallback* = proc(a1: ptr Connection) {.cdecl.}

  DriverImplementation* = object
    clientStartCb*: ClientStartCallback
    clientStopCb*: StopCallback
    clientRecvPacketsCb*: RecvPacketsCallback
    clientSendPacketCb*: ClientSendPacketCallback
    serverStartCb*: ServerStartCallback
    serverStopCb*: StopCallback
    serverRecvPacketsCb*: RecvPacketsCallback
    serverSendPacketToCb*: ServerSendPacketToCallback
    serverRemoveConnectionCb*: ServerRemoveConnectionCallback
  
  Driver* = object
    id*: int32
    name*: cstring
    impl*: DriverImplementation

  DriverEvent* = distinct int32

  StreamKind* = distinct int32

  SerializeU32Callback* = proc(a1: ptr Stream; a2: ptr uint32; a3, a4: uint32): int32 {.cdecl, gcsafe.}
  SerializeUint64Callback* = proc(a1: ptr Stream; a2: ptr uint64): int32 {.cdecl, gcsafe.}
  SerializeIntCallback* = proc(a1: ptr Stream; a2: ptr int32; a3, a4: int32): int32 {.cdecl, gcsafe.}
  SerializeFloatCallback* = proc(a1: ptr Stream; a2: ptr float32; a3, a4: float32; a5: int32): int32 {.cdecl, gcsafe.}
  SerializeBoolCallback* = proc(a1: ptr Stream; a2: ptr bool): int32 {.cdecl, gcsafe.}
  SerializePaddingCallback* = proc(a1: ptr Stream): int32 {.cdecl, gcsafe.}
  SerializeBytesCallback* = proc(a1: ptr Stream; a2: ptr uint8; a3: uint32): int32 {.cdecl, gcsafe.}

  Stream* = object
    kind*: StreamKind
    serializeU32Cb*: SerializeU32Callback
    serializeUint64Cb*: SerializeUint64Callback
    serializeIntCb*: SerializeIntCallback
    serializeFloatCb*: SerializeFloatCallback
    serializeBoolCb*: SerializeBoolCallback
    serializePaddingCb*: SerializePaddingCallback
    serializeBytesCb*: SerializeBytesCallback

  ReadStream* = object
    base*: Stream
    bitReader*: BitReader

  WriteStream* = object
    base*: Stream
    bitWriter*: BitWriter

  MeasureStream* = object
    base*: Stream
    numberOfBits*: uint32

  PacketMode* = distinct int32

  PacketHeader* = object
    protocoolId*: uint32
    seqNumber*: uint16
    ack*: uint16
    ackBits*: uint32
    messagesCount*: uint8
    isEncrypted*: uint8
    authTag*: array[16, uint8]

  Packet* = object
    header*: PacketHeader
    mode*: PacketMode
    sender*: ptr Connection
    buffer*: array[1400, uint8]
    size*: uint32
    sealed*: bool
    wStream*: WriteStream
    rStream*: ReadStream
    mStream*: MeasureStream
    aesIv*: array[16, uint8]

  OutgoingMessage* = object
    kind*: uint8
    refCount*: uint32
    data*: pointer

  MessageHeader* = object
    id*: uint16
    kind*: uint8
    channelId*: uint8

  MessageChunk* = object
    id*: uint8
    total*: uint8
    data*: array[((1400 - sizeof(PacketHeader)) - 16) - sizeof(MessageHeader) - 2, uint8]
    outgoingMsg*: ptr OutgoingMessage

  Message* = object
    header*: MessageHeader
    sender*: ptr Connection
    outgoingMsg*: ptr OutgoingMessage
    data*: pointer
  
  MessageInfo* = object
    kind*: uint8
    channelId*: uint8
    data*: pointer
    sender*: ptr Connection

  MessageSlot* = object
    message*: Message
    lastSendTime*: float64
    free*: bool
  
  MessageSerializer* = proc(msg: pointer; stream: ptr Stream): int32 {.cdecl.}
  MessageBuilder* = proc(): pointer {.cdecl.}
  MessageDestructor* = proc(msg: pointer) {.cdecl.}

  Channel* = object
    id*: uint8
    write_chunk_buffer*: ptr uint8
    next_outgoing_message_id*: uint16
    next_recv_message_id*: uint16
    next_outgoing_message_pool_slot*: uint32
    outgoing_message_count*: uint32
    chunk_count*: uint32
    write_chunk_buffer_size*: uint32
    read_chunk_buffer_size*: uint32
    next_outgoing_chunked_message*: uint32
    last_received_chunk_id*: int32
    time*: float64
    read_chunk_buffer*: ptr uint8
    destructor*: ChannelDestructor
    connection*: ptr Connection
    outgoing_message_slot_buffer*: array[1024, MessageSlot]
    recved_message_slot_buffer*: array[1024, MessageSlot]
    recv_chunk_buffer*: array[255, ptr MessageChunk]
    outgoing_message_pool*: array[512, OutgoingMessage]
    AddReceivedMessage*: proc (a1: ptr Channel;
                             a2: ptr Message): bool {.cdecl.}
    AddOutgoingMessage*: proc (a1: ptr Channel;
                             a2: ptr Message): bool {.cdecl.}
    GetNextRecvedMessage*: proc (a1: ptr Channel): ptr Message {.cdecl.}
    GetNextOutgoingMessage*: proc (a1: ptr Channel): ptr Message {.cdecl.}
    OnOutgoingMessageAcked*: proc (a1: ptr Channel;
                                 a2: uint16): cint {.cdecl.}
    OnOutgoingMessageSent*: proc (a1: ptr Channel;
        a2: ptr Connection;
                                a3: ptr Message): cint {.cdecl.}

  MessageEntry* = object
    id*: uint16
    channelId*: uint8

  PacketEntry* = object
    acked*: bool
    flaggedAsLost*: bool
    messagesCount*: uint32
    sendTime*: float64
    messages*: array[255, MessageEntry]

  Config* = object
    protocolName*: cstring
    ipAddress*: cstring
    port*: uint16
    isEncryptionEnabled*: bool
  
  ConnectionVector* = object
    connections*: ptr ptr Connection
    count*: uint32
    capacity*: uint32

  ChannelBuilder* = proc (): ptr Channel {.cdecl.}
  ChannelDestructor* = proc (a1: ptr Channel) {.cdecl.}

  EventData* {.union.} = object
    messageInfo*: MessageInfo
    connection*: ptr Connection

  Event* = object
    kind*: int32
    data*: EventData

  EventQueue* = object
    events*: array[maxEvents, Event]
    head*: uint32
    tail*: uint32
    count*: uint32

  RpcParamValue* {.union.} = object
    i*: int32
    f*: float32
    b*: bool
    s*: array[maxRpcStringLength, char]

  RpcParamKind* = distinct int32

  RpcParam* = object
    kind*: RpcParamKind
    value*: RpcParamValue
  
  RpcSignature* = object
    paramCount*: uint32
    params*: array[maxRpcParams, RpcParamKind]
  
  RpcFunc* = proc(id: uint32; params: array[maxRpcParams, RpcParam]; sender: ptr Connection) {.cdecl.}

  Rpc* = object
    id*: uint32
    signature*: RpcSignature
    fn: RpcFunc

  Endpoint* = object
    config*: Config
    channelBuilders*: array[maxChannels, ChannelBuilder]
    channelDestructors*: array[maxChannels, ChannelDestructor]
    messageBuilders*: array[maxMessageKinds, MessageBuilder]
    messageDestructors*: array[maxMessageKinds, MessageDestructor]
    messageSerializers*: array[maxMessageKinds, MessageSerializer]
    eventQueue*: EventQueue
    rpcs*: array[maxRpcs, Rpc]
    isServer*: bool

  GameServerStats* = object
    uploadBandwidth*: float32
    downloadBandwidth*: float32

  GameServer* = object
    endpoint*: Endpoint
    clients*: ptr ConnectionVector
    stats*: GameServerStats
    context*: pointer
    nextConnId*: uint32

  ConnectionStats* = object
    ping*: float64
    totalLostPackets*: uint32
    packetLoss*: float32
    uploadBandwidth*: float32
    downloadBandwidth*: float32

  ConnectionKeySet* = object
    pubKey*: array[64, uint8]
    prvKey*: array[32, uint8]
    sharedKey*: array[64, uint8]

  Connection* = object
    id*: uint32
    protocol_id*: uint32
    last_recv_packet_time*: float64
    last_flush_time*: float64
    last_read_packets_time*: float64
    time*: float64
    downloaded_bytes*: uint32
    is_accepted* {.bitsize: 1.}: uint8
    is_stale* {.bitsize: 1.}: uint8
    is_closed* {.bitsize: 1.}: uint8
    endpoint*: ptr Endpoint
    driver*: ptr Driver
    channels*: array[8, ptr Channel]
    stats*: ConnectionStats
    driver_data*: pointer
    user_data*: pointer
    connection_data*: array[512, uint8]
    accept_data*: array[4096, uint8]
    accept_data_w_stream*: WriteStream
    accept_data_r_stream*: ReadStream
    next_packet_seq_number*: uint16
    last_received_packet_seq_number*: uint16
    packet_send_seq_buffer*: array[1024, uint32]
    packet_send_buffer*: array[1024, PacketEntry]
    packet_recv_seq_buffer*: array[1024, uint32]
    keys1*: ConnectionKeySet
    keys2*: ConnectionKeySet
    keys3*: ConnectionKeySet
    aes_iv*: array[16, uint8]
    can_decrypt* {.bitsize: 1.}: uint8
    can_encrypt* {.bitsize: 1.}: uint8

const
  pmWrite* = PacketMode(1)
  pmRead* = PacketMode(2)

  deClientConnected* = DriverEvent(0)
  deClientPacketReceived* = DriverEvent(1)
  deServerClientConnected* = DriverEvent(2)
  deServerClientPacketReceived* = DriverEvent(3)

when defined(server):
  const
    evNewConnection* = 2'i32
    evClientDisconnected* = 3'i32
    evClientMessageReceived* = 4'i32
  
  var
    gameServer* {.importc: "nbn_game_server".}: GameServer



template serializeU32*(stream, v, min, max: untyped) =
  discard stream.serializeU32Cb(stream, cast[ptr uint32](addr v), min, max)

template serializeInt*(stream, v, min, max: untyped) =
  discard stream.serializeIntCb(stream, cast[ptr int32](addr v), min, max)

proc registerDriver*(id: int32; name: cstring; impl: DriverImplementation) {.importc: "NBN_Driver_Register", cdecl.}
proc raiseDriverEvent*(ev: DriverEvent; data: pointer): int32 {.importc: "NBN_Driver_RaiseEvent", cdecl, discardable.}

proc initPacketRead*(packet: ptr Packet; sender: ptr Connection; buffer: ptr uint8; size: uint32): int32 {.importc: "NBN_Packet_InitRead", cdecl.}

proc initGameClient*(protocolName, ipAddress: cstring; port: uint16; encryption: bool; connectionData: ptr uint8) {.importc: "NBN_GameClient_Init", cdecl.}
proc startGameClient*(): int32 {.importc: "NBN_GameClient_Start", cdecl.}
proc createServerConnection*(driverId: int32; driverData: pointer): ptr Connection {.importc: "NBN_GameClient_CreateServerConnection", cdecl.}
proc registerGameClientMessage*(kind: uint8; builder: MessageBuilder; destructor: MessageDestructor; serializer: MessageSerializer) {.importc: "NBN_GameClient_RegisterMessage", cdecl.}
proc addGameClientTime*(time: float64) {.importc: "NBN_GameClient_AddTime", cdecl.}
proc pollGameClient*(): int32 {.importc: "NBN_GameClient_Poll", cdecl.}
proc sendGameClientPackets*(): int32 {.importc: "NBN_GameClient_SendPackets", cdecl.}
proc getAcceptDataReadStream*(): ptr Stream {.importc: "NBN_GameClient_GetAcceptDataReadStream", cdecl.}
proc getServerCloseCode*(): int32 {.importc: "NBN_GameClient_GetServerCloseCode", cdecl.}
proc getGameClientMessageInfo*(): MessageInfo {.importc: "NBN_GameClient_GetMessageInfo", cdecl.}
proc disconnectGameClient*(): int32 {.importc: "NBN_GameClient_Disconnect", cdecl, discardable.}
proc stopGameClient*() {.importc: "NBN_GameClient_Stop", cdecl.}
proc sendUnreliableGameClientMessage*(msgKind: uint8; msgData: pointer): int32 {.importc: "NBN_GameClient_SendUnreliableMessage", cdecl.}

when defined(server):
  proc getGameServerClientCount*(): uint32 {.importc: "NBN_GameServer_GetClientCount", cdecl.}

  proc initGameServer*(protocolName: cstring; port: uint16; encryption: bool) {.importc: "NBN_GameServer_Init", cdecl.}
  proc startGameServer*(): int32  {.importc: "NBN_GameServer_Start", cdecl.}
  proc pollGameServer*(): int32 {.importc: "NBN_GameServer_Poll", cdecl.}
  proc registerGameServerMesssage*(kind: uint8; builder: MessageBuilder; destructor: MessageDestructor; serializer: MessageSerializer) {.importc: "NBN_GameServer_RegisterMessage", cdecl.}
  proc addGameServerTime*(time: float64) {.importc: "NBN_GameServer_AddTime", cdecl.}
  proc rejectIncomingConnectionWithCode*(code: int32): int32 {.importc: "NBN_GameServer_RejectIncomingConnectionWithCode", cdecl, discardable.}
  proc getIncomingConnection*(): ptr Connection {.importc: "NBN_GameServer_GetIncomingConnection", cdecl.}
  proc getConnectionAcceptDataWriteStream*(client: ptr Connection): ptr Stream {.importc: "NBN_GameServer_GetConnectionAcceptDataWriteStream", cdecl.}
  proc acceptIncomingConnection*(): int32 {.importc: "NBN_GameServer_AcceptIncomingConnection", cdecl, discardable.}
  proc getDisconnectedClient*(): ptr Connection {.importc: "NBN_GameServer_GetDisconnectedClient", cdecl.}
  proc destroyConnection*(connection: ptr Connection) {.importc: "NBN_Connection_Destroy", cdecl.}
  proc getGameServerMessageInfo*(): MessageInfo {.importc: "NBN_GameServer_GetMessageInfo", cdecl.}
  proc sendUnreliableMessageTo*(client: ptr Connection; msgType: uint8; msgData: pointer): int32 {.importc: "NBN_GameServer_SendUnreliableMessageTo", cdecl, discardable.}
  proc sendGameServerPackets*(): int32 {.importc: "NBN_GameServer_SendPackets", cdecl.}
  proc getGameServerStats*(): GameServerStats {.importc: "NBN_GameServer_GetStats", cdecl.}
  proc stopGameServer*() {.importc: "NBN_GameServer_Stop", cdecl.}
  proc createGameServerClientConnection*(driverId: int32; driverData: pointer): ptr Connection {.importc: "NBN_GameServer_CreateClientConnection", cdecl.}