interface Props {
    size?: number;
    inverted?: boolean;
}

/**
 * Logomark HelpSphere — esfera concêntrica representando suporte multi-camada.
 * Navy fundo + accent gold no anel + dot accent no centro = "núcleo de operação".
 */
export const BrandMark = ({ size = 32, inverted = false }: Props) => {
    const bg = inverted ? "#fafaf7" : "#0c1834";
    const ring = "#a87b3f";
    const core = inverted ? "#0c1834" : "#fafaf7";
    return (
        <svg width={size} height={size} viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <rect width="32" height="32" rx="7" fill={bg} />
            <circle cx="16" cy="16" r="9" stroke={ring} strokeWidth="1.5" fill="none" opacity="0.85" />
            <circle cx="16" cy="16" r="5" stroke={ring} strokeWidth="1" fill="none" opacity="0.5" />
            <circle cx="16" cy="16" r="1.75" fill={core} />
        </svg>
    );
};
