import { BrowserRouter, Link, Route, Routes } from "react-router-dom";
import Products from "./components/Products";
import Cart from "./components/Cart";
import Payments from "./components/Payments";
import Register from "./components/Register";
import Comments from "./components/Comments";
import Login from "./components/Login";
import Account from "./components/Account";
import { ShopProvider, useShop } from "./hooks/ShopContext";
import { AuthProvider, useAuth } from "./hooks/AuthContext";

function AppContent() {
  const { status } = useShop();
  const { user } = useAuth();
  return (
    <div className="container">
      <h1>Zadanie 8 - Sklep</h1>
      <nav className="nav">
        <Link to="/" data-testid="nav-products">
          Produkty
        </Link>
        <Link to="/cart" data-testid="nav-cart">
          Koszyk
        </Link>
        <Link to="/payments" data-testid="nav-payments">
          Platnosci
        </Link>
        <Link to="/register" data-testid="nav-register">
          Rejestracja
        </Link>
        <Link to="/comments" data-testid="nav-comments">
          Komentarze
        </Link>
        {user ? (
          <Link to="/account" data-testid="nav-account">
            Konto ({user.username})
          </Link>
        ) : (
          <Link to="/login" data-testid="nav-login">
            Logowanie
          </Link>
        )}
      </nav>
      <Routes>
        <Route path="/" element={<Products />} />
        <Route path="/cart" element={<Cart />} />
        <Route path="/payments" element={<Payments />} />
        <Route path="/register" element={<Register />} />
        <Route path="/comments" element={<Comments />} />
        <Route path="/login" element={<Login />} />
        <Route path="/account" element={<Account />} />
      </Routes>
      {status ? (
        <p className="status" data-testid="global-status">
          {status}
        </p>
      ) : null}
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ShopProvider>
          <AppContent />
        </ShopProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
