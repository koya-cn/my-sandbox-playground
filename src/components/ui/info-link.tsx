"use client";

const BASE_URL = "https://code.claude.com/docs/en";

interface InfoLinkProps {
  href: string;
  label?: string;
}

export function InfoLink({ href, label }: InfoLinkProps) {
  const fullUrl = href.startsWith("http") ? href : `${BASE_URL}/${href}`;
  return (
    <a
      href={fullUrl}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 text-muted-foreground hover:text-foreground transition-colors"
      title={label ?? "公式ドキュメントを見る"}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        fill="currentColor"
        className="size-4 shrink-0"
      >
        <path
          fillRule="evenodd"
          d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
          clipRule="evenodd"
        />
      </svg>
      {label && <span className="text-xs underline">{label}</span>}
    </a>
  );
}
