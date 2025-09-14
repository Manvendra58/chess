import 'dart:math';
import 'package:flutter/material.dart';

// --- ENUMS and DATA CLASSES ---

enum PieceType { pawn, rook, knight, bishop, queen, king }

enum PieceColor { white, black }

enum GameMode { singlePlayer, twoPlayer }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece(this.type, this.color, {this.hasMoved = false});

  // Creates a deep copy of the piece
  ChessPiece copy() {
    return ChessPiece(type, color, hasMoved: hasMoved);
  }

  String get unicode {
    switch (type) {
      case PieceType.pawn:
        return color == PieceColor.white ? '♙' : '♟';
      case PieceType.rook:
        return color == PieceColor.white ? '♖' : '♜';
      case PieceType.knight:
        return color == PieceColor.white ? '♘' : '♞';
      case PieceType.bishop:
        return color == PieceColor.white ? '♗' : '♝';
      case PieceType.queen:
        return color == PieceColor.white ? '♕' : '♛';
      case PieceType.king:
        return color == PieceColor.white ? '♔' : '♚';
    }
  }

  int get value {
    switch (type) {
      case PieceType.pawn:
        return 1;
      case PieceType.knight:
      case PieceType.bishop:
        return 3;
      case PieceType.rook:
        return 5;
      case PieceType.queen:
        return 9;
      case PieceType.king:
        return 100;
    }
  }
}

class Move {
  final int startRow, startCol, endRow, endCol;
  Move(this.startRow, this.startCol, this.endRow, this.endCol);
}

// --- MAIN WIDGETS ---

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF262522),
      ),
      home: const ChessGamePage(),
    );
  }
}

class ChessGamePage extends StatefulWidget {
  const ChessGamePage({super.key});

  @override
  _ChessGamePageState createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  late List<List<ChessPiece?>> _board;
  GameMode _gameMode = GameMode.singlePlayer;
  ChessPiece? _selectedPiece;
  int _selectedRow = -1, _selectedCol = -1;
  PieceColor _currentPlayer = PieceColor.white;
  List<Offset> _validMoves = [];
  String _status = "";
  List<ChessPiece> _whiteCaptured = [];
  List<ChessPiece> _blackCaptured = [];
  Offset? _kingInCheckPos;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  void _initializeBoard() {
    _board = List.generate(8, (_) => List.filled(8, null));
    // Pawns
    for (int i = 0; i < 8; i++) {
      _board[1][i] = ChessPiece(PieceType.pawn, PieceColor.black);
      _board[6][i] = ChessPiece(PieceType.pawn, PieceColor.white);
    }
    // Rooks, Knights, Bishops, Queen, King
    const pieceOrder = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int i = 0; i < 8; i++) {
      _board[0][i] = ChessPiece(pieceOrder[i], PieceColor.black);
      _board[7][i] = ChessPiece(pieceOrder[i], PieceColor.white);
    }
    _resetSelection();
    _currentPlayer = PieceColor.white;
    _whiteCaptured = [];
    _blackCaptured = [];
    _kingInCheckPos = null;
    _updateStatus();
    setState(() {});
  }

  void _handleTap(int row, int col) {
    if (_isGameOver()) return;

    setState(() {
      if (_selectedPiece == null) {
        if (_board[row][col] != null &&
            _board[row][col]!.color == _currentPlayer) {
          _selectedPiece = _board[row][col];
          _selectedRow = row;
          _selectedCol = col;
          _validMoves = _getLegalMoves(row, col, _selectedPiece!);
        }
      } else {
        if (_validMoves.contains(Offset(row.toDouble(), col.toDouble()))) {
          _movePiece(row, col);
        } else if (_board[row][col] != null &&
            _board[row][col]!.color == _currentPlayer) {
          _selectedPiece = _board[row][col];
          _selectedRow = row;
          _selectedCol = col;
          _validMoves = _getLegalMoves(row, col, _selectedPiece!);
        } else {
          _resetSelection();
        }
      }
    });
  }

  void _movePiece(int newRow, int newCol, {bool isAiMove = false}) {
    // Capture logic
    if (_board[newRow][newCol] != null) {
      final captured = _board[newRow][newCol]!;
      if (captured.color == PieceColor.white) {
        _blackCaptured.add(captured);
      } else {
        _whiteCaptured.add(captured);
      }
    }

    _board[newRow][newCol] = _selectedPiece;
    _board[_selectedRow][_selectedCol] = null;
    _board[newRow][newCol]!.hasMoved = true;

    if (_selectedPiece!.type == PieceType.pawn &&
        (newRow == 0 || newRow == 7)) {
      _promotePawn(newRow, newCol, isAiMove: isAiMove);
    } else {
      _postMoveUpdate();
    }
  }

  void _postMoveUpdate() {
    _switchPlayer();
    _resetSelection();
    _checkForMate();

    if (_gameMode == GameMode.singlePlayer &&
        _currentPlayer == PieceColor.black &&
        !_isGameOver()) {
      Future.delayed(const Duration(milliseconds: 500), _makeAiMove);
    }
  }

  void _promotePawn(int row, int col, {bool isAiMove = false}) {
    if (isAiMove) {
      // AI always promotes to Queen
      setState(() {
        _board[row][col] = ChessPiece(PieceType.queen, _currentPlayer);
        _postMoveUpdate();
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Promote Pawn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    PieceType.queen,
                    PieceType.rook,
                    PieceType.bishop,
                    PieceType.knight,
                  ]
                  .map(
                    (type) => TextButton(
                      onPressed: () {
                        setState(() {
                          _board[row][col] = ChessPiece(type, _currentPlayer);
                          _postMoveUpdate();
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        type.toString().split('.').last,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  void _switchPlayer() {
    _currentPlayer = _currentPlayer == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;
  }

  void _resetSelection() {
    _selectedPiece = null;
    _selectedRow = -1;
    _selectedCol = -1;
    _validMoves = [];
  }

  void _updateStatus() {
    if (_status.contains("wins")) return;

    var turn = '${_currentPlayer.toString().split('.').last}\'s Turn';
    if (_kingInCheckPos != null) {
      turn += " (Check!)";
    }
    setState(() {
      _status = turn;
    });
  }

  bool _isGameOver() =>
      _status.contains("wins") || _status.contains("Stalemate");

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text(_status),
          actions: <Widget>[
            TextButton(
              child: const Text('Play Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeBoard();
              },
            ),
          ],
        );
      },
    );
  }

  // --- AI LOGIC ---
  void _makeAiMove() {
    if (_isGameOver()) return;

    List<Move> allPossibleMoves = [];
    int bestScore = -9999;
    Move? bestMove;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (_board[r][c] != null && _board[r][c]!.color == PieceColor.black) {
          var moves = _getLegalMoves(r, c, _board[r][c]!);
          for (var moveOffset in moves) {
            allPossibleMoves.add(
              Move(r, c, moveOffset.dx.toInt(), moveOffset.dy.toInt()),
            );
          }
        }
      }
    }

    if (allPossibleMoves.isEmpty) return;

    // Evaluate moves
    for (var move in allPossibleMoves) {
      int score = 0;
      final targetPiece = _board[move.endRow][move.endCol];
      if (targetPiece != null) {
        score = targetPiece.value;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    // Add randomness if no good capture is found
    if (bestScore == 0) {
      bestMove = allPossibleMoves[Random().nextInt(allPossibleMoves.length)];
    }

    if (bestMove != null) {
      setState(() {
        _selectedRow = bestMove!.startRow;
        _selectedCol = bestMove!.startCol;
        _selectedPiece = _board[_selectedRow][_selectedCol];
        _movePiece(bestMove!.endRow, bestMove!.endCol, isAiMove: true);
      });
    }
  }

  // --- MOVE VALIDATION & LOGIC ---

  bool _isValid(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<Offset> _getLegalMoves(int row, int col, ChessPiece piece) {
    List<Offset> pseudoLegalMoves = _getPseudoLegalMoves(row, col, piece);
    List<Offset> legalMoves = [];

    for (var move in pseudoLegalMoves) {
      if (!_movePutsKingInCheck(
        row,
        col,
        move.dx.toInt(),
        move.dy.toInt(),
        piece.color,
      )) {
        legalMoves.add(move);
      }
    }
    return legalMoves;
  }

  List<Offset> _getAllLegalMovesForColor(PieceColor color) {
    List<Offset> allMoves = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (_board[r][c] != null && _board[r][c]!.color == color) {
          allMoves.addAll(_getLegalMoves(r, c, _board[r][c]!));
        }
      }
    }
    return allMoves;
  }

  void _checkForMate() {
    final opponentColor = _currentPlayer;
    final hasLegalMoves = _getAllLegalMovesForColor(opponentColor).isNotEmpty;
    final kingInCheck = _isKingInCheck(opponentColor);

    if (!hasLegalMoves) {
      if (kingInCheck) {
        setState(() {
          _status =
              '${opponentColor == PieceColor.white ? 'Black' : 'White'} wins by Checkmate!';
        });
      } else {
        setState(() {
          _status = 'Stalemate! It\'s a draw.';
        });
      }
      _showGameOverDialog();
    } else if (kingInCheck) {
      _kingInCheckPos = _findKing(opponentColor);
    } else {
      _kingInCheckPos = null;
    }
    _updateStatus();
  }

  bool _movePutsKingInCheck(
    int startRow,
    int startCol,
    int endRow,
    int endCol,
    PieceColor kingColor,
  ) {
    // Create a deep copy of the board to simulate the move
    var tempBoard = _board
        .map((row) => row.map((piece) => piece?.copy()).toList())
        .toList();

    // Simulate the move
    tempBoard[endRow][endCol] = tempBoard[startRow][startCol];
    tempBoard[startRow][startCol] = null;

    return _isKingInCheck(kingColor, board: tempBoard);
  }

  bool _isKingInCheck(PieceColor kingColor, {List<List<ChessPiece?>>? board}) {
    final currentBoard = board ?? _board;
    final kingPos = _findKing(kingColor, board: currentBoard);
    if (kingPos == null) return false;

    final opponentColor = kingColor == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (currentBoard[r][c] != null &&
            currentBoard[r][c]!.color == opponentColor) {
          var moves = _getPseudoLegalMoves(r, c, currentBoard[r][c]!);
          if (moves.contains(kingPos)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Offset? _findKing(PieceColor color, {List<List<ChessPiece?>>? board}) {
    final currentBoard = board ?? _board;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (currentBoard[r][c]?.type == PieceType.king &&
            currentBoard[r][c]!.color == color) {
          return Offset(r.toDouble(), c.toDouble());
        }
      }
    }
    return null;
  }

  List<Offset> _getPseudoLegalMoves(int row, int col, ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(row, col, piece);
      case PieceType.rook:
        return _getRookMoves(row, col, piece.color);
      case PieceType.knight:
        return _getKnightMoves(row, col, piece.color);
      case PieceType.bishop:
        return _getBishopMoves(row, col, piece.color);
      case PieceType.queen:
        return _getQueenMoves(row, col, piece.color);
      case PieceType.king:
        return _getKingMoves(row, col, piece.color);
    }
  }

  List<Offset> _getPawnMoves(int r, int c, ChessPiece piece) {
    List<Offset> moves = [];
    int dir = piece.color == PieceColor.white ? -1 : 1;
    // Forward 1
    if (_isValid(r + dir, c) && _board[r + dir][c] == null) {
      moves.add(Offset((r + dir).toDouble(), c.toDouble()));
    }
    // Forward 2
    if (!piece.hasMoved &&
        _isValid(r + dir, c) &&
        _board[r + dir][c] == null &&
        _isValid(r + 2 * dir, c) &&
        _board[r + 2 * dir][c] == null) {
      moves.add(Offset((r + 2 * dir).toDouble(), c.toDouble()));
    }
    // Capture
    for (int dc in [-1, 1]) {
      if (_isValid(r + dir, c + dc) &&
          _board[r + dir][c + dc] != null &&
          _board[r + dir][c + dc]!.color != piece.color) {
        moves.add(Offset((r + dir).toDouble(), (c + dc).toDouble()));
      }
    }
    return moves;
  }

  List<Offset> _getLineMoves(
    int r,
    int c,
    PieceColor color,
    List<Offset> directions,
  ) {
    List<Offset> moves = [];
    for (var dir in directions) {
      for (int i = 1; i < 8; i++) {
        int dr = r + dir.dx.toInt() * i;
        int dc = c + dir.dy.toInt() * i;
        if (!_isValid(dr, dc)) break;
        if (_board[dr][dc] == null) {
          moves.add(Offset(dr.toDouble(), dc.toDouble()));
        } else {
          if (_board[dr][dc]!.color != color) {
            moves.add(Offset(dr.toDouble(), dc.toDouble()));
          }
          break;
        }
      }
    }
    return moves;
  }

  List<Offset> _getRookMoves(int r, int c, PieceColor color) {
    return _getLineMoves(r, c, color, [
      const Offset(-1, 0),
      const Offset(1, 0),
      const Offset(0, -1),
      const Offset(0, 1),
    ]);
  }

  List<Offset> _getBishopMoves(int r, int c, PieceColor color) {
    return _getLineMoves(r, c, color, [
      const Offset(-1, -1),
      const Offset(-1, 1),
      const Offset(1, -1),
      const Offset(1, 1),
    ]);
  }

  List<Offset> _getQueenMoves(int r, int c, PieceColor color) {
    return _getRookMoves(r, c, color) + _getBishopMoves(r, c, color);
  }

  List<Offset> _getKnightMoves(int r, int c, PieceColor color) {
    List<Offset> moves = [];
    var offsets = [
      const Offset(-2, -1),
      const Offset(-2, 1),
      const Offset(-1, -2),
      const Offset(-1, 2),
      const Offset(1, -2),
      const Offset(1, 2),
      const Offset(2, -1),
      const Offset(2, 1),
    ];
    for (var o in offsets) {
      int dr = r + o.dx.toInt();
      int dc = c + o.dy.toInt();
      if (_isValid(dr, dc) &&
          (_board[dr][dc] == null || _board[dr][dc]!.color != color)) {
        moves.add(Offset(dr.toDouble(), dc.toDouble()));
      }
    }
    return moves;
  }

  List<Offset> _getKingMoves(int r, int c, PieceColor color) {
    List<Offset> moves = [];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = r + dr;
        int nc = c + dc;
        if (_isValid(nr, nc) &&
            (_board[nr][nc] == null || _board[nr][nc]!.color != color)) {
          moves.add(Offset(nr.toDouble(), nc.toDouble()));
        }
      }
    }
    return moves;
  }

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Chess'),
        backgroundColor: const Color(0xFF1a1a19),
        actions: [
          PopupMenuButton<GameMode>(
            onSelected: (GameMode mode) {
              setState(() {
                _gameMode = mode;
                _initializeBoard();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<GameMode>>[
              const PopupMenuItem<GameMode>(
                value: GameMode.singlePlayer,
                child: Text('Single Player'),
              ),
              const PopupMenuItem<GameMode>(
                value: GameMode.twoPlayer,
                child: Text('Two Players'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeBoard,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CapturedPiecesWidget(pieces: _blackCaptured),
            const SizedBox(height: 10),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  itemCount: 64,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                  ),
                  itemBuilder: (context, index) {
                    int row = index ~/ 8;
                    int col = index % 8;
                    bool isLightSquare = (row + col) % 2 == 0;
                    bool isSelected =
                        row == _selectedRow && col == _selectedCol;
                    bool isValidMove = _validMoves.contains(
                      Offset(row.toDouble(), col.toDouble()),
                    );
                    bool isKingInCheck =
                        _kingInCheckPos != null &&
                        _kingInCheckPos!.dx == row &&
                        _kingInCheckPos!.dy == col;

                    return GestureDetector(
                      onTap: () => _handleTap(row, col),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade400
                              : isKingInCheck
                              ? Colors.red.shade400
                              : isLightSquare
                              ? const Color(0xFFF0D9B5)
                              : const Color(0xFFB58863),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_board[row][col] != null)
                              Text(
                                _board[row][col]!.unicode,
                                style: TextStyle(
                                  fontSize: 36,
                                  color:
                                      _board[row][col]!.color ==
                                          PieceColor.white
                                      ? Colors.white
                                      : Colors.black,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4.0,
                                      color:
                                          _board[row][col]!.color ==
                                              PieceColor.white
                                          ? Colors.black.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.5),
                                      offset: const Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                            if (isValidMove)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            CapturedPiecesWidget(pieces: _whiteCaptured),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                _status,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CapturedPiecesWidget extends StatelessWidget {
  final List<ChessPiece> pieces;
  const CapturedPiecesWidget({super.key, required this.pieces});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pieces.length,
        itemBuilder: (context, index) {
          return Text(
            pieces[index].unicode,
            style: TextStyle(
              fontSize: 24,
              color: pieces[index].color == PieceColor.white
                  ? Colors.white70
                  : Colors.black87,
            ),
          );
        },
      ),
    );
  }
}
