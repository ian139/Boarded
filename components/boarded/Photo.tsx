'use client';

import { useState } from 'react';
import Image from 'next/image';

export interface PhotoProps {
  src: string;
  alt: string;
  className?: string;
}

export function Photo({ src, alt, className = '' }: PhotoProps) {
  const [hasError, setHasError] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  if (hasError) {
    return (
      <div
        className={`b-photo b-photo-fallback ${className}`}
        role="img"
        aria-label={alt}
      >
        <svg
          className="w-10 h-10 text-stone-400 mb-2"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={1.5}
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
          />
        </svg>
        <span className="text-xs text-stone-200 font-medium">Climbing documentation photo</span>
        <span className="text-xs text-stone-300 max-w-xs">{alt}</span>
      </div>
    );
  }

  return (
    <div className={`b-photo ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={495}
        height={600}
        unoptimized
        loading="eager"
        onLoad={() => setIsLoaded(true)}
        onError={() => setHasError(true)}
        className={`w-full h-auto transition-opacity duration-200 ${isLoaded ? 'opacity-100' : 'opacity-80'}`}
      />
    </div>
  );
}
