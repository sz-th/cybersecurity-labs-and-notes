import { useState } from "react";
import { useShop } from "../hooks/ShopContext";

const INITIAL_FORM = { fullName: "", email: "", amount: "" };

export default function Payments() {
  const { paymentStatus, sendPayment } = useShop();
  const [formData, setFormData] = useState(INITIAL_FORM);

  function onChange(event) {
    setFormData((prev) => ({
      ...prev,
      [event.target.name]: event.target.value,
    }));
  }

  async function onSubmit(event) {
    event.preventDefault();
    const success = await sendPayment(formData);
    if (success) {
      setFormData(INITIAL_FORM);
    }
  }

  return (
    <section>
      <h2>Platnosci</h2>
      <form onSubmit={onSubmit} data-testid="payments-form">
        <input
          name="fullName"
          placeholder="Imie i nazwisko"
          value={formData.fullName}
          onChange={onChange}
          required
          maxLength={200}
          data-testid="payments-fullname"
        />
        <input
          name="email"
          type="email"
          placeholder="Email"
          value={formData.email}
          onChange={onChange}
          required
          maxLength={320}
          data-testid="payments-email"
        />
        <input
          name="amount"
          type="number"
          step="0.01"
          min="0.01"
          placeholder="Kwota"
          value={formData.amount}
          onChange={onChange}
          required
          data-testid="payments-amount"
        />
        <button type="submit" data-testid="payments-submit">
          Wyslij
        </button>
      </form>
      {paymentStatus ? (
        <p data-testid="payments-status">{paymentStatus}</p>
      ) : null}
    </section>
  );
}
