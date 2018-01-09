from pushfight import Board, EXAMPLE_BOARD
from mcts import MCTS

if __name__ == '__main__':
    board = EXAMPLE_BOARD
    mcts = MCTS(3.0)
    while not board.is_over():
        print(board.pieces)
        board = mcts.get_next_move(board)
    print('GAME OVER')
    print(board.pieces)
