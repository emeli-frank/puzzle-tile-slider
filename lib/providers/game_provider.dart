import 'dart:async';

import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/material.dart';
import 'package:number_sliding_puzzle/models/game_status.dart';
import 'package:number_sliding_puzzle/models/position.dart';
import 'package:number_sliding_puzzle/models/tile.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class GameProvider with ChangeNotifier {
  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  List<List<Tile>> _tilePositions = [
    [],
    [],
    [],
    []
  ]; // holds arrangement of tiles
  final GameStatus gameStatus = GameStatus();
  String gameStatusText = '';
  int moveCount = 0;
  int bestMoveCount = 0;
  int lastGameMoveCount = 0;
  bool _playSound = false;

  GameProvider() {
    // init sound preference
    _prefs.then((prefs) {
      bool playSound = prefs.getBool('play_sound_key') ?? false;
      _playSound = playSound;
      prefs.setBool('play_sound_key', _playSound);
    });

    // Create tiles and arrange them without shuffling yet
    for(int y = 0; y < _tilePositions.length; y ++) {
      for(int x = 0; x < _tilePositions.length; x ++) {
        _tilePositions[y].add(Tile(order: (y * 4) + (x + 1)));
      }
    }

    // set the cell at the lowest rightmost corner to be empty
    _tilePositions[3][3] = null;

    gameStatus.isCompleted = false;

    // shuffle tiles
    shuffleTiles();
  }

  AxisDirection _getMoveDirection(Position touchedTilePosition) {
    /*
    * Returns move direction or nil if it cannot move
    * This function can secondarily be used to find out if a tile can move
    */

    // holds clicked tile including tiles at it's left and right
    List<Position> verticalPositions = [];

    // holds clicked tile including tiles at it's top and bottom
    List<Position> horizontalPositions = [];

    // add clicked tile including those at it's left and right to the horizontalPositions list
    for (int x = 0; x < 4; x++) {
      horizontalPositions.add(Position(
        x: x,
        y: touchedTilePosition.y,
      ));
    }

    // add clicked tile including those at it's top and bottom to the verticalPositions list
    for (int y = 0; y < 4; y++) {
      verticalPositions.add(Position(
          x: touchedTilePosition.x,
          y: y,
      ));
    }

    Position emptyPosition = getEmptyPosition();

    for (Position horizontalPosition in horizontalPositions) {
      if (horizontalPosition.y == emptyPosition.y) {

        if ((touchedTilePosition.x - emptyPosition.x).isNegative) {
          // tile movement is left to right
          return AxisDirection.leftToRight;
        }
        else {
          // tile movement is right to left
          return AxisDirection.rightToLeft;
        }
      }
    }

    for (Position verticalPosition in verticalPositions) {
      if (verticalPosition.x == emptyPosition.x) {

        if ((touchedTilePosition.y - emptyPosition.y).isNegative) {
          // tile movement is top to bottom
          return AxisDirection.topToBottom;
        }
        else {
          // tile movement is bottom to top
          return AxisDirection.bottomToTop;
        }
      }
    }

    return AxisDirection.nil;
  }

  // checks if a piece can move by trying to get it's move direction
  // and moving it if it can
  bool move(Position touchedTilePosition, {bool shuffling = false}) {
    // todo:: this flag is used to signal widget to show game over dialog
    // implement properly, they should be notified via stream or something
    bool gameCompleted = false;
    if (gameStatus.isCompleted)
      return false;

    Position emptyPosition = getEmptyPosition();
    List<Position> positions = [];

    final AudioCache player = AudioCache(prefix: 'sounds/');
    if (shuffling == false && _playSound == true) {
      player.play('pop.mp3');
    }

    // return false if tile can't be moved
    if (_getMoveDirection(touchedTilePosition) == AxisDirection.nil) {
      return false;
    }

    if (_getMoveDirection(touchedTilePosition) == AxisDirection.leftToRight) {
      for (int x = 0; x < 4; x++) {
        if (x >= touchedTilePosition.x && x <= emptyPosition.x) {
          positions.add(Position(
            x: x,
            y: touchedTilePosition.y,
          ));
        }
      }

      int noOfSwaps = positions.length - 1;

      while (noOfSwaps > 0) {
        // print('swapping ${Position(x: positions[noOfSwaps].x, y: touchedTilePosition.y)} and ${Position(x:positions[--noOfSwaps].x, y: touchedTilePosition.y)}');
        _swapTiles(Position(x: positions[noOfSwaps].x, y: touchedTilePosition.y),
            Position(x:positions[--noOfSwaps].x, y: touchedTilePosition.y));
      }

      notifyListeners();
    }
    else if (_getMoveDirection(touchedTilePosition) == AxisDirection.rightToLeft) {
      for (int x = 0; x < 4; x++) {
        // TODO:: Add helpful comment
        if (x <= touchedTilePosition.x && x >= emptyPosition.x) {
          positions.add(Position(
            x: x,
            y: touchedTilePosition.y,
          ));
        }
      }

      // Get number of times to call swap function
      int noOfSwaps = positions.length - 1;
      List<Position> reversedPositions = positions.reversed.toList();

      while (noOfSwaps > 0) {
        // print('swapping ${Position(x: positions[noOfSwaps].x, y: touchedTilePosition.y)} and ${Position(x:positions[--noOfSwaps].x, y: touchedTilePosition.y)}');
        _swapTiles(Position(x: reversedPositions[noOfSwaps].x, y: touchedTilePosition.y),
            Position(x:reversedPositions[--noOfSwaps].x, y: touchedTilePosition.y));
      }

      notifyListeners();
    }
    else if (_getMoveDirection(touchedTilePosition) == AxisDirection.topToBottom) {
      for (int y = 0; y < 4; y++) {
        if (y >= touchedTilePosition.y && y <= emptyPosition.y) {
          positions.add(Position(
            x: touchedTilePosition.x,
            y: y,
          ));
        }
      }

      int noOfSwaps = positions.length - 1;

      while (noOfSwaps > 0) {
        // print('swapping ${Position(x: positions[noOfSwaps].x, y: touchedTilePosition.y)} and ${Position(x:positions[--noOfSwaps].x, y: touchedTilePosition.y)}');
        _swapTiles(Position(y: positions[noOfSwaps].y, x: touchedTilePosition.x),
            Position(y:positions[--noOfSwaps].y, x: touchedTilePosition.x));
      }

      notifyListeners();
    }
    else if (_getMoveDirection(touchedTilePosition) == AxisDirection.bottomToTop) {
      for (int y = 0; y < 4; y++) {
        if (y <= touchedTilePosition.y && y >= emptyPosition.y) {
          positions.add(Position(
            y: y,
            x: touchedTilePosition.x,
          ));
        }
      }

      int noOfSwaps = positions.length - 1;
      List<Position> reversedPositions = positions.reversed.toList();

      while (noOfSwaps > 0) {
        // print('swapping ${Position(x: positions[noOfSwaps].x, y: touchedTilePosition.y)} and ${Position(x:positions[--noOfSwaps].x, y: touchedTilePosition.y)}');
        _swapTiles(Position(y: reversedPositions[noOfSwaps].y, x: touchedTilePosition.x),
            Position(y:reversedPositions[--noOfSwaps].y, x: touchedTilePosition.x));
      }

      notifyListeners();
    }

    moveCount++;

    if (shuffling == false) {
      bool inOrder = isTileInOrder();
      if (inOrder) {
        gameStatus.isCompleted = true;
        bestMoveCount = bestMoveCount > 0 && bestMoveCount < moveCount
            ? bestMoveCount : moveCount;
        lastGameMoveCount = moveCount;
        gameCompleted = true;
        notifyListeners();
      }
    }

    return gameCompleted;
  }

  // checks if tiles are in order
  bool isTileInOrder() { // TODO:: double check algorithm
    int next = 1;

    for (int y = 0; y < tilePositions.length; y++) {
      for (int x = 0; x < tilePositions[y].length; x++) {
        // if we have not finished counting loop and return false if tile is out
        // of order
        if (next <= 15) {
          // game is not complete, just exit
          if (tilePositions[y][x] == null) {
            notifyListeners();
            return false;
          }
          else {
            // check if current tile is increasing by one
            if (tilePositions[y][x].order == next++) {
              // print(tilePositions[y][x].order);
              continue;
            }
            // current tile did not increase by one
            else {
              notifyListeners();
              return false;
            }
          }
        }
        // count finished without exiting, so tile has to be in order
        else {
          return true;
        }
      }
    }
    
    return false;
  }

  void restartGame() {
    gameStatus.isCompleted = false;
    gameStatusText = "";
    moveCount = 0;
    shuffleTiles();
    moveCount = 0;
    lastGameMoveCount = 0;
  }

  void shuffleTiles() {
    final random = Random();

    for (int i = 0; i < 500; i++) {
      Position emptyPosition = getEmptyPosition();
      ShuffleDirection shuffleDirection = (random.nextInt(2) == 1)
          ? ShuffleDirection.horizontal
          : ShuffleDirection.vertical;

      int x, y; // positions to move to

      if (shuffleDirection == ShuffleDirection.horizontal) {
        // get random x position that is not empty
        do {
          x = random.nextInt(4);
        } while (x == emptyPosition.x);

        // set y to the row that has the empty slot (so that it can move)
        y = emptyPosition.y;
      }
      else {
        // get random y position that is not empty
         do {
          y = random.nextInt(4);
        } while (y == emptyPosition.y);

         // set x to the column that has the empty slot (so that it can move)
        x = emptyPosition.x;
      }

      move(Position(x: x, y: y), shuffling: true);
    }

    moveCount = 0;
  }

  void _swapTiles(Position tile, Position empty) {
    var temp = _tilePositions[tile.y][tile.x];
    _tilePositions[tile.y][tile.x] = _tilePositions[empty.y][empty.x];
    _tilePositions[empty.y][empty.x] = temp;
  }

  // finds and returns the position of the empty cell on the board
  Position getEmptyPosition() {
    Position position;

    for (int y = 0; y < _tilePositions.length; y++) {
      for (int x = 0; x < _tilePositions[y].length; x++) {
        if (_tilePositions[y][x] == null) {
          position = Position(
            x: x,
            y: y,
          );
        }
      }
    }

    return position;
  }

  List<List<Tile>> get tilePositions => _tilePositions;

  Map<String, double> getWidgetPosition({@required double boardWidth, @required Position position}) {
    return {
      'x': boardWidth * (((position.x + 4) % 4) / 4),
      'y': boardWidth * (position.y) / 4,
    };
  }

  Map<String, double> getAlignment({@required Position position}) {
    double getCoordinate(value) {
      switch(value) {
        case 0:
          return -1;
        case 1:
          return -1 / 3;
        case 2:
          return 1 / 3;
        case 3:
          return 1;
        default:
          return null;
      }
    }

    return {
      'x': getCoordinate(position.x),
      'y': getCoordinate(position.y),
    };


  }

  Future <void> toggleSound() async {
    final SharedPreferences prefs = await _prefs;
    bool playSound = prefs.getBool('play_sound_key') ?? false;
    _playSound = !playSound;
    prefs.setBool('play_sound_key', _playSound);
    notifyListeners();
  }

  bool get playSound {
    return _playSound;
  }
}

enum AxisDirection {
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
  nil,
}


enum ShuffleDirection {
  horizontal,
  vertical,
}