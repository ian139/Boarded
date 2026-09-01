import type { Metadata, Viewport } from "next";
import { Bodoni_Moda, Manrope } from "next/font/google";
import "./globals.css";
import { BottomNav } from "@/components/shared/BottomNav";
import { Toaster } from "@/components/ui/sonner";
import { Providers } from "@/components/providers/Providers";
import { Analytics } from "@vercel/analytics/next";
import Script from "next/script";


const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
  display: "swap",
});

const bodoni = Bodoni_Moda({
  variable: "--font-bodoni",
  subsets: ["latin"],
  style: ["italic"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Boarded board studio",
  description: "Create, document, and share routes in the Boarded board studio.",
  manifest: "/manifest.json",
  icons: {
    icon: "/icon.png",
    apple: "/apple-touch-icon.png",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0A0B10",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={`${manrope.variable} ${bodoni.variable} antialiased font-sans`}>
        <Providers>
          {children}
          <BottomNav />
          <Toaster />
          <Analytics />
          <Script id="sw-register" strategy="afterInteractive">{`
            if ('serviceWorker' in navigator) {
              const version = '${process.env.NEXT_PUBLIC_APP_VERSION || 'dev'}';
              window.addEventListener('load', () => {
                navigator.serviceWorker.register('/sw.js?v=' + encodeURIComponent(version)).catch(() => {});
              });
            }
          `}</Script>
        </Providers>
      </body>
    </html>
  );
}
