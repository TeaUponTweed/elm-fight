.DELETE_ON_ERROR:


.PHONY: build clean run upload

build: target_devel/elm.js target_devel/pushfight-message-passer target_devel/index.html

clean:
	rm -f target_devel/* target_prod/*

run: build
	cd target_devel && ./pushfight-message-passer

target_devel/elm.js: pushfight-viz/*
	elm make ./pushfight-viz/Main.elm --output=./target_devel/elm.js

target_devel/index.html: pushfight-viz/index.html
	cp pushfight-viz/index.html target_devel/
# 	sed -i '' -e "s/ELM_SOURCE_FILE/elm.js/g" ./target_devel/index.html
	sed -i '' -e "s?https:?http:?g" -e "s?wss:?ws:?g" ./target_devel/index.html

target_devel/pushfight-message-passer: pushfight-message-passer/*.go
	cd ./pushfight-message-passer/ && go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target_devel


target_prod/elm.min.js: target_devel/elm.js
	elm make ./pushfight-viz/Main.elm --optimize --output=./target_prod/elm.optimized.js
	uglifyjs ./target_prod/elm.optimized.js \
		--compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" \
		| uglifyjs --mangle --output=./target_prod/elm.min.js

target_prod/pushfight-message-passer_linux ./target_prod/index.html: pushfight-message-passer/*.go
	cp pushfight-viz/index.html target_prod/
	cd ./pushfight-message-passer/ && GOOS=linux GOARCH=amd64 go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target_prod/pushfight-message-passer_linux

upload: ./target_prod/pushfight-message-passer_linux ./target_prod/elm.min.js ./target_prod/index.html
	cd target && rsync -au pushfight-message-passer_linux index.html nanode:webapp/
	scp ./target_prod/elm.min.js nanode:webapp/elm.js
