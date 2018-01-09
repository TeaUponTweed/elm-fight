class Board(object):
    def __init__(self, pieces, anchored, is_whites_turn):
        self.pieces = pieces
        self.anchored = anchored
        self.is_whites_turn = is_whites_turn

    def __hash__(self):
        return hash((sorted(self.pieces.items(), self.anchored, self.is_whites_turn)))

    def gen_neighbors(self, pieces, row, col):
        unexplored = set([(row, col)])
        explored = set(pieces.values())
        def should_explore(row, col):
            key = (row, col)
            return (is_inbounds(row, col) and
                    key not in explored)

        while unexplored:
            row, col = unexplored.pop()
            explored.add((row, col))
            for row, col in gen_ajacent_ixs(row, col):
                if should_explore(row, col):
                    yield row, col
                    unexplored.add((row, col))

    def gen_next_states(self, pieces=None, nmoves=2):
        pieces = pieces or self.pieces
        yield from self.gen_execute_pushes(pieces)
        if nmoves == 0:
            return

        for piece, (row, col) in pieces.items():
            for (other_row, other_col) in self.gen_neighbors(pieces, row, col):
                next_pieces = pieces.copy()
                next_pieces[piece] = (other_row, other_col)
                yield from self.gen_next_states(next_pieces, nmoves - 1)

    def gen_execute_pushes(self, pieces):
        if self.is_whites_turn:
            pushers = ('wp1', 'wp2', 'wp3')
        else:
            pushers = ('bp1', 'bp2', 'bp3')

        for pusher in pushers:
            row,  col = pieces[pusher]
            for dr, dc in gen_cardinal_dirs():
                can_push, pushed_pieces = self.try_push(
                    pieces, row + dr, col + dr, dr, dc, [pusher])
                if can_push:
                    new_pieces = pieces.copy()
                    for piece in pushed_pieces:
                        r, c = new_pieces[piece]
                        new_pieces[piece] = (r + dr, c + dc)
                    yield Board(new_pieces, anchored=(row + dr, col + dc), is_whites_turn=not self.is_whites_turn)

    def try_push(self, pieces, row, col, dr, dc, pushed_pieces):
        if (row, col) == self.anchored:
            return False, pushed_pieces

        if (row, col) in pieces:
            return try_push(pieces, row + dr, col + dc, pushed_pieces + [pieces])
        else:
            if row == -1:
                return not (2 < col < 8), pushed_pieces
            elif row == 4:
                return not (1 < col < 7), pushed_pieces
            else:
                return len(pushed_pieces) > 1, pushed_pieces

    def is_over(self, pieces=None):
        pieces = pieces or self.pieces
        return not all(is_inbounds(r, c) for r, c in pieces.values())


def gen_cardinal_dirs():
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            if dr == dc == 0:
                continue
            yield dr, dc


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


EXAMPLE_BOARD = Board(
    pieces={
        'wp1': (0, 4),
        'wp2': (1, 4),
        'wp3': (3, 4),
        'wm1': (2, 4),
        'wm2': (2, 3),
        'bp1': (0, 5),
        'bp2': (2, 5),
        'bp3': (3, 5),
        'bm1': (2, 5),
        'bm2': (1, 6)
    },
    anchored=None,
    is_whites_turn=True
)
