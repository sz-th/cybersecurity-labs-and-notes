import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/AuthContext";

const INITIAL_FORM = { username: "", password: "" };

export default function Login() {
  const { user, login, error } = useAuth();
  const [form, setForm] = useState(INITIAL_FORM);
  const [submitting, setSubmitting] = useState(false);
  const [localError, setLocalError] = useState("");
  const navigate = useNavigate();

  function onChange(event) {
    setForm((prev) => ({
      ...prev,
      [event.target.name]: event.target.value,
    }));
  }

  async function onSubmit(event) {
    event.preventDefault();
    setLocalError("");
    if (!form.username.trim() || !form.password) {
      setLocalError("Uzupelnij login i haslo");
      return;
    }
    setSubmitting(true);
    const ok = await login(form.username.trim(), form.password);
    setSubmitting(false);
    if (ok) {
      setForm(INITIAL_FORM);
      navigate("/account");
    }
  }

  if (user) {
    return (
      <section>
        <h2>Logowanie</h2>
        <p data-testid="login-already">
          Jestes zalogowany jako {user.username}
        </p>
      </section>
    );
  }

  return (
    <section>
      <h2>Logowanie</h2>
      <form onSubmit={onSubmit} data-testid="login-form" noValidate>
        <label>
          Nazwa uzytkownika
          <input
            name="username"
            value={form.username}
            onChange={onChange}
            maxLength={64}
            autoComplete="username"
            data-testid="login-username"
          />
        </label>
        <label>
          Haslo
          <input
            name="password"
            type="password"
            value={form.password}
            onChange={onChange}
            maxLength={128}
            autoComplete="current-password"
            data-testid="login-password"
          />
        </label>
        <button
          type="submit"
          disabled={submitting}
          data-testid="login-submit"
        >
          {submitting ? "Logowanie..." : "Zaloguj"}
        </button>
      </form>
      {localError ? (
        <p className="field-error" data-testid="login-local-error">
          {localError}
        </p>
      ) : null}
      {error ? (
        <p className="error" data-testid="login-error">
          {error}
        </p>
      ) : null}
    </section>
  );
}
