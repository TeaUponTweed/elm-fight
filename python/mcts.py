import math, random, time


class Node(object):
    def __init__(self, board, parent=None, children=None):
        self.board = board
        self.nvisits = 0
        self.nwins = 0
        self.parent = parent
        self.children = children
    
    def ucts(self, child):
        return child.nwins / child.nvisits + math.sqrt(2 * math.log(self.nvisits) / child.nvisits)

    def select(self):
        if self.children is None:
            return self
        else:
            return max(self.children, key=self.ucts).select()
    
    def expand(self):
        assert self.children is None
        self.children = [Node(b, self) for b in self.board.gen_next_states()]
        assert len(self.children) > 0

    def simulate(self):
        b = self.board
        i = 0
        while not b.is_over():
            b = random.choice(list(b.gen_next_states()))
            # b = random.choice(list(set(b.gen_next_states())))
            i += 1
        print(i)
        white_wins = not b.is_whites_turn
        return white_wins

    def backpropagate(self, white_wins):
        if self.board.is_whites_turn != white_wins:
            self.nwins += 1
        self.nvisits += 1
        if self.parent is not None:
            self.parent.backpropagate(white_wins)

class MCTS(object):
    def __init__(self, max_delta):
        self.max_delta = max_delta

    def get_next_move(self, board):
        endtime = time.time() + self.max_delta
        root = Node(board)
        while time.time() < endtime:
            next_node = root.select()
            next_node.expand()
            for child in next_node.children:
                white_wins = child.simulate()
                child.backpropagate(white_wins)
        return max(root.children, key=lambda x: x.nwins/x.nvisits).board
