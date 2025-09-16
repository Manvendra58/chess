import 'dart:async';
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
  final String id;

  ChessPiece(this.type, this.color, {this.hasMoved = false})
    : id = UniqueKey().toString();

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
        return 100;
      case PieceType.knight:
        return 320;
      case PieceType.bishop:
        return 330;
      case PieceType.rook:
        return 500;
      case PieceType.queen:
        return 900;
      case PieceType.king:
        return 20000;
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
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF1a1a19),
        fontFamily: 'Roboto',
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
  String _status = "Choose a Game Mode";
  List<ChessPiece> _whiteCaptured = [];
  List<ChessPiece> _blackCaptured = [];
  Offset? _kingInCheckPos;
  Move? _lastMove;
  Offset? _enPassantTarget;
  bool _isAiThinking = false;

  // AI piece-square tables for better evaluation
  final Map<PieceType, List<int>> _pieceSquareTables = {
    PieceType.pawn: [
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      50,
      50,
      50,
      50,
      50,
      50,
      50,
      50,
      10,
      10,
      20,
      30,
      30,
      20,
      10,
      10,
      5,
      5,
      10,
      25,
      25,
      10,
      5,
      5,
      0,
      0,
      0,
      20,
      20,
      0,
      0,
      0,
      5,
      -5,
      -10,
      0,
      0,
      -10,
      -5,
      5,
      5,
      10,
      10,
      -20,
      -20,
      10,
      10,
      5,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ],
    PieceType.knight: [
      -50,
      -40,
      -30,
      -30,
      -30,
      -30,
      -40,
      -50,
      -40,
      -20,
      0,
      0,
      0,
      0,
      -20,
      -40,
      -30,
      0,
      10,
      15,
      15,
      10,
      0,
      -30,
      -30,
      5,
      15,
      20,
      20,
      15,
      5,
      -30,
      -30,
      0,
      15,
      20,
      20,
      15,
      0,
      -30,
      -30,
      5,
      10,
      15,
      15,
      10,
      5,
      -30,
      -40,
      -20,
      0,
      5,
      5,
      0,
      -20,
      -40,
      -50,
      -40,
      -30,
      -30,
      -30,
      -30,
      -40,
      -50,
    ],
    PieceType.bishop: [
      -20,
      -10,
      -10,
      -10,
      -10,
      -10,
      -10,
      -20,
      -10,
      0,
      0,
      0,
      0,
      0,
      0,
      -10,
      -10,
      0,
      5,
      10,
      10,
      5,
      0,
      -10,
      -10,
      5,
      5,
      10,
      10,
      5,
      5,
      -10,
      -10,
      0,
      10,
      10,
      10,
      10,
      0,
      -10,
      -10,
      10,
      10,
      10,
      10,
      10,
      10,
      -10,
      -10,
      5,
      0,
      0,
      0,
      0,
      5,
      -10,
      -20,
      -10,
      -10,
      -10,
      -10,
      -10,
      -10,
      -20,
    ],
    PieceType.rook: [
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      5,
      10,
      10,
      10,
      10,
      10,
      10,
      5,
      -5,
      0,
      0,
      0,
      0,
      0,
      0,
      -5,
      -5,
      0,
      0,
      0,
      0,
      0,
      0,
      -5,
      -5,
      0,
      0,
      0,
      0,
      0,
      0,
      -5,
      -5,
      0,
      0,
      0,
      0,
      0,
      0,
      -5,
      -5,
      0,
      0,
      0,
      0,
      0,
      0,
      -5,
      0,
      0,
      0,
      5,
      5,
      0,
      0,
      0,
    ],
    PieceType.queen: [
      -20,
      -10,
      -10,
      -5,
      -5,
      -10,
      -10,
      -20,
      -10,
      0,
      0,
      0,
      0,
      0,
      0,
      -10,
      -10,
      0,
      5,
      5,
      5,
      5,
      0,
      -10,
      -5,
      0,
      5,
      5,
      5,
      5,
      0,
      -5,
      0,
      0,
      5,
      5,
      5,
      5,
      0,
      -5,
      -10,
      5,
      5,
      5,
      5,
      5,
      0,
      -10,
      -10,
      0,
      5,
      0,
      0,
      0,
      0,
      -10,
      -20,
      -10,
      -10,
      -5,
      -5,
      -10,
      -10,
      -20,
    ],
    PieceType.king: [
      -30,
      -40,
      -40,
      -50,
      -50,
      -40,
      -40,
      -30,
      -30,
      -40,
      -40,
      -50,
      -50,
      -40,
      -40,
      -30,
      -30,
      -40,
      -40,
      -50,
      -50,
      -40,
      -40,
      -30,
      -30,
      -40,
      -40,
      -50,
      -50,
      -40,
      -40,
      -30,
      -20,
      -30,
      -30,
      -40,
      -40,
      -30,
      -30,
      -20,
      -10,
      -20,
      -20,
      -20,
      -20,
      -20,
      -20,
      -10,
      20,
      20,
      0,
      0,
      0,
      0,
      20,
      20,
      20,
      30,
      10,
      0,
      0,
      10,
      30,
      20,
    ],
  };

  @override
  void initState() {
    super.initState();
    _board = List.generate(8, (_) => List.filled(8, null)); // Init empty board
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGameModeDialog());
  }

  void _playSound(String sound) {
    // DartPad does not support audio, but the logic is here for a full Flutter project.
    // Example: if (sound == 'move') AudioPlayer().play(AssetSource('sounds/move.mp3'));
  }

  void _showGameModeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text('New Game', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4a4a4a),
                minimumSize: const Size.fromHeight(45),
              ),
              child: const Text('Single Player (vs AI)'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeBoard(GameMode.singlePlayer);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4a4a4a),
                minimumSize: const Size.fromHeight(45),
              ),
              child: const Text('Two Players'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeBoard(GameMode.twoPlayer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _initializeBoard(GameMode mode) {
    setState(() {
      _gameMode = mode;
      _board = List.generate(8, (_) => List.filled(8, null));
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
        _board[1][i] = ChessPiece(PieceType.pawn, PieceColor.black);
        _board[6][i] = ChessPiece(PieceType.pawn, PieceColor.white);
        _board[0][i] = ChessPiece(pieceOrder[i], PieceColor.black);
        _board[7][i] = ChessPiece(pieceOrder[i], PieceColor.white);
      }

      _resetSelection();
      _currentPlayer = PieceColor.white;
      _whiteCaptured = [];
      _blackCaptured = [];
      _kingInCheckPos = null;
      _lastMove = null;
      _enPassantTarget = null;
      _isAiThinking = false;
      _updateStatus();
    });
  }

  void _handleTap(int row, int col) {
    if (_isGameOver() || _isAiThinking) return;

    setState(() {
      if (_selectedPiece == null) {
        if (_board[row][col] != null &&
            _board[row][col]!.color == _currentPlayer) {
          _selectPiece(row, col);
        }
      } else {
        if (_validMoves.contains(Offset(row.toDouble(), col.toDouble()))) {
          _movePiece(row, col);
        } else if (_board[row][col] != null &&
            _board[row][col]!.color == _currentPlayer) {
          _selectPiece(row, col);
        } else {
          _resetSelection();
        }
      }
    });
  }

  void _selectPiece(int row, int col) {
    _selectedPiece = _board[row][col];
    _selectedRow = row;
    _selectedCol = col;
    _validMoves = _getLegalMoves(row, col, _selectedPiece!);
  }

  void _movePiece(int newRow, int newCol, {bool isAiMove = false}) {
    final piece = _selectedPiece!;
    bool isCapture = _board[newRow][newCol] != null;
    _lastMove = Move(_selectedRow, _selectedCol, newRow, newCol);

    if (piece.type == PieceType.pawn &&
        Offset(newRow.toDouble(), newCol.toDouble()) == _enPassantTarget) {
      int capturedPawnRow = _currentPlayer == PieceColor.white
          ? newRow + 1
          : newRow - 1;
      _board[capturedPawnRow][newCol] = null;
      isCapture = true;
    }

    _enPassantTarget = null;
    if (piece.type == PieceType.pawn && (_selectedRow - newRow).abs() == 2) {
      _enPassantTarget = Offset(
        ((_selectedRow + newRow) / 2),
        newCol.toDouble(),
      );
    }

    if (piece.type == PieceType.king && (newCol - _selectedCol).abs() == 2) {
      if (newCol > _selectedCol) {
        _board[newRow][newCol - 1] = _board[newRow][7];
        _board[newRow][7] = null;
        _board[newRow][newCol - 1]!.hasMoved = true;
      } else {
        _board[newRow][newCol + 1] = _board[newRow][0];
        _board[newRow][0] = null;
        _board[newRow][newCol + 1]!.hasMoved = true;
      }
    }

    if (_board[newRow][newCol] != null) {
      final captured = _board[newRow][newCol]!;
      (captured.color == PieceColor.white)
          ? _blackCaptured.add(captured)
          : _whiteCaptured.add(captured);
    }

    _board[newRow][newCol] = piece;
    _board[_selectedRow][_selectedCol] = null;
    piece.hasMoved = true;

    _playSound(isCapture ? 'capture.mp3' : 'move.mp3');

    if (piece.type == PieceType.pawn && (newRow == 0 || newRow == 7)) {
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
      setState(() => _isAiThinking = true);
      Future.delayed(const Duration(milliseconds: 400), _makeAiMove);
    }
  }

  void _promotePawn(int row, int col, {bool isAiMove = false}) {
    if (isAiMove) {
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
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text(
          'Promote Pawn',
          style: TextStyle(color: Colors.white),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              [
                    PieceType.queen,
                    PieceType.rook,
                    PieceType.bishop,
                    PieceType.knight,
                  ]
                  .map(
                    (type) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _board[row][col] = ChessPiece(type, _currentPlayer);
                          _postMoveUpdate();
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        ChessPiece(type, _currentPlayer).unicode,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  void _switchPlayer() => _currentPlayer = _currentPlayer == PieceColor.white
      ? PieceColor.black
      : PieceColor.white;

  void _resetSelection() {
    _selectedPiece = null;
    _selectedRow = -1;
    _selectedCol = -1;
    _validMoves = [];
  }

  void _updateStatus() {
    if (_isGameOver()) return;
    var turn =
        '${_currentPlayer.toString().split('.').last.capitalize()}\'s Turn';
    if (_kingInCheckPos != null) turn += " (Check!)";
    setState(() => _status = turn);
  }

  bool _isGameOver() =>
      _status.contains("wins") || _status.contains("Stalemate");

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF2c2c2c),
        title: const Text('Game Over', style: TextStyle(color: Colors.white)),
        content: Text(_status, style: const TextStyle(color: Colors.white70)),
        actions: <Widget>[
          TextButton(
            child: const Text('New Game'),
            onPressed: () {
              Navigator.of(context).pop();
              _showGameModeDialog();
            },
          ),
        ],
      ),
    );
  }

  // --- AI LOGIC ---
  void _makeAiMove() {
    if (_isGameOver()) return;
    Move? bestMove;
    int bestScore = -99999;
    final allPossibleMoves = _getAllPossibleMovesForColor(PieceColor.black);
    allPossibleMoves.shuffle();
    for (var move in allPossibleMoves) {
      var tempBoard = _cloneBoard(_board);
      _simulateMove(tempBoard, move);
      int score = _minimax(tempBoard, 2, -100000, 100000, false);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    if (bestMove != null) {
      setState(() {
        _selectedRow = bestMove!.startRow;
        _selectedCol = bestMove!.startCol;
        _selectedPiece = _board[_selectedRow][_selectedCol];
        _movePiece(bestMove.endRow, bestMove.endCol, isAiMove: true);
      });
    }
    setState(() => _isAiThinking = false);
  }

  int _minimax(
    List<List<ChessPiece?>> board,
    int depth,
    int alpha,
    int beta,
    bool isMaximizingPlayer,
  ) {
    final playerColor = isMaximizingPlayer
        ? PieceColor.black
        : PieceColor.white;
    if (depth == 0 || _isCheckmateOrStalemate(board, playerColor)) {
      return _evaluateBoard(board);
    }
    List<Move> allMoves = _getAllPossibleMovesForColor(
      playerColor,
      board: board,
    );
    if (isMaximizingPlayer) {
      int maxEval = -99999;
      for (var move in allMoves) {
        var tempBoard = _cloneBoard(board);
        _simulateMove(tempBoard, move);
        int eval = _minimax(tempBoard, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 99999;
      for (var move in allMoves) {
        var tempBoard = _cloneBoard(board);
        _simulateMove(tempBoard, move);
        int eval = _minimax(tempBoard, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  int _evaluateBoard(List<List<ChessPiece?>> board) {
    int score = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null) {
          int value = piece.value + _getPositionalValue(piece, r, c);
          score += (piece.color == PieceColor.black) ? value : -value;
        }
      }
    }
    return score;
  }

  int _getPositionalValue(ChessPiece piece, int row, int col) {
    List<int> table = _pieceSquareTables[piece.type]!;
    int index = piece.color == PieceColor.white
        ? row * 8 + col
        : (7 - row) * 8 + col;
    return table[index];
  }

  // --- MOVE VALIDATION & LOGIC ---
  bool _isValid(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<Offset> _getLegalMoves(int row, int col, ChessPiece piece) {
    List<Offset> pseudoLegalMoves = _getPseudoLegalMoves(row, col, piece);
    return pseudoLegalMoves
        .where(
          (move) => !_movePutsKingInCheck(
            row,
            col,
            move.dx.toInt(),
            move.dy.toInt(),
            piece.color,
          ),
        )
        .toList();
  }

  List<Move> _getAllPossibleMovesForColor(
    PieceColor color, {
    List<List<ChessPiece?>>? board,
  }) {
    final currentBoard = board ?? _board;
    List<Move> allMoves = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (currentBoard[r][c] != null && currentBoard[r][c]!.color == color) {
          var moves = _getPseudoLegalMoves(
            r,
            c,
            currentBoard[r][c]!,
            board: currentBoard,
          );
          for (var moveOffset in moves) {
            if (!_movePutsKingInCheck(
              r,
              c,
              moveOffset.dx.toInt(),
              moveOffset.dy.toInt(),
              color,
              board: currentBoard,
            )) {
              allMoves.add(
                Move(r, c, moveOffset.dx.toInt(), moveOffset.dy.toInt()),
              );
            }
          }
        }
      }
    }
    return allMoves;
  }

  bool _isCheckmateOrStalemate(
    List<List<ChessPiece?>> board,
    PieceColor playerColor,
  ) => _getAllPossibleMovesForColor(playerColor, board: board).isEmpty;

  void _checkForMate() {
    final hasLegalMoves = _getAllPossibleMovesForColor(
      _currentPlayer,
    ).isNotEmpty;
    final kingInCheck = _isKingInCheck(_currentPlayer);
    if (!hasLegalMoves) {
      if (kingInCheck) {
        setState(
          () => _status =
              '${_currentPlayer == PieceColor.white ? 'Black' : 'White'} wins by Checkmate!',
        );
      } else {
        setState(() => _status = 'Stalemate! It\'s a draw.');
      }
      _showGameOverDialog();
    } else if (kingInCheck) {
      _kingInCheckPos = _findKing(_currentPlayer);
      _playSound('check.mp3');
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
    PieceColor kingColor, {
    List<List<ChessPiece?>>? board,
  }) {
    var tempBoard = _cloneBoard(board ?? _board);
    _simulateMove(tempBoard, Move(startRow, startCol, endRow, endCol));
    return _isKingInCheck(kingColor, board: tempBoard);
  }

  bool _isKingInCheck(PieceColor kingColor, {List<List<ChessPiece?>>? board}) {
    final currentBoard = board ?? _board;
    final kingPos = _findKing(kingColor, board: currentBoard);
    if (kingPos == null) return false;
    final opponentColor = (kingColor == PieceColor.white)
        ? PieceColor.black
        : PieceColor.white;
    return _isSquareUnderAttack(
      kingPos.dx.toInt(),
      kingPos.dy.toInt(),
      opponentColor,
      board: currentBoard,
    );
  }

  bool _isSquareUnderAttack(
    int row,
    int col,
    PieceColor attackerColor, {
    required List<List<ChessPiece?>> board,
  }) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == attackerColor) {
          if (piece.type == PieceType.king) continue;
          if (piece.type == PieceType.pawn) {
            int dir = piece.color == PieceColor.white ? -1 : 1;
            if ((row == r + dir && (col == c + 1 || col == c - 1))) return true;
          } else {
            final moves = _getPseudoLegalMoves(r, c, piece, board: board);
            if (moves.any((move) => move.dx == row && move.dy == col))
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

  List<List<ChessPiece?>> _cloneBoard(List<List<ChessPiece?>> board) =>
      board.map((row) => row.map((piece) => piece?.copy()).toList()).toList();
  void _simulateMove(List<List<ChessPiece?>> board, Move move) {
    final piece = board[move.startRow][move.startCol];
    board[move.endRow][move.endCol] = piece;
    board[move.startRow][move.startCol] = null;
    if (piece != null) piece.hasMoved = true;
  }

  List<Offset> _getPseudoLegalMoves(
    int row,
    int col,
    ChessPiece piece, {
    List<List<ChessPiece?>>? board,
  }) {
    final currentBoard = board ?? _board;
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(row, col, piece, board: currentBoard);
      case PieceType.rook:
        return _getLineMoves(row, col, piece.color, [
          const Offset(-1, 0),
          const Offset(1, 0),
          const Offset(0, -1),
          const Offset(0, 1),
        ], board: currentBoard);
      case PieceType.knight:
        return _getKnightMoves(row, col, piece.color, board: currentBoard);
      case PieceType.bishop:
        return _getLineMoves(row, col, piece.color, [
          const Offset(-1, -1),
          const Offset(-1, 1),
          const Offset(1, -1),
          const Offset(1, 1),
        ], board: currentBoard);
      case PieceType.queen:
        return _getLineMoves(row, col, piece.color, [
          const Offset(-1, 0),
          const Offset(1, 0),
          const Offset(0, -1),
          const Offset(0, 1),
          const Offset(-1, -1),
          const Offset(-1, 1),
          const Offset(1, -1),
          const Offset(1, 1),
        ], board: currentBoard);
      case PieceType.king:
        return _getKingMoves(row, col, piece, board: currentBoard);
    }
  }

  List<Offset> _getPawnMoves(
    int r,
    int c,
    ChessPiece piece, {
    required List<List<ChessPiece?>> board,
  }) {
    List<Offset> moves = [];
    int dir = piece.color == PieceColor.white ? -1 : 1;
    if (_isValid(r + dir, c) && board[r + dir][c] == null) {
      moves.add(Offset((r + dir).toDouble(), c.toDouble()));
      if (!piece.hasMoved &&
          _isValid(r + 2 * dir, c) &&
          board[r + 2 * dir][c] == null) {
        moves.add(Offset((r + 2 * dir).toDouble(), c.toDouble()));
      }
    }
    for (int dc in [-1, 1]) {
      if (_isValid(r + dir, c + dc) &&
          board[r + dir][c + dc] != null &&
          board[r + dir][c + dc]!.color != piece.color) {
        moves.add(Offset((r + dir).toDouble(), (c + dc).toDouble()));
      }
    }
    if (_enPassantTarget != null &&
        _enPassantTarget!.dx == (r + dir) &&
        (_enPassantTarget!.dy - c).abs() == 1) {
      moves.add(_enPassantTarget!);
    }
    return moves;
  }

  List<Offset> _getLineMoves(
    int r,
    int c,
    PieceColor color,
    List<Offset> directions, {
    required List<List<ChessPiece?>> board,
  }) {
    List<Offset> moves = [];
    for (var dir in directions) {
      for (int i = 1; i < 8; i++) {
        int dr = r + dir.dx.toInt() * i;
        int dc = c + dir.dy.toInt() * i;
        if (!_isValid(dr, dc)) break;
        if (board[dr][dc] == null) {
          moves.add(Offset(dr.toDouble(), dc.toDouble()));
        } else {
          if (board[dr][dc]!.color != color)
            moves.add(Offset(dr.toDouble(), dc.toDouble()));
          break;
        }
      }
    }
    return moves;
  }

  List<Offset> _getKnightMoves(
    int r,
    int c,
    PieceColor color, {
    required List<List<ChessPiece?>> board,
  }) {
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
          (board[dr][dc] == null || board[dr][dc]!.color != color)) {
        moves.add(Offset(dr.toDouble(), dc.toDouble()));
      }
    }
    return moves;
  }

  List<Offset> _getKingMoves(
    int r,
    int c,
    ChessPiece piece, {
    required List<List<ChessPiece?>> board,
  }) {
    List<Offset> moves = [];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = r + dr;
        int nc = c + dc;
        if (_isValid(nr, nc) &&
            (board[nr][nc] == null || board[nr][nc]!.color != piece.color)) {
          moves.add(Offset(nr.toDouble(), nc.toDouble()));
        }
      }
    }
    if (!piece.hasMoved && !_isKingInCheck(piece.color, board: board)) {
      if (_isValid(r, c + 3) &&
          board[r][c + 1] == null &&
          board[r][c + 2] == null &&
          board[r][c + 3]?.type == PieceType.rook &&
          !board[r][c + 3]!.hasMoved) {
        if (!_isSquareUnderAttack(
              r,
              c + 1,
              piece.color.opponent,
              board: board,
            ) &&
            !_isSquareUnderAttack(
              r,
              c + 2,
              piece.color.opponent,
              board: board,
            )) {
          moves.add(Offset(r.toDouble(), (c + 2).toDouble()));
        }
      }
      if (_isValid(r, c - 4) &&
          board[r][c - 1] == null &&
          board[r][c - 2] == null &&
          board[r][c - 3] == null &&
          board[r][c - 4]?.type == PieceType.rook &&
          !board[r][c - 4]!.hasMoved) {
        if (!_isSquareUnderAttack(
              r,
              c - 1,
              piece.color.opponent,
              board: board,
            ) &&
            !_isSquareUnderAttack(
              r,
              c - 2,
              piece.color.opponent,
              board: board,
            )) {
          moves.add(Offset(r.toDouble(), (c - 2).toDouble()));
        }
      }
    }
    return moves;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth > 500 ? 500.0 : screenWidth - 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Chess'),
        backgroundColor: const Color(0xFF1a1a19),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _showGameModeDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF2c2c2c), const Color(0xFF1a1a19)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusDisplay(
                    status: _status,
                    currentPlayer: _currentPlayer,
                    isGameOver: _isGameOver(),
                  ),
                  CapturedPiecesWidget(pieces: _blackCaptured),
                  const SizedBox(height: 10),
                  ChessBoardWidget(
                    board: _board,
                    boardSize: boardSize,
                    selectedRow: _selectedRow,
                    selectedCol: _selectedCol,
                    validMoves: _validMoves,
                    kingInCheckPos: _kingInCheckPos,
                    lastMove: _lastMove,
                    onTap: _handleTap,
                  ),
                  const SizedBox(height: 10),
                  CapturedPiecesWidget(pieces: _whiteCaptured),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- UI WIDGETS ---
class ChessBoardWidget extends StatelessWidget {
  final List<List<ChessPiece?>> board;
  final double boardSize;
  final int selectedRow, selectedCol;
  final List<Offset> validMoves;
  final Offset? kingInCheckPos;
  final Move? lastMove;
  final Function(int, int) onTap;

  const ChessBoardWidget({
    super.key,
    required this.board,
    required this.boardSize,
    required this.selectedRow,
    required this.selectedCol,
    required this.validMoves,
    this.kingInCheckPos,
    this.lastMove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boardSize,
      height: boardSize,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 64,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemBuilder: (context, index) {
          int row = index ~/ 8;
          int col = index % 8;
          return ChessSquare(
            row: row,
            col: col,
            piece: board[row][col],
            isSelected: row == selectedRow && col == selectedCol,
            isValidMove: validMoves.contains(
              Offset(row.toDouble(), col.toDouble()),
            ),
            isKingInCheck:
                kingInCheckPos != null &&
                kingInCheckPos!.dx == row &&
                kingInCheckPos!.dy == col,
            isLastMove:
                (lastMove?.startRow == row && lastMove?.startCol == col) ||
                (lastMove?.endRow == row && lastMove?.endCol == col),
            isLastMoveStart:
                lastMove?.startRow == row && lastMove?.startCol == col,
            onTap: () => onTap(row, col),
          );
        },
      ),
    );
  }
}

class ChessSquare extends StatefulWidget {
  final int row, col;
  final ChessPiece? piece;
  final bool isSelected,
      isValidMove,
      isKingInCheck,
      isLastMove,
      isLastMoveStart;
  final VoidCallback onTap;

  const ChessSquare({
    super.key,
    required this.row,
    required this.col,
    this.piece,
    required this.isSelected,
    required this.isValidMove,
    required this.isKingInCheck,
    required this.isLastMove,
    required this.isLastMoveStart,
    required this.onTap,
  });

  @override
  State<ChessSquare> createState() => _ChessSquareState();
}

class _ChessSquareState extends State<ChessSquare>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0.1,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isValidMove) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ChessSquare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isValidMove && !oldWidget.isValidMove) {
      _controller.repeat(reverse: true);
    } else if (!widget.isValidMove && oldWidget.isValidMove) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BoxDecoration _getSquareDecoration() {
    Color baseColor;
    if (widget.isSelected) {
      baseColor = const Color(0xFF86A666);
    } else if (widget.isKingInCheck) {
      baseColor = const Color(0xFFD96459);
    } else if (widget.isLastMove) {
      baseColor = widget.isLastMoveStart
          ? const Color(0xFFE8B33A).withOpacity(0.7)
          : const Color(0xFFE8B33A);
    } else {
      baseColor = (widget.row + widget.col) % 2 == 0
          ? const Color(0xFFEADAB9)
          : const Color(0xFF9F7E61);
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [baseColor, Color.lerp(baseColor, Colors.black, 0.2)!],
        stops: const [0.7, 1.0],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: _getSquareDecoration(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.piece != null)
              Text(
                widget.piece!.unicode,
                style: TextStyle(
                  fontSize: 36,
                  color: widget.piece!.color == PieceColor.white
                      ? Colors.white
                      : Colors.black,
                  shadows: [
                    Shadow(
                      blurRadius: 3.0,
                      color: widget.piece!.color == PieceColor.white
                          ? Colors.black.withOpacity(0.6)
                          : Colors.white.withOpacity(0.6),
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
              ),
            if (widget.isValidMove)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(_animation.value),
                      ],
                    ),
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
    if (pieces.isEmpty) return const SizedBox(height: 30);
    int materialScore = pieces.fold(
      0,
      (sum, piece) => sum + (piece.value ~/ 100),
    );
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pieces.map((p) => p.unicode).join(" "),
            style: const TextStyle(fontSize: 24, color: Colors.white70),
          ),
          if (materialScore > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '+$materialScore',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusDisplay extends StatelessWidget {
  final String status;
  final PieceColor currentPlayer;
  final bool isGameOver;

  const StatusDisplay({
    super.key,
    required this.status,
    required this.currentPlayer,
    required this.isGameOver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isGameOver)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: currentPlayer == PieceColor.white
                    ? Colors.white
                    : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            status,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

extension PieceColorExtension on PieceColor {
  PieceColor get opponent =>
      this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
