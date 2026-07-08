import { useShop } from "../hooks/ShopContext";

function formatPrice(value) {
  return `${value.toFixed(2)} PLN`;
}

export default function Products() {
  const { products, productsError, addToCart } = useShop();

  return (
    <section>
      <h2>Produkty</h2>
      {productsError ? (
        <p className="error" data-testid="products-error">
          {productsError}
        </p>
      ) : null}
      <ul data-testid="products-list">
        {products.map((product) => (
          <li key={product.id} data-testid={`product-${product.id}`}>
            <span data-testid={`product-name-${product.id}`}>{product.name}</span>
            {" - "}
            <span data-testid={`product-price-${product.id}`}>
              {formatPrice(product.price)}
            </span>
            <button
              type="button"
              onClick={() => addToCart(product)}
              data-testid={`add-to-cart-${product.id}`}
            >
              Dodaj do koszyka
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
