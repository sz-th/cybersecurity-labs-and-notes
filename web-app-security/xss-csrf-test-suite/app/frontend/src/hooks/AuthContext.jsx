import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import axios from "axios";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8080";
const API_LOGIN_URL = `${API_BASE_URL}/api/login`;
const API_LOGOUT_URL = `${API_BASE_URL}/api/logout`;
const API_ACCOUNT_URL = `${API_BASE_URL}/api/account`;

const AuthContext = createContext(null);
AuthContext.displayName = "AuthContext";

const STORAGE_KEY = "zadanie8.auth";

function readStored() {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function writeStored(data) {
  if (typeof window === "undefined") return;
  try {
    if (data) {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } else {
      window.localStorage.removeItem(STORAGE_KEY);
    }
  } catch {
    // ignore
  }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => readStored());
  const [error, setError] = useState("");

  useEffect(() => {
    writeStored(user);
  }, [user]);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    function onStorage(event) {
      if (event.key !== STORAGE_KEY) return;
      setUser(readStored());
    }
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  const login = useCallback(async (username, password) => {
    setError("");
    try {
      const response = await axios.post(
        API_LOGIN_URL,
        { username, password },
        { withCredentials: true },
      );
      setUser({
        username: response.data.username,
        email: response.data.email,
        csrfToken: response.data.csrfToken,
      });
      return true;
    } catch (err) {
      const message =
        err?.response?.data?.message || "Logowanie nie powiodlo sie";
      setError(message);
      return false;
    }
  }, []);

  const logout = useCallback(async () => {
    try {
      await axios.post(API_LOGOUT_URL, {}, { withCredentials: true });
    } catch {
      // ignore
    }
    setUser(null);
  }, []);

  const refreshAccount = useCallback(async () => {
    try {
      const response = await axios.get(API_ACCOUNT_URL, {
        withCredentials: true,
      });
      setUser((prev) => ({
        ...(prev || {}),
        username: response.data.username,
        email: response.data.email,
        csrfToken: response.data.csrfToken,
      }));
      return response.data;
    } catch (err) {
      if (err?.response?.status === 401) {
        setUser(null);
      }
      return null;
    }
  }, []);

  const value = useMemo(
    () => ({ user, error, login, logout, refreshAccount }),
    [user, error, login, logout, refreshAccount],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
}
