from pushfight import Board, EXAMPLE_BOARD, OtherBoard
from mcts import MCTS

'''
timing results:
first attempt impl 0m0.764s real
second attempt impl 0m0.415s real
'''

if __name__ == '__main__':
    board = EXAMPLE_BOARD
    # board.vis()
    # for thing in board.gen_next_states():
    #     thing.vis()
    # exit(0)
    for _ in range(10):
        print(len(list(board.gen_next_states())))
        # print(len(set(board.gen_next_states())))
        # print(len(set(map(OtherBoard, board.gen_next_states()))))
    exit(0)
    # print(len(list(set(board.gen_next_states()))))
    mcts = MCTS(1.0)
    while not board.is_over():
        # print(board.pieces)
        board.vis()
        board = mcts.get_next_move(board)
    print('GAME OVER')
    board.vis()

