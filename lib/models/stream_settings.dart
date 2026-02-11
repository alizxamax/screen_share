import 'dart:math' as math;

class AspectPreset {
  const AspectPreset(this.label, this.width, this.height);

  final String label;
  final double width;
  final double height;

  double get ratio => width / height;

  static const landscape16x9 = AspectPreset('16:9 (Landscape)', 16, 9);
  static const portrait9x16 = AspectPreset('9:16 (Portrait)', 9, 16);
  static const classic4x3 = AspectPreset('4:3', 4, 3);
  static const square1x1 = AspectPreset('1:1', 1, 1);
  static const cinematic21x9 = AspectPreset('21:9', 21, 9);

  static const List<AspectPreset> presets = [
    landscape16x9,
    portrait9x16,
    classic4x3,
    square1x1,
    cinematic21x9,
  ];
}

class EdgeCrop {
  const EdgeCrop({
    this.topPercent = 0,
    this.bottomPercent = 0,
    this.leftPercent = 0,
    this.rightPercent = 0,
  });

  final double topPercent;
  final double bottomPercent;
  final double leftPercent;
  final double rightPercent;

  EdgeCrop copyWith({
    double? topPercent,
    double? bottomPercent,
    double? leftPercent,
    double? rightPercent,
  }) {
    return EdgeCrop(
      topPercent: topPercent ?? this.topPercent,
      bottomPercent: bottomPercent ?? this.bottomPercent,
      leftPercent: leftPercent ?? this.leftPercent,
      rightPercent: rightPercent ?? this.rightPercent,
    );
  }

  double get horizontalTotal => leftPercent + rightPercent;
  double get verticalTotal => topPercent + bottomPercent;

  bool get isValid => horizontalTotal < 99 && verticalTotal < 99;

  @override
  String toString() {
    return 'top:${topPercent.toStringAsFixed(1)}%, '
        'bottom:${bottomPercent.toStringAsFixed(1)}%, '
        'left:${leftPercent.toStringAsFixed(1)}%, '
        'right:${rightPercent.toStringAsFixed(1)}%';
  }
}

class StreamSettings {
  const StreamSettings({
    required this.bitrateKbps,
    required this.resolutionPercent,
    required this.aspectPreset,
    required this.crop,
    required this.audioVolume,
  });

  final int bitrateKbps;
  final int resolutionPercent;
  final AspectPreset aspectPreset;
  final EdgeCrop crop;
  final double audioVolume;

  StreamSettings copyWith({
    int? bitrateKbps,
    int? resolutionPercent,
    AspectPreset? aspectPreset,
    EdgeCrop? crop,
    double? audioVolume,
  }) {
    return StreamSettings(
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      resolutionPercent: resolutionPercent ?? this.resolutionPercent,
      aspectPreset: aspectPreset ?? this.aspectPreset,
      crop: crop ?? this.crop,
      audioVolume: audioVolume ?? this.audioVolume,
    );
  }

  int get scaledWidth => math.max(320, (1920 * (resolutionPercent / 100)).round());

  int get scaledHeight => math.max(180, (1080 * (resolutionPercent / 100)).round());

  static const defaults = StreamSettings(
    bitrateKbps: 6000,
    resolutionPercent: 100,
    aspectPreset: AspectPreset.landscape16x9,
    crop: EdgeCrop(),
    audioVolume: 1,
  );
}
