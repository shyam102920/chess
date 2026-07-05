"""
A complete chess game with Stockfish AI engine integration.
"""

from enum import Enum
from typing import List, Tuple, Optional, Set
from dataclasses import dataclass
import subprocess
import sys

try:
    import chess
    import chess.engine
except ImportError:
    print("Installing required packages...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-chess"])
    import chess
    import chess.engine

class ChessGame:
    """Chess game with Stockfish AI integration."""
    
    def __init__(self, player_color=chess.WHITE, difficulty=1):
        """
        Initialize chess game.
        
        Args:
            player_color: chess.WHITE or chess.BLACK
            difficulty: 1-20 (higher = stronger)
        """
        self.board = chess.Board()
        self.player_color = player_color
        self.difficulty = difficulty
        self.engine = None
        self.game_over = False
        self.winner = None
        self.move_history = []
        
        try:
            self._load_engine()
        except Exception as e:
            print(f"Warning: Could not load Stockfish engine: {e}")
            print("Make sure Stockfish is installed. Download from: https://stockfishchess.org/download/")
    
    def _load_engine(self):
        """Load Stockfish engine."""
        try:
            # Try common Stockfish paths
            paths = [
                "stockfish",  # Linux/Mac
                "stockfish.exe",  # Windows
                "/usr/bin/stockfish",  # Linux
                "/usr/local/bin/stockfish",  # Mac
                "C:\\Program Files\\Stockfish\\stockfish.exe",  # Windows
            ]
            
            for path in paths:
                try:
                    self.engine = chess.engine.SimpleEngine.popen_uci(path)
                    print(f"✓ Stockfish loaded successfully!")
                    return
                except:
                    continue
            
            raise Exception("Stockfish not found in common locations")
        except Exception as e:
            print(f"Error loading Stockfish: {e}")
            self.engine = None
    
    def display_board(self):
        """Display the chess board."""
        print("\n" + str(self.board))
        print("\nMove history:", " ".join(self.move_history))
    
    def get_ai_move(self):
        """Get the best move from Stockfish."""
        if not self.engine:
            print("Error: Stockfish engine not loaded!")
            return None
        
        try:
            # Analyze position with time limit based on difficulty
            limit = chess.engine.Limit(time=0.1 + (self.difficulty * 0.05))
            result = self.engine.play(self.board, limit)
            return result.move
        except Exception as e:
            print(f"Error getting AI move: {e}")
            return None
    
    def make_move(self, move_uci: str) -> bool:
        """
        Make a move in UCI notation (e.g., 'e2e4').
        
        Returns:
            True if move was successful, False otherwise
        """
        try:
            move = chess.Move.from_uci(move_uci)
            
            if move not in self.board.legal_moves:
                print("Illegal move!")
                return False
            
            piece_symbol = self.board.piece_at(move.from_square)
            self.board.push(move)
            self.move_history.append(move_uci)
            
            # Check for captures
            if self.board.is_capture(move):
                print(f"✓ Captured piece!")
            
            return True
        except Exception as e:
            print(f"Invalid move format. Use UCI notation (e.g., e2e4): {e}")
            return False
    
    def get_valid_moves(self) -> List[str]:
        """Get all legal moves in UCI notation."""
        return [move.uci() for move in self.board.legal_moves]
    
    def is_checkmate(self) -> bool:
        """Check if current position is checkmate."""
        return self.board.is_checkmate()
    
    def is_stalemate(self) -> bool:
        """Check if current position is stalemate."""
        return self.board.is_stalemate()
    
    def is_check(self) -> bool:
        """Check if current player is in check."""
        return self.board.is_check()
    
    def whose_turn(self) -> str:
        """Return whose turn it is."""
        return "WHITE" if self.board.turn == chess.WHITE else "BLACK"
    
    def get_evaluation(self) -> Optional[float]:
        """Get evaluation of current position from Stockfish."""
        if not self.engine:
            return None
        
        try:
            info = self.engine.analyse(self.board, chess.engine.Limit(depth=15))
            if chess.engine.Cp in info:
                return info[chess.engine.Cp] / 100.0  # Convert to pawns
            elif chess.engine.Mate in info:
                return float('inf') if info[chess.engine.Mate] > 0 else float('-inf')
        except:
            pass
        
        return None
    
    def close_engine(self):
        """Close the Stockfish engine."""
        if self.engine:
            self.engine.quit()

def print_welcome():
    """Print welcome message."""
    print("=" * 50)
    print("      ♔ CHESS vs STOCKFISH AI ♔")
    print("=" * 50)
    print("\nPlay chess against Stockfish engine!")
    print("\nInstructions:")
    print("  - Enter moves in UCI notation: e2e4, g1f3, etc.")
    print("  - Type 'help' for valid moves")
    print("  - Type 'eval' to see position evaluation")
    print("  - Type 'undo' to undo last move")
    print("  - Type 'quit' to exit\n")

def get_difficulty():
    """Get difficulty level from user."""
    print("Select difficulty level:")
    print("  1 = Beginner")
    print("  5 = Intermediate")
    print("  10 = Advanced")
    print("  15 = Expert")
    print("  20 = Master")
    
    while True:
        try:
            level = int(input("\nEnter difficulty (1-20): "))
            if 1 <= level <= 20:
                return level
            print("Please enter a number between 1 and 20")
        except ValueError:
            print("Invalid input. Please enter a number.")

def get_color():
    """Get player color from user."""
    while True:
        choice = input("\nDo you want to play as WHITE or BLACK? (w/b): ").lower()
        if choice in ['w', 'white']:
            return chess.WHITE
        elif choice in ['b', 'black']:
            return chess.BLACK
        print("Please enter 'w' for WHITE or 'b' for BLACK")

def play_game():
    """Main game loop."""
    print_welcome()
    
    # Check if Stockfish is installed
    try:
        test_engine = chess.engine.SimpleEngine.popen_uci("stockfish")
        test_engine.quit()
    except:
        print("⚠️  WARNING: Stockfish not found!")
        print("Please install Stockfish from: https://stockfishchess.org/download/")
        print("After installation, ensure 'stockfish' is in your PATH\n")
    
    difficulty = get_difficulty()
    player_color = get_color()
    
    game = ChessGame(player_color=player_color, difficulty=difficulty)
    
    print(f"\nGame started! Difficulty: {difficulty}/20")
    print(f"You are playing as {'WHITE' if player_color == chess.WHITE else 'BLACK'}\n")
    
    try:
        while True:
            game.display_board()
            
            # Check game status
            if game.is_checkmate():
                print("\n♔ CHECKMATE! ♔")
                if game.board.turn == chess.WHITE:
                    print("BLACK wins!")
                else:
                    print("WHITE wins!")
                break
            elif game.is_stalemate():
                print("\n♙ STALEMATE! ♙")
                break
            
            if game.is_check():
                print("\n⚠️  CHECK! ⚠️")
            
            # Player's turn
            if game.board.turn == player_color:
                print(f"\n{game.whose_turn()}'s turn (YOU)")
                
                while True:
                    move_input = input("Enter your move (or 'help'/'eval'/'quit'): ").strip().lower()
                    
                    if move_input == 'quit':
                        print("Thanks for playing!")
                        return
                    elif move_input == 'help':
                        valid = game.get_valid_moves()
                        print(f"Valid moves ({len(valid)}): {', '.join(valid[:20])}")
                        if len(valid) > 20:
                            print(f"... and {len(valid) - 20} more")
                        continue
                    elif move_input == 'eval':
                        eval_score = game.get_evaluation()
                        if eval_score is not None:
                            if eval_score == float('inf'):
                                print("Evaluation: Checkmate for WHITE")
                            elif eval_score == float('-inf'):
                                print("Evaluation: Checkmate for BLACK")
                            else:
                                print(f"Evaluation: {eval_score:+.2f} (positive = WHITE advantage)")
                        else:
                            print("Could not evaluate position")
                        continue
                    elif move_input == 'undo':
                        if len(game.move_history) >= 2:
                            game.board.pop()
                            game.board.pop()
                            game.move_history = game.move_history[:-2]
                            print("Last two moves undone")
                            break
                        else:
                            print("Cannot undo")
                        continue
                    
                    if game.make_move(move_input):
                        break
            
            # AI's turn
            else:
                print(f"\n{game.whose_turn()}'s turn (STOCKFISH)")
                print("Stockfish is thinking...")
                
                ai_move = game.get_ai_move()
                
                if ai_move:
                    move_uci = ai_move.uci()
                    game.make_move(move_uci)
                    print(f"Stockfish played: {move_uci}")
                else:
                    print("Error: Could not get AI move")
                    break
    
    finally:
        game.close_engine()

if __name__ == "__main__":
    play_game()
