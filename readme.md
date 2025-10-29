## godot-gds-tcpclient

### example
```gds
extends Control

@onready var tcp_client:TCPClient = TCPClient.new()

func _ready() -> void:
	tcp_client.on_connect.connect(on_connect)
	tcp_client.on_disconnect.connect(on_disconnect)
	tcp_client.on_message.connect(on_message)

    # tcp_client.disconnect_from_host()
	if tcp_client.connect_to_host("baidu.com", 443, true, "baidu.com") == Error.OK:
		print("connect_to_host ok")
	else:
		print("connect_to_host fail")

func _exit_tree() -> void:
	tcp_client.disconnect_from_host()

func _process(delta: float) -> void:
	tcp_client.poll()

func on_connect(sender:TCPClient) -> void:
	print("on_connect")
	sender.put_data("GET / HTTP/1.1\r\nHost: baidu.com\r\n\r\n".to_utf8_buffer())

func on_disconnect(sender:TCPClient) -> void:
	print("on_disconnect")

func on_message(sender:TCPClient, data:PackedByteArray) -> void:
	print("on_message: %s" % data.get_string_from_utf8())

```