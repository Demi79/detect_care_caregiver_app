class CameraCardTheme {
  final bool isGrid2;
  final double borderRadius;
  final double elevation;
  final double boxShadowBlur;
  final double thumbIconSize;
  final double statusChipTop;
  final double statusChipRight;
  final double paddingH;
  final double paddingV;
  final double labelFontSize;
  final double labelPaddingH;
  final double labelPaddingV;
  final double labelRadius;
  final double nameFontSize;
  final double actionIconSize;
  final double actionSplash;
  final double maxHeight;

  const CameraCardTheme(this.isGrid2)
    : borderRadius = isGrid2 ? 18 : 24,
      elevation = isGrid2 ? 4 : 8,
      boxShadowBlur = isGrid2 ? 7 : 12,
      thumbIconSize = isGrid2 ? 24 : 32,
      statusChipTop = isGrid2 ? 8 : 12,
      statusChipRight = isGrid2 ? 8 : 12,
      paddingH = isGrid2 ? 10 : 16,
      paddingV = isGrid2 ? 7 : 12,
      labelFontSize = isGrid2 ? 10 : 13,
      labelPaddingH = isGrid2 ? 7 : 10,
      labelPaddingV = isGrid2 ? 3 : 4,
      labelRadius = isGrid2 ? 6 : 8,
      nameFontSize = isGrid2 ? 14 : 22,
      actionIconSize = isGrid2 ? 13 : 16,
      actionSplash = isGrid2 ? 18 : 26,
      maxHeight = isGrid2 ? 220 : 300;
}
