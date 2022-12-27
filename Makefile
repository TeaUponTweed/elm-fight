.DELETE_ON_ERROR:


.PHONY: build clean run upload

build: target_devel/elm.js target_devel/pushfight-message-passer target_devel/index.html target_devel/send.py target_devel/token.pickle

clean:
	rm -f target_devel/* target_prod/*

run: build
	cd target_devel && ./pushfight-message-passer

target_devel/elm.js: pushfight-viz/*
	elm make ./pushfight-viz/Main.elm --output=./target_devel/elm.js

target_devel/index.html target_devel/send.py target_devel/token.pickle: pushfight-viz/index.html send_gmail/send.py token.pickle
	cp pushfight-viz/index.html target_devel/
	cp token.pickle target_devel/
	sed -i '' -e "s?https:?http:?g" -e "s?wss:?ws:?g" ./target_devel/index.html
	cp send_gmail/send.py target_devel/send.py

target_devel/pushfight-message-passer: pushfight-message-passer/*.go
	cd ./pushfight-message-passer/ && go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target_devel


target_prod/elm.min.js: target_devel/elm.js
	# brew install node
	# npm install uglify-js -g
	mkdir -p target_prod
	elm make ./pushfight-viz/Main.elm --optimize --output=./target_prod/elm.optimized.js
	cat ./target_prod/elm.optimized.js | uglifyjs -m -c -o ./target_prod/elm.min.js

target_prod/pushfight-message-passer_linux ./target_prod/index.html ./target_prod/send.py target_prod/token.pickle : pushfight-message-passer/*.go target_devel/index.html target_devel/send.py token.pickle
	cp pushfight-viz/index.html target_prod/
	cp target_devel/send.py target_prod/
	cd ./pushfight-message-passer/ && GOOS=linux GOARCH=amd64 go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target_prod/pushfight-message-passer_linux
	cp token.pickle target_prod/

upload: ./target_prod/pushfight-message-passer_linux ./target_prod/elm.min.js ./target_prod/index.html ./target_prod/send.py
	cd target_prod && rsync -au pushfight-message-passer_linux index.html send.py nanode:webapp/
	scp ./target_prod/elm.min.js nanode:webapp/elm.js
	scp ./target_prod/send.py nanode:webapp/send.py
	scp ./target_prod/token.pickle nanode:webapp/token.pickle
