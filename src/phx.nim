import std/[asyncdispatch, json, sequtils, strformat, tables],
       ews, jsbind, results

export WebSocket, json

type
  TimerId = ref object of JSObj

  Timer = ref object
    callback: proc()
    timerCalc: proc(tries: int): int
    timer: TimerId
    tries: int

  Payload = JsonNode

  MessageObj* = object
    re*: string
    joinRe*: string
    topic*: string
    event*: string
    payload*: Payload
  Message* = ref MessageObj

  Presence*[T] = ref object
    channel*: Channel[T]
    joinRe*: string

  Push*[T] = ref object
    channel: Channel[T]
    event: string
    payload: Payload
    receivedResp: Message
    timeout: int
    timeoutTimer: TimerId
    re: string
    reEvent: string
    sent: bool = false
    recHooks: Table[string, seq[proc(msg: Message)]]

  Error* = enum
    eAlreadyJoined

  State* = enum
    csClosed
    csErrored
    csJoined
    csJoining
    csLeaving

  Event* = enum
    eClose
    eError
    eJoin
    eReply
    eLeave

  Binding = object
    event: string
    re: int
    callback: MessageCallback

  ChannelEvent* = enum
    ceClose = "phx_close"
    ceError = "phx_error"
    ceJoin = "phx_join"
    ceReply = "phx_reply"
    ceLeave = "phx_leave"

  MessageCallback = proc(msg: Message)

  Channel*[T] = ref object
    joined: bool
    timeout: int
    topic: string
    state: State
    bindings: seq[Binding]
    bindingRef: int
    joinPush: Push[T]
    pushBuffer: seq[Push[T]]
    stateChangeRefs: seq[string]

    rejoinTimer: Timer
    socket: Socket[T]

  SocketState* = enum
    ssConnecting
    ssOpen
    ssClosing
    ssClosed

  StateChangeCallback = object
    re: string
    cb: proc()

  StateChangeCallbacks = object
    open, close, error, message: seq[StateChangeCallback]

  Socket*[T] = ref object
    stateChangeCallbacks: StateChangeCallbacks
    channels: seq[Channel[T]]
    sendBuffer: seq[proc()]
    timeout: int
    establishedConnections: int
    closeWasClean: bool
    conn: T
    re: int
    rejoinAfterMs: proc(tries: int): int

const
  defaultTimeout = 10000

proc setTimeout(p: proc(), timeout: SomeNumber): TimerId {.jsimportg.}
proc clearTimeout(tid: TimerId) {.jsimportg.}

proc newTimer(cb: proc(); timerCalc: proc(tries: int): int): Timer =
  result = new Timer
  result.callback = cb
  result.timerCalc = timerCalc
  result.timer = nil
  result.tries = 0

proc reset(t: Timer) =
  t.tries = 0
  clearTimeout(t.timer)

proc scheduleTimeout(t: Timer) =
  clearTimeout(t.timer)

  t.timer = setTimeout(
    proc() = 
      discard
      t.tries = t.tries + 1
      t.callback()
    , t.timerCalc(t.tries + 1)
  )

proc findIf[T](s: seq[T], pred: proc(x: T): bool): int =
  result = -1 # return -1 if no items satisfy the predicate
  for i, x in s:
    if pred(x):
      result = i
      break

proc makeRef[T](s: Socket[T]): string =
  let newRef = s.re + 1
  if newRef == s.re: s.re = 0 else: s.re = newRef

  result = $s.re

proc joinRe*[T](c: Channel[T]): string =
  result = c.joinPush.re

proc onOpen[T](s: Socket[T]; callback: proc()): string =
  result = s.makeRef()
  s.stateChangeCallbacks.open.add(StateChangeCallback(re: result, cb: callback))

proc onError[T](s: Socket[T]; callback: proc()): string =
  result = s.makeRef()
  s.stateChangeCallbacks.error.add(StateChangeCallback(re: result, cb: callback))

proc connectionState[T](s: Socket[T]): string =
  if s.conn != invalidWebSocket:
    case SocketState(s.conn.readyState())
    of ssConnecting: "connecting"
    of ssOpen: "open"
    of ssClosing: "closing"
    else: "closed"
  else:
    "closed"

proc connected[T](s: Socket[T]): bool =
  result = s.connectionState() == "open"

proc encode[T](s: Socket[T]; msg: Message; callback: proc(msg: string): int) =
  echo "encoding: ", $(%* {"join_ref": msg.joinRe, "ref": msg.re, "topic": msg.topic, "event": msg.event, "payload": msg.payload})
  discard callback($(%* {"join_ref": msg.joinRe, "ref": msg.re, "topic": msg.topic, "event": msg.event, "payload": msg.payload}))
  
proc push[T](s: Socket[T]; msg: Message) =
  if s.connected():
    s.encode(msg, proc(msg: string): int = s.conn.send(msg))
  else:
    s.sendBuffer.add(proc() = s.encode(msg, proc(msg: string): int = s.conn.send(msg)))
  echo s.timeout

proc unsubscribe[T](s: Socket[T]; refs: seq[string]) =
  s.stateChangeCallbacks.open = s.stateChangeCallbacks.open.filter(
    proc(callback: StateChangeCallback): bool =
      refs.find(callback.re) == -1
  )

proc remove[T](s: Socket[T]; c: Channel[T]) =
  s.unsubscribe(c.stateChangeRefs)
  s.channels = s.channels.filter(proc(ch: Channel[T]): bool = ch.joinRe() != c.joinRe())

proc errored[T](c: Channel[T]): bool =
  result = c.state == csErrored

proc replyEventName[T](c: Channel[T]; re: string): string =
  result = &"chan_reply_{re}"

proc joined*[T](c: Channel[T]): bool =
  result = c.state == csJoined

proc joining*[T](c: Channel[T]): bool =
  result = c.state == csJoining

proc canPush*[T](c: Channel[T]): bool =
  result = c.socket.connected() and c.joined()

proc unsubscribe*[T](c: Channel[T]; event: string; re: int = -1) =
  c.bindings = c.bindings.filter(proc(b: Binding): bool = not (b.event ==
      event and (re == -1 or re == b.re)))

proc subscribe*[T](c: Channel[T]; event: string; callback: MessageCallback): int {.discardable.} =
  inc(c.bindingRef)
  result = c.bindingRef
  c.bindings.add(Binding(event: event, re: result, callback: callback))

proc onMessage[T](c: Channel[T]; msg: Message): Message =
  result = msg

proc onClose[T](c: Channel[T]; callback: MessageCallback) =
  c.subscribe($ceClose, callback)

proc onError[T](c: Channel[T]; callback: MessageCallback): int {.discardable.} =
  result = c.subscribe($ceError, callback)

proc trigger[T](c: Channel[T]; msg: Message) =
  block a:
    let 
      handledMessage = c.onMessage(msg)
      evtBindings = c.bindings.filter(proc(b: Binding): bool = b.event == msg.event)

    for b in evtBindings:
      echo "executing callback"
      b.callback(handledMessage)

proc trigger[T](c: Channel[T]; event: string; payload: Payload; re: string = ""; joinRe: string = "") =
  c.trigger(Message(
    re: re,
    topic: c.topic,
    event: event,
    payload: payload,
    joinRe: if len(joinRe) > 0: joinRe else: c.joinRe()
  ))

proc newPush*[T](c: Channel[T]; event: string; payload: Payload; timeout: int): Push[T] =
  result = new Push[T]
  result.channel = c
  result.event = event
  result.payload = payload
  result.receivedResp = nil
  result.timeout = timeout

proc push*[T](c: Channel[T]; event: string; payload: Payload; timeout: int = c.timeout): Push[T] =
  result = newPush[T](c, event, if payload != nil: payload else: new(JsonNode), timeout)
  if c.canPush():
    result.send()
  else:
    result.startTimeout()
    c.pushBuffer.add(result)

proc status(msg: Message): string =
  result = msg.payload{"status"}.getStr()

proc hasReceived[T](p: Push[T]; status: string): bool =
  result = p.receivedResp != nil and p.receivedResp.status == status

proc cancelReEvent[T](p: Push[T]) =
  if len(p.reEvent) == 0:
    p.channel.unsubscribe(p.reEvent)

proc receive*[T](p: Push[T]; status: string; callback: MessageCallback): Push[T] {.discardable.} =
  if p.hasReceived(status):
    callback(p.receivedResp)
  
  p.recHooks.mgetOrPut(status, @[]).add(callback)
  result = p

proc reset*[T](p: Push[T]) =
  p.cancelReEvent()
  p.re = ""
  p.reEvent = ""
  p.receivedResp = nil
  p.sent = false

proc trigger[T](p: Push[T]; status: string; payload: Payload) =
  payload{"status"} = % status
  p.channel.trigger(p.reEvent, payload)

proc cancelTimeout[T](p: Push[T]) =
  clearTimeout(p.timeoutTimer)
  p.timeoutTimer = nil

proc matchReceive[T](p: Push[T]; msg: Message) =
  for hook in p.recHooks.getOrDefault(msg.status()):
    hook(msg)

proc startTimeout[T](p: Push[T]) =
  if p.timeoutTimer != nil:
    p.cancelTimeout()
  p.re = p.channel.socket.makeRef()
  p.reEvent = p.channel.replyEventName(p.re)

  echo p.re
  echo p.reEvent

  p.channel.subscribe(p.reEvent, proc(msg: Message) = 
    echo "inside subscription handler!"
    p.cancelReEvent()
    p.cancelTimeout()
    p.receivedResp = msg
    p.matchReceive(msg)
  )

  p.timeoutTimer = setTimeout(proc() = p.trigger("timeout", %* {}), p.timeout)

proc send[T](p: Push[T]) =
  block a:
    if p.hasReceived("timeout"): break a
    p.startTimeout()
    p.sent = true
    p.channel.socket.push(
      Message(
        topic: p.channel.topic,
        event: p.event,
        payload: p.payload,
        re: p.re,
        joinRe: p.channel.joinRe()
      )
    )

proc resend*[T](p: Push[T]; timeout: int) =
  p.timeout = timeout
  p.reset()
  p.send()

proc newChannel*[T](topic: string; socket: Socket[T]): Channel[T] =
  result = new Channel[T]
  result.state = csClosed
  result.topic = topic
  result.socket = socket
  result.timeout = result.socket.timeout
  result.joinPush = newPush[T](result, $ceJoin, %* {}, result.timeout)
  
  let c = result
  result.rejoinTimer = newTimer(
    proc() =
      if c.socket.connected():
        c.rejoin()
    , c.socket.rejoinAfterMs
  )
  result.stateChangeRefs.add(result.socket.onError(proc() = c.rejoinTimer.reset()))
  result.stateChangeRefs.add(result.socket.onOpen(
    proc() =
      c.rejoinTimer.reset()
      if c.errored(): c.rejoin()
  ))
  result.joinPush.receive("ok", proc(msg: Message) =
    echo "received okay!!!"
    c.state = csJoined
    c.rejoinTimer.reset()
    for pushEvent in c.pushBuffer:
      pushEvent.send()
    c.pushBuffer.setLen(0)
  )
  result.joinPush.receive("error", proc(msg: Message) =
    c.state = csErrored
    if c.socket.connected(): c.rejoinTimer.scheduleTimeout()
  )
  result.onClose(proc(msg: Message) = 
    c.rejoinTimer.reset()
    echo "channel ", &"close {c.topic} {c.joinRe()}"
    c.state = csClosed
    c.socket.remove(c)
  )
  result.onError(proc(msg: Message) = 
    echo "channel ", &"error {c.topic} {repr msg}"
    if c.joining(): c.joinPush.reset()
    c.state = csClosed
  )
  result.joinPush.receive("timeout", proc(msg: Message) =
    echo "channel ", &"timeout {c.topic} ({c.joinRe()})"
    let leavePush = newPush(c, $ceLeave, %* {}, c.timeout)
    leavePush.send()
    c.state = csErrored
    c.joinPush.reset()
    if c.socket.connected(): c.rejoinTimer.scheduleTimeout()
  )
  result.subscribe($ceReply, proc(msg: Message) =
    echo "inside reply event handler!" 
    c.trigger(c.replyEventName(msg.re), msg.payload, msg.re, msg.joinRe)
  )

proc isLeaving*[T](c: Channel[T]): bool =
  result = c.state == csLeaving

proc leaveOpenTopic*[T](s: Socket[T]; topic: string) =
  let dupChannelIdx = s.channels.findIf(proc(c: Channel[T]): bool = c.topic == topic and (joined(c) or c.joining()))
  if dupChannelIdx != -1:
    echo "transport ", &"leaving duplicate topic {topic}"
    s.channels[dupChannelIdx].leave()

proc leave*[T](c: Channel[T]; timeout: int = c.timeout) =
  c.rejoinTimer.reset()
  c.joinPush.cancelTimeout()

  c.state = csLeaving
  let 
    onClose = proc() =
      echo "channel ", &"leave {c.topic}"
      c.trigger($ceClose, %* {"reason": "leave"})
    leavePush = newPush(c, $ceLeave, %* {}, timeout)

  leavePush.receive("ok", proc(msg: Message) = onClose())
    .receive("timeout", proc(msg: Message) = onClose())
  

proc rejoin*[T](c: Channel[T]; timeout: int = c.timeout) =
  block a:
    if c.isLeaving(): break a
    c.socket.leaveOpenTopic(c.topic)
    c.state = csJoining
    c.joinPush.resend(timeout)

proc join*[T](c: Channel[T]; timeout: int = c.timeout): Push[T] =
  block a:
    if c.joined:
      break a
    else:
      c.timeout = timeout
      c.joined = true
      c.rejoin(c.timeout)
      result = c.joinPush

proc isMember*[T](c: Channel[T]; topic, event: string; payload: Payload; joinRe: string): bool =
  block early:
    if c.topic != topic:
      break early

    if len(joinRe) > 0 and c.joinRe != joinRe:
      echo "channel: dropping outdated message"
      break early

    result = true

proc newSocket*[T](): Socket[T] =
  result = new Socket[T]
  result.timeout = defaultTimeout
  result.rejoinAfterMs = proc(tries: int): int =
    result = if tries > 1 and tries < 4: [1000, 2000, 5000][tries - 1] else: 10000

proc flushSendBuffer*[T](s: Socket[T]) =
  if s.connected() and len(s.sendBuffer) > 0:
    for cb in s.sendBuffer:
      cb()

proc onConnOpen*(eventKind: int32; event: ptr WebSocketOpenEvent;
    userData: pointer): int32 {.cdecl.} =
  let socket = cast[Socket[WebSocket]](userData)
  socket.closeWasClean = false
  inc(socket.establishedConnections)
  socket.flushSendBuffer()

  result = 1

proc onConnError*(eventKind: int32; event: ptr WebSocketErrorEvent;
    userData: pointer): int32 {.cdecl.} =
  echo "in onConnError"
  result = 1

proc onConnClose*(eventKind: int32; event: ptr WebSocketCloseEvent;
    userData: pointer): int32 {.cdecl.} =
  echo "in onConnClose"
  result = 1

proc onConnMessage*(eventKind: int32; event: ptr WebSocketMessageEvent;
    userData: pointer): int32 {.cdecl.} =
  let
    s = cast[Socket[WebSocket]](userData) 
    msg = parseJson($cast[cstring](addr(event.data[0])))

    topic = msg{"topic"}.getStr()
    eventName = msg{"event"}.getStr()
    payload = to(msg{"payload"}, Payload)
    re = msg{"ref"}.getStr()
    joinRe = msg{"join_ref"}.getStr()

  for c in s.channels:
    if not c.isMember(topic, eventName, payload, joinRe): continue
    c.trigger(eventName, payload, re, joinRe)

  for sccb in s.stateChangeCallbacks.message:
    sccb.cb()

  result = 1

proc connect*[WebSocket](s: Socket[WebSocket]; url: string) =
  s.conn = newWebSocket(url)
  setOnOpenCallbackOnThread(s.conn, cast[pointer](s), onConnOpen, callbackThreadContextCallingThread)
  setOnErrorCallbackOnThread(s.conn, nil, onConnError, callbackThreadContextCallingThread)
  setOnCloseCallbackOnThread(s.conn, nil, onConnClose, callbackThreadContextCallingThread)
  setOnMessageCallbackOnThread(s.conn, cast[pointer](s), onConnMessage, callbackThreadContextCallingThread)

proc channel*[T](s: Socket[T]; topic: string): Channel[T] =
  result = newChannel[T](topic, s)
  s.channels.add(result)

proc newPresence*[T](c: Channel[T]): Presence[T] =
  result = new Presence[T]
  result.channel = c

  let r = result
  result.channel.subscribe("presence_state", proc(newState: Message) =
    r.joinRe = r.channel.joinRe()
    echo "presence_state: ", $newState.payload
    # result.state = syncState(result.state, newState)
  )

  result.channel.subscribe("presence_diff", proc(newState: Message) = 
    echo "presence_diff: ", $newState.payload
  )