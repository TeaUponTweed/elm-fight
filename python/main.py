from pushfight import Board, EXAMPLE_BOARD
from mcts import MCTS



if __name__ == '__main__':
    board = EXAMPLE_BOARD
    # board.vis()
    # for thing in board.gen_next_states():
    #     thing.vis()
    print(len(list(board.gen_next_states())))
    # print(len(list(set(board.gen_next_states()))))
    mcts = MCTS(1.0)
    while not board.is_over():
        # print(board.pieces)
        board.vis()
        board = mcts.get_next_move(board)
    print('GAME OVER')
    board.vis()

