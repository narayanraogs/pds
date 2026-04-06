import 'package:uuid/uuid.dart';

enum CellType {
  empty,
  header,
  parameter,
}

class CellData {
  final String id;
  final CellType type;
  final String content; // Header text OR Parameter ID

  CellData({
    required this.id,
    this.type = CellType.empty,
    this.content = '',
  });

  static CellData empty() => CellData(id: const Uuid().v4());
  
  CellData copyWith({
    CellType? type,
    String? content,
  }) {
    return CellData(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'content': content,
  };

  factory CellData.fromJson(Map<String, dynamic> json) => CellData(
    id: json['id'],
    type: CellType.values[json['type']],
    content: json['content'],
  );
}

class PageLayout {
  final String id;
  final String name;
  final List<List<CellData>> grid;

  PageLayout({
    required this.id,
    required this.name,
    required this.grid,
  });

  // Grow/Shrink operations
  PageLayout addRow({int? index}) {
    final newRow = List.generate(
      grid.isEmpty ? 1 : grid[0].length, 
      (_) => CellData.empty()
    );
    final newGrid = List<List<CellData>>.from(grid);
    if (index != null && index >= 0 && index < newGrid.length) {
      newGrid.insert(index, newRow);
    } else {
      newGrid.add(newRow);
    }
    return copyWith(grid: newGrid);
  }

  PageLayout addColumn({int? index}) {
    final newGrid = List<List<CellData>>.from(grid);
    for (int i = 0; i < newGrid.length; i++) {
        final newRow = List<CellData>.from(newGrid[i]);
        if (index != null && index >= 0 && index < newRow.length) {
          newRow.insert(index, CellData.empty());
        } else {
          newRow.add(CellData.empty());
        }
        newGrid[i] = newRow;
    }
    return copyWith(grid: newGrid);
  }

  PageLayout deleteRow(int index) {
    if (grid.length <= 1) return this;
    final newGrid = List<List<CellData>>.from(grid);
    newGrid.removeAt(index);
    return copyWith(grid: newGrid);
  }

  PageLayout deleteColumn(int index) {
    if (grid.isEmpty || grid[0].length <= 1) return this;
    final newGrid = List<List<CellData>>.from(grid);
    for (int i = 0; i < newGrid.length; i++) {
        final newRow = List<CellData>.from(newGrid[i]);
        newRow.removeAt(index);
        newGrid[i] = newRow;
    }
    return copyWith(grid: newGrid);
  }

  PageLayout updateCell(int row, int col, CellData newData) {
    final newGrid = List<List<CellData>>.from(grid);
    final newRow = List<CellData>.from(newGrid[row]);
    newRow[col] = newData;
    newGrid[row] = newRow;
    return copyWith(grid: newGrid);
  }

  PageLayout copyWith({
    String? name,
    List<List<CellData>>? grid,
  }) {
    return PageLayout(
      id: id,
      name: name ?? this.name,
      grid: grid ?? this.grid,
    );
  }
}
