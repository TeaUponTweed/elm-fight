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

target/pushfight-message-passer: pushfight-message-passer/*.go
	 cd ./pushfight-message-passer/ && go build .
	 mv ./pushfight-message-passer/pushfight-message-passer ./target

target/index.html: pushfight-viz/index.html
	cp pushfight-viz/index.html target/index.html

.PHONY: run
run: target/elm.min.js target/pushfight-message-passer target/index.html
	cd target && ./pushfight-message-passer
