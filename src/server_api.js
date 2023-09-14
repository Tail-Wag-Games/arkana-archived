mergeInto(LibraryManager.library,
  {
    __js_send_game_server_packet_to__proxy: 'sync',
    __js_dequeue_game_server_packet__proxy: 'sync',

    __js_init_game_server: function () {
      const net = Module['net']
      this.gameServer = new net.GameServer()
    },

    __js_start_game_server: function (port, userTokenPtr, lobbyIdPtr) {
      this.gameServer.start(port, UTF8ToString(userTokenPtr), UTF8ToString(lobbyIdPtr)).then(() => {
        console.log("about to call js game server started!!!")
        _jsGameServerStarted()
      }).catch(_ => {
        
      })
    },

    __js_dequeue_game_server_packet: function (peerIdPtr, lenPtr) {
      const packet = this.gameServer.packets.shift()

      if (packet) {
        const packetData = packet[0]
        const packetSenderId = packet[1]
        const ptr = stackAlloc(packetData.byteLength)
        const byteArray = new Uint8Array(packetData)
        
        setValue(peerIdPtr, packetSenderId, 'i32')
        setValue(lenPtr, packetData.byteLength, 'i32')
        writeArrayToMemory(byteArray, ptr)

        return ptr
      } else {
        return null
      }
    },

    __js_send_game_server_packet_to: function(packetPtr, packetSize, peerId) {
      const data = new Uint8Array(Module.HEAPU8.subarray(packetPtr, packetPtr + packetSize))

      this.gameServer.send(data, peerId)
    },

    __js_close_game_server_client_peer: function(peerId) {
      this.gameServer.closePeer(peerId)
    },

    __js_stop_game_server: function() {
      // this.gameServer.stop()
    }
  });