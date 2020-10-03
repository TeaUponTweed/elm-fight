.DELETE_ON_ERROR:


.PHONY: build clean run

build: target/elm.js target/pushfight-message-passer target/index.html

clean:
	rm -f target/*

run: build
	cd target && ./pushfight-message-passer

target/elm.js: pushfight-viz/*
	elm make ./pushfight-viz/Main.elm --output=./target/elm.js

target/index.html: pushfight-viz/index.html
	cp pushfight-viz/index.html target/
	sed -i '' -e "s/ELM_SOURCE_FILE/elm.js/g" ./target/index.html

target/pushfight-message-passer: pushfight-message-passer/*.go
	cd ./pushfight-message-passer/ && go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target

