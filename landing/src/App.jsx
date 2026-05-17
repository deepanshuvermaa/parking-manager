import React, { useRef } from 'react'
import { motion, useScroll, useTransform } from 'motion/react'
import { Facebook, Twitter, Instagram, Linkedin, Download, Smartphone, Monitor, Shield, Printer, Zap, BarChart3, Wifi } from 'lucide-react'

const BG_IMAGE = "https://images.higgs.ai/?default=1&output=webp&url=https%3A%2F%2Fd8j0ntlcm91z4.cloudfront.net%2Fuser_38xzZboKViGWJOttwIXH07lWA1P%2Fhf_20260430_115327_3f256636-9e63-4885-8d0b-09317dc2b0a5.png&w=1280&q=85"
const TRUCK_IMAGE = "https://roof-wish-40038865.figma.site/_components/v2/f31fd17907ce60745d45e83a61d44fd3810d5f25/truck_1.8c4bff83.png"

function App() {
  const containerRef = useRef(null)
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start end", "end start"] })
  const truckY = useTransform(scrollYProgress, [0, 1], [-50, 150])

  return (
    <div className="font-sans">
      {/* Top Spacer */}
      <section className="h-[50vh] md:h-[30vh] bg-[#FDFDFD] flex items-center justify-center">
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1.2 }}
          className="text-gray-300 text-sm font-bold uppercase tracking-[0.5em]"
        >
          View Below
        </motion.p>
      </section>

      {/* Parallax Hero */}
      <section
        ref={containerRef}
        className="h-screen relative overflow-hidden bg-cover bg-center"
        style={{ backgroundImage: `url(${BG_IMAGE})` }}
      >
        {/* Card */}
        <div className="absolute top-0 w-full pt-12 lg:pt-12 md:pt-24 z-30">
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="max-w-7xl mx-auto bg-white/95 backdrop-blur-sm shadow-xl rounded-2xl md:rounded-3xl overflow-hidden mx-4 md:mx-auto"
          >
            {/* Footer Top */}
            <div className="p-6 md:p-10 flex flex-col md:flex-row justify-between gap-8">
              {/* Logo */}
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 md:w-12 md:h-12 bg-orange-500 rounded-lg shadow-inner p-2 flex items-center justify-center">
                  <svg viewBox="0 0 256 256" className="w-full h-full">
                    <path fill="white" d="M 228 0 C 172.772 0 128 44.772 128 100 L 128 0 L 0 0 L 0 28 C 0 83.228 44.772 128 100 128 L 0 128 L 0 256 L 28 256 C 83.228 256 128 211.228 128 156 L 128 256 L 256 256 L 256 228 C 256 172.772 211.228 128 156 128 L 256 128 L 256 0 Z" />
                  </svg>
                </div>
                <span className="text-gray-900 text-2xl md:text-3xl font-bold tracking-tighter">HAUL!</span>
              </div>

              {/* Links */}
              <div className="flex flex-wrap gap-8 md:gap-12">
                <div>
                  <h4 className="uppercase tracking-widest text-sm font-bold text-gray-900 mb-3">Company</h4>
                  {['Founding', 'Platform', 'Testify'].map(l => (
                    <a key={l} href="#" className="block text-gray-500 font-medium hover:text-orange-600 transition mb-1.5">{l}</a>
                  ))}
                </div>
                <div>
                  <h4 className="uppercase tracking-widest text-sm font-bold text-gray-900 mb-3">Mobile</h4>
                  {['Get Apple App', 'Get Google App'].map(l => (
                    <a key={l} href="#" className="block text-gray-500 font-medium hover:text-orange-600 transition mb-1.5">{l}</a>
                  ))}
                </div>
                <div>
                  <h4 className="uppercase tracking-widest text-sm font-bold text-gray-900 mb-3">Contracts</h4>
                  {['Private Data', 'User Consent'].map(l => (
                    <a key={l} href="#" className="block text-gray-500 font-medium hover:text-orange-600 transition mb-1.5">{l}</a>
                  ))}
                </div>
              </div>
            </div>

            {/* Footer Bottom */}
            <div className="border-t border-gray-100 bg-white px-6 md:px-10 py-4 flex items-center justify-between">
              <p className="text-sm text-gray-500 font-medium">© 2026 HAUL! All Rights Reserved</p>
              <div className="flex gap-2">
                {[Facebook, Twitter, Instagram, Linkedin].map((Icon, i) => (
                  <a key={i} href="#" className="w-10 h-10 rounded-full border border-gray-100 flex items-center justify-center text-gray-400 hover:bg-orange-500 hover:text-white hover:border-orange-500 transition-all duration-300">
                    <Icon className="w-5 h-5" />
                  </a>
                ))}
              </div>
            </div>
          </motion.div>
        </div>

        {/* Truck Parallax */}
        <motion.div
          style={{ y: truckY }}
          className="absolute inset-x-0 bottom-0 h-full pointer-events-none z-20"
        >
          <img
            src={TRUCK_IMAGE}
            alt=""
            className="w-full h-full object-contain object-bottom origin-bottom scale-[1.5] sm:scale-110 md:scale-[2.0] lg:scale-105"
          />
        </motion.div>
      </section>

      {/* ===== PARKEASE LANDING CONTENT ===== */}

      {/* Hero Section */}
      <section className="py-20 md:py-32 bg-gradient-to-b from-green-50 to-white">
        <div className="max-w-6xl mx-auto px-6 text-center">
          <motion.div initial={{ opacity: 0, y: 30 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6 }}>
            <div className="inline-flex items-center gap-2 bg-green-100 text-green-800 px-4 py-1.5 rounded-full text-sm font-medium mb-6">
              <Zap className="w-4 h-4" /> Now Available for Android & Windows
            </div>
            <h1 className="text-4xl md:text-6xl font-bold text-gray-900 mb-6 leading-tight">
              Smart Parking<br />Management System
            </h1>
            <p className="text-lg md:text-xl text-gray-600 max-w-2xl mx-auto mb-10">
              Complete parking solution with thermal printing, offline-first architecture, and real-time analytics. Built for Indian parking businesses.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a href="/downloads/ParkEase-v5.apk" className="inline-flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white px-8 py-3.5 rounded-xl font-semibold transition shadow-lg shadow-green-200">
                <Smartphone className="w-5 h-5" /> Download APK
              </a>
              <a href="/downloads/ParkEase-Windows.zip" className="inline-flex items-center gap-2 bg-gray-900 hover:bg-gray-800 text-white px-8 py-3.5 rounded-xl font-semibold transition shadow-lg shadow-gray-200">
                <Monitor className="w-5 h-5" /> Windows Desktop
              </a>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-20 bg-white">
        <div className="max-w-6xl mx-auto px-6">
          <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="text-3xl md:text-4xl font-bold text-center text-gray-900 mb-4">
            Everything You Need
          </motion.h2>
          <p className="text-center text-gray-500 mb-14 max-w-xl mx-auto">One app to manage your entire parking business — from entry to exit, billing to reports.</p>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: Printer, title: "Auto Thermal Printing", desc: "Bluetooth & USB printer support. 2-inch and 3-inch receipts auto-print on vehicle entry." },
              { icon: Wifi, title: "Offline-First", desc: "Works without internet. All data saved locally, syncs when connection is available." },
              { icon: BarChart3, title: "Real-Time Analytics", desc: "Daily, weekly, monthly reports. Revenue tracking, vehicle type breakdown, peak hours." },
              { icon: Shield, title: "Secure & Private", desc: "JWT authentication, encrypted data, multi-device management with auto-logout." },
              { icon: Smartphone, title: "Android + Windows", desc: "Same app runs on your phone and desktop. Seamless experience across devices." },
              { icon: Zap, title: "Fast Entry/Exit", desc: "3-tap vehicle entry. Auto-calculated fees. QR code on receipts for quick exit." },
            ].map(({ icon: Icon, title, desc }, i) => (
              <motion.div
                key={title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1 }}
                className="p-6 rounded-2xl border border-gray-100 hover:border-green-200 hover:shadow-lg transition-all duration-300"
              >
                <div className="w-12 h-12 bg-green-50 rounded-xl flex items-center justify-center mb-4">
                  <Icon className="w-6 h-6 text-green-600" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 bg-green-600">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">Start Managing Your Parking Today</h2>
          <p className="text-green-100 text-lg mb-8">Free to use. No credit card required. Works offline from day one.</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="/downloads/ParkEase-v5.apk" className="inline-flex items-center gap-2 bg-white text-green-700 px-8 py-3.5 rounded-xl font-semibold hover:bg-green-50 transition">
              <Download className="w-5 h-5" /> Download Free
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-10 bg-gray-900 text-center">
        <p className="text-gray-400 text-sm">© 2026 Go2-Parking by Deepanshu Verma. All rights reserved.</p>
      </footer>
    </div>
  )
}

export default App
