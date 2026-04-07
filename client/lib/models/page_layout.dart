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
  final List<List<CellData>> columns;

  PageLayout({
    required this.id,
    required this.name,
    required this.columns,
  });

  // Adding a new column entirely
  PageLayout addColumn({int? index}) {
    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    final newCol = [CellData.empty()];
    if (index != null && index >= 0 && index <= newColumns.length) {
      newColumns.insert(index, newCol);
    } else {
      newColumns.add(newCol);
    }
    return copyWith(columns: newColumns);
  }

  // Adding a cell above/below (up/down) in a specific column
  PageLayout addCell(int colIndex, {int? rowIndex}) {
    if (colIndex < 0 || colIndex >= columns.length) return this;
    
    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    final newCol = newColumns[colIndex];
    
    if (rowIndex != null && rowIndex >= 0 && rowIndex <= newCol.length) {
      newCol.insert(rowIndex, CellData.empty());
    } else {
      newCol.add(CellData.empty());
    }
    
    return copyWith(columns: newColumns);
  }

  PageLayout deleteColumn(int index) {
    if (columns.length <= 1) return this;
    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    newColumns.removeAt(index);
    return copyWith(columns: newColumns);
  }

  PageLayout deleteCell(int colIndex, int rowIndex) {
    if (colIndex < 0 || colIndex >= columns.length) return this;
    final newCol = columns[colIndex];
    
    if (newCol.length <= 1) {
      return deleteColumn(colIndex);
    }
    
    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    newColumns[colIndex].removeAt(rowIndex);
    return copyWith(columns: newColumns);
  }

  PageLayout updateCell(int col, int row, CellData newData) {
    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    newColumns[col][row] = newData;
    return copyWith(columns: newColumns);
  }

  PageLayout moveCell(int fromCol, int fromRow, int toCol, int toRow) {
    if (fromCol < 0 || fromCol >= columns.length) return this;
    if (fromRow < 0 || fromRow >= columns[fromCol].length) return this;

    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    final cell = newColumns[fromCol].removeAt(fromRow);

    int dropCol = toCol;
    int dropRow = toRow;

    if (fromCol == dropCol && fromRow < dropRow) {
      dropRow -= 1;
    }

    if (newColumns[fromCol].isEmpty) {
      newColumns.removeAt(fromCol);
      if (fromCol < dropCol) {
        dropCol -= 1;
      }
    }

    if (dropCol < 0) dropCol = 0;
    if (dropCol >= newColumns.length) {
      newColumns.add([cell]);
      return copyWith(columns: newColumns);
    }

    if (dropRow < 0) dropRow = 0;
    if (dropRow > newColumns[dropCol].length) dropRow = newColumns[dropCol].length;

    newColumns[dropCol].insert(dropRow, cell);
    return copyWith(columns: newColumns);
  }

  PageLayout moveCellToNewColumn(int fromCol, int fromRow, int newColIndex) {
    if (fromCol < 0 || fromCol >= columns.length) return this;
    if (fromRow < 0 || fromRow >= columns[fromCol].length) return this;

    final newColumns = List<List<CellData>>.from(columns.map((c) => List<CellData>.from(c)));
    final cell = newColumns[fromCol].removeAt(fromRow);

    int dropCol = newColIndex;

    if (newColumns[fromCol].isEmpty) {
      newColumns.removeAt(fromCol);
      if (fromCol < dropCol) {
        dropCol -= 1;
      }
    }

    if (dropCol < 0) dropCol = 0;
    if (dropCol > newColumns.length) dropCol = newColumns.length;

    newColumns.insert(dropCol, [cell]);
    return copyWith(columns: newColumns);
  }

  PageLayout copyWith({
    String? name,
    List<List<CellData>>? columns,
  }) {
    return PageLayout(
      id: id,
      name: name ?? this.name,
      columns: columns ?? this.columns,
    );
  }
}
