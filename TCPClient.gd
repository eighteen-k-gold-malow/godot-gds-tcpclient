
class_name TCPClient

signal on_connect(sender:TCPClient)
signal on_disconnect(sender:TCPClient)
signal on_message(sender:TCPClient, data:PackedByteArray)

enum Status {
	STATUS_CONNECTED,
	STATUS_DISCONNECTED,
	STATUS_CONNECTING,
	STATUS_HANDSHAKEING
}

var _tcp:StreamPeerTCP = null
var _tls:StreamPeerTLS = null
var _is_use_tls:bool = false
var _status:Status = Status.STATUS_DISCONNECTED
var _tls_hostname:String = ""

func _init() -> void:
	_tcp = StreamPeerTCP.new()
	_tls = StreamPeerTLS.new()

func connect_to_host(address:String, port:int,use_tls:bool=false, tls_hostname:String="") -> Error:
	if _status != Status.STATUS_DISCONNECTED:
		return Error.ERR_BUSY
	_status = Status.STATUS_CONNECTING
	_is_use_tls = use_tls
	_tls_hostname = tls_hostname
	var err:Error = _tcp.connect_to_host(address, port)
	if err != Error.OK:
		_status = Status.STATUS_DISCONNECTED
	return err

func _disconnect_from_host(is_poll:bool=true) -> void:
	if _tls.get_status() != _tls.STATUS_DISCONNECTED:
		_tls.disconnect_from_stream()
	if _tcp.get_status() != _tcp.STATUS_NONE:
		_tcp.disconnect_from_host()
	if is_poll:
		poll()

func disconnect_from_host() -> void:
	_disconnect_from_host(true)

func get_status() -> Status:
	return _status

func is_use_tls() -> bool:
	return _is_use_tls

func get_tls_hostname() -> String:
	return _tls_hostname

func put_data(data:PackedByteArray) -> Error:
	if _is_use_tls:
		return _tls.put_data(data)
	else:
		return _tcp.put_data(data)

func poll() -> void:
	match _status:
		Status.STATUS_CONNECTING:
			_tcp_connect_func()
		Status.STATUS_HANDSHAKEING:
			_tls_connect_func()
		Status.STATUS_CONNECTED:
			if _is_use_tls:
				_tls_receive_func()
			else:
				_tcp_receive_func()
		Status.STATUS_DISCONNECTED:
			_disconnect_from_host(false)

func _tcp_connect_func() -> void:
	_tcp.poll()
	match _tcp.get_status():
		_tcp.STATUS_CONNECTED:
			if _is_use_tls:
				_status = Status.STATUS_HANDSHAKEING
				if _tls.connect_to_stream(_tcp, _tls_hostname) != Error.OK:
					_status = Status.STATUS_DISCONNECTED
					on_disconnect.emit(self)
					return
			else:
				_status = Status.STATUS_CONNECTED
				on_connect.emit(self)
			return
		_tcp.STATUS_ERROR:
			_status = Status.STATUS_DISCONNECTED
			on_disconnect.emit(self)
			return
		_:
			pass

func _tls_connect_func() -> void:
	_tls.poll()
	match _tls.get_status():
		_tls.STATUS_CONNECTED:
			_status = Status.STATUS_CONNECTED
			on_connect.emit(self)
			return
		_tls.STATUS_HANDSHAKING:
			return
		_:
			_status = Status.STATUS_DISCONNECTED
			on_disconnect.emit(self)

func _tcp_receive_func() -> void:
	while _status == Status.STATUS_CONNECTED:
		if not(_tcp.poll() == Error.OK and _tcp.get_status() == _tcp.STATUS_CONNECTED):
			_status = Status.STATUS_DISCONNECTED
			on_disconnect.emit(self)
			return
		var bytes_count:int = _tcp.get_available_bytes()
		if bytes_count > 0:
			var result:Array = _tcp.get_data(bytes_count)
			var err:Error = result[0] as Error
			var data:PackedByteArray = result[1] as PackedByteArray
			if err == Error.OK:
				on_message.emit(self, data)
		else:
			return

func _tls_receive_func() -> void:
	while _status == Status.STATUS_CONNECTED:
		_tls.poll()
		if not(_tls.get_status() == _tls.STATUS_CONNECTED):
			_status = Status.STATUS_DISCONNECTED
			on_disconnect.emit(self)
			return
		var bytes_count:int = _tls.get_available_bytes()
		if bytes_count > 0:
			var result:Array = _tls.get_data(bytes_count)
			var err:Error = result[0] as Error
			var data:PackedByteArray = result[1] as PackedByteArray
			if err == Error.OK:
				on_message.emit(self, data)
		else:
			return
