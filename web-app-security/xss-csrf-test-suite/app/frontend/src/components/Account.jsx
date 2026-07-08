import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import axios from "axios";
import { useAuth } from "../hooks/AuthContext";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8080";
const API_EMAIL_SECURE_URL = `${API_BASE_URL}/api/account/email/secure`;

export default function Account() {
  const { user, refreshAccount, logout } = useAuth();
  const [newEmail, setNewEmail] = useState("");
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      await refreshAccount();
      setLoading(false);
    })();
  }, [refreshAccount]);

  async function onSubmit(event) {
    event.preventDefault();
    setStatus("");
    setError("");
    if (!user) {
      setError("Brak sesji - zaloguj sie ponownie");
      return;
    }
    try {
      await axios.post(
        API_EMAIL_SECURE_URL,
        { email: newEmail.trim() },
        {
          withCredentials: true,
          headers: { "X-CSRF-Token": user.csrfToken || "" },
        },
      );
      setStatus("Email zaktualizowany");
      setNewEmail("");
      await refreshAccount();
    } catch (err) {
      const message =
        err?.response?.data?.message || "Nie udalo sie zmienic adresu email";
      setError(message);
    }
  }

  if (loading) {
    return (
      <section>
        <h2>Konto</h2>
        <p data-testid="account-loading">Ladowanie...</p>
      </section>
    );
  }

  if (!user) {
    return (
      <section>
        <h2>Konto</h2>
        <p data-testid="account-not-logged-in">
          Nie jestes zalogowany. <Link to="/login">Zaloguj sie</Link>.
        </p>
      </section>
    );
  }

  return (
    <section>
      <h2>Konto</h2>
      <p>
        Uzytkownik:{" "}
        <span data-testid="account-username">{user.username}</span>
      </p>
      <p>
        Aktualny email:{" "}
        <span data-testid="account-email">{user.email}</span>
      </p>
      <button
        type="button"
        onClick={refreshAccount}
        data-testid="account-refresh"
      >
        Odswiez
      </button>
      <button
        type="button"
        onClick={logout}
        data-testid="account-logout"
      >
        Wyloguj
      </button>

      <h3>Zmiana adresu email (z tokenem CSRF)</h3>
      <form onSubmit={onSubmit} data-testid="email-change-form" noValidate>
        <input
          type="email"
          value={newEmail}
          onChange={(event) => setNewEmail(event.target.value)}
          placeholder="Nowy email"
          maxLength={320}
          data-testid="email-change-input"
        />
        <button type="submit" data-testid="email-change-submit">
          Zapisz
        </button>
      </form>
      {status ? (
        <p className="status" data-testid="email-change-status">
          {status}
        </p>
      ) : null}
      {error ? (
        <p className="error" data-testid="email-change-error">
          {error}
        </p>
      ) : null}
    </section>
  );
}
