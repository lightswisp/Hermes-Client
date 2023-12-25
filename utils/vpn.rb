class VPN

  def initialize(ws_client)
    @ws_client = ws_client
    @ws_pipe   = nil
    @tun = nil
    @vpn_server_ip = nil
    @addr = nil
  end

   def send(data)
		@ws_pipe.send(data)
   end

   def ws_pipe_init()
		Thread.new{
				EM.run do
				
				  WebSocket::EventMachine::Server.start(:host => "127.0.0.1", :port => 8000) do |ws|
				    ws.onopen do |c|
				      LOGGER.info("Websocket pipe between browser and remote server is established.")
				    	@ws_pipe = ws
				    end
				
				    ws.onmessage do |msg, type|
				      case msg
								when Conn::INIT
									LOGGER.info("Connection is established!")
								when /#{Conn::LEASE}/
									@addr = msg.split("/").last
								else
									data = msg.unpack('m0').first
									next if data.empty?
									@tun.to_io.syswrite(data)
				      end
				
				    end
				
				    ws.onclose do
				      LOGGER.info("Websocket pipe is closed.")
				    end
				  end
				
				end
			}
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
    return tun
  end

  def restore_routes
      `ip route del #{SERVER_ADDRESS}`
      puts("ip route del #{SERVER_ADDRESS}")
      `ip route add default via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}`
      puts("ip route add default via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}")
  end

  def setup_routes(dev_addr)
		LOGGER.info("Setting up routes")
    `ip route add #{SERVER_ADDRESS} via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}`
    LOGGER.info("ip route add #{SERVER_ADDRESS} via #{DEV_MAIN_INTERFACE_DEFAULT_ROUTE} dev #{DEV_MAIN_INTERFACE}")
    `ip route del default`
    LOGGER.info("ip route del default")
    `ip route add default via #{dev_addr} dev #{DEV_NAME}`
    LOGGER.info("ip route add default via #{dev_addr} dev #{DEV_NAME}")
  end

  def lease_address()
		send("#{Conn::LEASE}/#{Conn::UUID}")
		LOGGER.info("#{Conn::LEASE} is send with uuid #{Conn::UUID}")
		loop do
			break if @addr
		end

		dev_addr, dev_netmask, public_ip = @addr.split('-')
		return [dev_addr, dev_netmask, public_ip]
  end

  def init()
		dev_addr, dev_netmask, public_ip = lease_address()
		@vpn_server_ip = public_ip
		@tun = setup_tun(dev_addr, dev_netmask)
		setup_routes(dev_addr)
		send(Conn::DONE)
		LOGGER.info("init is finished, sending #{Conn::DONE}")
  end

  def disconnect()
		if @tun && @tun.opened?
	      @tun.down
	      @tun.close
    end
    restore_routes if @tun && @tun.closed?
    puts("Disconnected")
  end

  def handle_requests
    Thread.new{
      loop do
				buf = @tun.to_io.sysread(MAX_BUFFER)
				send([buf].pack("m0"))
      end
    }
  end

end
