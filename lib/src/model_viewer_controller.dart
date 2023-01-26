part of sni_model_viewer;

abstract class ModelViewerController {
  Future<void> changeColor(String materialName, Color color);
  Future<void> setVariant(String? variant);
  List<String> get materials;
  List<String> get variants;
}
