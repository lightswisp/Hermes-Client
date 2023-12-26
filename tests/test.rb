require 'faye/websocket'
require 'eventmachine'

EM.run {
  ws = Faye::WebSocket::Client.new('wss://sdnet.lol')

  ws.on :open do |event|
    p [:open]
    #ws.send("CONN_INIT")
    #ws.send("CONN_LEASE")
    ws.send("CONN_CLOSE")
  end

  ws.on :message do |event|
    p [:message, event.data]
    #data = [Array.new(100).map{|a| a = Random.rand(2000)}.pack("C*")].pack("m0")
    #p data
    #ws.send(data)
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end
}
