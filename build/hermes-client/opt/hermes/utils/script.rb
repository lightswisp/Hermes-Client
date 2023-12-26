module Script
  def gen_script(hostname)
    <<-EOF

			let local_socket = new WebSocket("ws://127.0.0.1:8000")
			let socket = new WebSocket("wss://#{hostname}");

			local_socket.onopen = function(e){
			#{'	'}
			}

			local_socket.onmessage = function(event){
				socket.send(event.data)
			}

			socket.onopen = function(e) {
			  socket.send("CONN_INIT");
			}

			socket.onmessage = function(event) {
				local_socket.send(event.data)
			};
    EOF
  end
end
