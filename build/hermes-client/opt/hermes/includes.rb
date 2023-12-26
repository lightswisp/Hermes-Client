require 'ferrum'
require 'websocket-eventmachine-server'
require 'socket'
require 'colorize'
require 'base64'
require 'securerandom'
require 'timeout'
require 'logger'
require 'rb_tuntap'
require 'resolv'
require 'json'
require_relative 'utils/vpn'
require_relative 'utils/ws_client'
require_relative 'utils/script'
require_relative 'utils/constants'
include Script