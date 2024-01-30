module WinNet 
    def htonl(netlong)
        return [netlong].pack("N").unpack("l").first
    end
    
    def str_to_hostbytes(addr)
        addr = addr.split(".").map{|b| b.to_i}
        return (addr[0] << 24) | (addr[1] << 16) | (addr[2] << 8) | (addr[3] << 0)
    end

end