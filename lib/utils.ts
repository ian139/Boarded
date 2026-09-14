import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** Keep authentication return destinations inside the standalone board routes. */
export function boardRedirect(value: string | null, fallback: string): string {
  if (
    !value ||
    /[\u0000-\u0020\\]/.test(value) ||
    !/^\/(?:(?:editor|profile|settings)\/?|share\/[A-Za-z0-9_-]+\/?)?(?:[?#].*)?$/.test(value)
  ) {
    return fallback
  }
  return value
}
