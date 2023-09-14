mergeInto(LibraryManager.library, {
  __js_send_game_client_packet__proxy: 'sync',
  __js_dequeue_game_client_packet__proxy: 'sync',

  __js_get_user_token: function() {
    return stringToNewUTF8(window.userToken)
  },

  __js_get_lobby_id: function() {
    return stringToNewUTF8(window.lobbyId)
  },

  __js_init_game_client: function (protocol_id, use_https) {
    const net = Module['net']
    this.gameClient = new net.GameClient()
  },

  __js_start_game_client: function (hostPtr, port) {
    this.gameClient.connect(UTF8ToString(hostPtr), port).then(() => {
      _jsGameClientStarted()
    }).catch(_ => {
      
    })
  },

  __js_dequeue_game_client_packet: function (lenPtr) {
    const packet = this.gameClient.packets.shift()

    if (packet) {
      const ptr = stackAlloc(packet.byteLength)
      const byteArray = new Uint8Array(packet)

      setValue(lenPtr, packet.byteLength, 'i32')
      writeArrayToMemory(byteArray, ptr)

      return ptr
    } else {
      return null
    }
  },

  __js_send_game_client_packet: function (packetPtr, packetSize) {
    const data = new Uint8Array(Module.HEAPU8.subarray(packetPtr, packetPtr + packetSize))

    this.gameClient.send(data)
  },

  __js_shutdown_game_client: function() {
    this.gameClient.close().then().catch()
  }
});