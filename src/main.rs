extern crate rand;
extern crate noisy_float;
extern crate indextree;

// use std::collections::HashMap;
// use std::collections::BTreeMap;
use std::time::{Duration, SystemTime};
use std::iter;
use noisy_float::prelude::*;
use indextree::{Arena, NodeId};

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
    board: TicTacToeBoard,
    nwins: usize,
    nsims: usize,
    // nloss: usize
    // children: Option<Vec<MCTSNode>>,
    // parent: Option<MCTSNode<'a>>
}

impl MCTSNode {
    fn new(board: TicTacToeBoard) -> MCTSNode {
        MCTSNode {
            board: board,
            nwins: 0,
            nsims: 0,
            // nloss: 0
            // children: None,
            // parent: parent
        }
    }

    // fn new(board: TicTacToeBoard) -> MCTSNode {
    //     new(board, None)
    // }
}

struct MonteCarloTreeSearch {
    nodes: Arena<MCTSNode>,
    // nsims: BTreeMap<usize, usize> // depth -> nsims
    root: NodeId,
    rng: rand::ThreadRng,
    // max_depth: usize,
    max_time: Duration,
    start_time: SystemTime
}

 fn confifence_bound(wi: usize, ni: usize, Ni: usize) -> R32 {
    let wi = r32(wi as f32);
    let ni = r32(ni as f32);
    let Ni = r32(Ni as f32);
    (Ni.ln()/ni.sqrt()) * 2.0.sqrt() + wi/ni
 }

enum TicTacToeResult {
    WhiteWins,
    BlackWins,
    CatsGame
}

impl MonteCarloTreeSearch {
    fn new(max_time: Duration, board: TicTacToeBoard) -> MonteCarloTreeSearch {
        let now = SystemTime::now();
        let mut arena = Arena::new();
        let root = arena.new_node(MCTSNode::new(board));
        MonteCarloTreeSearch {
            nodes: arena,
            // nodes: HashMap::new(),
            // nsims: BTreeMap::new(),
            root: root,
            rng: rand::thread_rng(),
            // max_depth: max_depth,
            max_time: max_time,
            start_time: now
        }
    }

    fn selection(&self, root: NodeId) -> NodeId {
        if self.nodes[root].data.board.is_terminal() {
            return root;
        }

        if root.children(&self.nodes).count() > 1 {
            // let Ni = match self.nsims.get(root_depth+2) {
            //     Some(n) => n,
            //     None    => 0
            // }
            let ntotal_sims = root.descendants(&self.nodes).map(|n| self.nodes[n].data.nsims).sum();
            // let mut children = root.children(&self.nodes);
            // children.next.
            if let Some(selected_child) = root.children(&self.nodes).max_by_key(|n| confifence_bound(self.nodes[*n].data.nwins, self.nodes[*n].data.nsims, ntotal_sims)) {
                return self.selection(selected_child);
            }
            else {
                panic!("No child nodes or something")
            }
        }
        else {
            return root;
        }
    }

    fn expansion(&mut self, root: NodeId) {
        // let children : Vec<_> = NextMoves::new(children).map(|child| MCTSNode::new(child, Some(root))
        for next_board in NextMoves::new(self.nodes[root].data.board) {
            let result = self.light_simulation(&next_board);
            let child_node = self.nodes.new_node(MCTSNode::new(next_board));
            root.append(child_node, &mut self.nodes);
            self.back_propagate(child_node, result);
        }
    }

    fn light_simulation(&mut self, board: &TicTacToeBoard) -> TicTacToeResult {
        let mut b = board.clone();
        if b.white_wins() {
            return TicTacToeResult::WhiteWins;
        }
        if b.black_wins() {
            return TicTacToeResult::BlackWins;
        }
        while !b.is_terminal() {
            b = self.random_move(&b);
            if b.white_wins() {
                return TicTacToeResult::WhiteWins;
            }
            if b.black_wins() {
                return TicTacToeResult::BlackWins;
            }
        }
        return TicTacToeResult::CatsGame;

    }

    fn back_propagate(&mut self, child: NodeId, result: TicTacToeResult) {
        let ancestors : Vec<_> = child.ancestors(&self.nodes).collect();
        // if was_win(&self.nodes[child].data.board, &result) {
        //     self.nodes[child].data.nwins += 1;
        //     // ancestor.data.nwins += 1;
        // }
        // self.nodes[child].data.nsims += 1;
        // match result,self.nodes[child].data.board.is_whites_turn {
        //     (WhiteWins, false) => {self.nodes[child].data.nwins += 1},
        //     (WhiteWins, true)  => {self.nodes[child].data.nloss += 1},
        //     (BlackWins, true)  => {self.nodes[child].data.nwins += 1},
        //     (BlackWins, false) => {self.nodes[child].data.nloss += 1},
        // }
        for node in iter::once(child).chain(ancestors) {
            self.nodes[node].data.nsims += 2;
            match (&result, self.nodes[node].data.board.is_whites_turn) {
                (&TicTacToeResult::WhiteWins, false) => {self.nodes[node].data.nwins += 2},
                // (&TicTacToeResult::WhiteWins, true)  => {self.nodes[node].data.nwins -= 2},
                // (WhiteWins, true)  => {self.nodes[node].data.nloss += 2},
                (&TicTacToeResult::BlackWins, true)  => {self.nodes[node].data.nwins += 2},
                // (&TicTacToeResult::BlackWins, false) => {self.nodes[node].data.nwins -= 2},
                // (BlackWins, false) => {self.nodes[node].data.nloss += 1},
                (&TicTacToeResult::CatsGame, _)      => {self.nodes[node].data.nwins += 1},
                _                                    => {}
            }
        }
    }

    fn random_move(&mut self, board: &TicTacToeBoard) -> TicTacToeBoard {
        match rand::seq::sample_iter(&mut self.rng,  NextMoves::new(*board), 1) {
            Ok(next) => { next[0]}
            Err(_) => {println!("It's so broken"); *board}
        }
    }

    fn make_move(&mut self) -> TicTacToeBoard {
        let mut over_time = false;
        while !over_time {
            let selection = self.selection(self.root);
            self.expansion(selection);
            over_time = match self.start_time.elapsed() {
                Ok(elapsed) => self.max_time < elapsed,
                Err(_) => panic!("can't get system time")
            };
        }
        if let Some(best_child) = self.root.children(&self.nodes).max_by_key(|n| r32(self.nodes[*n].data.nwins as f32)/r32(self.nodes[*n].data.nsims as f32)) {
            return self.nodes[best_child].data.board;
        }
        else
        {
            panic!("No children at evaluation");
        }
    }
}


fn was_win(board: &TicTacToeBoard, result: &TicTacToeResult) -> bool {
    match (result, board.is_whites_turn) {
        (&TicTacToeResult::WhiteWins, false) => true,
        (&TicTacToeResult::BlackWins, true)  => true,
        _ => false
    }
}


fn main() {
    let mut b = TicTacToeBoard::new();
    while !b.is_terminal() {
        b.display();
        let mut mcts = MonteCarloTreeSearch::new(Duration::from_secs(1), b.clone());
        b = mcts.make_move();
    }
    if b.white_wins() {
        println!("O's wins!");
    }
    else if b.black_wins() {
        println!("X's wins!");
    }
    else {
        println!("Cats!");
    }

    b.display()

    // while !b.is_terminal() {
    //     b.display();
    //     b = mcts.random_move(&b);
    //     if b.white_wins() {
    //         println!("O's wins");
    //     }
    //     if b.black_wins() {
    //         println!("X's wins");
    //     }
    // }
    // b.display();
}
