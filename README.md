# Overview
## Goals
The goal is to create a virtual space to play boardgames, not to fascillitate competitive play. With that in mind:
* Any player can make a move at any time
* There is no authentication
* Players make and choose their own IDs

## Implementation

Elm front end with basic GoLang WebSocket server attempting to ensure consistency bewteen clients.

## Building & Running
To create a local developement server run
`make build`
To spin up the server on localhost run
`make run`

## TODO
* Add simple authentication to reduce webscrapers
* Re-architect board state to remove turn dependence (all can be inferred from the move stack) and allow undo / history viewing of past turns. Likely need to increase websocket max message length.
* Server selects new game ID (add route validation)
* Lobby to display ongoing games (with filter functionality)
* Make everything look nicer
* Store some number of games to server to allow restart tolerance

