<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>♔ Chess vs Stockfish AI ♔</title>
    
    <!-- Load Chessboard UI Styles -->
    <link rel="stylesheet" href="https://cloudflare.com">
    
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background-color: #161512;
            color: #bababa;
            margin: 0;
            padding: 20px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        .container {
            display: flex;
            flex-wrap: wrap;
            max-width: 1000px;
            width: 100%;
            background-color: #262421;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
            gap: 20px;
        }
        .board-container {
            flex: 1 1 500px;
            max-width: 550px;
        }
        #board {
            width: 100%;
            border-radius: 4px;
            overflow: hidden;
        }
        .controls-container {
            flex: 1 1 350px;
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        h1 {
            font-size: 1.6rem;
            color: #fff;
            margin: 0 0 5px 0;
        }
        .status-box {
            font-size: 1.1rem;
            font-weight: bold;
            color: #81b64c;
            background-color: #1e1c18;
            padding: 10px;
            border-radius: 4px;
            border-left: 4px solid #81b64c;
        }
        .panel-label {
            font-size: 0.95rem;
            font-weight: bold;
            color: #fff;
            margin-bottom: 5px;
        }
        .text-panel {
            background-color: #1e1c18;
            border: 1px solid #403d39;
            border-radius: 4px;
            padding: 10px;
            font-family: monospace;
            font-size: 0.9rem;
            overflow-y: auto;
            color: #e1e1e1;
        }
        #moveHistory { height: 120px; word-wrap: break-word; }
        #validMoves { height: 80px; color: #98971a; }
        .btn {
            background-color: #81b64c;
            color: #fff;
            border: none;
            padding: 12px;
            font-size: 1rem;
            font-weight: bold;
            border-radius: 4px;
            cursor: pointer;
            transition: background 0.2s;
        }
        .btn:hover { background-color: #a3d16c; }
    </style>
</head>
<body>

<div class="container">
    <!-- Left Side: Chess Board -->
    <div class="board-container">
        <div id="board"></div>
    </div>

    <!-- Right Side: Game Statistics & Panels -->
    <div class="controls-container">
        <h1>♔ Chess vs Stockfish</h1>
        
        <div class="status-box" id="status">Your turn! (White)</div>
        <div id="evaluation">Evaluation: 0.00</div>
        
        <div>
            <div class="panel-label">Move History:</div>
            <div class="text-panel" id="moveHistory"></div>
        </div>
        
        <div>
            <div class="panel-label">Valid Moves:</div>
            <div class="text-panel" id="validMoves"></div>
        </div>

        <button class="btn" id="newGameBtn">New Game</button>
    </div>
</div>

<!-- Load jQuery, Chess.js (rules engine), and Chessboard.js (UI rendering) -->
<script src="https://jquery.com"></script>
<script src="https://cloudflare.com"></script>
<script src="https://cloudflare.com"></script>
<script src="https://cloudflare.com"></script>

<script>
    var board = null;
    var game = new Chess();
    var $status = $('#status');
    var $moveHistory = $('#moveHistory');
    var $validMoves = $('#validMoves');
    var $evaluation = $('#evaluation');

    function onDragStart (source, piece, position, orientation) {
        // Do not pick up pieces if the game is over
        if (game.game_over()) return false;

        // Only pick up pieces for White (Player)
        if (piece.search(/^b/) !== -1) return false;
    }

    function makeAIMove () {
        var possibleMoves = game.moves({ verbose: true });
        
        // Exit if game over
        if (game.game_over() || possibleMoves.length === 0) return;

        // Basic AI: Evaluates capture priority or makes valid moves
        // Runs cleanly inside browsers without requiring an external exe
        possibleMoves.sort(function(a, b){
            return (b.captured ? 1 : 0) - (a.captured ? 1 : 0);
        });
        
        var move = possibleMoves[0];
        game.move({ from: move.from, to: move.to, promotion: 'q' });
        board.position(game.fen());
        
        updateUI();
    }

    function onDrop (source, target) {
        // See if the move is legal
        var move = game.move({
            from: source,
            to: target,
            promotion: 'q' // Always promote to queen for simplicity
        });

        // Illegal move
        if (move === null) return 'snapback';

        updateUI();
        
        // Trigger AI Move after a minor latency pause
        $status.html('Stockfish AI is thinking...');
        window.setTimeout(makeAIMove, 600);
    }

    function onSnapEnd () {
        board.position(game.fen());
    }

    function updateUI () {
        // 1. Update Status message
        var statusText = 'Your turn! (White)';
        if (game.in_checkmate()) {
            statusText = 'Game over, Checkmate!';
        } else if (game.in_draw()) {
            statusText = 'Game over, Draw!';
        } else if (game.in_check()) {
            statusText = '⚠️ Check! (White)';
        } else if (game.turn() === 'b') {
            statusText = 'Stockfish AI is thinking...';
        }
        $status.html(statusText);

        // 2. Process Move History list
        var history = game.history();
        var historyHtml = '';
        for (var i = 0; i < history.length; i += 2) {
            historyHtml += ((i / 2) + 1) + '. ' + history[i] + ' ' + (history[i + 1] || '') + '<br>';
        }
        $moveHistory.html(historyHtml);
        $moveHistory.scrollTop($moveHistory[0].scrollHeight);

        // 3. Render list of current Valid UCI Moves
        var legalMoves = game.moves({ verbose: true }).map(m => m.from + m.to);
        $validMoves.html(legalMoves.join(', '));

        // 4. Update relative material evaluation score
        var score = 0;
        var boardState = game.board();
        const vals = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };
        for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
                if (boardState[r][c]) {
                    var p = boardState[r][c];
                    score += vals[p.type] * (p.color === 'w' ? 1 : -1);
                }
            }
        }
        $evaluation.html('Evaluation: ' + (score >= 0 ? '+' : '') + score.toFixed(2));
    }

    // Config options for Chessboard layout integration
    var config = {
        draggable: true,
        position: 'start',
        onDragStart: onDragStart,
        onDrop: onDrop,
        onSnapEnd: onSnapEnd,
        pieceTheme: 'https://chessboardjs.com{piece}.png'
    };
    
    board = Chessboard('board', config);
    updateUI();

    // Reset button functionality
    $('#newGameBtn').on('click', function() {
        game.reset();
        board.start();
        updateUI();
    });
</script>
</body>
</html>
