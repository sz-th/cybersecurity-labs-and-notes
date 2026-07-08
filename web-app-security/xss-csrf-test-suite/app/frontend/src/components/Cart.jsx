import { useShop } from "../hooks/ShopContext";

export default function Cart() {
  const { cartItems, cartStatus, sendCart, removeFromCart, clearCart } =
    useShop();
  const total = cartItems.reduce((sum, item) => sum + item.price, 0);

  async function onSubmit() {
    await sendCart();
  }

  return (
    <section>
      <h2>Koszyk</h2>
      <p data-testid="cart-count">Liczba pozycji: {cartItems.length}</p>
      {cartItems.length === 0 ? (
        <p data-testid="cart-empty">Koszyk jest pusty</p>
      ) : (
        <ul data-testid="cart-items">
          {cartItems.map((item) => (
            <li key={item.cartId} data-testid={`cart-item-${item.cartId}`}>
              <span data-testid={`cart-item-name-${item.cartId}`}>
                {item.name}
              </span>
              {" - "}
              <span data-testid={`cart-item-price-${item.cartId}`}>
                {item.price.toFixed(2)} PLN
              </span>
              <button
                type="button"
                onClick={() => removeFromCart(item.cartId)}
                data-testid={`remove-${item.cartId}`}
              >
                Usun
              </button>
            </li>
          ))}
        </ul>
      )}
      <p data-testid="cart-total">Razem: {total.toFixed(2)} PLN</p>
      <button
        type="button"
        disabled={cartItems.length === 0}
        onClick={onSubmit}
        data-testid="cart-submit"
      >
        Wyslij koszyk
      </button>
      <button
        type="button"
        disabled={cartItems.length === 0}
        onClick={clearCart}
        data-testid="cart-clear"
      >
        Wyczysc
      </button>
      {cartStatus ? <p data-testid="cart-status">{cartStatus}</p> : null}
    </section>
  );
}
