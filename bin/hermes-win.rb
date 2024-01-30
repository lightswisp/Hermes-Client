require_relative '../includes/windows'

LOGGER = Logger.new(STDOUT)
LOGGER.info("Starting on #{RUBY_PLATFORM}")

CONFIG_PATH = ENV["APPDATA"] + "\\Hermes"
CONFIG_NAME = "#{CONFIG_PATH}\\config.json"

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

lan_ip = UDPSocket.open {|s| s.connect("8.8.8.8", 1); s.addr.last}
adapter_info = WinStructs::IP_ADAPTER_INFO.malloc()
iface_index = nil
iface_default_gateway = nil

buflen = [0x2C0].pack("L_")
if WinAPI.GetAdaptersInfo(adapter_info, Fiddle::Pointer[buflen]) == 111
    new_size = buflen.unpack("L_").first
    LOGGER.warn("Buffer overflow! Adjusting the size to #{new_size}")
    Fiddle::Pointer[adapter_info].free()
    adapter_info = Fiddle::Pointer.malloc(new_size)
end

# Unfortunately, Fiddle structs don't have realloc method :(

new_adapter_info = WinStructs::IP_ADAPTER_INFO.new(adapter_info)

if WinAPI.GetAdaptersInfo(new_adapter_info, Fiddle::Pointer[buflen]) == 0
    while new_adapter_info && !Fiddle::Pointer[new_adapter_info].null?

        ip_addr = new_adapter_info.IpAddressList.IpAddress.String.pack('U*').delete("\000")
        if ip_addr == lan_ip
            name  = new_adapter_info.AdapterName.pack('U*').delete("\000")
            iface_index = new_adapter_info.Index.to_s
            iface_default_gateway = new_adapter_info.GatewayList.IpAddress.String.pack('U*').delete("\000")
            LOGGER.info("Selected interface name: #{name}") 
            LOGGER.info("Selected interface index: #{iface_index}") 
            LOGGER.info("Selected interface ip address: #{ip_addr}") 
            LOGGER.info("Selected interface default gateway ip address: #{iface_default_gateway}") 
            break
        end

        new_adapter_info = WinStructs::IP_ADAPTER_INFO.new(new_adapter_info.Next)
    end
end

server_hostname = CONFIG['server']
server_address = Resolv.getaddress(server_hostname)
max_buffer = CONFIG['max_buffer']
script = Script.gen_script(server_hostname)
ws_client = nil
vpn = nil

trap 'SIGINT' do
    puts('Closing the browser...')
    Thread.new do
        if vpn
            vpn.disconnect
        end
        if ws_client
            ws_client.close
        end
    end
    sleep 1
    exit
end

ws_client = WSClient.new(script, LOGGER)
vpn = VPNWindows.new(
											ws_client,
											LOGGER, 
											server_address, 
											max_buffer, 
											iface_index, 
											iface_default_gateway
										)

vpn.init							# get address, init tun, etc...
vpn.handle_requests


sleep

