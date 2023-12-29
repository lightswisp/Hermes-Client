class VPN
  def initialize(ws_client)
    @ws_client = ws_client
    @ws_pipe   = nil
    @tun = nil
    @vpn_server_ip = nil
    @addr = nil
    @default_dns = File.read("/etc/resolv.conf")
  end

  def send(data)
    @ws_pipe.send(data)
  end

  def ws_pipe_init
    Thread.new do
      EM.run do
        WebSocket::EventMachine::Server.start(host: '127.0.0.1', port: 8000) do |ws|
          ws.onopen do |_c|
            LOGGER.info('Websocket pipe between browser and remote server is established.')
            @ws_pipe = ws
          end

          ws.onmessage do |msg, _type|
            case msg
            when Conn::INIT
              LOGGER.info('Connection is established!')
            when /#{Conn::LEASE}/
              @addr = msg.split('/').last
            else
              data = msg.unpack1('m0')
              next if data.empty?

              @tun.to_io.syswrite(data)
            end
          end

          ws.onclose do
            LOGGER.info('Websocket pipe is closed.')
          end
        end
      end
    end
  end

  def setup_dns(dns)
  	LOGGER.info("Setting dns to #{dns}")
		File.write("/etc/resolv.conf", "nameserver #{dns}")
  end

  def restore_dns()
  	puts "Dns settings are restored."
		File.write("/etc/resolv.conf", @default_dns)
  end

  def setup_tun(dev_addr, dev_netmask)
    LOGGER.info("Opening tun device as #{DEV_NAME}")
    tun = RbTunTap::TunDevice.new(DEV_NAME)
    tun.open(true)

    LOGGER.info("Assigning ip #{dev_addr} to device")
    tun.addr    = dev_addr
    tun.netmask = dev_netmask
    tun.up

    LOGGER.info("set #{DEV_NAME} up")
    tun
  end

  def restore_routes
    IO.popen(['ip', 'route', 'del', SERVER_ADDRESS]).close
    puts("ip route del #{SERVER_ADDRESS}")
    IO.popen(['ip', 'route', 'add', 'default', 'via', DEV_MAIN_INTERFACE_DEFAULT_ROUTE, 'dev',
              DEV_MAIN_INTERFACE]).close
    puts("ip route add default via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}")
  end

  def setup_routes(dev_addr)
    LOGGER.info('Setting up routes')
    IO.popen(['ip', 'route', 'add', SERVER_ADDRESS, 'via', DEV_MAIN_INTERFACE_DEFAULT_ROUTE, 'dev',
              DEV_MAIN_INTERFACE]).close
    LOGGER.info("ip route add #{SERVER_ADDRESS} via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}")
    IO.popen(%w[ip route del default]).close
    LOGGER.info('ip route del default')
    IO.popen(['ip', 'route', 'add', 'default', 'via', dev_addr, 'dev', DEV_NAME]).close
    LOGGER.info("ip route add default via #{dev_addr} dev #{DEV_NAME}")
  end

  def lease_address
    send("#{Conn::LEASE}/#{Conn::UUID}")
    LOGGER.info("#{Conn::LEASE} is send with uuid #{Conn::UUID}")
    loop do
      break if @addr
    end

    dev_addr, dev_netmask, public_ip, dns = @addr.split('-')
    [dev_addr, dev_netmask, public_ip, dns]
  end

  def init
    dev_addr, dev_netmask, public_ip, dns = lease_address
    @vpn_server_ip = public_ip
    setup_dns(dns)
    @tun = setup_tun(dev_addr, dev_netmask)
    setup_routes(dev_addr)
    send(Conn::DONE)
    LOGGER.info("init is finished, sending #{Conn::DONE}")
  end

  def disconnect
    if @tun && @tun.opened?
      @tun.down
      @tun.close
    end
    if @tun && @tun.closed?
			restore_routes()
			restore_dns()
			puts('Disconnected')
    end
  end

  def handle_requests
    Thread.new do
      loop do
        buf = @tun.to_io.sysread(MAX_BUFFER)
        send([buf].pack('m0'))
      end
    end
  end
end
