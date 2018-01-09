from pushfight import Board, EXAMPLE_BOARD
from mcts import MCTS

if __name__ == '__main__':
    board = EXAMPLE_BOARD
    mcts = MCTS(1.0)
    while not board.is_over():
        print(board)
        board = mcts.get_next_move(board)
    print('GAME OVER')
    print(board)
