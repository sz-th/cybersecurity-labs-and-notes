import { useState } from "react";

export default function Comments() {
  const [comments, setComments] = useState([]);
  const [draft, setDraft] = useState("");

  function onSubmit(event) {
    event.preventDefault();
    const value = draft.trim();
    if (!value) return;
    setComments((prev) => [
      ...prev,
      { id: `${Date.now()}-${prev.length}`, text: value },
    ]);
    setDraft("");
  }

  return (
    <section>
      <h2>Komentarze</h2>
      <form onSubmit={onSubmit} data-testid="comments-form">
        <textarea
          rows={3}
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          maxLength={500}
          placeholder="Napisz komentarz"
          data-testid="comment-input"
        />
        <button type="submit" data-testid="comment-submit">
          Dodaj komentarz
        </button>
      </form>
      <div data-testid="comments-list">
        {comments.length === 0 ? (
          <p data-testid="comments-empty">Brak komentarzy</p>
        ) : (
          comments.map((comment, index) => (
            <p
              key={comment.id}
              className="user-comment"
              data-testid={`comment-${index}`}
            >
              {comment.text}
            </p>
          ))
        )}
      </div>
    </section>
  );
}
