// ignore_for_file: avoid_web_libraries_in_flutter
// genexp: ignore

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sni_model_viewer/sni_model_viewer.dart';

/* This is free and unencumbered software released into the public domain. */

final _random = math.Random();

/* This is free and unencumbered software released into the public domain. */

// ignore_for_file: undefined_prefixed_name

class ModelViewerState extends State<ModelViewer> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    generateModelViewerHtml();
  }

  /// To generate the HTML code for using the model viewer.
  void generateModelViewerHtml() async {
    final htmlTemplate = await rootBundle
        .loadString('packages/sni_model_viewer/assets/template.html');
    // allow to use elements
    final NodeValidator validator = NodeValidatorBuilder.common()
      ..allowElement(
        'meta',
        attributes: ['name', 'content'],
        uriPolicy: _AllowUriPolicy(),
      )
      ..allowElement('style')
      ..allowElement(
        'script',
        attributes: ['src', 'type', 'defer'],
        uriPolicy: _AllowUriPolicy(),
      )
      ..allowCustomElement(
        'model-viewer',
        attributes: [
          'style',

          // Loading Attributes
          'src',
          'alt',
          'poster',
          'seamless-poster',
          'loading',
          'reveal',
          'with-credentials',

          // Augmented Reality Attributes
          'ar',
          'ar-modes',
          'ar-scale',
          'ar-placement',
          'ios-src',
          'xr-environment',

          // Staing & Cameras Attributes
          'camera-controls',
          'enable-pan',
          'touch-action',
          'disable-zoom',
          'orbit-sensitivity',
          'auto-rotate',
          'auto-rotate-delay',
          'rotation-per-second',
          'interaction-policy',
          'interaction-prompt',
          'interaction-prompt-style',
          'interaction-prompt-threshold',
          'camera-orbit',
          'camera-target',
          'field-of-view',
          'max-camera-orbit',
          'min-camera-orbit',
          'max-field-of-view',
          'min-field-of-view',
          'bounds',
          'interpolation-decay',

          // Lighting & Env Attributes
          'skybox-image',
          'environment-image',
          'exposure',
          'shadow-intensity',
          'shadow-softness ',

          // Animation Attributes
          'animation-name',
          'animation-crossfade-duration',
          'autoplay',

          // Scene Graph Attributes
          'variant-name',
          'orientation',
          'scale',
        ],
        uriPolicy: _AllowUriPolicy(),
      );

    ui.platformViewRegistry.registerViewFactory(
      'model-viewer-html-$variableName',
      (int viewId) => HtmlHtmlElement()
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..setInnerHtml(
          _buildHTML(htmlTemplate, viewId.toString()),
          validator: validator,
        ),
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading Model Viewer...',
            ),
          )
        : HtmlElementView(
            viewType: 'model-viewer-html-$variableName',
            onPlatformViewCreated: (id) {
              final modelViewer =
                  html.window.document.getElementById(variableName);
              if (modelViewer == null) return;

              modelViewer.addEventListener(
                'load',
                (event) {
                  if (widget.minRenderScale != null) {
                    js.context
                        .callMethod('setMinimumRenderScale_$variableName', [
                      variableName,
                      widget.minRenderScale,
                    ]);
                  }

                  final materialsJson = js.context
                      .callMethod('getMaterials_$variableName', [variableName]);

                  final materials = (json.decode(materialsJson) as List)
                      .cast<String>()
                      .toSet()
                      .toList();

                  final variantsJson = js.context
                      .callMethod('getVariants_$variableName', [variableName]);

                  final variants = (json.decode(variantsJson) as List)
                      .cast<String>()
                      .toSet()
                      .toList();

                  widget.onCreated?.call(
                    _ModelViewerController(
                      materials: materials,
                      variants: variants,
                      variableName: variableName,
                    ),
                  );
                },
              );

              modelViewer.addEventListener('progress', (event) {
                if (event is CustomEvent) {
                  final value = event.detail['totalProgress'];
                  if (value is num) {
                    widget.onLoading?.call(value.toDouble());
                  }
                }
              });
            },
          );
  }

  String _buildHTML(final String htmlTemplate, String viewId) {
    if (widget.src.startsWith('file://')) {
      // Local file URL can't be used in Flutter web.
      debugPrint("file:// URL scheme can't be used in Flutter web.");
      throw ArgumentError("file:// URL scheme can't be used in Flutter web.");
    }

    return HTMLBuilder.build(
      htmlTemplate: htmlTemplate.replaceFirst(
        '<script type="module" src="model-viewer.min.js" defer></script>',
        '',
      ),
      // Attributes
      src: widget.src,
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
      relatedJs: _relatedJS(viewId),
      id: variableName,
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
    _variableName ??= _createVariableName();

    return _variableName!;
  }

  String _relatedJS(String viewId) {
    return '''
  function updateMaterialColor_$variableName(name, materialName, colorString) {
    const viewer = document.querySelector("model-viewer#" + name);

    const color = JSON.parse(colorString);
    const material = viewer.model.getMaterialByName(materialName);
    if (material){
      material.pbrMetallicRoughness.setBaseColorFactor(color);
    }
  }

  function getMaterials_$variableName(name) {
    const viewer = document.querySelector("model-viewer#" + name);
    const materials = viewer.model.materials;
    const result = JSON.stringify(materials.map(material => material.name));
    return result;
  }

  function getVariants_$variableName(name){
    const viewer = document.querySelector("model-viewer#" + name);
    const names = viewer.availableVariants;
    return JSON.stringify(names);
  }

  function setVariant_$variableName(name, variantName){
    console.log(variantName);
    const viewer = document.querySelector("model-viewer#" + name);
    viewer.variantName = variantName;
  }

  function setMinimumRenderScale_$variableName(name, value){
    const viewer = document.querySelector("model-viewer#" + name);
    viewer.minimumRenderScale = value;
  }

  ${widget.relatedJs}
''';
  }
}

class _AllowUriPolicy implements UriPolicy {
  @override
  bool allowsUri(String uri) {
    return true;
  }
}

class _ModelViewerController implements ModelViewerController {
  final String variableName;

  @override
  final List<String> materials;

  @override
  final List<String> variants;

  _ModelViewerController({
    required this.materials,
    required this.variants,
    required this.variableName,
  });

  @override
  Future<void> changeColor(String materialName, ui.Color color) async {
    final colors = <double>[
      color.red / 256,
      color.green / 256,
      color.blue / 256,
      color.alpha / 256,
    ];

    js.context.callMethod('updateMaterialColor_$variableName', [
      variableName,
      materialName,
      json.encode(colors),
    ]);
  }

  @override
  Future<void> setVariant(String? variant) async {
    js.context.callMethod('setVariant_$variableName', [
      variableName,
      variant,
    ]);
  }
}
