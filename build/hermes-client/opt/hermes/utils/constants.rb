module Conn
  INIT = 'CONN_INIT'
  CLOSE = 'CONN_CLOSE'
  LEASE = 'CONN_LEASE'
  DONE = 'CONN_DONE'
  UUID = SecureRandom.uuid
end
