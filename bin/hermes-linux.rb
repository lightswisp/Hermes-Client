require_relative '../includes/linux'
LOGGER = Logger.new(STDOUT)
LOGGER.info("Starting on #{RUBY_PLATFORM}")
CONFIG_PATH = '/etc/hermes'
CONFIG_NAME = "#{CONFIG_PATH}/config.json"

unless Process.uid.zero?
  LOGGER.warn('You must run it with root privileges!'.yellow.bold)
  exit
end

begin
  unless File.exist?(CONFIG_PATH)
    Dir.mkdir(CONFIG_PATH) unless Dir.exist?(CONFIG_PATH)
    f = File.new(CONFIG_NAME, 'w+')
    f.write('{}')
    LOGGER.warn("New config is created at #{CONFIG_NAME}".yellow.bold)
    exit
  end
  CONFIG = JSON.parse(File.read(CONFIG_NAME))
rescue Errno::ENOENT
  LOGGER.warn("#{CONFIG_NAME} not found!".yellow.bold)
  exit
rescue JSON::ParserError
  LOGGER.warn("Couldn't parse the config!".yellow.bold)
  exit
end

REQUIRED_KEYS = %w[server max_buffer]
CONFIG_DIFF = (REQUIRED_KEYS - CONFIG.keys)

unless CONFIG_DIFF.empty?
  LOGGER.warn("#{CONFIG_DIFF.join(', ')} are missing!".yellow.bold)
  exit
end

if CONFIG.include?('default_interface')
  DEV_MAIN_INTERFACE = CONFIG['default_interface']
else
  # selecting the default iface
  lan_ip = # i should change static 8.8.8.8 later and make it configurable
    UDPSocket.open do |s|
      s.connect('8.8.8.8', 1)
      s.addr.last
    end
  interfaces = Socket.getifaddrs
  interface = nil
  interfaces.each do |i|
    next unless i.addr
    next unless i.addr.ip?
    next unless i.addr.ipv4?

    if i.addr.ip_address == lan_ip
      interface = i
      break
    end
  end

  dev_main_interface = interface.name
end

server_hostname = CONFIG['server']
server_address = Resolv.getaddress(server_hostname)
max_buffer = CONFIG['max_buffer']
script = Script.gen_script(server_hostname)
dev_name = 'tun0'
default_route = `ip route show default`.strip.split[2]

ws_client = nil
vpn = nil

trap 'SIGINT' do
  puts('Closing the browser...')
  vpn.disconnect if vpn
  ws_client.close if ws_client
  sleep 1
  exit
end

ws_client = WSClient.new(script, LOGGER)

vpn = VPNLinux.new(
  ws_client,
  LOGGER,
  server_address,
  max_buffer,
  default_route,
  dev_main_interface,
  dev_name
)

vpn.init	# get address, init tun, etc...
vpn.handle_requests

sleep
