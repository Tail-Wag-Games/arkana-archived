import cppstl

type
  PeerConnection {.header: "peerconnection.hpp",
                      importcpp: "rtc::PeerConnection".} = object

  CertificateType* = distinct int32
  TransportPolicy* = distinct int32
  PeerConnectionState* {.header: "peerconnection.hpp",
                      importcpp: "rtc::PeerConnection::State", size: sizeof(int32).} = enum
    pcsNew
    pcsConnecting
    pcsConnected
    pcsDisconnected
    pcsFailed
    pcsClosed

  IceServerType* = distinct int32
  RelayType* = distinct int32

  IceServer* {.header: "configuration.hpp",
                      importcpp: "rtc::IceServer".} = object
    hostname*: cstring
    port*: uint16
    serverType*: IceServerType
    username*: cstring
    password*: cstring
    relayType*: RelayType

  Configuration* {.header: "configuration.hpp",
                      importcpp: "rtc::Configuration".} = object
    iceServers*: CppVector[IceServer]

const
  ctDefault* = CertificateType(0)
  ctECDSA* = CertificateType(1)
  ctRSA* = CertificateType(2)

  tpAll* = TransportPolicy(0)
  tpRelay* = TransportPolicy(1)

proc createIceServer*(url: cstring): IceServer {.importcpp: "rtc::IceServer(@)", header: "configuration.hpp".}
proc createPeerConnection*(config: Configuration): PeerConnection {.importcpp: "rtc::PeerConnection(@)", header: "peerconnection.hpp".}
proc state*(pc: PeerConnection): PeerConnectionState {.importcpp: "#.state()", header: "peerconnection.hpp".}


{.passC: "-IC:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\include".}
{.passC: "-IC:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\include\\rtc".}
{.passC: "-std=c++17 -stdlib=libc++".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\candidate.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\channel.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\configuration.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\description.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\datachannel.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\peerconnection.cpp".}
{.compile: "C:\\Users\\Zach\\dev\\datachannel-wasm\\wasm\\src\\websocket.cpp".}
