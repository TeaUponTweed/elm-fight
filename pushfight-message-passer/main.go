// Copyright 2013 The Gorilla WebSocket Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
    "flag"
    "log"
    "net/http"
    // "github.com/gorilla/websocket/mux"
    "fmt"
)

var addr = flag.String("addr", ":8080", "http service address")

func serveHome(w http.ResponseWriter, r *http.Request) {
    log.Println(r.URL)
    if r.URL.Path != "/" {
        http.Error(w, "Not found", http.StatusNotFound)
        return
    }
    if r.Method != "GET" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    http.ServeFile(w, r, "./index.html")
}
func serveJS(w http.ResponseWriter, r *http.Request) {
    log.Println(r.URL)
    http.ServeFile(w, r, "./elm.js")
}

func main() {
    hubs := make(map[string]*Hub)
    handleGameID := func(w http.ResponseWriter, r *http.Request) {
        gameIDs, ok := r.URL.Query()["gameID"]
        if !ok || len(gameIDs) != 1 {
            http.Error(w, "No game ID specified", http.StatusInternalServerError)
            return
        }
        _, exists := hubs[gameIDs[0]]
        jsonBody := func() string {
            if exists {
                return fmt.Sprintf(`"joinGameIDValid": true, "newGameIDValid": false`)
            } else {
                return fmt.Sprintf(`"joinGameIDValid": false, "newGameIDValid": true`)
            }
        }()

        fmt.Fprintf(w, `{ "gameID": "%s", %s}`, gameIDs[0], jsonBody)
    }

    flag.Parse()

    http.HandleFunc("/", serveHome)
    http.HandleFunc("/elm.js", serveJS)
    http.HandleFunc("/gameIDStatus", handleGameID)
    http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
        gameIDs, ok := r.URL.Query()["gameID"]
        
        if !ok || len(gameIDs) < 1 {
            log.Println("Url Param 'gameID' is missing")
            return
        }
        for i := 0; i < len(gameIDs); i++ {
            hub, exists := hubs[gameIDs[i]]
            fmt.Println("gameID =", gameIDs[i])

            if !exists {
                hub := newHub()
                go hub.run()
                hubs[gameIDs[i]] = hub
                serveWs(hub, w, r)
            } else {
                serveWs(hub, w, r)
            }
        }
    })
    err := http.ListenAndServe(*addr, nil)
    if err != nil {
        log.Fatal("ListenAndServe: ", err)
    }
}
