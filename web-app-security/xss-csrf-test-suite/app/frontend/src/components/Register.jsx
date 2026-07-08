import { useState } from "react";
import axios from "axios";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8080";
const API_REGISTER_URL = `${API_BASE_URL}/api/register`;

const INITIAL_FORM = {
  username: "",
  email: "",
  password: "",
  passwordConfirm: "",
  accepted: false,
};

const EMAIL_PATTERN = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

function validate(form) {
  const errors = {};
  if (!form.username.trim()) {
    errors.username = "Nazwa uzytkownika jest wymagana";
  } else if (form.username.trim().length < 3) {
    errors.username = "Nazwa uzytkownika musi miec minimum 3 znaki";
  }
  if (!form.email.trim()) {
    errors.email = "Email jest wymagany";
  } else if (!EMAIL_PATTERN.test(form.email.trim())) {
    errors.email = "Niepoprawny format adresu email";
  }
  if (!form.password) {
    errors.password = "Haslo jest wymagane";
  } else if (form.password.length < 8) {
    errors.password = "Haslo musi miec minimum 8 znakow";
  }
  if (!form.passwordConfirm) {
    errors.passwordConfirm = "Potwierdzenie hasla jest wymagane";
  } else if (form.password !== form.passwordConfirm) {
    errors.passwordConfirm = "Hasla nie sa takie same";
  }
  if (!form.accepted) {
    errors.accepted = "Akceptacja regulaminu jest wymagana";
  }
  return errors;
}

export default function Register() {
  const [form, setForm] = useState(INITIAL_FORM);
  const [errors, setErrors] = useState({});
  const [submitStatus, setSubmitStatus] = useState("");
  const [serverError, setServerError] = useState("");

  function onChange(event) {
    const { name, type, checked, value } = event.target;
    setForm((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  }

  async function onSubmit(event) {
    event.preventDefault();
    setSubmitStatus("");
    setServerError("");
    const nextErrors = validate(form);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) {
      return;
    }
    try {
      const response = await axios.post(API_REGISTER_URL, {
        username: form.username.trim(),
        email: form.email.trim(),
        password: form.password,
      });
      setSubmitStatus(response.data.message);
      setForm(INITIAL_FORM);
    } catch (error) {
      const message =
        error?.response?.data?.message ||
        "Rejestracja nie powiodla sie";
      setServerError(message);
    }
  }

  return (
    <section>
      <h2>Rejestracja</h2>
      <form onSubmit={onSubmit} noValidate data-testid="register-form">
        <label>
          Nazwa uzytkownika
          <input
            name="username"
            value={form.username}
            onChange={onChange}
            maxLength={64}
            data-testid="register-username"
          />
        </label>
        {errors.username ? (
          <span className="field-error" data-testid="error-username">
            {errors.username}
          </span>
        ) : null}

        <label>
          Email
          <input
            name="email"
            value={form.email}
            onChange={onChange}
            maxLength={320}
            data-testid="register-email"
          />
        </label>
        {errors.email ? (
          <span className="field-error" data-testid="error-email">
            {errors.email}
          </span>
        ) : null}

        <label>
          Haslo
          <input
            name="password"
            type="password"
            value={form.password}
            onChange={onChange}
            maxLength={128}
            data-testid="register-password"
          />
        </label>
        {errors.password ? (
          <span className="field-error" data-testid="error-password">
            {errors.password}
          </span>
        ) : null}

        <label>
          Potwierdzenie hasla
          <input
            name="passwordConfirm"
            type="password"
            value={form.passwordConfirm}
            onChange={onChange}
            maxLength={128}
            data-testid="register-password-confirm"
          />
        </label>
        {errors.passwordConfirm ? (
          <span className="field-error" data-testid="error-password-confirm">
            {errors.passwordConfirm}
          </span>
        ) : null}

        <label>
          <input
            type="checkbox"
            name="accepted"
            checked={form.accepted}
            onChange={onChange}
            data-testid="register-accepted"
          />
          Akceptuje regulamin
        </label>
        {errors.accepted ? (
          <span className="field-error" data-testid="error-accepted">
            {errors.accepted}
          </span>
        ) : null}

        <button type="submit" data-testid="register-submit">
          Zarejestruj
        </button>
      </form>
      {submitStatus ? (
        <p className="status" data-testid="register-status">
          {submitStatus}
        </p>
      ) : null}
      {serverError ? (
        <p className="error" data-testid="register-server-error">
          {serverError}
        </p>
      ) : null}
    </section>
  );
}
