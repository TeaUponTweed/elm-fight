struct Pos {
    row: u8,
    col: u8
}

struct DictBoard {
    wp1: Pos,
    wp2: Pos,
    wp3: Pos,
    wm1: Pos,
    wm2: Pos,
    bp1: Pos,
    bp2: Pos,
    bp3: Pos,
    bm1: Pos,
    bm2: Pos,
    anc: Option<Pos>
}

struct PackedBoard {
    data: u64
}

enum Piece {
    WhitePusher,
    WhitePusherWithAnchor,
    WhiteDier,
    BlackPusher,
    BlackPusherWithAnchor,
    BlackDier,
    Empty,
    OffBoard
}

fn is_pusher(piece: Piece) -> bool {
    match piece {
        WhitePusher | WhitePusherWithAnchor | BlackPusher | BlackPusherWithAnchor => true,
        _                                                                         => false
    }
}


fn is_black(piece: Piece) -> bool {
    match piece {
        BlackDier | BlackPusher | BlackPusherWithAnchor => true,
        _                                               => false
    }
}

fn is_white(piece: Piece) -> bool {
    match piece {
        WhiteDier | WhitePusher | WhitePusherWithAnchor => true,
        _                                               => false
    }
}

fn can_be_pushed(piece: Piece) -> bool {
    match piece {
        WhitePusher | WhiteDier | BlackPusher | BlackDier => true,
        _                                                 => false
    }
}

static NROWS: u8 = 4;
static NCOLS: u8 = 8;

struct DenseBoard {
    data: [[Piece::OffBoard; 8] 4]
    is_transposed: bool
}

impl Index<(usize, usize)> for DenseBoard {
    type Output = Piece;

    fn index(&self, index: (usize, usize) ) -> &Piece {
        let (row, col) = index;
        if self.is_transposed {
            self.data[row][col]
        }
        else {
            self.data[col][row]
        }
    }
}

// struct RowBoardTranspose {
//     data: [[Piece::OffBoard; 4] 8]
// }

fn ExecuteVerticalPushes(board: ColBoard) {

}

struct ConnectedArea {
    Vec<u8>: empty_ixs,
    Vec<u8>: piece_ixs
}

fn find_connected_area(board: &DenseBoard, row: usize, col:usize) -> ConnectedArea {
    let mut unexplored_ixs = Set::new()
    let mut explored_ixs = Set::new()
    // let mut empty_ixs = Vec::new();
    // let mut piece_ixs = Vec::new();
    unexplored_ixs.add((row, col))
    while !unexplored_ixs.empty() {
        let (row, col) = unexplored_ixs.pop();
        for neighbor_ix in ((row + 1, col), (row - 1, col), (row, col + 1), (row, col -1)) {
            // neighbor_row, neighbor_col
            if (board[neighbor_ix] == Piece::Empty) && !explored_ixs.contains(neighbor_ix) {
                unexplored_ixs.add(neighbor_ix);
            }
            explored_ixs.add(neighbor_ix);
        }
    }
    
}
// fn find_connected_components(board: &DenseBoard) -> Vec<ConnectedArea> {
//     let mut connected_areas = Vec::new();
//     let mut visited_ixs = Set::new();
//     for row in 0 as usize..NROWS {
//         for col in 0 as usize..NCOLS {
//             match board[(row, col)] {
//                 &Piece::Empty => {

//                 }
//             }
//         }
//     }
//     let mut empty_ixs = Vec::new();
//     let mut piece_ixs = Vec::new();

// }