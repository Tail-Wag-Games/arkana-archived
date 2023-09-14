function onIceCandidate(peer, candidate) {
    if (candidate) {
        console.info(`(${peer.id}) received new ICE candidate from peer`)

        peer.candidates.push(candidate)
    }
}

function onSignalingStateChange(peer) {
    if (peer.peerConnection.signalingState == 'closed') {
        console.info('Closed')

        peer.onClosed()
    }
}

function onIceGatheringStateChanged(peer) {
    console.info('Ice gathering state changed: %s', peer.peerConnection.iceGatheringState)

    if (peer.peerConnection.iceGatheringState === 'complete') {
        console.info(`(${peer.id}) all candidates gathered, waiting for the remote peer to be ready to receive them`)

        peer.waitForRemotePeerToBeReadyToReceiveIceCandidates().then(() => {
            if (peer.state !== 'connected') {
                peer.sendCandidates()
            }
        }).catch((err) => {
            console.error(`waitForRemotePeerToBeReadyToReceiveIceCandidates: ${err}`)
        })
    }
}

function onDataChannelOpened(peer, dataChannel) {
    console.info(`(${peer.id}) ${dataChannel.label} data channel opened (id: ${dataChannel.id})`)

    peer.state = 'connected'

    peer.onConnected()
}

function onDataChannelError(peer, dataChannel, err) {
    console.error(`data channel ${dataChannel.label} (id: ${dataChannel.id}) error: ${err}`)
}

function onPacketReceived(peer, packet) {
    peer.onPacketReceived(packet)
}

function Peer(id, uid, connection) {
    this.id = id
    this.uid = uid
    this.connection = connection
    this.candidates = []
    this.peerConnection = new RTCPeerConnection({ 'iceServers': [{ 'urls': 'stun:127.0.0.1:3478' }] })
    this.channel = this.peerConnection.createDataChannel('unreliable',
        { negotiated: true, id: 0, maxRetransmits: 0, ordered: false })
    this.channel.binaryType = 'arraybuffer'

    this.peerConnection.addEventListener('icecandidate', ({ candidate }) => { onIceCandidate(this, candidate) })
    this.peerConnection.addEventListener('signalingstatechange', () => { onSignalingStateChange(this) })
    this.peerConnection.addEventListener('icegatheringstatechange', () => { onIceGatheringStateChanged(this) })
    this.peerConnection.addEventListener('icecandidateerror', (ev) => {
        console.error(`error while gathering ice candidates: ${ev}`)
    })

    this.peerConnection.addEventListener('connectionstatechange', (ev) => {
        console.info('peer connection connection state changed: ', ev)
        if (ev.target.connectionState === 'failed') {
            ev.target.restartIce()
        }
    })
    this.peerConnection.addEventListener('datachannel', (ev) => {
        console.info('data channel added to peer connection: ', ev)
    })

    this.channel.addEventListener('open', () => { onDataChannelOpened(this, this.channel) })
    this.channel.addEventListener('error', () => { onDataChannelError(this, this.channel) })
    this.channel.addEventListener('message', (ev) => { onPacketReceived(this, ev.data) })
}

Peer.prototype.onRemoteDescriptionSet = function (uid) {
    console.info(`(${this.id}) remote description set- notifying remote peer with uid ${uid} that we are ready for ice candidates`)
    this.connection.push(`ready_for_candidates:${uid}`, {})
}

Peer.prototype.send = function (data) {
    try {
        this.channel.send(data)
    } catch (err) {
        console.error(`failed to send: ${err}`)

        this.close()
    }
}

Peer.prototype.sendCandidates = function () {
    console.info(`(${this.id}) sending all gathered candidates to signaling server...`)

    this.candidates.forEach((candidate) => {
        console.info(`(${this.id}) sending candidate to signaling server`)
        this.connection.push(`candidate`, candidate)
    })

    console.info(`(${this.id}) finished sending candidates to signal server`)
}

Peer.prototype.connect = function () {
    this.state = 'connecting'

    // OfferToReceiveAudio & OfferToReceiveVideo seems to be required in Chrome even if we only need data channels
    this.peerConnection.createOffer({ mandatory: { OfferToReceiveAudio: true, OfferToReceiveVideo: true } }).then((offer) => {
        this.peerConnection.setLocalDescription(offer).then(() => {
            console.info('Offer created and set as local description')

            console.info(`${this.id} sending offer: ${JSON.stringify(offer)}`)

            this.connection.push('offer', { from: `${this.uid}`, offer })
        }).catch((err) => {
            console.error(`setLocalDescription: ${err}`)
            return -1
        })
    }).catch((err) => {
        console.error(`createOffer: ${err}`)
        return -1
    })
}

Peer.prototype.handleAnswer = function (answerData) {
    console.info(`(${this.id}) received answer from peer with id: ${answerData.from} - ${JSON.stringify(answerData.answer)}`)

    this.peerConnection.setRemoteDescription(new RTCSessionDescription(answerData.answer)).then(() => {
        this.onRemoteDescriptionSet(answerData.from)
    }).catch((err) => {
        console.error(`setRemoteDescription: ${err}`)
    })
}

Peer.prototype.createAnswer = function (uid) {
    this.peerConnection.createAnswer().then((answer) => {
        this.peerConnection.setLocalDescription(answer).then(() => {
            console.info(`(${this.id}) answer created and set as local description, sending it to peer with user id: ${uid}`)

            this.connection.push(`answer:${uid}`, { from: `${this.uid}:${this.id}`, answer })
        }).catch((err) => {
            console.error(`setLocalDescription: ${err}`)
        })
    }).catch((err) => {
        console.error(`createAnswer: ${err}`)
    })
}

Peer.prototype.handleOffer = function (offerData) {
    console.log(`(${this.id}) handling offer: ${JSON.stringify(offerData.offer)} from peer with id: ${offerData.from}`)

    this.peerConnection.setRemoteDescription(new RTCSessionDescription(offerData.offer)).then(() => {
        this.onRemoteDescriptionSet(offerData.from)
        this.createAnswer(offerData.from)
    }).catch((err) => {
        console.error(`setRemoteDescription: ${err}`)
    })
}

Peer.prototype.handleCandidate = function (candidate) {
    console.info(`attempting to add ice candidate: ${JSON.stringify(candidate)}`)

    if (candidate.candidate) {
        this.peerConnection.addIceCandidate(candidate).then(() => {
            console.info('Candidate added')
        }).catch((err) => {
            console.error(`addIceCandidate: ${err}`)
        })
    }
}

Peer.prototype.waitForRemotePeerToBeReadyToReceiveIceCandidates = function () {
    return new Promise((resolve, reject) => {
        const timeoutId = setTimeout(() => {
            reject('timeout')
        }, 5000)

        const intervalId = setInterval(() => {
            if (this.state === 'connected' || this.remotePeerReadyToReceiveRemoteIceCandidates) {
                clearTimeout(timeoutId)
                clearInterval(intervalId)
                resolve()
            }
        }, 500)
    })
}

Peer.prototype.close = function () {
    console.info('Closing peer...')

    this.peerConnection.close()
    this.connection.close()
}

Module['net'] = {
    GameServer: function () {
        this.peers = {}
        this.users = {}
        this.packets = []
        this.nextPeerId = 0
    },
    GameClient: function () {
        this.signalingClient = window.clientChannel
        this.peer = new Peer(0, window.userId, this.signalingClient)
        this.packets = []

        this.peer.onPacketReceived = (packet) => {
            this.packets.push(packet)
        }
    },
}

Module['net'].GameServer.prototype.handleConnection = function (uid, pid) {
    console.info(`new user with id: ${uid} has connected to the game server`)

    const peer = new Peer(pid, uid, this.signalingServer)

    peer.onConnected = () => {
        peer.candidates = []
        console.info(`peer with id ${peer.id} has successfully opened a data channel with the game server`)
    }

    peer.onPacketReceived = (packet) => {
        if (this.onPacketReceived) {
            this.onPacketReceived(packet, peer.id)
        } else {
            this.packets.push([packet, peer.id])
        }
    }

    console.info(`created new peer with id: ${peer.id} for user with id: ${uid}`)

    gameServer.peers[pid] = peer
    gameServer.users[uid] = pid

    this.signalingServer.on(`offer:${peer.uid}`, offer => {
        peer.handleOffer(offer)
    })

    this.signalingServer.on(`candidate`, candidate => {
        console.info(`(${peer.id}) received candidate from peer`)
        peer.handleCandidate(candidate)
    })

    this.signalingServer.on(`ready_for_candidates:${peer.uid}:${peer.id}`, candidates => {
        console.info(`(${peer.id}) remote is ready to receive list of candidates`)
        peer.remotePeerReadyToReceiveRemoteIceCandidates = true
    })

    console.log("pushing server reaedy!")
    this.signalingServer.push(`server_ready:${peer.uid}`, null)
}

Module['net'].GameServer.prototype.send = function (packet, peerId) {
    const peer = this.peers[peerId]

    if (peer) {
        peer.send(packet)
    } else {
        console.warn(`trying to send packet to unknown peer with id: ${peerId}`)
    }
}

Module['net'].GameServer.prototype.start = function (port, userToken, lobbyId) {
    return new Promise((resolve, reject) => {
        // let serverSocket = new Phoenix.Socket("/socket", {params: {token: userToken}})
        // let serverChannel = serverSocket.channel(`arkana:${lobbyId}`, {})
        // let serverPresence = new Phoenix.Presence(serverChannel)

        // serverSocket.onOpen( ev => console.log("OPEN", ev) )
        // serverSocket.onError( ev => console.log("ERROR", ev) )
        // serverSocket.onClose( e => console.log("CLOSE", e))

        // serverSocket.connect()

        // this.signalingServer = serverChannel
        // this.presence = serverPresence

        this.signalingServer = window.serverChannel
        this.presence = window.serverPresence

        this.presence.onSync(() => {
            this.presence.list((uid, { metas: [first, ...rest] }) => {
                console.info(`syncing user with id: ${uid}`)

                !(uid in this.users) && this.handleConnection(uid, this.nextPeerId++)
            })
        })

        this.signalingServer.onError(e => console.log("something went wrong", e))
        this.signalingServer.onClose(e => console.log("channel closed", e))

        this.signalingServer.join()
            .receive("ignore", () => reject())
            .receive("ok", () => resolve())
            .receive("error", resp => { reject() })
            .receive("timeout", () => reject())
    })
}

Module['net'].GameServer.prototype.closePeer = function (peerId) {
    const peer = this.peers[peerId]

    if (peer) {
        peer.close()
    }
}


Module['net'].GameClient.prototype.send = function (data) {
    this.peer.send(data)
}

Module['net'].GameClient.prototype.connect = function (host, port) {
    return new Promise((resolve, reject) => {
        console.log("attempting to join socket channel")

        this.signalingClient.join()
            .receive("ignore", () => console.log("auth error"))
            .receive("ok", () => console.log("join ok"))
            .receive("error", resp => { console.log("unable to join signaling server", resp) })
            .receive("timeout", () => console.log("game client connection to signaling server timed out"))

        this.peer.onConnected = () => {
            console.info('game client is connected to data channel')
            this.peer.candidates = []
            resolve()
        }

        this.peer.onConnectionError = (err) => {
            console.error(`connection failed: ${err}`)
            reject(err)
        }

        this.signalingClient.on(`answer:${this.peer.uid}`, answerData => {
            this.peer.handleAnswer(answerData)
        })

        this.signalingClient.on(`ready_for_candidates:${this.peer.uid}`, candidates => {
            console.info(`(${this.peer.id}) remote is ready to receive list of candidates`)
            this.peer.remotePeerReadyToReceiveRemoteIceCandidates = true
        })

        this.signalingClient.on(`candidate`, candidate => {
            console.info(`(${this.peer.id}) received candidate from peer`)
            this.peer.handleCandidate(candidate)
        })

        this.signalingClient.on(`server_ready:${this.peer.uid}`, msg => {
            console.info(`(${this.peer.id}) received server_ready message - attempting to connnect to signaling serever`)
            this.peer.connect()
        })
    })
}
