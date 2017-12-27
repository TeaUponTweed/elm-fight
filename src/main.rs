extern crate rand;
use std::collections::HashMap;


#[derive(Copy, Clone, Eq, PartialEq, Debug, Hash)]
enum TicTacToePiece {
    Empty,
    Black,
    White
}


#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq)]
struct TicTacToeBoard {
    data: [TicTacToePiece; 9],
    is_whites_turn: bool
}


impl TicTacToeBoard {
    fn new() -> TicTacToeBoard {
        TicTacToeBoard {
            data: [TicTacToePiece::Empty; 9],
            is_whites_turn: true
        }
    }
    fn is_terminal(self) -> bool {
        self.is_cats() || self.white_wins() || self.black_wins()
    }

    fn white_wins(self) -> bool {
        self.diagonal_victory(TicTacToePiece::White) ||
        self.row_victory(TicTacToePiece::White)      ||
        self.column_victory(TicTacToePiece::White)
    }

    fn black_wins(self) -> bool {
        self.diagonal_victory(TicTacToePiece::Black) ||
        self.row_victory(TicTacToePiece::Black)      ||
        self.column_victory(TicTacToePiece::Black)
    }

    fn is_cats(self) -> bool {
        !self.data.into_iter().any(|p| {*p == TicTacToePiece::Empty})
    }

    fn diagonal_victory(self, color: TicTacToePiece) -> bool{
        (self.data[0] == color && self.data[4] == color && self.data[8] == color) ||
        (self.data[2] == color && self.data[4] == color && self.data[6] == color)
    }
    fn row_victory(self, color: TicTacToePiece) -> bool{
        (self.data[0] == color && self.data[1] == color && self.data[2] == color) ||
        (self.data[3] == color && self.data[4] == color && self.data[5] == color) ||
        (self.data[6] == color && self.data[7] == color && self.data[8] == color)
    }

    fn column_victory(self, color: TicTacToePiece) -> bool{
        (self.data[0] == color && self.data[3] == color && self.data[6] == color) ||
        (self.data[1] == color && self.data[4] == color && self.data[7] == color) ||
        (self.data[2] == color && self.data[5] == color && self.data[8] == color)
    }

    fn display(self) {
        let string_board: Vec<String> = self.data[..].iter().map({|p| match *p {
            TicTacToePiece::Empty => " ".to_string(),
            TicTacToePiece::White => "O".to_string(),
            TicTacToePiece::Black => "X".to_string()
        }}).collect();

        for i in 0..3 {
            print!("|");

            for j in 0..3 {
                print!("{}", string_board[i*3 +j ]);
                print!(" ");
            }
            println!("|");
        }
        println!("");
    }
}


struct NextMoves {
    board: TicTacToeBoard,
    current_ix: u8,
    last_changed_ix: Option<u8>
}


impl NextMoves {
    fn new(board: TicTacToeBoard) -> NextMoves
    {
        NextMoves {
            board: board,
            current_ix: 0 as u8,
            last_changed_ix: None
        }
    }
}


impl Iterator for NextMoves
{
    type Item = TicTacToeBoard;

    fn next(&mut self) -> Option<TicTacToeBoard> {
        for i in self.current_ix..9 {
            if self.board.data[i as usize] == TicTacToePiece::Empty {
                if let Some(last_changed_ix) = self.last_changed_ix {
                    self.board.data[last_changed_ix as usize] = TicTacToePiece::Empty;
                    self.board.is_whites_turn = !self.board.is_whites_turn;
                }
                let next_piece = {
                    if self.board.is_whites_turn {
                        TicTacToePiece::White
                    }
                    else {
                        TicTacToePiece::Black
                    }
                };
                self.current_ix = i;
                self.last_changed_ix = Some(i);
                self.board.data[i as usize] = next_piece;
                self.board.is_whites_turn = !self.board.is_whites_turn;
                return Some(self.board)
            }
        }
        return None
    }
}


struct MCTSNode {
    wins: u32,
    losses: u32
}


struct MonteCarloTreeSearch {
    nodes: HashMap<TicTacToeBoard, MCTSNode>,
    rng: rand::ThreadRng
}


impl MonteCarloTreeSearch {
    fn new() -> MonteCarloTreeSearch {
        MonteCarloTreeSearch {
            nodes: HashMap::new(),
            rng: rand::thread_rng()
        }
    }

    fn random_move(&mut self, board: &TicTacToeBoard) -> TicTacToeBoard {
        match rand::seq::sample_iter(&mut self.rng,  NextMoves::new(*board), 1) {
            Ok(next) => { next[0]}
            Err(_) => {println!("It's so broken"); *board}
        }
    }
}


fn main() {
    let mut b = TicTacToeBoard::new();
    let mut mcts = MonteCarloTreeSearch::new();
    while !b.is_terminal() {
        b.display();
        b = mcts.random_move(&b);
        if b.white_wins() {
            println!("O's wins");
        }
        if b.black_wins() {
            println!("X's wins");
        }
    }
    b.display();
}
