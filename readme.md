## godot-gds-tcpclient

### example
```gds
extends Control

@onready var tcp_client: TCPClient = TCPClient.new()

func on_connected(_sender) -> void:
	print("connect")
	tcp_client.put_data("GET / HTTP/1.1\r\nHost: baidu.com\r\n\r\n".to_utf8_buffer())

func on_disconnected(_sender) -> void:
	print("disconnect")

func on_message(_sender, data:PackedByteArray) -> void:
	print("message: %s\r\n" % data.get_string_from_utf8())

func _ready():
	add_child(tcp_client)
	tcp_client.connected.connect(on_connected)
	tcp_client.disconnected.connect(on_disconnected)
	tcp_client.message.connect(on_message)
	tcp_client.timeout_second = 30.0
	tcp_client.use_tls = true
	tcp_client.hostname = "baidu.com"
	if tcp_client.connect_to_host("baidu.com", 443) == Error.OK:
		print("connect_to_host ok")
	else:
		print("connect_to_host fail")

```
