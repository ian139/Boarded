import type { Metadata, Viewport } from "next";
import { Manrope } from "next/font/google";
import "./globals.css";
import "./board-original.css";
import { BottomNav } from "@/components/original-board/shared/BottomNav";
import { BoardThemeProvider } from "@/components/original-board/theme";
import { Toaster } from "@/components/ui/sonner";
import { AuthProvider } from "@/components/providers/AuthProvider";
import { Analytics } from "@vercel/analytics/next";
import Script from "next/script";


const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
  display: "swap",
});


export const metadata: Metadata = {
  title: "Boarded - Digital Route Setter",
  description: "Document and share your climbing routes",
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
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f7f3ea" },
    { media: "(prefers-color-scheme: dark)", color: "#1b1a17" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={`${manrope.variable} antialiased font-sans`}>
        <AuthProvider>
          <BoardThemeProvider>
            {children}
            <BottomNav />
            <Toaster />
          </BoardThemeProvider>
          <Analytics />
          <Script id="sw-register" strategy="afterInteractive">{`
            if ('serviceWorker' in navigator) {
              const version = '${process.env.NEXT_PUBLIC_APP_VERSION || 'dev'}';
              const register = () => {
                navigator.serviceWorker.register('/sw.js?v=' + encodeURIComponent(version)).catch(() => {});
              };
              if (document.readyState === 'complete') register();
              else window.addEventListener('load', register, { once: true });
            }
          `}</Script>
        </AuthProvider>
      </body>
    </html>
  );
}
