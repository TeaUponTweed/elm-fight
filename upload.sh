# scp -r  ./target/ nanode:webapp/
rsync -au ./target/{pushfight-message-passer_linux,index.html,elm.js} nanode:webapp/
ssh nanode 'cd webapp && ./pushfight-message-passer_linux'
