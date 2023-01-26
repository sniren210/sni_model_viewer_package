// genexp: ignore

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:android_intent_plus/android_intent.dart' as android_content;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:sni_model_viewer/src/ios_ar_viewer.dart';
import 'package:sni_model_viewer/sni_model_viewer.dart';

/* This is free and unencumbered software released into the public domain. */

final _random = math.Random();

class ModelViewerState extends State<ModelViewer> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  HttpServer? _proxy;
  late String _proxyURL;

  @override
  void initState() {
    super.initState();
    _initProxy();
  }

  @override
  void dispose() {
    super.dispose();
    if (_proxy != null) {
      _proxy!.close(force: true);
      _proxy = null;
    }
  }

  @override
  void didUpdateWidget(final ModelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reloading
    _controller.future.then((value) => value.loadUrl(_proxyURL));
  }

  @override
  Widget build(final BuildContext context) {
    if (_proxy == null) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading Model Viewer...',
        ),
      );
    } else {
      String? userAgent;
      if (!kIsWeb) {
        if (Platform.isIOS) {
          userAgent =
              'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/101.0.4951.44 Mobile/15E148 Safari/604.1';
        }
      }

      return WebView(
        backgroundColor: widget.backgroundColor,
        initialUrl: null,
        javascriptMode: JavascriptMode.unrestricted,
        initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,
        userAgent: userAgent,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(
            () => EagerGestureRecognizer(),
          ),
        },
        onWebViewCreated: (final WebViewController webViewController) async {
          debugPrint('>>>> ModelViewer initializing... <$_proxyURL>'); // DEBUG
          await webViewController.loadUrl(_proxyURL);
          _controller.complete(webViewController);
        },
        javascriptChannels: {
          JavascriptChannel(
            name: 'OnLoadedEvent',
            onMessageReceived: (s) async {
              final webViewController = await _controller.future;
              if (widget.minRenderScale != null) {
                await webViewController.runJavascript(
                  'setMinimumRenderScale(${widget.minRenderScale})',
                );
              }

              final getMaterialsResult = await webViewController
                  .runJavascriptReturningResult('getMaterials()');
              // on Android it will be returned as a string of string
              // on iOS it will be returned as a string of JSON

              final materialJson = json.decode(getMaterialsResult);
              var materials = <String>[];

              if (materialJson is String) {
                final res = json.decode(materialJson);
                if (res is List) {
                  materials = res.cast<String>().toSet().toList();
                }
              } else if (materialJson is List) {
                materials = materialJson.cast<String>().toSet().toList();
              }

              final getVariantsResult = await webViewController
                  .runJavascriptReturningResult('getVariants()');

              final variantsJson = json.decode(getVariantsResult);
              var variants = <String>[];

              if (variantsJson is String) {
                final res = json.decode(variantsJson);
                if (res is List) {
                  variants = res.cast<String>().toSet().toList();
                }
              } else if (variantsJson is List) {
                variants = variantsJson.cast<String>().toSet().toList();
              }

              final controller = _ModelViewerControllerImpl(
                materials: materials,
                variants: variants,
                webViewController: webViewController,
              );
              widget.onCreated?.call(controller);
            },
          ),
          JavascriptChannel(
            name: 'OnProgressEvent',
            onMessageReceived: (m) async {
              final value = double.tryParse(m.message);
              widget.onLoading?.call(value ?? 0);
            },
          ),
        },
        navigationDelegate: (final NavigationRequest navigation) async {
          debugPrint(
            '>>>> ModelViewer wants to load: <${navigation.url}>',
          ); // DEBUG
          if (!io.Platform.isAndroid) {
            if (io.Platform.isIOS && navigation.url == widget.iosSrc) {
              // await launchUrlString(
              //   navigation.url,
              //   mode: LaunchMode.externalApplication,
              // );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IOSARViewer(url: widget.iosSrc!),
                ),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          }
          if (!navigation.url.startsWith('intent://')) {
            return NavigationDecision.navigate;
          }
          try {
            // Original, just keep as a backup
            // See: https://developers.google.com/ar/develop/java/scene-viewer
            // final intent = android_content.AndroidIntent(
            //   action: "android.intent.action.VIEW", // Intent.ACTION_VIEW
            //   data: "https://arvr.google.com/scene-viewer/1.0",
            //   arguments: <String, dynamic>{
            //     'file': widget.src,
            //     'mode': 'ar_preferred',
            //   },
            //   package: "com.google.ar.core",
            //   flags: <int>[
            //     Flag.FLAG_ACTIVITY_NEW_TASK
            //   ], // Intent.FLAG_ACTIVITY_NEW_TASK,
            // );

            // 2022-03-14 update
            final String fileURL;
            if (['http', 'https'].contains(Uri.parse(widget.src).scheme)) {
              fileURL = widget.src;
            } else {
              fileURL = p.joinAll([_proxyURL, 'model']);
            }
            final intent = android_content.AndroidIntent(
              action: 'android.intent.action.VIEW', // Intent.ACTION_VIEW
              // See https://developers.google.com/ar/develop/scene-viewer#3d-or-ar
              // data should be something like "https://arvr.google.com/scene-viewer/1.0?file=https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Avocado/glTF/Avocado.gltf"
              data: Uri(
                scheme: 'https',
                host: 'arvr.google.com',
                path: '/scene-viewer/1.0',
                queryParameters: {
                  // 'title': '', // TODO: maybe set by the user
                  // TODO: further test, and make it 'ar_preferred'
                  'mode': 'ar_preferred',
                  'file': fileURL,
                },
              ).toString(),
              // package changed to com.google.android.googlequicksearchbox
              // to support the widest possible range of devices
              package: 'com.google.android.googlequicksearchbox',
              arguments: <String, dynamic>{
                'browser_fallback_url':
                    'market://details?id=com.google.android.googlequicksearchbox'
              },
            );
            await intent.launch().onError((error, stackTrace) {
              debugPrint('>>>> ModelViewer Intent Error: $error'); // DEBUG
            });
          } catch (error) {
            debugPrint('>>>> ModelViewer failed to launch AR: $error'); // DEBUG
          }
          return NavigationDecision.prevent;
        },
        onPageStarted: (final String url) {
          //print('>>>> ModelViewer began loading: <$url>'); // DEBUG
        },
        onPageFinished: (final String url) {
          //print('>>>> ModelViewer finished loading: <$url>'); // DEBUG
        },
        onWebResourceError: (final WebResourceError error) {
          debugPrint(
            '>>>> ModelViewer failed to load: ${error.description} (${error.errorType} ${error.errorCode})',
          ); // DEBUG
        },
      );
    }
  }

  String _buildHTML(final String htmlTemplate) {
    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate,
      src: '/model',
      alt: widget.alt,
      poster: widget.poster,
      seamlessPoster: widget.seamlessPoster,
      loading: widget.loading,
      reveal: widget.reveal,
      withCredentials: widget.withCredentials,
      // AR Attributes
      ar: widget.ar,
      arModes: widget.arModes,
      arScale: widget.arScale,
      arPlacement: widget.arPlacement,
      iosSrc: widget.iosSrc,
      xrEnvironment: widget.xrEnvironment,
      // Staing & Cameras Attributes
      cameraControls: widget.cameraControls,
      enablePan: widget.enablePan,
      touchAction: widget.touchAction,
      disableZoom: widget.disableZoom,
      orbitSensitivity: widget.orbitSensitivity,
      autoRotate: widget.autoRotate,
      autoRotateDelay: widget.autoRotateDelay,
      rotationPerSecond: widget.rotationPerSecond,
      interactionPolicy: widget.interactionPolicy,
      interactionPrompt: widget.interactionPrompt,
      interactionPromptStyle: widget.interactionPromptStyle,
      interactionPromptThreshold: widget.interactionPromptThreshold,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      maxCameraOrbit: widget.maxCameraOrbit,
      minCameraOrbit: widget.minCameraOrbit,
      maxFieldOfView: widget.maxFieldOfView,
      minFieldOfView: widget.minFieldOfView,
      bounds: widget.bounds,
      interpolationDecay: widget.interpolationDecay,
      // Lighting & Env Attributes
      skyboxImage: widget.skyboxImage,
      environmentImage: widget.environmentImage,
      exposure: widget.exposure,
      shadowIntensity: widget.shadowIntensity,
      shadowSoftness: widget.shadowSoftness,
      // Animation Attributes
      animationName: widget.animationName,
      animationCrossfadeDuration: widget.animationCrossfadeDuration,
      autoPlay: widget.autoPlay,
      // Scene Graph Attributes
      variantName: widget.variantName,
      orientation: widget.orientation,
      scale: widget.scale,

      // CSS Styles
      backgroundColor: widget.backgroundColor,
      // Loading CSS
      posterColor: widget.posterColor,
      // Annotations CSS
      minHotspotOpacity: widget.minHotspotOpacity,
      maxHotspotOpacity: widget.maxHotspotOpacity,

      // Others
      innerModelViewerHtml: _innerModelViewerHtml(),
      relatedCss: _relatedCss(),
      relatedJs: _relatedJs(),
      id: widget.id,
    );
  }

  String? _relatedCss() {
    if (widget.onLoading == null) {
      return widget.relatedCss;
    }

    return '''
.progress-bar {
  display: none;
  visibility: hidden;
}
${widget.innerModelViewerHtml ?? ''}''';
  }

  String? _innerModelViewerHtml() {
    if (widget.onLoading == null) {
      return widget.innerModelViewerHtml;
    }

    return '<div class="progress-bar" slot="progress-bar"></div>${widget.innerModelViewerHtml ?? ''}';
  }

  String _createVariableName() {
    return 'modelViewer${_random.nextInt(10000000)}';
  }

  String? _variableName;
  String get variableName {
    return _variableName ??= _createVariableName();
  }

  String _relatedJs() {
    return '''
  const $variableName = document.querySelector("model-viewer#${widget.id}");
  $variableName.addEventListener('load', function () {
      OnLoadedEvent.postMessage(true);
  });

  $variableName.addEventListener('progress', function (event) {
      OnProgressEvent.postMessage(event.detail.totalProgress);
  });

  function updateMaterialColor(name, color) {
    const material = $variableName.model.getMaterialByName(name);
    if (material){
      material.pbrMetallicRoughness.setBaseColorFactor(color);
    }
  }

  function getMaterials() {
    const materials = $variableName.model.materials;
    const result = JSON.stringify(materials.map(material => material.name));
    return result;
  }

  function getVariants() {
    const names = $variableName.availableVariants;
    const result = JSON.stringify(names);
    return result;
  }

  function setVariant(variantName) {
    $variableName.variantName = variantName;
  }

  function setMinimumRenderScale(value){
    $variableName.minimumRenderScale = value;
  }

  ${widget.relatedJs}
  ''';
  }

  Future<void> _initProxy() async {
    final url = Uri.parse(widget.src);
    _proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    setState(() {
      _proxy;
      final host = _proxy!.address.address;
      final port = _proxy!.port;
      _proxyURL = 'http://$host:$port/';
    });

    _proxy!.listen((final io.HttpRequest request) async {
      //print("${request.method} ${request.uri}"); // DEBUG
      //print(request.headers); // DEBUG
      final response = request.response;

      switch (request.uri.path) {
        case '/':
        case '/index.html':
          final htmlTemplate = await rootBundle
              .loadString('packages/sni_model_viewer/assets/template.html');
          final html = utf8.encode(_buildHTML(htmlTemplate));
          response
            ..statusCode = HttpStatus.ok
            ..headers.add('Content-Type', 'text/html;charset=UTF-8')
            ..headers.add('Content-Length', html.length.toString())
            ..add(html);
          await response.close();
          break;

        case '/model-viewer.min.js':
          final code = await _readAsset(
            'packages/sni_model_viewer/assets/model-viewer.min.js',
          );
          response
            ..statusCode = HttpStatus.ok
            ..headers
                .add('Content-Type', 'application/javascript;charset=UTF-8')
            ..headers.add('Content-Length', code.lengthInBytes.toString())
            ..add(code);
          await response.close();
          break;

        case '/model':
          if (url.isAbsolute && !url.isScheme('file')) {
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

            final u = Uri.parse(widget.src).pathSegments.last;
            final x = u.substring(u.lastIndexOf('.') + 1);

            final filename = base64Url.encode(utf8.encode(widget.src));
            final file = File(p.join(cacheDir.absolute.path, '$filename.$x'));
            final exists = await file.exists();
            if (!exists) {
              final dio = Dio(BaseOptions(responseType: ResponseType.stream));
              final Response<ResponseBody> res = await dio.get(widget.src);
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

                response.statusCode = HttpStatus.ok;
                response.headers
                    .add('Content-Type', 'application/octet-stream');
                response.headers.add(
                  'Content-Length',
                  res.headers.value('Content-Length') ?? '',
                );
                response.headers.add('Access-Control-Allow-Origin', '*');

                await response.addStream(stream);
                await response.close();
              } else {
                response.statusCode = 404;
                response.close();
              }
            } else {
              final data = await _readFile(file.absolute.path);
              response
                ..statusCode = HttpStatus.ok
                ..headers.add('Content-Type', 'application/octet-stream')
                ..headers.add('Content-Length', data.lengthInBytes.toString())
                ..headers.add('Access-Control-Allow-Origin', '*')
                ..add(data);
              await response.close();
            }
          } else {
            final data = await (url.isScheme('file')
                ? _readFile(url.path)
                : _readAsset(url.path));
            response
              ..statusCode = HttpStatus.ok
              ..headers.add('Content-Type', 'application/octet-stream')
              ..headers.add('Content-Length', data.lengthInBytes.toString())
              ..headers.add('Access-Control-Allow-Origin', '*')
              ..add(data);
            await response.close();
          }
          break;

        case '/favicon.ico':
          final text = utf8.encode("Resource '${request.uri}' not found");
          response
            ..statusCode = HttpStatus.notFound
            ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
            ..headers.add('Content-Length', text.length.toString())
            ..add(text);
          await response.close();
          break;

        default:
          if (request.uri.isAbsolute) {
            await response.redirect(request.uri);
          } else if (request.uri.hasAbsolutePath) {
            // Some gltf models need other resources from the origin
            final pathSegments = [...url.pathSegments];
            pathSegments.removeLast();
            final tryDestination = p.joinAll([
              url.origin,
              ...pathSegments,
              request.uri.path.replaceFirst('/', '')
            ]);
            debugPrint('Try: $tryDestination');
            await response.redirect(Uri.parse(tryDestination));
          } else {
            debugPrint('404 with ${request.uri}');
            final text = utf8.encode("Resource '${request.uri}' not found");
            response
              ..statusCode = HttpStatus.notFound
              ..headers.add('Content-Type', 'text/plain;charset=UTF-8')
              ..headers.add('Content-Length', text.length.toString())
              ..add(text);
            await response.close();
            break;
          }
      }
    });
  }

  Future<Uint8List> _readAsset(final String key) async {
    final data = await rootBundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<Uint8List> _readFile(final String path) async {
    return await io.File(path).readAsBytes();
  }
}

class _ModelViewerControllerImpl implements ModelViewerController {
  final WebViewController webViewController;

  @override
  final List<String> materials;
  @override
  final List<String> variants;

  _ModelViewerControllerImpl({
    required this.webViewController,
    required this.materials,
    required this.variants,
  });

  @override
  Future<void> changeColor(String materialName, Color color) async {
    final colorString = [
      color.red / 256,
      color.green / 256,
      color.blue / 256,
      color.alpha / 256,
    ];
    await webViewController.runJavascript(
      'updateMaterialColor("$materialName", $colorString)',
    );
  }

  @override
  Future<void> setVariant(String? variant) async {
    await webViewController.runJavascript('setVariant("$variant")');
  }
}
