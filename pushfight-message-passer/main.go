package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
    "time"
    "os/exec"
)

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
    if r.URL.Path != "/elm.min.js" {
        http.Error(w, "Not found", http.StatusNotFound)
        return
    }
    if r.Method != "GET" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    http.ServeFile(w, r, "./elm.min.js")
}

var (
    httpPort = ""
)


func makeServerFromMux(mux *http.ServeMux) *http.Server {
    // set timeouts so that a slow or malicious client doesn't
    // hold resources forever
    return &http.Server{
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 5 * time.Second,
        IdleTimeout:  120 * time.Second,
        Handler:      mux,
    }
}


func parseFlags() {
    flag.StringVar(&httpPort, "port", "9898", "port to start HTTP server. Defaults to 9898")
    flag.Parse()
}

func sendNotificationEmail(w http.ResponseWriter, r *http.Request) {
    email, ok := r.URL.Query()["email"]
    if !ok || len(email) != 1 {
        http.Error(w, "No email specified specified", http.StatusInternalServerError)
        return
    }
    gameID, ok := r.URL.Query()["gameID"]
    
    if !ok || len(gameID) < 1 {
        log.Println("Url Param 'gameID' is missing")
        return
    }
    err := exec.Command("./send.py", "turn_notification", email[0], gameID[0]).Run()
    if err != nil {
        log.Println("Failed to run email cmd")
    }
}

func makeHTTPServer() *http.Server {
    mux := &http.ServeMux{}
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
    mux.HandleFunc("/", serveHome)
    // mux.HandleFunc("/.well-known/pki-validation/B0BF35BDC0BC60AD9175C9CEA6E49315.txt", serveDNSValid)
    mux.HandleFunc("/elm.min.js", serveJS)
    mux.HandleFunc("/gameIDStatus", handleGameID)
    mux.HandleFunc("/sendNotificationEmail", sendNotificationEmail)
    mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
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
    return makeServerFromMux(mux)
}

func main() {
    parseFlags()
    httpPort = "0.0.0.0:" + httpPort

    var httpSrv *http.Server
    httpSrv = makeHTTPServer()
    httpSrv.Addr = httpPort

    fmt.Printf("Starting HTTP server on %s\n", httpPort)
    err := httpSrv.ListenAndServe()
    if err != nil {
        log.Fatalf("httpSrv.ListenAndServe() failed with %s", err)
    }
}
