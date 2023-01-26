library sni_model_viewer;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:sni_model_viewer/stub/model_viewer_plus_stub.dart'
    if (dart.library.io) 'package:sni_model_viewer/stub/model_viewer_plus_mobile.dart'
    if (dart.library.js) 'package:sni_model_viewer/stub/model_viewer_plus_web.dart';

part 'src/model_viewer_controller.dart';
part 'src/model_viewer_plus.dart';
part 'src/shim/dart_ui_fake.dart';
part 'src/shim/dart_html_fake.dart';
part 'src/ios_ar_viewer.dart';
part 'src/html_builder.dart';