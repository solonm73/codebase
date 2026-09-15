import type { Metadata } from "next";
import localFont from "next/font/local";
import { Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";

const vazir = localFont({
  src: [
    {
      path: "../../public/fonts/vazir-font-v16.1.0/Vazir-Thin.woff2",
      weight: "100",
      style: "normal",
    },
    {
      path: "../../public/fonts/vazir-font-v16.1.0/Vazir-Light.woff2",
      weight: "300",
      style: "normal",
    },
    {
      path: "../../public/fonts/vazir-font-v16.1.0/Vazir.woff2",
      weight: "400",
      style: "normal",
    },
    {
      path: "../../public/fonts/vazir-font-v16.1.0/Vazir-Medium.woff2",
      weight: "500",
      style: "normal",
    },
    {
      path: "../../public/fonts/vazir-font-v16.1.0/Vazir-Bold.woff2",
      weight: "700",
      style: "normal",
    },
  ],
  variable: "--font-vazir",
  display: "swap",
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "part Code Scaffold - AI-Powered Development",
  description: "Modern Next.js scaffold optimized for AI-powered development with part. Built with TypeScript, Tailwind CSS, and shadcn/ui.",
  keywords: ["part", "Next.js", "TypeScript", "Tailwind CSS", "shadcn/ui", "AI development", "React"],
  authors: [{ name: "part Team" }],
  icons: {
    icon: "https://www.partsoftware.com/images/logo/partsoftware.png",
  },
  openGraph: {
    title: "part Code Scaffold",
    description: "AI-powered development with modern React stack",
    url: "https://chat.part",
    siteName: "part",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "part Code Scaffold",
    description: "AI-powered development with modern React stack",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${vazir.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
      >
        {children}
        <Toaster />
      </body>
    </html>
  );
}
