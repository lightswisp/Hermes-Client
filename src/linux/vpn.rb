require_relative 'tun/tun'

class VPNLinux
  def initialize(ws_client, logger, server_address, max_buffer, default_route, dev_main_interface, dev_name = 'tun0')
    @ws_client = ws_client
    @logger = logger
    @server_address = server_address
    @max_buffer = max_buffer
    @default_route = default_route
    @dev_main_interface = dev_main_interface
    @dev_name = dev_name
    @ws_pipe = nil
    @tun = nil
    @vpn_server_ip = nil
    @addr = nil
    @default_dns = File.read('/etc/resolv.conf')
  end

  def send(data)
    @ws_pipe.send(data)
  end

  def ws_pipe_init
    Thread.new do
      EM.run do
        WebSocket::EventMachine::Server.start(host: '127.0.0.1', port: 8000) do |ws|
          ws.onopen do |_c|
            @logger.info('Websocket pipe between browser and remote server is established.')
            @ws_pipe = ws
          end

          ws.onmessage do |msg, _type|
            case msg
            when Conn::INIT
              @logger.info('Connection is established!')
            when /#{Conn::LEASE}/
              @addr = msg.split('/').last
            else
              data = msg.unpack1('m0')
              next if data.empty?

              @tun.to_io.syswrite(data) unless @tun.closed?
            end
          end

          ws.onclose do
            @logger.info('Websocket pipe is closed.')
          end
        end
      end
    end
  end

  def setup_dns(dns)
    @logger.info("Setting dns to #{dns}")
    File.write('/etc/resolv.conf', "nameserver #{dns}")
  end

  def restore_dns
    @logger.info('Dns settings are restored.')
    File.write('/etc/resolv.conf', @default_dns)
  end

  def setup_tun(dev_addr, dev_netmask)
    @logger.info("Opening tun device as #{@dev_name}")

    tun = RubyTun::TunDevice.new(@dev_name)
    tun.open
    tun.init
    @logger.info("Assigning ip #{dev_addr} to device")
    tun.set_addr(dev_addr)
    tun.set_netmask(dev_netmask)
    tun.up
    tun.tun
  end

  def restore_routes
    IO.popen(['ip', 'route', 'del', @server_address]).close
    @logger.info("ip route del #{@server_address}")
    IO.popen(['ip', 'route', 'add', 'default', 'via', @default_route, 'dev',
              @dev_main_interface]).close
    @logger.info("ip route add default via #{@default_route} dev #{@dev_main_interface}")
  end

  def setup_routes(dev_addr)
    @logger.info('Setting up routes')
    IO.popen(['ip', 'route', 'add', @server_address, 'via', @default_route, 'dev',
              @dev_main_interface]).close
    @logger.info("ip route add #{@server_address} via #{@default_route} dev #{@dev_main_interface}")
    IO.popen(%w[ip route del default]).close
    @logger.info('ip route del default')
    IO.popen(['ip', 'route', 'add', 'default', 'via', dev_addr, 'dev', @dev_name]).close
    @logger.info("ip route add default via #{dev_addr} dev #{@dev_name}")
  end

  def lease_address
    send(Conn::LEASE)
    @logger.info("#{Conn::LEASE} is send")
    sleep(1) until @addr

    dev_addr, dev_netmask, public_ip, dns = @addr.split('-')
    [dev_addr, dev_netmask, public_ip, dns]
  end

  def init
    ws_pipe_init() 			# initialize the pipe between the browser and ruby
    @ws_client.ws_init			# Connect via WebSockets to the remote server_address
		sleep(1) until @ws_client.connected?
    
    dev_addr, dev_netmask, public_ip, dns = lease_address
    @vpn_server_ip = public_ip
    setup_dns(dns)
    @tun = setup_tun(dev_addr, dev_netmask)
    setup_routes(dev_addr)
    send(Conn::DONE)
    @logger.info("Connected".green.bold)
  end

  def disconnect
  	if @tun && !@tun.closed?
	    send(Conn::CLOSE)
	    @tun.close
	    
	    restore_routes
	    restore_dns
	    @logger.info('Tun device is closed')
    end
  end

  def handle_requests
    Thread.new do
      loop do
        buf = @tun.to_io.sysread(@max_buffer) unless @tun.closed?
        send([buf].pack('m0'))
      rescue IOError
        break
      end
    end
  end
end
