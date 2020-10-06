.DELETE_ON_ERROR:


.PHONY: build clean run upload

build: target/elm.js target/pushfight-message-passer target/index.html

clean:
	rm -f target/*

run: build
	cd target && ./pushfight-message-passer

target/elm.js: pushfight-viz/*
	elm make ./pushfight-viz/Main.elm --output=./target/elm.js

target/index.html: pushfight-viz/index.html
	cp pushfight-viz/index.html target/
# 	sed -i '' -e "s/ELM_SOURCE_FILE/elm.js/g" ./target/index.html

target/pushfight-message-passer: pushfight-message-passer/*.go
	cd ./pushfight-message-passer/ && go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target


target/elm.min.js: target/elm.js
	elm make ./pushfight-viz/Main.elm --optimize --output=./target/elm.optimized.js
	uglifyjs ./target/elm.optimized.js \
		--compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" \
		| uglifyjs --mangle --output=./target/elm.min.js

target/pushfight-message-passer_linux: target/pushfight-message-passer
	cd ./pushfight-message-passer/ && GOOS=linux GOARCH=amd64 go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target/pushfight-message-passer_linux

upload: ./target/pushfight-message-passer_linux ./target/elm.min.js ./target/index.html
	cd target && rsync -au pushfight-message-passer_linux index.html nanode:webapp/
	scp ./target/elm.min.js nanode:webapp/elm.js
