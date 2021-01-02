// // Copyright 2013 The Gorilla WebSocket Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style
// // license that can be found in the LICENSE file.
// // 2020 Code modified by Michael Mason from https://github.com/gorilla/websocket/tree/master/examples/chat

package main

import (
    "context"
    "crypto/tls"
    "flag"
    "fmt"
    // "io"
    "log"
    "net/http"
    "time"
    "os/exec"
    "golang.org/x/crypto/acme/autocert"
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
    if r.URL.Path != "/elm.js" {
        http.Error(w, "Not found", http.StatusNotFound)
        return
    }
    if r.Method != "GET" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    http.ServeFile(w, r, "./elm.js")
}

var (
    flgProduction          = true
    flgRedirectHTTPToHTTPS = true
)

// func handleIndex(w http.ResponseWriter, r *http.Request) {
//     io.WriteString(w, htmlIndex)
// }

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

// func makeHTTPServer() *http.Server {
//     mux := &http.ServeMux{}
//     mux.HandleFunc("/", handleIndex)
//     return makeServerFromMux(mux)

// }

func makeHTTPToHTTPSRedirectServer() *http.Server {
    handleRedirect := func(w http.ResponseWriter, r *http.Request) {
        newURI := "https://" + r.Host + r.URL.String()
        http.Redirect(w, r, newURI, http.StatusFound)
    }
    mux := &http.ServeMux{}
    mux.HandleFunc("/", handleRedirect)
    return makeServerFromMux(mux)
}

func parseFlags() {
    flag.BoolVar(&flgProduction, "production", false, "if true, we start HTTPS server")
    flag.BoolVar(&flgRedirectHTTPToHTTPS, "redirect-to-https", false, "if true, we redirect HTTP to HTTPS")
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
    // exec.Command("python", "../send_gmail/send.py", "turn_notification", email[0],  gameID[0])
    // cmd := fmt.Sprintf("./send.py turn_notification %s %s", email[0],  gameID[0])
    err := exec.Command("./send.py", "turn_notification", email[0], gameID[0]).Run()
    if err != nil {
        log.Println("Failed to run email cmd")
        // log.Println(err)
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
    mux.HandleFunc("/elm.js", serveJS)
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
    var m *autocert.Manager

    var httpsSrv *http.Server
    var httpPort string
    if flgProduction {
        httpPort = "0.0.0.0:80"
        hostPolicy := func(ctx context.Context, host string) error {
            // Note: change to your real host
            allowedHosts := []string{"www.masonuvagun.xyz", "masonuvagun.xyz"}
            fmt.Println(host)
            for _, allowedHost := range allowedHosts {
                if host == allowedHost {
                    return nil
                }                
            }

            return fmt.Errorf("acme/autocert: only %s hosts are allowed", allowedHosts)
        }

        dataDir := "."
        m = &autocert.Manager{
            Prompt:     autocert.AcceptTOS,
            HostPolicy: hostPolicy,
            Cache:      autocert.DirCache(dataDir),
        }

        httpsSrv = makeHTTPServer()
        httpsSrv.Addr = ":443"
        httpsSrv.TLSConfig = &tls.Config{GetCertificate: m.GetCertificate}

        go func() {
            fmt.Printf("Starting HTTPS server on %s\n", httpsSrv.Addr)
            err := httpsSrv.ListenAndServeTLS("", "")
            if err != nil {
                log.Fatalf("httpsSrv.ListendAndServeTLS() failed with %s", err)
            }
        }()
    } else {
        httpPort = "0.0.0.0:8000"
    }

    var httpSrv *http.Server
    if flgRedirectHTTPToHTTPS {
        httpSrv = makeHTTPToHTTPSRedirectServer()
    } else {
        httpSrv = makeHTTPServer()
    }
    // allow autocert handle Let's Encrypt callbacks over http
    if m != nil {
        httpSrv.Handler = m.HTTPHandler(httpSrv.Handler)
    }

    httpSrv.Addr = httpPort

    // pfdata := setupPushfight()

    fmt.Printf("Starting HTTP server on %s\n", httpPort)
    err := httpSrv.ListenAndServe()
    if err != nil {
        log.Fatalf("httpSrv.ListenAndServe() failed with %s", err)
    }
}