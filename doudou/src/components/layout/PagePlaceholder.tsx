interface PagePlaceholderProps {
  title: string;
  description: string;
}

export function PagePlaceholder({ title, description }: PagePlaceholderProps) {
  return (
    <section className="page-card">
      <h2 style={{ marginTop: 0 }}>{title}</h2>
      <p style={{ marginBottom: 0 }}>{description}</p>
    </section>
  );
}
