import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'dl_util.dart';
import 'generated/meesign_crypto_lib.dart';

// TODO: profile the functions in this file
// many chunks of data are copied, can it be avoided?
// keygen() and sign() do perform some serialization, is it quick enough?

// TODO: consider newer alternative solutions
// e.g. flutter rust bridge, membrane

extension IntIterConversion on Iterable<int> {
  Pointer<Uint8> dupToNative(Allocator alloc) {
    final buf = alloc<Uint8>(length);
    buf.asTypedList(length).setAll(0, this);
    return buf;
  }
}

extension BufferConversion on Buffer {
  Uint8List asTypedList() => ptr.asTypedList(len);

  Uint8List dupToDart() => Uint8List.fromList(asTypedList());
}

class ProtocolException implements Exception {
  final String message;
  ProtocolException(this.message);
}

class ProtocolData {
  final Uint8List context, data;
  ProtocolData(this.context, this.data);
}

final MeeSignCryptoLib _lib = MeeSignCryptoLib(dlOpen('meesign_crypto'));

class Error {
  Pointer<Pointer<Char>> ptr;

  bool get occured => ptr.value != nullptr;

  String get message => ptr.value.cast<Utf8>().toDartString();

  Error() : ptr = calloc();

  static void free(Error error) {
    _lib.error_free(error.ptr.value);
    calloc.free(error.ptr);
    error.ptr = nullptr;
  }
}

class ProtocolWrapper {
  static Uint8List keygen(int protoId) {
    return using((Arena alloc) {
      final proto = _lib.protocol_keygen(protoId);
      final context = alloc.using(
        _lib.protocol_serialize(proto),
        _lib.buffer_free,
      );

      return context.dupToDart();
    });
  }

  static Uint8List init(int protoId, Uint8List group) {
    return using((Arena alloc) {
      final groupBuf = group.dupToNative(alloc);

      final proto = _lib.protocol_init(protoId, groupBuf, group.length);
      final context = alloc.using(
        _lib.protocol_serialize(proto),
        _lib.buffer_free,
      );

      return context.dupToDart();
    });
  }

  static ProtocolData _advanceWorker(Uint8List context, Uint8List data) {
    return using((Arena alloc) {
      final ctxBuf = context.dupToNative(alloc);
      final dataBuf = data.dupToNative(alloc);
      final error = alloc.using(Error(), Error.free);

      final proto = _lib.protocol_deserialize(ctxBuf, context.length);
      final dataOut = alloc.using(
        _lib.protocol_advance(
          proto,
          dataBuf,
          data.length,
          error.ptr,
        ),
        _lib.buffer_free,
      );
      final contextOut = alloc.using(
        _lib.protocol_serialize(proto),
        _lib.buffer_free,
      );

      if (error.occured) throw ProtocolException(error.message);
      return ProtocolData(
        contextOut.dupToDart(),
        dataOut.dupToDart(),
      );
    });
  }

  static Future<ProtocolData> advance(Uint8List context, Uint8List data) {
    return Isolate.run(() => _advanceWorker(context, data));
  }

  static Uint8List finish(Uint8List context) {
    return using((Arena alloc) {
      final ctxBuf = context.dupToNative(alloc);
      final error = alloc.using(Error(), Error.free);

      final proto = _lib.protocol_deserialize(ctxBuf, context.length);
      final data = alloc.using(
        _lib.protocol_finish(proto, error.ptr),
        _lib.buffer_free,
      );

      if (error.occured) throw ProtocolException(error.message);
      return data.dupToDart();
    });
  }
}

class AuthKey {
  final Uint8List key, csr;
  AuthKey(this.key, this.csr);
}

class AuthWrapper {
  static AuthKey keygen(String name) {
    return using((Arena alloc) {
      final namePtr = name.toNativeUtf8(allocator: alloc);
      final error = alloc.using(Error(), Error.free);

      final res = alloc.using(
        _lib.auth_keygen(namePtr.cast(), error.ptr),
        _lib.auth_key_free,
      );

      if (error.occured) throw Exception(error.message);

      return AuthKey(res.key.dupToDart(), res.csr.dupToDart());
    });
  }

  static List<int> certKeyToPkcs12(List<int> key, List<int> cert) {
    return using((Arena alloc) {
      final keyPtr = key.dupToNative(alloc);
      final certPtr = cert.dupToNative(alloc);
      final error = alloc.using(Error(), Error.free);

      final res = alloc.using(
        _lib.auth_cert_key_to_pkcs12(
            keyPtr, key.length, certPtr, cert.length, error.ptr),
        _lib.buffer_free,
      );

      if (error.occured) throw Exception(error.message);

      return res.dupToDart();
    });
  }
}

class ElGamalWrapper {
  static List<int> encrypt(List<int> message, List<int> publicKey) {
    return using((Arena alloc) {
      final messagePtr = message.dupToNative(alloc);
      final publicKeyPtr = publicKey.dupToNative(alloc);
      final error = alloc.using(Error(), Error.free);

      final res = alloc.using(
        _lib.encrypt(messagePtr.cast(), message.length, publicKeyPtr,
            publicKey.length, error.ptr),
        _lib.buffer_free,
      );

      if (error.occured) throw Exception(error.message);

      return res.dupToDart();
    });
  }
}
