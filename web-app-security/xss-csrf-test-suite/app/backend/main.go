package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/mail"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	contentTypeJSON     = "application/json"
	headerContentType   = "Content-Type"
	methodNotAllowedMsg = "Method not allowed"
	invalidBodyMsg      = "Invalid request body"
	defaultOrigin       = "http://localhost:5173"
	defaultServerAddr   = ":8080"
	sessionCookieName   = "session"
	csrfHeaderName      = "X-CSRF-Token"

	maxBodyBytes      = 1 << 20
	maxFullNameLength = 200
	maxEmailLength    = 320
	maxAmount         = 1_000_000.0
	maxCartItems      = 1000
	minUsernameLen    = 3
	maxUsernameLen    = 64
	minPasswordLen    = 8
	maxPasswordLen    = 128
	sessionLifetime   = 24 * time.Hour
)

var emailPattern = regexp.MustCompile(`^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$`)

type Product struct {
	ID    int     `json:"id"`
	Name  string  `json:"name"`
	Price float64 `json:"price"`
}

type PaymentRequest struct {
	FullName string  `json:"fullName"`
	Email    string  `json:"email"`
	Amount   float64 `json:"amount"`
}

type CartRequest struct {
	Items []Product `json:"items"`
}

type GenericResponse struct {
	Message string `json:"message"`
}

type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Message   string `json:"message"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	CSRFToken string `json:"csrfToken"`
}

type AccountResponse struct {
	Username  string `json:"username"`
	Email     string `json:"email"`
	CSRFToken string `json:"csrfToken"`
}

type ChangeEmailRequest struct {
	Email string `json:"email"`
}

type Session struct {
	Username  string
	CSRFToken string
	Expires   time.Time
}

type User struct {
	Username string
	Email    string
	Password string
}

type store struct {
	mu       sync.Mutex
	users    map[string]*User
	sessions map[string]*Session
}

func newStore() *store {
	return &store{
		users:    make(map[string]*User),
		sessions: make(map[string]*Session),
	}
}

var products = []Product{
	{ID: 1, Name: "Laptop", Price: 3999.99},
	{ID: 2, Name: "Mysz", Price: 149.99},
	{ID: 3, Name: "Klawiatura", Price: 249.99},
	{ID: 4, Name: "Monitor", Price: 1299.00},
	{ID: 5, Name: "Sluchawki", Price: 399.50},
}

var dataStore = newStore()

func setSecurityHeaders(w http.ResponseWriter) {
	h := w.Header()
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("X-Frame-Options", "DENY")
	h.Set("Referrer-Policy", "no-referrer")
}

func withCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		setSecurityHeaders(w)
		origin := r.Header.Get("Origin")
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
		} else {
			w.Header().Set("Access-Control-Allow-Origin", defaultOrigin)
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-CSRF-Token")
		w.Header().Set("Vary", "Origin")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next(w, r)
	}
}

func requireMethod(w http.ResponseWriter, r *http.Request, methods ...string) bool {
	for _, m := range methods {
		if r.Method == m {
			return true
		}
	}
	http.Error(w, methodNotAllowedMsg, http.StatusMethodNotAllowed)
	return false
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set(headerContentType, contentTypeJSON)
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, GenericResponse{Message: message})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dest any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dest); err != nil {
		writeJSONError(w, http.StatusBadRequest, invalidBodyMsg)
		return false
	}
	return true
}

func validatePayment(p PaymentRequest) error {
	name := strings.TrimSpace(p.FullName)
	if name == "" || len(name) > maxFullNameLength {
		return errors.New("invalid full name")
	}

	email := strings.TrimSpace(p.Email)
	if email == "" || len(email) > maxEmailLength || !strings.Contains(email, "@") {
		return errors.New("invalid email")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return errors.New("invalid email")
	}

	if p.Amount <= 0 || p.Amount > maxAmount {
		return errors.New("invalid amount")
	}
	return nil
}

func validateCart(c CartRequest) error {
	if len(c.Items) == 0 || len(c.Items) > maxCartItems {
		return errors.New("invalid items")
	}
	return nil
}

func validateRegister(r RegisterRequest) error {
	username := strings.TrimSpace(r.Username)
	if len(username) < minUsernameLen || len(username) > maxUsernameLen {
		return errors.New("invalid username")
	}
	email := strings.TrimSpace(r.Email)
	if len(email) == 0 || len(email) > maxEmailLength {
		return errors.New("invalid email")
	}
	if !emailPattern.MatchString(email) {
		return errors.New("invalid email")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return errors.New("invalid email")
	}
	if len(r.Password) < minPasswordLen || len(r.Password) > maxPasswordLen {
		return errors.New("invalid password")
	}
	return nil
}

func validateEmail(email string) error {
	email = strings.TrimSpace(email)
	if len(email) == 0 || len(email) > maxEmailLength {
		return errors.New("invalid email")
	}
	if !emailPattern.MatchString(email) {
		return errors.New("invalid email")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return errors.New("invalid email")
	}
	return nil
}

func randomToken(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("fallback-%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(buf)
}

func setSessionCookie(w http.ResponseWriter, sessionID string) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    sessionID,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Now().Add(sessionLifetime),
	})
}

func clearSessionCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
}

func currentSession(r *http.Request) (string, *Session, bool) {
	cookie, err := r.Cookie(sessionCookieName)
	if err != nil || cookie.Value == "" {
		return "", nil, false
	}
	dataStore.mu.Lock()
	defer dataStore.mu.Unlock()
	sess, ok := dataStore.sessions[cookie.Value]
	if !ok {
		return "", nil, false
	}
	if time.Now().After(sess.Expires) {
		delete(dataStore.sessions, cookie.Value)
		return "", nil, false
	}
	return cookie.Value, sess, true
}

func productsHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	writeJSON(w, http.StatusOK, products)
}

func paymentsHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	defer r.Body.Close()

	var request PaymentRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := validatePayment(request); err != nil {
		writeJSONError(w, http.StatusBadRequest, invalidBodyMsg)
		return
	}

	message := fmt.Sprintf("Platnosc przyjeta na kwote %.2f", request.Amount)
	writeJSON(w, http.StatusOK, GenericResponse{Message: message})
}

func cartHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	defer r.Body.Close()

	var request CartRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := validateCart(request); err != nil {
		writeJSONError(w, http.StatusBadRequest, invalidBodyMsg)
		return
	}

	message := fmt.Sprintf("Koszyk przyjety (%d pozycji)", len(request.Items))
	writeJSON(w, http.StatusOK, GenericResponse{Message: message})
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	defer r.Body.Close()

	var request RegisterRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := validateRegister(request); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Niepoprawne dane rejestracji")
		return
	}

	username := strings.TrimSpace(request.Username)
	email := strings.TrimSpace(request.Email)

	dataStore.mu.Lock()
	if _, exists := dataStore.users[username]; exists {
		dataStore.mu.Unlock()
		writeJSONError(w, http.StatusConflict, "Uzytkownik juz istnieje")
		return
	}
	dataStore.users[username] = &User{
		Username: username,
		Email:    email,
		Password: request.Password,
	}
	dataStore.mu.Unlock()

	writeJSON(w, http.StatusOK, GenericResponse{
		Message: "Rejestracja zakonczona sukcesem",
	})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	defer r.Body.Close()

	var request LoginRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	username := strings.TrimSpace(request.Username)

	dataStore.mu.Lock()
	user, ok := dataStore.users[username]
	if !ok || user.Password != request.Password {
		dataStore.mu.Unlock()
		writeJSONError(w, http.StatusUnauthorized, "Niepoprawne dane logowania")
		return
	}
	sessionID := randomToken(32)
	csrfToken := randomToken(32)
	dataStore.sessions[sessionID] = &Session{
		Username:  user.Username,
		CSRFToken: csrfToken,
		Expires:   time.Now().Add(sessionLifetime),
	}
	currentEmail := user.Email
	dataStore.mu.Unlock()

	setSessionCookie(w, sessionID)
	writeJSON(w, http.StatusOK, LoginResponse{
		Message:   "Zalogowano",
		Username:  user.Username,
		Email:     currentEmail,
		CSRFToken: csrfToken,
	})
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	sessionID, _, ok := currentSession(r)
	if ok {
		dataStore.mu.Lock()
		delete(dataStore.sessions, sessionID)
		dataStore.mu.Unlock()
	}
	clearSessionCookie(w)
	writeJSON(w, http.StatusOK, GenericResponse{Message: "Wylogowano"})
}

func accountHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	_, sess, ok := currentSession(r)
	if !ok {
		writeJSONError(w, http.StatusUnauthorized, "Brak sesji")
		return
	}
	dataStore.mu.Lock()
	user := dataStore.users[sess.Username]
	dataStore.mu.Unlock()
	if user == nil {
		writeJSONError(w, http.StatusNotFound, "Brak uzytkownika")
		return
	}
	writeJSON(w, http.StatusOK, AccountResponse{
		Username:  user.Username,
		Email:     user.Email,
		CSRFToken: sess.CSRFToken,
	})
}

func accountEmailVulnerableHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet, http.MethodPost) {
		return
	}
	_, sess, ok := currentSession(r)
	if !ok {
		writeJSONError(w, http.StatusUnauthorized, "Brak sesji")
		return
	}

	var newEmail string
	if r.Method == http.MethodGet {
		newEmail = r.URL.Query().Get("newEmail")
	} else {
		if ct := r.Header.Get("Content-Type"); strings.HasPrefix(ct, "application/json") {
			var req ChangeEmailRequest
			if !decodeJSON(w, r, &req) {
				return
			}
			newEmail = req.Email
		} else {
			if err := r.ParseForm(); err != nil {
				writeJSONError(w, http.StatusBadRequest, invalidBodyMsg)
				return
			}
			newEmail = r.PostFormValue("newEmail")
		}
	}

	newEmail = strings.TrimSpace(newEmail)
	if err := validateEmail(newEmail); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Niepoprawny email")
		return
	}

	dataStore.mu.Lock()
	user := dataStore.users[sess.Username]
	if user == nil {
		dataStore.mu.Unlock()
		writeJSONError(w, http.StatusNotFound, "Brak uzytkownika")
		return
	}
	user.Email = newEmail
	dataStore.mu.Unlock()

	writeJSON(w, http.StatusOK, GenericResponse{Message: "Email zaktualizowany"})
}

func accountEmailSecureHandler(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	defer r.Body.Close()

	_, sess, ok := currentSession(r)
	if !ok {
		writeJSONError(w, http.StatusUnauthorized, "Brak sesji")
		return
	}

	headerToken := r.Header.Get(csrfHeaderName)
	if headerToken == "" || headerToken != sess.CSRFToken {
		writeJSONError(w, http.StatusForbidden, "Brak lub niepoprawny token CSRF")
		return
	}

	var req ChangeEmailRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	newEmail := strings.TrimSpace(req.Email)
	if err := validateEmail(newEmail); err != nil {
		writeJSONError(w, http.StatusBadRequest, "Niepoprawny email")
		return
	}

	dataStore.mu.Lock()
	user := dataStore.users[sess.Username]
	if user == nil {
		dataStore.mu.Unlock()
		writeJSONError(w, http.StatusNotFound, "Brak uzytkownika")
		return
	}
	user.Email = newEmail
	dataStore.mu.Unlock()
	writeJSON(w, http.StatusOK, GenericResponse{Message: "Email zaktualizowany"})
}

func serverAddr() string {
	if port := strings.TrimSpace(os.Getenv("PORT")); port != "" {
		if strings.HasPrefix(port, ":") {
			return port
		}
		return ":" + port
	}
	return defaultServerAddr
}

func main() {
	addr := serverAddr()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/products", withCORS(productsHandler))
	mux.HandleFunc("/api/cart", withCORS(cartHandler))
	mux.HandleFunc("/api/payments", withCORS(paymentsHandler))
	mux.HandleFunc("/api/register", withCORS(registerHandler))
	mux.HandleFunc("/api/login", withCORS(loginHandler))
	mux.HandleFunc("/api/logout", withCORS(logoutHandler))
	mux.HandleFunc("/api/account", withCORS(accountHandler))
	mux.HandleFunc("/api/account/email", withCORS(accountEmailVulnerableHandler))
	mux.HandleFunc("/api/account/email/secure", withCORS(accountEmailSecureHandler))

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	log.Printf("Backend listening on %s", addr)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
