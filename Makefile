.DELETE_ON_ERROR:

.PHONY: clean
clean:
	rm -f target/*

target/elm.min.js: pushfight-viz/*.elm
	# brew install node
	# npm install uglify-js -g
	mkdir -p target
	elm make ./pushfight-viz/Main.elm --optimize --output=./target/elm.optimized.js
	cat ./target/elm.optimized.js | uglifyjs -m -c -o ./target/elm.min.js
	rm ./target/elm.optimized.js

target/pushfight-message-passer_linux_amd64 target/pushfight-message-passer_darwin_arm64: pushfight-message-passer/*.go
	# https://go.dev/doc/install
	cd ./pushfight-message-passer && GOOS=linux GOARCH=amd64 go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target/pushfight-message-passer_linux_amd64
	cd ./pushfight-message-passer && GOOS=darwin GOARCH=arm64 go build .
	mv ./pushfight-message-passer/pushfight-message-passer ./target/pushfight-message-passer_darwin_arm64

target/index.html: pushfight-viz/index.html
	cp pushfight-viz/index.html target/index.html
