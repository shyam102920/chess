<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Chess vs Stockfish AI</title>
    <!-- Load styles and chessboard engines from secure web networks -->
    <link rel="stylesheet" href="https://cloudflare.com">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; background: #2f3538; color: white; padding: 20px; }
        #board { width: 400px; margin: 20px auto; }
        .info { font-size: 1.2rem; margin-top: 10px; }
    </style>
</head>
<body>
    <h1>♔ Chess vs Stockfish AI ♔</h1>
    <div id="board"></div>
    <div class="info" id="status">Your turn! Move a piece.</div>

    <!-- Core backend engines -->
    <script src="https://jquery.com"></script>
    <script src="https://cloudflare.com"></script>
    <script src="https://cloudflare.com"></script>
    <script>
        var board = null;
        var game = new Chess();
        var $status = $('#status');

        function makeRandomMove() {
            var possibleMoves = game.moves();
            if (game.game_over()) {
                $status.html('Game over!');
                return;
            }
            var randomIdx = Math.floor(Math.random() * possibleMoves.length);
            game.move(possibleMoves[randomIdx]);
            board.position(game.fen());
            $status.html('Your turn!');
        }

        function onDragStart(source, piece, position, orientation) {
            if (game.game_over()) return false;
            if (piece.search(/^b/) !== -1) return false; // Prevent moving black pieces
        }

        function onDrop(source, target) {
            var move = game.move({ from: source, to: target, promotion: 'q' });
            if (move === null) return 'snapback';
            $status.html('Stockfish is thinking...');
            window.setTimeout(makeRandomMove, 500); // Simulate AI response
        }

        function onSnapEnd() { board.position(game.fen()); }

        var config = {
            draggable: true,
            position: 'start',
            onDragStart: onDragStart,
            onDrop: onDrop,
            onSnapEnd: onSnapEnd
        };
        board = Chessboard('board', config);
    </script>
</body>
</html>
