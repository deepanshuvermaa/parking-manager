import React, { useRef } from 'react'
import { motion, useScroll, useTransform } from 'motion/react'
import { Download, Smartphone, Monitor, Shield, Printer, Zap, BarChart3, Car, Clock, CreditCard, QrCode, Users, CloudOff } from 'lucide-react'

const BG_IMAGE = "https://images.higgs.ai/?default=1&output=webp&url=https%3A%2F%2Fd8j0ntlcm91z4.cloudfront.net%2Fuser_38xzZboKViGWJOttwIXH07lWA1P%2Fhf_20260430_115327_3f256636-9e63-4885-8d0b-09317dc2b0a5.png&w=1280&q=85"
const TRUCK_IMAGE = "https://roof-wish-40038865.figma.site/_components/v2/f31fd17907ce60745d45e83a61d44fd3810d5f25/truck_1.8c4bff83.png"

function App() {
  const containerRef = useRef(null)
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start end", "end start"] })
  const truckY = useTransform(scrollYProgress, [0, 1], [-50, 150])

  return (
    <div className="antialiased" style={{ fontFamily: "'Inter', sans-serif" }}>
      {/* Hero */}
      <section
        ref={containerRef}
        className="min-h-screen relative overflow-hidden bg-cover bg-center flex items-center"
        style={{ backgroundImage: `url(${BG_IMAGE})` }}
      >
        <div className="absolute inset-0 bg-gradient-to-b from-black/70 via-black/50 to-black/80 z-10" />

        <div className="relative z-20 w-full px-6 py-24">
          <div className="max-w-5xl mx-auto text-center">
            <motion.div initial={{ opacity: 0, y: 40 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.9, ease: "easeOut" }}>
              {/* Logo - proper aspect ratio */}
              <div className="flex items-center justify-center gap-4 mb-12">
                <img src="/logo.png" alt="Go2" className="h-14 w-auto rounded-2xl shadow-2xl shadow-green-500/20 border-2 border-white/10" />
                <div className="text-left">
                  <span className="text-white text-3xl md:text-4xl font-extrabold tracking-tight block leading-none">Go2-Parking</span>
                  <span className="text-green-400 text-xs md:text-sm font-medium tracking-widest uppercase">Smart Parking System</span>
                </div>
              </div>

              <h1 className="text-5xl md:text-7xl lg:text-8xl font-black text-white mb-6 leading-[0.9] tracking-tight">
                Park Smarter.<br/>
                <span className="bg-gradient-to-r from-green-400 via-emerald-300 to-teal-400 bg-clip-text text-transparent">Earn Faster.</span>
              </h1>

              <p className="text-base md:text-lg text-white/70 max-w-xl mx-auto mb-12 leading-relaxed font-medium">
                Auto-print receipts. Track every vehicle. Calculate fees instantly. 
                <span className="text-white/90 font-semibold"> Works even without internet.</span>
              </p>

              {/* Buttons */}
              <div className="flex flex-col sm:flex-row gap-3 justify-center">
                <motion.a
                  href="/downloads/ParkEase-v5.apk"
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.97 }}
                  className="inline-flex items-center gap-2.5 bg-gradient-to-r from-green-500 to-emerald-600 text-white px-8 py-4 rounded-2xl font-bold transition shadow-xl shadow-green-500/25 text-base"
                >
                  <Smartphone className="w-5 h-5" /> Download for Android
                </motion.a>
                <motion.a
                  href="/downloads/ParkEase-Windows.zip"
                  whileHover={{ scale: 1.03 }}
                  whileTap={{ scale: 0.97 }}
                  className="inline-flex items-center gap-2.5 bg-white/5 hover:bg-white/10 backdrop-blur-md text-white border border-white/20 px-8 py-4 rounded-2xl font-bold transition text-base"
                >
                  <Monitor className="w-5 h-5" /> Get Windows App
                </motion.a>
              </div>

              {/* Trust badges */}
              <div className="mt-10 flex flex-wrap items-center justify-center gap-6 text-white/40 text-xs font-semibold uppercase tracking-wider">
                <span className="flex items-center gap-1.5"><CloudOff className="w-3.5 h-3.5" /> Offline Ready</span>
                <span className="flex items-center gap-1.5"><Printer className="w-3.5 h-3.5" /> Auto Print</span>
                <span className="flex items-center gap-1.5"><Shield className="w-3.5 h-3.5" /> Secure</span>
                <span className="flex items-center gap-1.5"><Zap className="w-3.5 h-3.5" /> 3-Tap Entry</span>
              </div>
            </motion.div>
          </div>
        </div>

        {/* Truck */}
        <motion.div style={{ y: truckY }} className="absolute inset-x-0 bottom-0 h-full pointer-events-none z-[5]">
          <img src={TRUCK_IMAGE} alt="" className="w-full h-full object-contain object-bottom origin-bottom scale-[1.5] sm:scale-110 md:scale-[2.0] lg:scale-105" />
        </motion.div>
      </section>

      {/* How It Works */}
      <section className="py-24 bg-white relative overflow-hidden">
        <div className="absolute top-0 left-0 w-72 h-72 bg-green-50 rounded-full -translate-x-1/2 -translate-y-1/2 blur-3xl" />
        <div className="max-w-5xl mx-auto px-6 relative">
          <motion.div initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} className="text-center mb-16">
            <p className="text-green-600 font-bold text-sm uppercase tracking-widest mb-3">How it works</p>
            <h2 className="text-4xl md:text-5xl font-black text-gray-900 tracking-tight">Three taps. Done.</h2>
          </motion.div>
          <div className="grid md:grid-cols-3 gap-10">
            {[
              { step: "01", icon: Car, title: "Vehicle In", desc: "Pick type from 13 categories. Enter plate number. That's it." },
              { step: "02", icon: QrCode, title: "Receipt Prints", desc: "Thermal printer fires automatically. QR code, rates, time — all on it." },
              { step: "03", icon: CreditCard, title: "Collect & Exit", desc: "Search plate, see fee calculated. Collect cash. Vehicle out." },
            ].map(({ step, icon: Icon, title, desc }, i) => (
              <motion.div key={step} initial={{ opacity: 0, y: 30 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.15 }}>
                <span className="text-5xl font-black text-green-100">{step}</span>
                <div className="w-12 h-12 bg-green-500 rounded-xl flex items-center justify-center mt-2 mb-4 shadow-lg shadow-green-500/20">
                  <Icon className="w-6 h-6 text-white" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">{title}</h3>
                <p className="text-gray-500 leading-relaxed">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-24 bg-gray-50">
        <div className="max-w-6xl mx-auto px-6">
          <motion.div initial={{ opacity: 0 }} whileInView={{ opacity: 1 }} viewport={{ once: true }} className="text-center mb-16">
            <p className="text-green-600 font-bold text-sm uppercase tracking-widest mb-3">Features</p>
            <h2 className="text-4xl md:text-5xl font-black text-gray-900 tracking-tight">Everything you need, built in.</h2>
          </motion.div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
            {[
              { icon: Printer, title: "Thermal Printing", desc: "Bluetooth & USB. 2\" and 3\" paper. Prints the moment vehicle enters." },
              { icon: CloudOff, title: "Offline First", desc: "No WiFi? Works perfectly. Syncs when you're back online." },
              { icon: BarChart3, title: "Revenue Reports", desc: "See daily earnings, vehicle counts, peak hours. Export anytime." },
              { icon: Shield, title: "Multi-Device Auth", desc: "Login from phone or PC. Auto-logout keeps your data safe." },
              { icon: Clock, title: "Smart Billing", desc: "Hourly rates, minimum charge, free minutes — fully configurable." },
              { icon: Users, title: "All Vehicle Types", desc: "Bike, Car, SUV, Auto, Bus, Truck, E-Rickshaw — 13 types covered." },
            ].map(({ icon: Icon, title, desc }, i) => (
              <motion.div key={title} initial={{ opacity: 0, y: 20 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ delay: i * 0.07 }}
                className="bg-white p-6 rounded-2xl border border-gray-100 hover:border-green-300 hover:shadow-xl hover:-translate-y-1 transition-all duration-300 group">
                <div className="w-11 h-11 bg-green-50 group-hover:bg-green-500 rounded-xl flex items-center justify-center mb-4 transition-colors duration-300">
                  <Icon className="w-5 h-5 text-green-600 group-hover:text-white transition-colors duration-300" />
                </div>
                <h3 className="font-bold text-gray-900 mb-1.5 text-lg">{title}</h3>
                <p className="text-gray-500 text-sm leading-relaxed">{desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-24 bg-gradient-to-br from-green-600 via-emerald-600 to-teal-700 relative overflow-hidden">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMzAiIGN5PSIzMCIgcj0iMSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjA1KSIvPjwvc3ZnPg==')] opacity-50" />
        <div className="max-w-4xl mx-auto px-6 text-center relative">
          <motion.div initial={{ opacity: 0, scale: 0.95 }} whileInView={{ opacity: 1, scale: 1 }} viewport={{ once: true }}>
            <h2 className="text-4xl md:text-5xl font-black text-white mb-4 tracking-tight">Ready to go?</h2>
            <p className="text-green-100 text-lg mb-10 font-medium">Free forever. No signup needed. Just download and start.</p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <motion.a href="/downloads/ParkEase-v5.apk" whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}
                className="inline-flex items-center gap-2 bg-white text-green-700 px-8 py-4 rounded-2xl font-bold hover:bg-green-50 transition shadow-xl text-base">
                <Download className="w-5 h-5" /> Android APK
              </motion.a>
              <motion.a href="/downloads/ParkEase-Windows.zip" whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.96 }}
                className="inline-flex items-center gap-2 bg-white/10 text-white px-8 py-4 rounded-2xl font-bold hover:bg-white/20 transition border border-white/20 text-base">
                <Monitor className="w-5 h-5" /> Windows .exe
              </motion.a>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 bg-gray-950">
        <div className="max-w-6xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <img src="/logo.png" alt="Go2" className="h-8 w-auto rounded-lg" />
            <span className="text-white font-bold text-lg">Go2-Parking</span>
          </div>
          <p className="text-gray-500 text-sm">© 2026 Go2 Billing Softwares by Deepanshu Verma</p>
        </div>
      </footer>
    </div>
  )
}

export default App
