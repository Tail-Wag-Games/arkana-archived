import posix

type
  WebSocket* = int32

  WebSocketState* = enum
    wssConnecting
    wssOpen
    wssClosing
    wssClosed
  
  WebSocketCreateAttributes* = object
    url*: cstring
    protocols*: cstring
    createOnMainThread*: int32

  WebSocketOpenEvent* = object
    socket*: WebSocket

  WebSocketErrorEvent* = object
    socket*: WebSocket
  
  WebSocketMessageEvent* = object
    socket*: WebSocket
    data*: ptr UncheckedArray[uint8]
    numBytes*: uint32
    isText*: int32

  WebSocketCloseEvent* = object
    socket*: WebSocket
    wasClean*: int32
    code*: int16
    reason*: array[512, char]

  WebSocketOpenCallbackProc* = proc(eventKind: int32; event: ptr WebSocketOpenEvent; userData: pointer): int32 {.cdecl.}
  WebSocketErrorCallbackProc* = proc(eventKind: int32; event: ptr WebSocketErrorEvent; userData: pointer): int32 {.cdecl.}
  WebSocketCloseCallbackProc* = proc(eventKind: int32; event: ptr WebSocketCloseEvent; userData: pointer): int32 {.cdecl.}
  WebSocketMessageCallbackProc* = proc(eventKind: int32; event: ptr WebSocketMessageEvent; userData: pointer): int32 {.cdecl.}

const
  invalidWebSocket* = WebSocket(-1)
  callbackThreadContextCallingThread* = cast[PThread](0x2)

proc newWebSocketImpl(createAttributes: ptr WebSocketCreateAttributes): WebSocket {.importc: "emscripten_websocket_new".}
proc newWebSocket*(createAttributes: var WebSocketCreateAttributes): WebSocket =
  newWebSocketImpl(addr(createAttributes))
proc newWebSocket*(url: string): WebSocket =
  var wsAttrs = WebSocketCreateAttributes(
    url: url,
    protocols: nil,
    createOnMainThread: 1
  )
  result = newWebSocket(wsAttrs)

proc readyStateImpl(socket: WebSocket; readyState: ptr uint16): int32 {.importc: "emscripten_websocket_get_ready_state", discardable.}
proc readyState*(socket: WebSocket): WebSocketState =
  var wss: uint16
  readyStateImpl(socket, addr(wss))
  result = WebSocketState(wss)

proc setOnOpenCallbackOnThread*(socket: WebSocket; userData: pointer; callback: WebsocketOpenCallbackProc; targetThread: Pthread) {.importc: "emscripten_websocket_set_onopen_callback_on_thread".}
proc setOnErrorCallbackOnThread*(socket: WebSocket; userData: pointer; callback: WebsocketErrorCallbackProc; targetThread: Pthread) {.importc: "emscripten_websocket_set_onerror_callback_on_thread".}
proc setOnCloseCallbackOnThread*(socket: WebSocket; userData: pointer; callback: WebsocketCloseCallbackProc; targetThread: Pthread) {.importc: "emscripten_websocket_set_onclose_callback_on_thread".}
proc setOnMessageCallbackOnThread*(socket: WebSocket; userData: pointer; callback: WebsocketMessageCallbackProc; targetThread: Pthread) {.importc: "emscripten_websocket_set_onmessage_callback_on_thread".}

proc sendImpl(socket: WebSocket; textData: cstring): int32 {.importc: "emscripten_websocket_send_utf8_text", discardable.}
proc send*(socket: WebSocket; textData: string): int32 =
  result = sendImpl(socket, textData)