part of sni_model_viewer;

class IOSARViewer extends StatefulWidget {
  final String url;
  const IOSARViewer({super.key, required this.url});

  @override
  State<IOSARViewer> createState() => _IOSARViewerState();
}

class _IOSARViewerState extends State<IOSARViewer> {
  ARKitController? arkitController;
  ARKitReferenceNode? node;
  ARKitAnchor? anchor;
  bool isDownloading = true;

  @override
  void dispose() {
    super.dispose();
    arkitController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (isDownloading)
            const AspectRatio(
              aspectRatio: 1.0,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ARKitSceneView(
        showFeaturePoints: true,
        planeDetection: ARPlaneDetection.horizontalAndVertical,
        onARKitViewCreated: onARKitViewCreated,
      ),
    );
  }

  Future<void> onARKitViewCreated(ARKitController arkitController) async {
    this.arkitController = arkitController;
    // arkitController.onNodePinch = (pinch) => _onPinchHandler(pinch);
    // arkitController.onNodePan = (pan) => _onPanHandler(pan);
    // arkitController.onNodeRotation = (rotation) => _onRotationHandler(rotation);

    arkitController.addCoachingOverlay(CoachingOverlayGoal.horizontalPlane);
    arkitController.onAddNodeForAnchor = _handleAddAnchor;
  }

  // void _onPinchHandler(List<ARKitNodePinchResult> pinch) {
  //   try {
  //     final pinchNode = pinch.first;
  //     final scale = Vector3.all(pinchNode.scale);
  //     node?.scale = scale;
  //     //arkitController!.update(node!.name, node: node);
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  // void _onPanHandler(List<ARKitNodePanResult> pan) {
  //   try {
  //     final panNode = pan.first;

  //     final old = node?.position;
  //     final newAngleY = panNode.translation.x * math.pi / 180;
  //     node?.position = Vector3(old?.x ?? 0, newAngleY, old?.z ?? 0);
  //     //arkitController!.update(node!.name, node: node);
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  // void _onRotationHandler(List<ARKitNodeRotationResult> rotation) {
  //   try {
  //     final rotationNode = rotation.first;
  //     final r = node?.eulerAngles ??
  //         Vector3.zero() + Vector3.all(rotationNode.rotation);
  //     node?.eulerAngles = r;
  //     //arkitController!.update(node!.name, node: node);
  //   } catch (e) {
  //     print(e);
  //   }
  // }

  void _handleAddAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitPlaneAnchor) {
      _addPlane(arkitController!, anchor);
    }
  }

  Future<void> _addPlane(
    ARKitController controller,
    ARKitPlaneAnchor anchor,
  ) async {
    setState(() {
      this.anchor = anchor;
      place();
    });
  }

  Future<void> place() async {
    if (node != null) {
      arkitController!.remove(node!.name);
    }

    final String? path = await download();
    if (path != null) {
      node = ARKitReferenceNode(
        name: 'model3d',
        url: path,
        position: Vector3.all(0.0),
        scale: Vector3.all(0.3),
      );

      await arkitController!.add(node!, parentNodeName: anchor!.nodeName);
    }
  }

  Future<String?> download() async {
    setState(() {
      isDownloading = true;
    });
    try {
      final appDir = await getTemporaryDirectory();
      final cacheDir = Directory(
        p.join(
          appDir.absolute.path,
          'cache',
          '3d-models',
        ),
      );
      if (!(await cacheDir.exists())) {
        await cacheDir.create(recursive: true);
      }

      final u = Uri.parse(widget.url).pathSegments.last;
      final x = u.substring(u.lastIndexOf('.') + 1);

      final filename = base64Url.encode(utf8.encode(widget.url));
      final file = File(p.join(cacheDir.absolute.path, '$filename.$x'));
      final exists = await file.exists();
      if (!exists) {
        final dio = Dio(BaseOptions(responseType: ResponseType.stream));
        final Response<ResponseBody> res = await dio.get(widget.url);
        if (res.statusCode == 200) {
          final fileSink = file.openWrite();

          final stream = res.data!.stream.transform<Uint8List>(
            StreamTransformer.fromHandlers(
              handleData: (data, sink) {
                fileSink.add(data);
                sink.add(data);
              },
              handleDone: (sink) {
                sink.close();
                fileSink.close();
              },
            ),
          );

          await stream.join();
          return file.absolute.path;
        }
      } else {
        return file.absolute.path;
      }

      return null;
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }
}
