require 'fiddle/import'
require 'fiddle/types'

# module Kernel32 
#   extend Fiddle::Importer
#   #include Fiddle::Win32Types
#   dlload 'kernel32.dll'
#   extern 'void* LoadLibraryExW(const char* lpLibFileName, void* hFile, unsigned long dwFlags)'
# end

module WinAPI
  extend Fiddle::Importer
  
  dlload 'Iphlpapi.dll'
  include Fiddle::Win32Types
  extern 'void InitializeUnicastIpAddressEntry(void* AddressRow)'
  extern 'int CreateUnicastIpAddressEntry(void* Row)'
  extern 'unsigned long GetAdaptersInfo(void* AdapterInfo, void* SizePointer)'
end

module WinStructs
  extend Fiddle::Importer
  # typedef struct _GUID {
  #     unsigned long  Data1;
  #     unsigned short Data2;
  #     unsigned short Data3;
  #     unsigned char  Data4[8];
  # } GUID;
  GUID = struct [
    'unsigned long Data1',
    'unsigned short Data2',
    'unsigned short Data3',
    'unsigned char Data4[8]'
  ]

  IN_ADDR = struct [
    { S_un: union([
                    {
                      S_un_b: struct([
                                       'unsigned char s_b1',
                                       'unsigned char s_b2',
                                       'unsigned char s_b3',
                                       'unsigned char s_b4'
                                     ]),
                      S_un_w: struct([
                                       'unsigned short s_w1',
                                       'unsigned short s_w2'
                                     ])
                    },
                    'unsigned long S_addr'
                  ]) }
  ]

  SOCKADDR_IN = struct [
    'unsigned short sin_family',
    'unsigned short sin_port',
    { sin_addr: IN_ADDR },
    'char sin_zero[8]'
  ]

  # typedef union _SOCKADDR_INET {
  #     SOCKADDR_IN Ipv4;
  #     SOCKADDR_IN6 Ipv6;
  #     ADDRESS_FAMILY si_family;
  # } SOCKADDR_INET, *PSOCKADDR_INET;

  SOCKADDR_INET = union [
    { Ipv4: SOCKADDR_IN },
    'void* Ipv6',
    'unsigned short si_family'
  ]

  # typedef union _NET_LUID_LH
  # {
  #     ULONG64     Value;
  #     struct
  #     {
  #         ULONG64     Reserved:24;
  #         ULONG64     NetLuidIndex:24;
  #         ULONG64     IfType:16;
  #     }Info;
  # } NET_LUID_LH, *PNET_LUID_LH;

  NET_LUID = union [
    'unsigned long long Value',
    { Info: struct([
                     'unsigned char Reserved[10]',
                     'unsigned char NetLuidIndex[10]',
                     'unsigned char IfType[4]'
                   ]) }
  ]

  # typedef struct _MIB_UNICASTIPADDRESS_ROW {
  #     SOCKADDR_INET    Address;
  #     NET_LUID         InterfaceLuid;
  #     NET_IFINDEX      InterfaceIndex;
  #     NL_PREFIX_ORIGIN PrefixOrigin;
  #     NL_SUFFIX_ORIGIN SuffixOrigin;
  #     ULONG            ValidLifetime;
  #     ULONG            PreferredLifetime;
  #     UINT8            OnLinkPrefixLength;
  #     BOOLEAN          SkipAsSource;
  #     NL_DAD_STATE     DadState;
  #     SCOPE_ID         ScopeId;
  #     LARGE_INTEGER    CreationTimeStamp;
  # } MIB_UNICASTIPADDRESS_ROW, *PMIB_UNICASTIPADDRESS_ROW;

  MIB_UNICASTIPADDRESS_ROW = struct [
    { Address: SOCKADDR_INET },
    { InterfaceLuid: NET_LUID },
    'unsigned long InterfaceIndex',
    'int PrefixOrigin',
    'int SuffixOrigin',
    'unsigned long ValidLifetime',
    'unsigned long PreferredLifetime',
    'unsigned char OnLinkPrefixLength',
    'unsigned char SkipAsSource',
    'int DadState',
    'void* ScopeId',
    'void* CreationTimeStamp'
  ]

  # typedef struct {
  #     char String[4 * 4];
  # } IP_ADDRESS_STRING, *PIP_ADDRESS_STRING, IP_MASK_STRING, *PIP_MASK_STRING;

  IP_ADDRESS_STRING = struct [
    'char String[16]'
  ]

  # typedef struct _IP_ADDR_STRING {
  #     struct _IP_ADDR_STRING* Next;
  #     IP_ADDRESS_STRING IpAddress;
  #     IP_MASK_STRING IpMask;
  #     DWORD Context;
  # } IP_ADDR_STRING, *PIP_ADDR_STRING;

  IP_ADDR_STRING = struct [
    'void* Next',
    { IpAddress: IP_ADDRESS_STRING },
    { IpMask: IP_ADDRESS_STRING },
    'unsigned long Context'
  ]

  # typedef struct _IP_ADAPTER_INFO {
  #     struct _IP_ADAPTER_INFO* Next;
  #     DWORD ComboIndex;
  #     char AdapterName[MAX_ADAPTER_NAME_LENGTH + 4];
  #     char Description[MAX_ADAPTER_DESCRIPTION_LENGTH + 4];
  #     UINT AddressLength;
  #     BYTE Address[MAX_ADAPTER_ADDRESS_LENGTH];
  #     DWORD Index;
  #     UINT Type;
  #     UINT DhcpEnabled;
  #     PIP_ADDR_STRING CurrentIpAddress;
  #     IP_ADDR_STRING IpAddressList;
  #     IP_ADDR_STRING GatewayList;
  #     IP_ADDR_STRING DhcpServer;
  #     BOOL HaveWins;
  #     IP_ADDR_STRING PrimaryWinsServer;
  #     IP_ADDR_STRING SecondaryWinsServer;
  #     time_t LeaseObtained;
  #     time_t LeaseExpires;
  # } IP_ADAPTER_INFO, *PIP_ADAPTER_INFO;

  IP_ADAPTER_INFO = struct [
    'void* Next',
    'unsigned long ComboIndex',
    'char AdapterName[260]',
    'char Description[132]',
    'unsigned int AddressLength',
    'unsigned char Address[8]',
    'unsigned long Index',
    'unsigned int Type',
    'unsigned int DhcpEnabled',
    'void* CurrentIpAddress',
    { IpAddressList: IP_ADDR_STRING },
    { GatewayList: IP_ADDR_STRING },
    { DhcpServer: IP_ADDR_STRING },
    'int HaveWins',
    { PrimaryWinsServer: IP_ADDR_STRING },
    { SecondaryWinsServer: IP_ADDR_STRING },
    'long long LeaseObtained',
    'long long LeaseExpires'
  ]
end

module WinTun
  RubyInstaller::Runtime.add_dll_directory(File.expand_path('lib/windows', Dir.pwd))
  extend Fiddle::Importer
  if RUBY_PLATFORM.include?('x64') # if 64 bit
    dlload 'wintun.dll'
  else
    dlload 'wintun32.dll' # if 32 bit
  end

  include Fiddle::Win32Types

  extern 'void* WintunCreateAdapter(const wchar_t* NAME, const wchar_t* TYPE, void* RequestedGUID)'
  extern 'int WintunGetRunningDriverVersion()'
  extern 'void WintunGetAdapterLUID(void* Adapter, void* Luid)'
  extern 'void* WintunStartSession(void* Adapter, unsigned long Capacity)'
  extern 'void WintunCloseAdapter(void* Adapter)'
  extern 'unsigned char* WintunReceivePacket(void* Session, unsigned long* PacketSize)'
  extern 'void WintunReleaseReceivePacket(void* Session, const unsigned char* Packet)'
  extern 'unsigned char* WintunAllocateSendPacket(void* Session, unsigned long PacketSize)'
  extern 'void WintunSendPacket(void* Session, const unsigned char* Packet)'

  class TunDevice
    attr_accessor :addr, :netmask

    def initialize(name, logger)
      @name = name
      @logger = logger
      @opened = false
      @adapter = nil
      @session = nil
    end

    def up
      unless @addr && @netmask
        @logger.fatal('Address or netmask are not specified!')
        exit
      end

      guid = WinStructs::GUID.malloc
      guid.Data1 = 0xdeadbabe
      guid.Data2 = 0xcafe
      guid.Data3 = 0xbeef
      guid.Data4 = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]

      name = @name.encode('UTF-16LE')
      @adapter = WinTun.WintunCreateAdapter(name, name, guid)

      if Fiddle.win32_last_error != 0
        @logger.fatal("Failed to create WinTun adapter! Error code: #{Fiddle.win32_last_error}")
        exit
      end

      version = WinTun.WintunGetRunningDriverVersion()
      @logger.info(format("Wintun v%u.%u loaded\n", (version >> 16) & 0xff, (version >> 0) & 0xff))

      address_row = WinStructs::MIB_UNICASTIPADDRESS_ROW.malloc
      @logger.info("AddressRow => #{address_row}")
      WinAPI.InitializeUnicastIpAddressEntry(address_row)

      luid_offset = 0x20
      WinTun.WintunGetAdapterLUID(@adapter, Fiddle::Pointer.new(address_row.to_ptr.to_i + luid_offset))

      address_row.Address.Ipv4.sin_family = 2 # AF_INET
      h = WinNet.str_to_hostbytes(@addr)
      host = WinNet.htonl(h)

      address_row.Address.Ipv4.sin_addr.S_un.S_addr = host
      address_row.OnLinkPrefixLength = @netmask; # /24 => 255.255.255.0
      address_row.DadState = 4 # IpDadStatePreferred = 4

      last_error = WinAPI.CreateUnicastIpAddressEntry(address_row)
      # ERROR_SUCCESS = 0
      # ERROR_OBJECT_ALREADY_EXISTS = 5010
      if last_error != 0 && last_error != 5010
        @logger.fatal("Failed to set IP address, error #{last_error}")
        close
        exit
      end

      @session = WinTun.WintunStartSession(@adapter, 0x4000000)

      if @session.null?
        @logger.fatal('Failed to create adapter')
        close
        exit
      end

      @logger.info('WinTun session is started!')
      @opened = true
    end

    def opened?
      @opened
    end

    def read(packetSize, packetSize_ptr)
        packet = WinTun.WintunReceivePacket(@session, packetSize_ptr)
        return if packet.null?

        size = packetSize.unpack1('i')
        WinTun.WintunReleaseReceivePacket(@session, packet)
        packet[0, size]
    end

    def write(data)
      packet = WinTun.WintunAllocateSendPacket(@session, data.size)
      if !packet.null?
        packet[0, data.size] = data
        WinTun.WintunSendPacket(@session, packet)
      elsif Fiddle.win32_last_error != 111 # Buffer overflow
        @logger.fatal("Packet write failed: #{Fiddle.win32_last_error}")
      end
    end

    def close
      WinTun.WintunCloseAdapter(@adapter)
      @opened = false
    end
  end
end
