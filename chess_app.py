"""
Chess GUI App with Stockfish AI - Built with PyQt5
"""

import sys
import subprocess
from pathlib import Path

# Install required packages
def install_packages():
    try:
        import chess
        from PyQt5.QtWidgets import QApplication
    except ImportError:
        print("Installing required packages...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "python-chess", "PyQt5", "-q"])

install_packages()

import chess
import chess.engine
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QGridLayout, QPushButton, QLabel, QComboBox, QSpinBox, QMessageBox,
    QTextEdit, QFrame
)
from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtGui import QColor, QFont, QPainter, QPen, QBrush

class ChessBoardWidget(QWidget):
    """Interactive chess board widget"""
    
    def __init__(self, gui):
        super().__init__()
        self.gui = gui
        self.selected_square = None
        self.board = chess.Board()
        self.highlighted_squares = set()
        self.setMinimumSize(600, 600)
    
    def update_board(self, board):
        """Update board state"""
        self.board = board.copy()
        self.repaint()
    
    def mousePressEvent(self, event):
        """Handle square clicks"""
        size = min(self.width(), self.height())
        square_size = size // 8
        
        col = event.x() // square_size
        row = 7 - (event.y() // square_size)
        
        square = chess.square(col, row)
        
        if self.selected_square is None:
            piece = self.board.piece_at(square)
            if piece and piece.color == self.gui.player_color:
                self.selected_square = square
                self.highlighted_squares = set(move.to_square for move in self.board.legal_moves if move.from_square == square)
                self.repaint()
        else:
            try:
                move = chess.Move(self.selected_square, square)
                if move in self.board.legal_moves:
                    self.gui.board.push(move)
                    self.gui.move_history.append(move.uci())
                    self.update_board(self.gui.board)
                    self.selected_square = None
                    self.highlighted_squares = set()
                    self.gui.update_status()
                    
                    # AI move after delay
                    if self.gui.game_active and self.gui.board.turn != self.gui.player_color:
                        QTimer.singleShot(500, self.make_ai_move)
            except:
                self.selected_square = None
                self.highlighted_squares = set()
                self.repaint()
    
    def make_ai_move(self):
        """Make AI move"""
        if not self.gui.engine or not self.gui.game_active:
            return
        
        try:
            limit = chess.engine.Limit(time=0.1 + (self.gui.difficulty * 0.05))
            result = self.gui.engine.play(self.gui.board, limit)
            
            if result.move:
                self.gui.board.push(result.move)
                self.gui.move_history.append(result.move.uci())
                self.update_board(self.gui.board)
                self.gui.update_status()
        except Exception as e:
            print(f"AI move error: {e}")
    
    def paintEvent(self, event):
        """Draw chess board"""
        painter = QPainter(self)
        
        size = min(self.width(), self.height())
        square_size = size // 8
        
        # Draw squares
        for row in range(8):
            for col in range(8):
                x = col * square_size
                y = (7 - row) * square_size
                
                # Background color
                is_light = (row + col) % 2 == 0
                color = QColor(240, 217, 181) if is_light else QColor(181, 136, 99)
                
                painter.fillRect(x, y, square_size, square_size, color)
                
                # Highlight selected square
                square = chess.square(col, row)
                if square == self.selected_square:
                    painter.fillRect(x, y, square_size, square_size, QColor(100, 200, 100))
                
                # Highlight valid moves
                if square in self.highlighted_squares:
                    center_x = x + square_size // 2
                    center_y = y + square_size // 2
                    painter.fillEllipse(center_x - 10, center_y - 10, 20, 20, QColor(100, 100, 100))
                
                # Draw border
                painter.drawRect(x, y, square_size, square_size)
        
        # Draw pieces using Unicode symbols
        piece_symbols = {
            chess.PAWN: ('♙', '♟'), chess.KNIGHT: ('♘', '♞'),
            chess.BISHOP: ('♗', '♝'), chess.ROOK: ('♖', '♜'),
            chess.QUEEN: ('♕', '♛'), chess.KING: ('♔', '♚')
        }
        
        font = QFont("Arial", square_size // 2)
        font.setBold(True)
        painter.setFont(font)
        
        for square in chess.SQUARES:
            piece = self.board.piece_at(square)
            if piece:
                col = chess.square_file(square)
                row = chess.square_rank(square)
                x = col * square_size
                y = (7 - row) * square_size
                
                symbol = piece_symbols[piece.piece_type][0 if piece.color == chess.WHITE else 1]
                color = QColor(255, 255, 255) if piece.color == chess.WHITE else QColor(0, 0, 0)
                
                painter.setPen(color)
                painter.drawText(x, y, square_size, square_size, Qt.AlignCenter, symbol)

class ChessGUI(QMainWindow):
    """Main Chess GUI Application"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("♔ Chess vs Stockfish AI ♔")
        self.setGeometry(100, 100, 1200, 700)
        
        # Chess game state
        self.board = chess.Board()
        self.engine = None
        self.player_color = chess.WHITE
        self.difficulty = 10
        self.game_active = True
        self.move_history = []
        
        self.init_ui()
        self.load_engine()
    
    def init_ui(self):
        """Initialize the UI"""
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        
        main_layout = QHBoxLayout()
        
        # Left side - Board
        board_layout = QVBoxLayout()
        self.board_widget = ChessBoardWidget(self)
        board_layout.addWidget(self.board_widget)
        
        # Right side - Controls
        control_layout = QVBoxLayout()
        
        # Title
        title = QLabel("♔ Chess vs Stockfish")
        title_font = QFont()
        title_font.setPointSize(16)
        title_font.setBold(True)
        title.setFont(title_font)
        control_layout.addWidget(title)
        
        # Game status
        self.status_label = QLabel("Loading...")
        self.status_label.setFont(QFont("Arial", 12))
        self.status_label.setStyleSheet("color: green; font-weight: bold;")
        control_layout.addWidget(self.status_label)
        
        # Evaluation
        self.eval_label = QLabel("Evaluation: -")
        self.eval_label.setFont(QFont("Arial", 11))
        control_layout.addWidget(self.eval_label)
        
        # Move history label
        move_label = QLabel("Move History:")
        move_label.setFont(QFont("Arial", 11, QFont.Bold))
        control_layout.addWidget(move_label)
        
        self.move_text = QTextEdit()
        self.move_text.setReadOnly(True)
        self.move_text.setMaximumHeight(120)
        self.move_text.setStyleSheet("background-color: #f0f0f0; padding: 5px;")
        control_layout.addWidget(self.move_text)
        
        # Valid moves label
        valid_label = QLabel("Valid Moves:")
        valid_label.setFont(QFont("Arial", 11, QFont.Bold))
        control_layout.addWidget(valid_label)
        
        self.valid_moves_text = QTextEdit()
        self.valid_moves_text.setReadOnly(True)
        self.valid_moves_text.setMaximumHeight(80)
        self.valid_moves_text.setStyleSheet("background-color: #f0f0f0; padding: 5px;")
        control_layout.addWidget(self.valid_moves_text)
        
        # Settings Frame
        settings_frame = QFrame()
        settings_frame.setStyleSheet("border: 1px solid gray; padding: 10px; border-radius: 5px;")
        settings_layout = QVBoxLayout()
        
        # Difficulty
        diff_label = QLabel("Difficulty Level:")
        diff_label.setFont(QFont("Arial", 10, QFont.Bold))
        settings_layout.addWidget(diff_label)
        
        self.difficulty_spin = QSpinBox()
        self.difficulty_spin.setMinimum(1)
        self.difficulty_spin.setMaximum(20)
        self.difficulty_spin.setValue(10)
        self.difficulty_spin.setSuffix(" / 20")
        self.difficulty_spin.valueChanged.connect(self.set_difficulty)
        settings_layout.addWidget(self.difficulty_spin)
        
        # Player color
        color_label = QLabel("Your Color:")
        color_label.setFont(QFont("Arial", 10, QFont.Bold))
        settings_layout.addWidget(color_label)
        
        self.color_combo = QComboBox()
        self.color_combo.addItems(["WHITE", "BLACK"])
        self.color_combo.currentTextChanged.connect(self.set_player_color)
        settings_layout.addWidget(self.color_combo)
        
        settings_frame.setLayout(settings_layout)
        control_layout.addWidget(settings_frame)
        
        # Buttons
        button_layout = QVBoxLayout()
        
        new_game_btn = QPushButton("🎮 New Game")
        new_game_btn.setStyleSheet("background-color: #4CAF50; color: white; padding: 8px; font-weight: bold;")
        new_game_btn.clicked.connect(self.new_game)
        button_layout.addWidget(new_game_btn)
        
        undo_btn = QPushButton("↶ Undo Move")
        undo_btn.setStyleSheet("background-color: #2196F3; color: white; padding: 8px; font-weight: bold;")
        undo_btn.clicked.connect(self.undo_move)
        button_layout.addWidget(undo_btn)
        
        hint_btn = QPushButton("💡 Get Hint")
        hint_btn.setStyleSheet("background-color: #FF9800; color: white; padding: 8px; font-weight: bold;")
        hint_btn.clicked.connect(self.get_hint)
        button_layout.addWidget(hint_btn)
        
        eval_btn = QPushButton("📊 Analyze")
        eval_btn.setStyleSheet("background-color: #9C27B0; color: white; padding: 8px; font-weight: bold;")
        eval_btn.clicked.connect(self.analyze_position)
        button_layout.addWidget(eval_btn)
        
        quit_btn = QPushButton("❌ Quit")
        quit_btn.setStyleSheet("background-color: #f44336; color: white; padding: 8px; font-weight: bold;")
        quit_btn.clicked.connect(self.close)
        button_layout.addWidget(quit_btn)
        
        control_layout.addLayout(button_layout)
        control_layout.addStretch()
        
        # Add layouts to main
        main_layout.addWidget(self.board_widget, 3)
        main_layout.addLayout(control_layout, 1)
        main_widget.setLayout(main_layout)
        
        self.update_status()
    
    def load_engine(self):
        """Load Stockfish engine"""
        try:
            paths = [
                "stockfish", "stockfish.exe",
                "/usr/bin/stockfish", "/usr/local/bin/stockfish",
                "C:\\Program Files\\Stockfish\\stockfish.exe"
            ]
            
            for path in paths:
                try:
                    self.engine = chess.engine.SimpleEngine.popen_uci(path)
                    print("✓ Stockfish loaded!")
                    self.status_label.setText("✓ Stockfish Ready - Game Started")
                    return
                except:
                    continue
        except:
            pass
        
        self.status_label.setText("⚠️ Stockfish not found. Install from stockfishchess.org")
    
    def set_difficulty(self, value):
        """Set AI difficulty"""
        self.difficulty = value
    
    def set_player_color(self, color):
        """Set player color"""
        self.player_color = chess.WHITE if color == "WHITE" else chess.BLACK
        self.new_game()
    
    def new_game(self):
        """Start new game"""
        self.board = chess.Board()
        self.move_history = []
        self.game_active = True
        self.board_widget.update_board(self.board)
        self.update_status()
        self.move_text.clear()
        self.valid_moves_text.clear()
        self.eval_label.setText("Evaluation: -")
    
    def undo_move(self):
        """Undo last move"""
        if len(self.board.move_stack) >= 2:
            self.board.pop()
            self.board.pop()
            self.move_history = self.move_history[:-2]
            self.board_widget.update_board(self.board)
            self.update_status()
            QMessageBox.information(self, "Undo", "✓ Last move undone")
        else:
            QMessageBox.warning(self, "Undo", "⚠️ Cannot undo")
    
    def get_hint(self):
        """Get AI hint"""
        if not self.engine:
            QMessageBox.warning(self, "Error", "Stockfish not loaded")
            return
        
        self.analyze_position()
    
    def analyze_position(self):
        """Analyze current position"""
        if not self.engine:
            QMessageBox.warning(self, "Error", "Stockfish not loaded")
            return
        
        try:
            info = self.engine.analyse(self.board, chess.engine.Limit(depth=20))
            
            eval_text = "Unknown"
            if chess.engine.Cp in info:
                cp = info[chess.engine.Cp]
                eval_text = f"{cp/100:.2f} pawns"
            elif chess.engine.Mate in info:
                mate = info[chess.engine.Mate]
                eval_text = f"Mate in {abs(mate)}"
            
            self.eval_label.setText(f"Evaluation: {eval_text}")
            
            QMessageBox.information(self, "Position Analysis", f"Evaluation: {eval_text}\n\nThis shows the advantage in the position.")
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Analysis failed: {str(e)}")
    
    def update_status(self):
        """Update game status"""
        if self.board.is_checkmate():
            winner = "BLACK" if self.board.turn == chess.WHITE else "WHITE"
            self.status_label.setText(f"♔ CHECKMATE! {winner} wins! ♔")
            self.status_label.setStyleSheet("color: red; font-weight: bold; font-size: 14px;")
            self.game_active = False
        elif self.board.is_stalemate():
            self.status_label.setText("♙ STALEMATE - Draw ♙")
            self.status_label.setStyleSheet("color: orange; font-weight: bold;")
            self.game_active = False
        elif self.board.is_check():
            turn = "YOUR TURN" if self.board.turn == self.player_color else "Stockfish"
            self.status_label.setText(f"⚠️  {turn} - IN CHECK!")
            self.status_label.setStyleSheet("color: red; font-weight: bold;")
        else:
            turn = "YOUR TURN ♟" if self.board.turn == self.player_color else "Stockfish thinking... 🤖"
            self.status_label.setText(turn)
            self.status_label.setStyleSheet("color: green; font-weight: bold;")
        
        # Update move history
        self.move_text.setText(" ".join(self.move_history) if self.move_history else "No moves yet")
        
        # Update valid moves
        moves = [move.uci() for move in self.board.legal_moves]
        if moves:
            moves_str = ", ".join(moves[:15]) + ("..." if len(moves) > 15 else "")
        else:
            moves_str = "No legal moves"
        self.valid_moves_text.setText(moves_str)

def main():
    app = QApplication(sys.argv)
    window = ChessGUI()
    window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
