extends Node
class_name TCPClient

signal connected(sender:TCPClient)
signal disconnected(sender:TCPClient)
signal message(sender:TCPClient, data:PackedByteArray)
signal status_changed(sender:TCPClient, status:Status)

enum Status {
	STATUS_CONNECTED,
	STATUS_DISCONNECTED,
	STATUS_CONNECTING,
	STATUS_HANDSHAKEING
}

var _tcp:StreamPeerTCP = null
var _tls:StreamPeerTLS = null
var status:Status = Status.STATUS_DISCONNECTED

var use_tls:bool = false
var hostname:String = ""
var timeout_second: float = 30.0
var _connect_duration: float = 0

func _init() -> void:
	_tcp = StreamPeerTCP.new()
	_tls = StreamPeerTLS.new()

func _exit_tree() -> void:
	_disconnect_from_host(true)

func _process(delta: float) -> void:
	_poll()
	match status:
		Status.STATUS_CONNECTING, Status.STATUS_HANDSHAKEING:
			_connect_duration += delta
			if _connect_duration > timeout_second:
				_disconnect_from_host(true)
		_:
			_connect_duration = 0

func connect_to_host(address:String, port:int) -> Error:
	if status != Status.STATUS_DISCONNECTED:
		return Error.ERR_BUSY
	status = Status.STATUS_CONNECTING
	status_changed.emit(self, status)
	var err:Error = _tcp.connect_to_host(address, port)
	if err != Error.OK:
		status = Status.STATUS_DISCONNECTED
		status_changed.emit(self, status)
	return err

func _disconnect_from_host(is_poll:bool=true) -> void:
	if status != Status.STATUS_DISCONNECTED:
		if _tls.get_status() != _tls.STATUS_DISCONNECTED:
			_tls.disconnect_from_stream()
		if _tcp.get_status() != _tcp.STATUS_NONE:
			_tcp.disconnect_from_host()
		if is_poll:
			_poll()

func disconnect_from_host() -> void:
	_disconnect_from_host(true)

func put_data(data:PackedByteArray) -> Error:
	if use_tls:
		return _tls.put_data(data)
	else:
		return _tcp.put_data(data)

func _poll() -> void:
	match status:
		Status.STATUS_CONNECTING:
			_tcp_connect_func()
		Status.STATUS_HANDSHAKEING:
			_tls_connect_func()
		Status.STATUS_CONNECTED:
			if use_tls:
				_tls_receive_func()
			else:
				_tcp_receive_func()
		Status.STATUS_DISCONNECTED:
			_disconnect_from_host(false)

func _tcp_connect_func() -> void:
	_tcp.poll()
	match _tcp.get_status():
		_tcp.STATUS_CONNECTING:
			return
		_tcp.STATUS_CONNECTED:
			if use_tls:
				status = Status.STATUS_HANDSHAKEING
				status_changed.emit(self, status)
				if _tls.connect_to_stream(_tcp, hostname) != Error.OK:
					status = Status.STATUS_DISCONNECTED
					status_changed.emit(self, status)
					disconnected.emit(self)
					return
			else:
				status = Status.STATUS_CONNECTED
				status_changed.emit(self, status)
				connected.emit(self)
			return
		_:
			status = Status.STATUS_DISCONNECTED
			status_changed.emit(self, status)
			disconnected.emit(self)
			return

func _tls_connect_func() -> void:
	_tls.poll()
	match _tls.get_status():
		_tls.STATUS_CONNECTED:
			status = Status.STATUS_CONNECTED
			status_changed.emit(self, status)
			connected.emit(self)
			return
		_tls.STATUS_HANDSHAKING:
			return
		_:
			status = Status.STATUS_DISCONNECTED
			status_changed.emit(self, status)
			disconnected.emit(self)
			return

func _tcp_receive_func() -> void:
	while status == Status.STATUS_CONNECTED:
		if not(_tcp.poll() == Error.OK and _tcp.get_status() == _tcp.STATUS_CONNECTED):
			status = Status.STATUS_DISCONNECTED
			status_changed.emit(self, status)
			disconnected.emit(self)
			return
		var bytes_count:int = _tcp.get_available_bytes()
		if bytes_count > 0:
			var result:Array = _tcp.get_data(bytes_count)
			var err:Error = result[0] as Error
			var data:PackedByteArray = result[1] as PackedByteArray
			if err == Error.OK:
				message.emit(self, data)
			continue
		else:
			return

func _tls_receive_func() -> void:
	while status == Status.STATUS_CONNECTED:
		_tls.poll()
		if not(_tls.get_status() == _tls.STATUS_CONNECTED):
			status = Status.STATUS_DISCONNECTED
			status_changed.emit(self, status)
			disconnected.emit(self)
			return
		var bytes_count:int = _tls.get_available_bytes()
		if bytes_count > 0:
			var result:Array = _tls.get_data(bytes_count)
			var err:Error = result[0] as Error
			var data:PackedByteArray = result[1] as PackedByteArray
			if err == Error.OK:
				message.emit(self, data)
			continue
		else:
			return
