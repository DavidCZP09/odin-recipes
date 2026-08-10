import SwiftUI
import Foundation

enum Mark: String {
    case x = "X"
    case o = "O"
}

enum GameMode: Hashable {
    case twoPlayer
    case vsComputer
}

enum Difficulty: Hashable {
    case easy
    case unbeatable
}

enum FirstPlayer: Hashable {
    case human
    case computer
}

struct ContentView: View {
    @State private var cells: [Mark?] = Array(repeating: nil, count: 9)
    @State private var currentPlayer: Mark = .x
    @State private var gameOver = false
    @State private var statusText = "Player X's turn"
    @State private var winningLine: [Int] = []

    @State private var mode: GameMode = .twoPlayer
    @State private var difficulty: Difficulty = .unbeatable
    @State private var firstPlayer: FirstPlayer = .human
    @State private var aiThinking = false

    private var humanMark: Mark { firstPlayer == .human ? .x : .o }
    private var aiMark: Mark { humanMark == .x ? .o : .x }

    private let winLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Tic Tac Toe")
                .font(.largeTitle.bold())

            VStack(spacing: 10) {
                HStack {
                    Text("Mode:")
                    Picker("Mode", selection: $mode) {
                        Text("2 Players").tag(GameMode.twoPlayer)
                        Text("Vs Computer").tag(GameMode.vsComputer)
                    }
                    .pickerStyle(.segmented)
                }
                .onChange(of: mode) { _ in resetGame() }

                if mode == .vsComputer {
                    HStack {
                        Text("Difficulty:")
                        Picker("Difficulty", selection: $difficulty) {
                            Text("Easy").tag(Difficulty.easy)
                            Text("Unbeatable").tag(Difficulty.unbeatable)
                        }
                        .pickerStyle(.segmented)
                    }
                    .onChange(of: difficulty) { _ in resetGame() }

                    HStack {
                        Text("Go first:")
                        Picker("Go first", selection: $firstPlayer) {
                            Text("You").tag(FirstPlayer.human)
                            Text("Computer").tag(FirstPlayer.computer)
                        }
                        .pickerStyle(.segmented)
                    }
                    .onChange(of: firstPlayer) { _ in resetGame() }
                }
            }
            .padding(.horizontal)

            Text(statusText)
                .font(.title2)
                .frame(height: 30)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 6), count: 3), spacing: 6) {
                ForEach(0..<9, id: \.self) { index in
                    Button(action: { handleMove(index) }) {
                        Text(cells[index]?.rawValue ?? "")
                            .font(.system(size: 40, weight: .bold))
                            .frame(width: 90, height: 90)
                            .background(winningLine.contains(index) ? Color.green : Color(white: 0.85))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    .disabled(cells[index] != nil || gameOver || aiThinking)
                }
            }
            .padding(6)
            .background(Color(white: 0.6))
            .cornerRadius(10)

            Button("Restart") { resetGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { resetGame() }
    }

    private func checkWinner(_ state: [Mark?]) -> (winner: Mark?, isDraw: Bool, line: [Int]) {
        for line in winLines {
            let (a, b, c) = (line[0], line[1], line[2])
            if let v = state[a], v == state[b], v == state[c] {
                return (v, false, line)
            }
        }
        if state.allSatisfy({ $0 != nil }) {
            return (nil, true, [])
        }
        return (nil, false, [])
    }

    private func handleMove(_ index: Int) {
        guard cells[index] == nil, !gameOver, !aiThinking else { return }
        if mode == .vsComputer && currentPlayer == aiMark { return }

        cells[index] = currentPlayer
        afterMove()
    }

    private func afterMove() {
        let result = checkWinner(cells)
        if result.winner != nil || result.isDraw {
            finishGame(winner: result.winner, isDraw: result.isDraw, line: result.line)
            return
        }

        currentPlayer = currentPlayer == .x ? .o : .x

        if mode == .vsComputer && currentPlayer == aiMark {
            statusText = "Computer's turn"
            aiThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                makeAIMove()
            }
        } else {
            statusText = mode == .vsComputer ? "Your turn" : "Player \(currentPlayer.rawValue)'s turn"
        }
    }

    private func finishGame(winner: Mark?, isDraw: Bool, line: [Int]) {
        gameOver = true
        winningLine = line
        if isDraw {
            statusText = "It's a draw!"
        } else if let winner = winner {
            if mode == .vsComputer {
                statusText = winner == humanMark ? "You win!" : "Computer wins!"
            } else {
                statusText = "Player \(winner.rawValue) wins!"
            }
        }
    }

    private func makeAIMove() {
        aiThinking = false
        guard !gameOver else { return }

        let emptyIndices = cells.indices.filter { cells[$0] == nil }
        let move: Int
        if difficulty == .easy {
            move = emptyIndices.randomElement()!
        } else {
            move = bestMove(cells)
        }

        cells[move] = aiMark
        afterMove()
    }

    private func minimax(_ state: [Mark?], depth: Int, isMaximizing: Bool) -> Int {
        let result = checkWinner(state)
        if let winner = result.winner {
            return winner == aiMark ? 10 - depth : depth - 10
        }
        if result.isDraw {
            return 0
        }

        var state = state
        if isMaximizing {
            var best = Int.min
            for i in state.indices where state[i] == nil {
                state[i] = aiMark
                best = max(best, minimax(state, depth: depth + 1, isMaximizing: false))
                state[i] = nil
            }
            return best
        } else {
            var best = Int.max
            for i in state.indices where state[i] == nil {
                state[i] = humanMark
                best = min(best, minimax(state, depth: depth + 1, isMaximizing: true))
                state[i] = nil
            }
            return best
        }
    }

    private func bestMove(_ state: [Mark?]) -> Int {
        var bestScore = Int.min
        var move = 0
        var state = state
        for i in state.indices where state[i] == nil {
            state[i] = aiMark
            let score = minimax(state, depth: 0, isMaximizing: false)
            state[i] = nil
            if score > bestScore {
                bestScore = score
                move = i
            }
        }
        return move
    }

    private func resetGame() {
        cells = Array(repeating: nil, count: 9)
        currentPlayer = .x
        gameOver = false
        winningLine = []
        aiThinking = false

        if mode == .vsComputer && currentPlayer == aiMark {
            statusText = "Computer's turn"
            aiThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                makeAIMove()
            }
        } else {
            statusText = mode == .vsComputer ? "Your turn" : "Player \(currentPlayer.rawValue)'s turn"
        }
    }
}
