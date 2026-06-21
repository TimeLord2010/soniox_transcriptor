import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

double blur = 0.5;

var glassConfig = GlassThemeSettings(
  glassColor: const Color.fromARGB(170, 178, 178, 193),
  thickness: 30,
  blur: blur,
  chromaticAberration: .01,
  lightAngle: GlassDefaults.lightAngle,
  lightIntensity: .5,
  ambientStrength: 0,
  refractiveIndex: 1.2,
  saturation: 1.2,
  specularSharpness: GlassSpecularSharpness.medium,
);

var glassSettings = LiquidGlassSettings(
  glassColor: const Color.fromARGB(170, 204, 204, 221),
  thickness: 30,
  blur: blur,
  chromaticAberration: .01,
  lightAngle: GlassDefaults.lightAngle,
  lightIntensity: .5,
  ambientStrength: 0,
  refractiveIndex: 1.2,
  saturation: 1.2,
  specularSharpness: GlassSpecularSharpness.medium,
);
