# The code is divided into 3 parts:
1. Elm frontend for pushfight at top level
2. Performant (supposedly) Rust code in src/ directory
3. Prototype python code in python/ directory

# Python TODO
* Implement connected components for move generation
* Handle redundancy in board state (wp1 == wp2 == wp3 for all intents and purposes)
* Bitpack boards
    * Investigate whether valid random moves can be generated from bit representation
* Implement valid move detector: given two boards, could one be produced from the other
