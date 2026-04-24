import '../painters/whiteboard_painter.dart';

class WhiteboardPage {
  final String name;
  final List<WhiteboardItem> items;
  final BackgroundStyle background;
  final Map<String, dynamic>? savedTransform;

  WhiteboardPage({
    required this.name,
    List<WhiteboardItem>? items,
    this.background = BackgroundStyle.dots,
    this.savedTransform,
  }) : items = items ?? [];

  WhiteboardPage copyWith({
    String? name,
    List<WhiteboardItem>? items,
    BackgroundStyle? background,
    Map<String, dynamic>? savedTransform,
    bool clearTransform = false,
  }) =>
      WhiteboardPage(
        name: name ?? this.name,
        items: items ?? List.from(this.items),
        background: background ?? this.background,
        savedTransform:
            clearTransform ? null : (savedTransform ?? this.savedTransform),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'background': background.name,
        'items': items.map((i) => i.toJson()).toList(),
        if (savedTransform != null) 'transform': savedTransform,
      };

  static WhiteboardPage fromJson(Map<String, dynamic> j) => WhiteboardPage(
        name: j['name'] as String? ?? 'Page 1',
        items: (j['items'] as List)
            .map((i) => WhiteboardItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        background: BackgroundStyle.values.firstWhere(
          (s) => s.name == (j['background'] as String? ?? 'dots'),
          orElse: () => BackgroundStyle.dots,
        ),
        savedTransform: j['transform'] as Map<String, dynamic>?,
      );
}
