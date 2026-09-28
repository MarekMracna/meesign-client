import 'package:fixnum/fixnum.dart';
import 'package:meesign_core/src/data/network_dispatcher.dart';
import 'package:meesign_core/src/util/uuid.dart';
import 'package:meesign_network/grpc.dart' as rpc;

class UploadService {
  UploadService(this._dispatcher);
  final NetworkDispatcher _dispatcher;

  Future<rpc.UploadResponse> upload(Uuid did, List<int> data) async {
    const chunkSize = 256 * 1024; // 256KB chunks

    Stream<rpc.UploadChunk> chunks() async* {
      // First chunk: request
      yield rpc.UploadChunk()
        ..request = (rpc.UploadRequest()..totalSize = Int64(data.length));

      // Subsequent chunks: data
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;

        yield rpc.UploadChunk()..data = data.sublist(i, end);
      }
    }

    return await _dispatcher[did].upload(chunks());
  }
}
