require_relative "includes"
LOGGER = Logger.new(STDOUT)


unless Process.uid.zero?
	LOGGER.warn("You must run it with root privileges!".yellow.bold)
	exit
end

begin
	CONFIG = JSON.parse(File.read("config.json"))
rescue Errno::ENOENT
	LOGGER.warn("config.json not found!".yellow.bold)
	exit
rescue JSON::ParserError
	LOGGER.warn("Couldn't parse the config!".yellow.bold)
	exit
end

REQUIRED_KEYS = ["server", "max_buffer"]
CONFIG_DIFF = (REQUIRED_KEYS - CONFIG.keys)
unless CONFIG_DIFF.empty?
	LOGGER.warn("#{CONFIG_DIFF.join(', ')} are missing!".yellow.bold)
end

unless CONFIG.include?("default_interface")
	puts "Please select your interface number: ".bold
	interfaces = Socket.getifaddrs
	interfaces.reject!{|i| !i.addr.ipv4?}.reject!{|i| i.addr.ipv4_loopback?}.each.with_index do |i, j|
		puts "#{i.name} => #{j.to_s.bold.yellow}"
	end
	user_choice = 0
	loop do
		print("\n> ")
		user_choice = gets.chomp.to_i
		
		break if interfaces[user_choice]
		interfaces.each.with_index do |i, j|
			puts "#{i.name} => #{j.to_s.bold.yellow}"
		end
	end
	DEV_MAIN_INTERFACE = interfaces[user_choice]
else
	DEV_MAIN_INTERFACE = CONFIG["default_interface"]
end


SERVER_HOSTNAME = CONFIG["server"]
SERVER_ADDRESS = Resolv.getaddress(SERVER_HOSTNAME)
MAX_BUFFER = CONFIG["max_buffer"]
SCRIPT = Script::gen_script(SERVER_HOSTNAME)
DEV_NAME = 'tun0'
DEV_MAIN_INTERFACE_DEFAULT_ROUTE = `ip route show default`.strip.split[2]


ws_client = nil
vpn = nil

trap 'SIGINT' do
	puts('Closing the browser...')
	if ws_client && vpn
		vpn.send("#{Conn::CLOSE}/#{Conn::UUID}")
		ws_client.close() 
		vpn.disconnect()
	end
	exit
end

ws_client = WSClient.new(SCRIPT)

vpn = VPN.new(ws_client)
vpn.ws_pipe_init() 			# initialize the pipe between the browser and ruby
ws_client.ws_init()			# Connect via WebSockets to the remote server

sleep 2

vpn.init()							# get address, init tun, etc...
vpn.handle_requests()


sleep 
