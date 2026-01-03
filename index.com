<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Pong Online - The Dinis</title>
    <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
    <style>
        body { background: #1a1a1a; color: white; font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; overflow: hidden; }
        canvas { border: 4px solid #fff; background: #000; box-shadow: 0 0 20px rgba(255,255,255,0.2); max-width: 95vw; max-height: 70vh; }
        .status { margin-bottom: 10px; font-size: 1.2rem; }
    </style>
</head>
<body>
    <div class="status" id="status">A ligar ao Umbrel...</div>
    <canvas id="pong" width="600" height="400"></canvas>

    <script>
        const canvas = document.getElementById("pong");
        const ctx = canvas.getContext("2d");
        const statusEl = document.getElementById("status");

        // 2. LIGAÇÃO AO TEU TÚNEL (O "TELEFONE" PARA O UMBREL)
        const socket = io("https://multiplayerpong.thedinis.com");

        let player1 = { y: 150, score: 0 };
        let player2 = { y: 150, score: 0 };
        let ball = { x: 300, y: 200 };
        let myRole = null; // Sabe se és o jogador da esquerda ou direita

        socket.on("connect", () => {
            statusEl.innerText = "Ligado! À espera de adversário...";
            statusEl.style.color = "#4CAF50";
        });

        // Recebe qual o teu lado (1 ou 2)
        socket.on("playerRole", (role) => {
            myRole = role;
            statusEl.innerText = "És o Jogador " + myRole;
        });

        // 3. ENVIAR MOVIMENTO (RATO OU TOQUE)
        function move(e) {
            let rect = canvas.getBoundingClientRect();
            let clientY = e.touches ? e.touches[0].clientY : e.clientY;
            let relativeY = (clientY - rect.top) * (canvas.height / rect.height);
            
            let newY = relativeY - 50; // Centraliza a raquete no dedo/rato

            // Só movemos a nossa própria raquete
            if (myRole === 1) player1.y = newY;
            else player2.y = newY;

            // Envia a nova posição para o Umbrel via Túnel
            socket.emit("paddleMove", { y: newY });
        }

        canvas.addEventListener("mousemove", move);
        canvas.addEventListener("touchmove", (e) => { e.preventDefault(); move(e); }, { passive: false });

        // 4. RECEBER ATUALIZAÇÕES DO UMBREL
        socket.on("updatePlayers", (playersData) => {
            const ids = Object.keys(playersData);
            ids.forEach(id => {
                if (id !== socket.id) {
                    // Atualiza a posição do adversário que veio do servidor
                    player2.y = playersData[id].y; 
                }
            });
        });

        // 5. DESENHAR O JOGO
        function draw() {
            // Limpa o campo
            ctx.fillStyle = "#000";
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Linha central
            ctx.setLineDash([10, 10]);
            ctx.strokeStyle = "#fff";
            ctx.strokeRect(canvas.width/2, 0, 0, canvas.height);

            // Raquetes
            ctx.fillStyle = "#fff";
            ctx.fillRect(10, player1.y, 10, 100); // Esquerda
            ctx.fillRect(580, player2.y, 10, 100); // Direita

            // Bola
            ctx.beginPath();
            ctx.arc(ball.x, ball.y, 8, 0, Math.PI*2);
            ctx.fill();

            requestAnimationFrame(draw);
        }

        draw();
    </script>
</body>
</html>
