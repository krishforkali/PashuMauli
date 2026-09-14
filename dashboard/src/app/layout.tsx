import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PashuMauli Dashboard",
  description: "Live Command Center for Livestock Health",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased font-sans bg-gray-50 text-slate-900">
        {children}
      </body>
    </html>
  );
}
