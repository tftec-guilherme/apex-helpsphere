import { type CSSProperties } from "react";

interface HelpSphereLogoProps {
    size?: number;
    className?: string;
    style?: CSSProperties;
    title?: string;
}

export const HelpSphereLogo = ({ size = 32, className, style, title = "HelpSphere" }: HelpSphereLogoProps) => {
    return (
        <svg
            width={size}
            height={size}
            viewBox="0 0 32 32"
            xmlns="http://www.w3.org/2000/svg"
            role="img"
            aria-label={title}
            className={className}
            style={style}
        >
            <title>{title}</title>
            <circle cx="16" cy="16" r="14" fill="none" stroke="currentColor" strokeWidth="2" />
            <path d="M16 2 C 8 2 8 30 16 30" fill="none" stroke="currentColor" strokeWidth="1.4" opacity="0.55" />
            <path d="M16 2 C 24 2 24 30 16 30" fill="none" stroke="currentColor" strokeWidth="1.4" opacity="0.55" />
            <ellipse cx="16" cy="16" rx="14" ry="6" fill="none" stroke="currentColor" strokeWidth="1.4" opacity="0.55" />
            <circle cx="16" cy="16" r="3" fill="currentColor" />
        </svg>
    );
};
