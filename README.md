# ♔ Chess Game with Stockfish AI ♔

A complete chess application featuring an interactive GUI and command-line interface with Stockfish AI engine.

## Features

### 🎮 GUI Application (`chess_app.py`)
- **Interactive Chess Board** - Beautiful visual board with piece highlighting
- **Click-to-Move Interface** - Select piece and click destination
- **Valid Moves Display** - See all legal moves highlighted
- **Difficulty Levels** - 20 adjustable difficulty settings (Beginner to Master)
- **Color Selection** - Play as WHITE or BLACK
- **Move History** - Track all moves in the game
- **Position Analysis** - Get Stockfish evaluation of positions
- **Hint System** - Receive AI suggestions
- **Undo Moves** - Take back your last move
- **Game Status Indicators** - Check, checkmate, stalemate detection
- **Modern Dark Theme** - Professional interface design

### 🎯 Command-Line Interface (`chess_with_ai.py`)
- **Console-based Gameplay** - Play via terminal
- **UCI Notation Input** - Standard chess notation (e.g., e2e4)
- **Move Validation** - Full legal move checking
- **Evaluation Display** - See position scores
- **Move Suggestions** - Get help with "help" command
- **Game History** - Track all moves played
- **Undo Support** - Take back moves

### 🤖 Stockfish AI Integration
- **Real Chess Engine** - Powered by Stockfish
- **Adjustable Difficulty** - 20 levels of AI strength
- **Position Analysis** - Deep position evaluation
- **Best Move Suggestions** - Get hints from the engine

## Installation

### Requirements
- Python 3.7+
- Stockfish Chess Engine

### Step 1: Install Python Packages

```bash
pip install python-chess PyQt5
```

### Step 2: Install Stockfish

**macOS:**
```bash
brew install stockfish
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install stockfish
```

**Windows:**
Download from [stockfishchess.org](https://stockfishchess.org/download/) and add to PATH

## Usage

### GUI Application (Recommended)

```bash
python chess_app.py
```

**How to Play:**
1. Click a piece to select it
2. Valid moves are highlighted with dots
3. Click destination square to move
4. Stockfish automatically responds
5. Use buttons for analysis, hints, and undo

### Command-Line Interface

```bash
python chess_with_ai.py
```

**How to Play:**
1. Enter moves in UCI notation (e.g., `e2e4`)
2. Type `help` to see all valid moves
3. Type `eval` for position evaluation
4. Type `undo` to take back moves
5. Type `quit` to exit

## Game Controls

### GUI Controls
- **🎮 New Game** - Start fresh game
- **↶ Undo Move** - Take back last move
- **💡 Get Hint** - Receive AI suggestion
- **📊 Analyze** - Analyze current position
- **❌ Quit** - Exit application

### Settings
- **Difficulty Level** - 1-20 (Beginner to Master)
- **Player Color** - Choose WHITE or BLACK

## Difficulty Levels

| Level | Skill |
|-------|-------|
| 1-3 | Beginner |
| 4-7 | Intermediate |
| 8-12 | Advanced |
| 13-17 | Expert |
| 18-20 | Master |

## Files

- **chess_app.py** - GUI application with PyQt5
- **chess_with_ai.py** - Command-line interface
- **README.md** - Documentation

## Troubleshooting

### "Stockfish not found" Error

1. Verify Stockfish installation:
   ```bash
   which stockfish  # macOS/Linux
   where stockfish  # Windows
   ```

2. If not in PATH, install it:
   - macOS: `brew install stockfish`
   - Linux: `sudo apt install stockfish`
   - Windows: Download and add to System PATH

### Module Import Errors

```bash
pip install --upgrade python-chess PyQt5
```

## Chess Notation

### Board Coordinates
- **Files (columns):** a-h (left to right)
- **Ranks (rows):** 1-8 (bottom to top)
- **Example:** `e2e4` = move pawn from e2 to e4

### Piece Symbols
- ♙ = Pawn (White)
- ♘ = Knight
- ♗ = Bishop
- ♖ = Rook
- ♕ = Queen
- ♔ = King

## AI Features

### Position Evaluation
- Measured in "pawns" (100 centipawns = 1 pawn)
- Positive = Advantage for WHITE
- Negative = Advantage for BLACK
- Examples:
  - +2.5 = WHITE is 2.5 pawns ahead
  - -1.2 = BLACK is 1.2 pawns ahead

### Mate Detection
- Engine shows "Mate in X" when checkmate is approaching
- Helps understand critical positions

## Game Rules Implemented

✅ Standard chess rules
✅ Piece movement validation
✅ Check detection
✅ Checkmate detection
✅ Stalemate detection
✅ Pawn promotion
✅ Capture detection
✅ Legal move generation

## Performance Tips

1. **Lower Difficulty** for faster games
2. **Close Other Apps** for better AI performance
3. **Use SSD Storage** for faster startup
4. **Update Stockfish** for better AI strength

## License

This project uses:
- [python-chess](https://python-chess.readthedocs.io/) - BSD License
- [PyQt5](https://www.riverbankcomputing.com/software/pyqt/) - GPL License
- [Stockfish](https://stockfishchess.org/) - GPL License

## Contributing

Feel free to fork and submit pull requests!

## Support

For issues or questions:
1. Check the Troubleshooting section
2. Verify Stockfish installation
3. Ensure all dependencies are installed

## Future Enhancements

- [ ] Game saving/loading
- [ ] Opening book integration
- [ ] Endgame tablebase support
- [ ] Network multiplayer
- [ ] Move animation
- [ ] Sound effects
- [ ] Custom themes

---

**Enjoy playing chess! ♔♕♗♘♖♙**
