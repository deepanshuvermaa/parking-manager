import React, { useRef } from 'react'
import { motion, useScroll, useTransform } from 'motion/react'
import { Download, Smartphone, Monitor, Shield, Printer, Zap, BarChart3, Wifi, Car, Clock, CreditCard, QrCode, Users, CloudOff } from 'lucide-react'

const BG_IMAGE = "https://images.higgs.ai/?default=1&output=webp&url=https%3A%2F%2Fd8j0ntlcm91z4.cloudfront.net%2Fuser_38xzZboKViGWJOttwIXH07lWA1P%2Fhf_20260430_115327_3f256636-9e63-4885-8d0b-09317dc2b0a5.png&w=1280&q=85"
const TRUCK_IMAGE = "https://roof-wish-40038865.figma.site/_components/v2/f31fd17907ce60745d45e83a61d44fd3810d5f25/truck_1.8c4bff83.png"

function App() {
  const containerRef = useRef(null)
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start end", "end start"] })
  const truckY = useTransform(scrollYProgress, [0, 1], [-50, 150])

  return (
    <div className="font-sans antialiased">
      {/* Hero with Parallax */}
      <section
        ref={containerRef}
        className="min-h-screen relative overflow-hidden bg-cover bg-center flex items-center"
        style={{ backgroundImage: `url(${BG_IMAGE})` }}
      >
        <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-black/40 to-black/70 z-10" />

        {/* Hero Content */}
        <div className="relative z-20 w-full px-6 py-20">
          <div className="max-w-5xl mx-auto text-center">
            <motion.div initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8 }}>
              {/* Logo */}
              <div className="flex items-center justify-center gap-3 mb-10">
                <img src="/logo.png" alt="Go2" className="w-12 h-12 rounded-xl shadow-lg" />
                <span className="text-white text-3xl font-bold tracking-tight">Go2-Parking</span>
              </div>

              <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight">
                Your Parking Lot,<br/>
                <span className="text-green-400">Fully Managed.</span>
              </h1>
              <p className="text-lg md:text-xl text-white/80 max-w-2xl mx-auto mb-10">
                Vehicle entry → Auto receipt print → Easy exit with fee calculation. Works offline. Built for Indian parking businesses.
              </p>

              {/* Download Buttons */}
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <a href="/downloads/ParkEase-v5.apk" className="inline-flex items-center gap-2 bg-green-500 hover:bg-green-600 text-white px-8 py-4 rounded-xl font-semibold transition shadow-lg shadow-green-500/30 text-lg">
                  <Smartphone className="w-5 h-5" /> Download Android
                </a>
                <a href="/downloads/ParkEase-Windows.zip" className="inline-flex items-center gap-2 bg-white/10 hover:bg-white/20 backdrop-blur text-white border border-white/30 px-8 py-4 rounded-xl font-semibold transition text-lg">
                  <Monitor className="w-5 h-5" /> Windows Desktop
                </a>
              </div>
            </motion.div>
          </div>
        </div>

        {/* Truck Parallax Layer */}
        <motion.div style={{ y: truckY }} className="absolute inset-x-0 bottom-0 h-full pointer-events-none z-[5]">
          <img src={TRUCK_IMAGE} alt="" className="w-full h-full object-contain object-bottom origin-bottom scale-[1.5] sm:scale-110 md:scale-[2.0] lg:scale-105" />
        </motion.div>
      </section>

      {/* How It Works */}
      <section className="py-20 bg-white">
        <div className="max-w-6xl mx-auto px-6">
          <motion.div initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="text-center mb-14">
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mb-3">3 Taps. That's It.</h2>
            <p className="text-gray-500 max-w-lg mx-auto">Vehicle enters → Select type → Enter plate → Receipt prints automatically.</p>
          </motion.div>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              { step: "1", icon: Car, title: "Vehicle Arrives", desc: "Select from 13 Indian vehicle types — Bike, Car, SUV, Auto, Bus, Truck & more" },
              { step: "2", icon: QrCode, title: "Auto Receipt Print", desc: "Thermal receipt prints instantly with QR code, ticket ID, rates & entry time" },
              { step: "3", icon: CreditCard, title: "Easy Exit & Payment", desc: "Search plate, auto-calculate fee based on duration, collect & done" },
            ].map(({ step, icon: Icon, title, desc }, i) => (
              <motion.div key={step} initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.15 }} className="text-center">
                <div className="w-14 h-14 bg-green-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
                  <Icon className="w-7 h-7 text-green-600" />
                </div>
                <div className="text-xs font-bold text-green-600 uppercase tracking-wider mb-1">Step {step}</div>
                <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
                <p className="text-gray-500 text-sm">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 bg-gray-50">
        <div className="max-w-6xl mx-auto px-6">
          <motion.h2 initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="text-3xl md:text-4xl font-bold text-center text-gray-900 mb-4">
            Built for Real Parking Businesses
          </motion.h2>
          <p className="text-center text-gray-500 mb-14 max-w-xl mx-auto">Production-grade features used by parking lots across India.</p>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
            {[
              { icon: Printer, title: "Thermal Printing", desc: "Bluetooth & USB. 2-inch and 3-inch paper. Auto-print on entry." },
              { icon: CloudOff, title: "Works Offline", desc: "No internet? No problem. Everything saves locally, syncs later." },
              { icon: BarChart3, title: "Revenue Reports", desc: "Daily/weekly/monthly. Vehicle type breakdown. Export & share." },
              { icon: Shield, title: "Secure Login", desc: "JWT auth, multi-device management, auto-logout on new device." },
              { icon: Clock, title: "Auto Fee Calculation", desc: "Hourly rates, minimum charges, free minutes — all configurable." },
              { icon: Users, title: "13 Vehicle Types", desc: "Car, Bike, Scooter, SUV, Bus, Truck, Auto, E-Rickshaw & more." },
            ].map(({ icon: Icon, title, desc }, i) => (
              <motion.div key={title} initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.08 }}
                className="bg-white p-5 rounded-xl border border-gray-100 hover:border-green-200 hover:shadow-md transition-all">
                <div className="w-10 h-10 bg-green-50 rounded-lg flex items-center justify-center mb-3">
                  <Icon className="w-5 h-5 text-green-600" />
                </div>
                <h3 className="font-semibold text-gray-900 mb-1">{title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 bg-green-600">
        <div className="max-w-4xl mx-auto px-6 text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">Start Today. Free Forever.</h2>
          <p className="text-green-100 text-lg mb-8">No subscription. No hidden fees. Download and manage your parking in 2 minutes.</p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a href="/downloads/ParkEase-v5.apk" className="inline-flex items-center gap-2 bg-white text-green-700 px-8 py-3.5 rounded-xl font-semibold hover:bg-green-50 transition">
              <Download className="w-5 h-5" /> Download APK
            </a>
            <a href="/downloads/ParkEase-Windows.zip" className="inline-flex items-center gap-2 bg-green-700 text-white px-8 py-3.5 rounded-xl font-semibold hover:bg-green-800 transition border border-green-500">
              <Monitor className="w-5 h-5" /> Windows App
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 bg-gray-900">
        <div className="max-w-6xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <img src="/logo.png" alt="Go2" className="w-7 h-7 rounded" />
            <span className="text-white font-semibold">Go2-Parking</span>
          </div>
          <p className="text-gray-400 text-sm">© 2026 Go2 Billing Softwares by Deepanshu Verma</p>
        </div>
      </footer>
    </div>
  )
}

export default App
