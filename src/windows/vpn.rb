class VPNWindows
  def initialize(ws_client, logger, server_address, iface_index, iface_default_gateway, dev_name = 'win0')
    @ws_client = ws_client
    @logger = logger
    @server_address = server_address
    @iface_index = iface_index
    @iface_default_gateway = iface_default_gateway
    @dev_name = dev_name
    @vpn_server_ip = nil
    @ws_pipe = nil
    @tun = nil
  end

  def send(data)
    @ws_pipe.send(data)
  end

  def ws_pipe_init
    Thread.new do
      EM.run do
        WebSocket::EventMachine::Server.start(host: '127.0.0.1', port: 8000) do |ws|
          ws.onopen do |_c|
            @logger.info('Websocket pipe between browser and local websocket server is established.')
            @ws_pipe = ws
            @logger.info("Trying to establish the connection with remote server...")
          end

          ws.onmessage do |msg, _type|
            case msg
            when Conn::INIT
              @logger.info('Connection with the remote server is established!')
            when /#{Conn::LEASE}/
              @addr = msg.split('/').last
            else
              data = msg.unpack1('m0')
              next if data.empty?

              # p "RECV: #{data.unpack('H*')}"
              @tun.write(data) if @tun && @tun.opened?
            end
          end

          ws.onclose do
            @logger.info('Websocket pipe is closed.')
          end
        end
      end
    end
  end

  def lease_address
    send(Conn::LEASE)
    @logger.info("#{Conn::LEASE} is sent")
    sleep(1) until @addr

    dev_addr, dev_netmask, public_ip, dns = @addr.split('-')
    [dev_addr, dev_netmask, public_ip, dns]
  end

  def setup_tun(dev_addr, dev_netmask)
    @logger.info("Opening tun device as #{@dev_name}")
    tun = WinTun::TunDevice.new(@dev_name, @logger)

    @logger.info("Assigning ip #{dev_addr} to device")
    tun.addr = dev_addr
    tun.netmask = dev_netmask
    tun.up
    @logger.info("set #{@dev_name} up")
    tun
  end

  def setup_routes(dev_addr)
    @logger.info('Setting up routes')
    # # ADD
    IO.popen(['route', 'add', @server_address, 'mask', '255.255.255.255', @iface_default_gateway, 'IF',
              @iface_index]).close
    @logger.info("route add #{@server_address} mask 255.255.255.255 #{@iface_default_gateway} IF #{@iface_index}")
    IO.popen(['route', 'delete', '0.0.0.0']).close
    @logger.info('route delete 0.0.0.0')
    IO.popen(['route', 'add', '0.0.0.0', 'mask', '0.0.0.0', dev_addr]).close
    @logger.info("route add 0.0.0.0 mask 0.0.0.0 #{dev_addr}")
  end

  def restore_routes
    IO.popen(['route', 'delete', @server_address, 'IF', @iface_index]).close
    @logger.info("route delete #{@server_address} IF #{@iface_index}")
    IO.popen(['route', 'add', '0.0.0.0', 'mask', '0.0.0.0', @iface_default_gateway, 'IF', @iface_index]).close
    @logger.info("route add 0.0.0.0 mask 0.0.0.0 #{@iface_default_gateway} IF #{@iface_index}")
  end

  def init
    ws_pipe_init()
    @ws_client.ws_init 

    sleep(1) until @ws_client.connected?

    dev_addr, dev_netmask, public_ip, dns = lease_address
    dev_netmask = IPAddr.new(dev_netmask).to_i.to_s(2).count('1')
    @vpn_server_ip = public_ip
    @logger.info("Leased ip from the server(#{public_ip}): #{dev_addr}/#{dev_netmask}")

    @tun = setup_tun(dev_addr, dev_netmask)

    setup_routes(dev_addr)
    send(Conn::DONE)
    @logger.info("Connected".green.bold)
  end

  def handle_requests
    Thread.new do
      packetSize = [0].pack('i')
      packetSize_ptr = Fiddle::Pointer[packetSize]
      loop do
        next unless @tun && @tun.opened?
        buf = @tun.read(packetSize, packetSize_ptr)
        next if buf.nil? || buf.empty?

        send([buf].pack('m0'))
      end
    end
  end

  def disconnect
    if @tun && @tun.opened?
      send(Conn::CLOSE)
      @tun.close

      restore_routes
      @logger.info('Tun device is closed')
    end
  end
end
