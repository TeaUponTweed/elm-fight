import itertools as it

class OtherBoard(object):
    def __init__(self, pieces_dict):
        # pieces_dict = board.pieces
        self.white_pushers = frozenset((pieces_dict['wp1'], pieces_dict['wp2'], pieces_dict['wp3']))
        self.black_pushers = frozenset((pieces_dict['bp1'], pieces_dict['bp2'], pieces_dict['bp3']))
        self.white_movers = frozenset((pieces_dict['wm1'], pieces_dict['wm2']))
        self.black_movers = frozenset((pieces_dict['bm1'], pieces_dict['bm2']))
        # self.anchored = board.anchored

    def __hash__(self):
        return hash((self.white_pushers,
                     self.black_pushers,
                     self.white_movers,
                     self.black_movers))

    def __eq__(self, other):
        return (self.white_pushers == other.white_pushers and
                self.black_pushers == other.black_pushers and
                self.white_movers == other.white_movers and
                self.black_movers == other.black_movers)

    def to_dict(self):
        out = {}
        for k, v in it.chain(zip(('wp1', 'wp2', 'wp3'), self.white_pushers),
                             zip(('bp1', 'bp2', 'bp3'), self.black_pushers),
                             zip(('wm1', 'wm2'       ), self.white_movers ),
                             zip(('bm1', 'bm2'       ), self.black_movers )):
            out[k] = v
        return out


class Board(object):
    def __init__(self, pieces, anchored, is_whites_turn):
        self.pieces = pieces
        self.anchored = anchored
        self.is_whites_turn = is_whites_turn

    def __hash__(self):
        return hash((tuple(sorted(self.pieces.items())), self.anchored, self.is_whites_turn))

    def __eq__(self, other):
        return (tuple(sorted(self.pieces.items())), self.anchored, self.is_whites_turn) == (tuple(sorted(other.pieces.items())), other.anchored, other.is_whites_turn)

    def gen_neighbors(self, pieces, row, col):
        unexplored = set([(row, col)])
        explored = set(pieces.values())
        def should_explore(r, c):
            key = (r, c)
            return (is_inbounds(r, c) and
                    key not in explored)

        while unexplored:
            row, col = unexplored.pop()
            explored.add((row, col))
            for other_row, other_col in gen_ajacent_ixs(row, col):
                if should_explore(other_row, other_col):
                    yield other_row, other_col
                    unexplored.add((other_row, other_col))

    def gen_next_states(self, pieces=None, nmoves=2):
        pieces = pieces or self.pieces
        for b in (b.to_dict() for b in set(map(OtherBoard, self.gen_next_moves(pieces)))):
            yield from self.gen_execute_pushes(b)
        # for b in self.gen_next_moves(pieces):
            # yield from self.gen_execute_pushes(b)

    # def gen_next_moves(self, pieces, next_moves, nmoves=2):
    def gen_next_moves(self, pieces, nmoves=2):
        if nmoves == 0:
            yield pieces
            return
        # next_moves = next_moves or {}
        pos_to_piece_map = {v:k for k,v in pieces.items()}
        for empty_spaces, pieces_pos in self.gen_connected_components(pieces):
            movable_pieces = [pos_to_piece_map[pos] for pos in pieces_pos]
            for piece in movable_pieces:
                if self.is_whites_turn != piece.startswith('w'):
                    continue
                old_space = pieces[piece]
                for empty_space in empty_spaces:
                    pieces[piece] = empty_space
                    # ob = OtherBoard(piece)
                    # try:
                    #     previous_number_of_moves = next_moves[ob]
                    # except KeyError:
                    #     next_moves[ob] = nmoves
                    # else:
                    #     if nmoves <= previous_number_of_moves:
                    #         continue
                    yield from self.gen_next_moves(pieces, nmoves-1)

                pieces[piece] = old_space


    def gen_connected_components(self, pieces):
        occupied_positions = set(pieces.values())
        all_toexplore = _ALL_POSITIONS - occupied_positions
        while all_toexplore:
            toexplore = set()
            explored = set()
            pieces = set()
            toexplore.add(all_toexplore.pop())
            while toexplore:
                row, col = toexplore.pop()
                all_toexplore.discard((row, col))
                explored.add((row, col))
                for ix in (ix for ix in gen_ajacent_ixs(row, col) if is_inbounds(*ix)):
                    other_row, other_col = ix
                    if ix not in explored:
                        if ix in occupied_positions:
                            pieces.add(ix)
                        else:
                            toexplore.add(ix)
            yield explored, pieces

    def gen_execute_pushes(self, pieces):
        if self.is_whites_turn:
            pushers = _WHITE_PUSHERS
        else:
            pushers = _BLACK_PUSHERS
        inverted_pieces = dict(((r, c), p) for p, (r, c) in pieces.items())
        for pusher in pushers:
            row, col = pieces[pusher]
            for dr, dc in gen_cardinal_dirs():
                can_push, pushed_pieces = self.try_push(inverted_pieces, row + dr, col + dc, dr, dc, [pusher])
                if can_push:
                    new_pieces = pieces.copy()
                    for piece in pushed_pieces:
                        r, c = new_pieces[piece]
                        new_pieces[piece] = (r + dr, c + dc)
                    yield Board(new_pieces, anchored=(row + dr, col + dc), is_whites_turn=not self.is_whites_turn)

    def try_push(self, inverted_pieces, row, col, dr, dc, pushed_pieces):
        if (row, col) == self.anchored:
            return False, pushed_pieces

        if (row, col) in inverted_pieces:
            piece = inverted_pieces[(row, col)]
            return self.try_push(inverted_pieces, row + dr, col + dc, dr, dc, pushed_pieces + [piece])
        else:
            if row == -1:
                return not (2 < col < 8) and len(pushed_pieces) > 1, pushed_pieces
            elif row == 4:
                return not (1 < col < 7) and len(pushed_pieces) > 1, pushed_pieces
            else:
                return len(pushed_pieces) > 1, pushed_pieces

    def is_over(self, pieces=None):
        pieces = pieces or self.pieces
        return not all(is_inbounds(r, c) for r, c in pieces.values())

    def vis(self):
        board = [
            ['  ','  ','  ','==','==','==','==','==','  ','  '],
            ['  ','  ','  ','__','__','__','__','__','  ','  '],
            ['  ','__','__','__','__','__','__','__','__','  '],
            ['  ','__','__','__','__','__','__','__','__','  '],
            ['  ','  ','__','__','__','__','__','  ','  ','  '],
            ['  ','  ','==','==','==','==','==','  ','  ','  '],
        ]
        for piece, (row, col) in self.pieces.items():
            if 'm' in piece:
                board[row+1][col] = '{}{}'.format(piece[0].upper(), piece[1])
            else:
                board[row + 1][col] = '{}{}'.format(piece[0].upper(), piece[1].upper())
        if self.anchored is not None:
            row, col = self.anchored
            board[row+1][col] = '{}#'.format(board[row+1][col][0])
        for row in board:
            # print(row)
            print(''.join(row))
        print()


_CARDINAL_DIRS = ((-1, 0), (1, 0), (0, -1), (0, 1))
def gen_cardinal_dirs():
    for direction in _CARDINAL_DIRS:
        yield direction

def gen_ajacent_ixs(row, col):
    for dr, dc in gen_cardinal_dirs():
        yield row + dr, col + dc


def is_inbounds(row, col):
    if row == 0:
        return 2 < col < 8
    elif row == 1 or row == 2:
        return 0 < col < 9
    elif row == 3:
        return 1 < col < 7
    else:
        return False


_ALL_POSITIONS = set()
for row in range(4):
    for col in range(0, 10):
        if is_inbounds(row, col):
            _ALL_POSITIONS.add((row, col))



EXAMPLE_BOARD = Board(
    pieces={
        'wp1': (1, 4),
        'wp2': (2, 4),
        'wp3': (2, 2),
        'wm1': (0, 4),
        'wm2': (3, 4),
        'bp1': (3, 5),
        'bp2': (2, 5),
        'bp3': (0, 5),
        'bm1': (1, 5),
        'bm2': (1, 6)
    },
    anchored=None,
    is_whites_turn=True
)

_WHITE_PUSHERS = ('wp1', 'wp2', 'wp3')
_WHITE_PIECES = ('wp1', 'wp2', 'wp3', 'wm1', 'wm2')
_BLACK_PUSHERS = ('bp1', 'bp2', 'bp3')
_BLACK_PIECES = ('bp1', 'bp2', 'bp3', 'bm1', 'bm2')
    
def bit_to_xy(bit, board_size=None):
    if board_size is None:
        board_size = [4,8]
    x = bit % board_size[0]
    y = bit - board_size[0]*x
    return (x, y)

def bits_to_board(board_bits, is_whites_turn=None, board_size=None):
    # Set defaults
    if is_whites_turn is None:
        is_whites_turn = True
    if board_size is None:
        board_size = [4,8]

    occupied = board_bits[0]
    is_pusher = board_bits[1]
    is_white = board_bits[2]
    is_anchor = board_bits[3]
    N = len(occupied)
    
    # Loop over all bits, plugging into the board when occupied
    n_found = {'wp':0, 'wm':0, 'bp':0, 'bm':0}
    pieces = {}
    anchor = None
    for bit in range(N):
        if not occupied[bit]:
            continue
        xy = bit_to_xy(bit)
        color = 'w' if is_white[bit] else 'b'
        piece = 'p' if is_pusher[bit] else 'm'
        label = color + piece
        n_found[label] += 1
        pieces[label+str(n_found[label])] = xy
        if is_anchor[bit]:
            anchor = xy
            assert(is_pusher[bit], 'Anchor not on pusher')

    return Board(pieces, anchor, is_whites_turn)
