import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import axios from "axios";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL || "http://localhost:8080";
const API_PRODUCTS_URL = `${API_BASE_URL}/api/products`;
const API_CART_URL = `${API_BASE_URL}/api/cart`;
const API_PAYMENTS_URL = `${API_BASE_URL}/api/payments`;
const CART_STORAGE_KEY = "zadanie8.cart";
const CART_SYNC_EVENT = "zadanie8.cart.sync";

const PRODUCTS_ERROR_MSG = "Nie udalo sie pobrac produktow";
const CART_ERROR_MSG = "Nie udalo sie wyslac koszyka";
const PAYMENT_ERROR_MSG = "Nie udalo sie wyslac platnosci";

const ShopContext = createContext(null);
ShopContext.displayName = "ShopContext";

function generateCartId() {
  if (
    typeof crypto !== "undefined" &&
    typeof crypto.randomUUID === "function"
  ) {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function readCartFromStorage() {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(CART_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed;
  } catch {
    return [];
  }
}

function writeCartToStorage(items) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(items));
  } catch {
    // ignore quota errors
  }
}

export function ShopProvider({ children }) {
  const [products, setProducts] = useState([]);
  const [productsError, setProductsError] = useState("");
  const [cartItems, setCartItems] = useState(() => readCartFromStorage());
  const [paymentStatus, setPaymentStatus] = useState("");
  const [cartStatus, setCartStatus] = useState("");
  const [status, setStatus] = useState("");
  const skipPersistRef = useRef(false);

  useEffect(() => {
    let cancelled = false;

    async function loadProducts() {
      try {
        const response = await axios.get(API_PRODUCTS_URL);
        if (cancelled) return;
        setProducts(response.data);
        setProductsError("");
      } catch (error) {
        if (cancelled) return;
        console.error("loadProducts failed", error);
        setProductsError(PRODUCTS_ERROR_MSG);
      }
    }

    loadProducts();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    function onStorage(event) {
      if (event.key !== CART_STORAGE_KEY) return;
      skipPersistRef.current = true;
      setCartItems(readCartFromStorage());
    }
    function onSync() {
      skipPersistRef.current = true;
      setCartItems(readCartFromStorage());
    }
    window.addEventListener("storage", onStorage);
    window.addEventListener(CART_SYNC_EVENT, onSync);
    return () => {
      window.removeEventListener("storage", onStorage);
      window.removeEventListener(CART_SYNC_EVENT, onSync);
    };
  }, []);

  useEffect(() => {
    if (skipPersistRef.current) {
      skipPersistRef.current = false;
      return;
    }
    writeCartToStorage(cartItems);
    if (typeof window !== "undefined") {
      window.dispatchEvent(new Event(CART_SYNC_EVENT));
    }
  }, [cartItems]);

  const addToCart = useCallback((product) => {
    setCartItems((prev) => [...prev, { ...product, cartId: generateCartId() }]);
  }, []);

  const removeFromCart = useCallback((cartId) => {
    setCartItems((prev) => prev.filter((item) => item.cartId !== cartId));
  }, []);

  const clearCart = useCallback(() => {
    setCartItems([]);
  }, []);

  const sendCart = useCallback(async () => {
    setCartStatus("");
    try {
      const items = cartItems.map(({ cartId, ...rest }) => rest);
      const response = await axios.post(API_CART_URL, { items });
      setCartStatus(response.data.message);
      setStatus(response.data.message);
      return true;
    } catch (error) {
      console.error("sendCart failed", error);
      setCartStatus(CART_ERROR_MSG);
      setStatus(CART_ERROR_MSG);
      return false;
    }
  }, [cartItems]);

  const sendPayment = useCallback(async (formData) => {
    setPaymentStatus("");
    try {
      const response = await axios.post(API_PAYMENTS_URL, {
        ...formData,
        amount: Number(formData.amount),
      });
      setPaymentStatus(response.data.message);
      setStatus(response.data.message);
      return true;
    } catch (error) {
      console.error("sendPayment failed", error);
      setPaymentStatus(PAYMENT_ERROR_MSG);
      setStatus(PAYMENT_ERROR_MSG);
      return false;
    }
  }, []);

  const value = useMemo(
    () => ({
      products,
      productsError,
      cartItems,
      cartStatus,
      paymentStatus,
      status,
      addToCart,
      removeFromCart,
      clearCart,
      sendCart,
      sendPayment,
    }),
    [
      products,
      productsError,
      cartItems,
      cartStatus,
      paymentStatus,
      status,
      addToCart,
      removeFromCart,
      clearCart,
      sendCart,
      sendPayment,
    ],
  );

  return <ShopContext.Provider value={value}>{children}</ShopContext.Provider>;
}

export function useShop() {
  const context = useContext(ShopContext);
  if (!context) {
    throw new Error("useShop must be used within ShopProvider");
  }
  return context;
}
