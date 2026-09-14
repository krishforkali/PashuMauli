"use client";

import { useState, useEffect, useMemo } from "react";
import dynamic from "next/dynamic";
import { Activity, AlertTriangle, PhoneCall, ShieldAlert, CheckCircle2, Server, LogIn } from "lucide-react";
import { apiConfig } from "../config/api";

// Dynamic import for Leaflet map to avoid SSR issues
const MapComponent = dynamic(() => import("./Map"), {
  ssr: false,
  loading: () => <div className="h-full w-full bg-slate-100 animate-pulse rounded-xl flex items-center justify-center">Loading Map...</div>
});

const API_BASE = apiConfig.API_BASE_URL;
const WS_BASE = apiConfig.WS_BASE_URL;

export default function Dashboard() {
  const [token, setToken] = useState<string | null>(null);
  const [cases, setCases] = useState<any[]>([]);
  const [phone, setPhone] = useState("+919999999999");
  const [password, setPassword] = useState("password123");
  const [error, setError] = useState("");
  const [wsStatus, setWsStatus] = useState<"disconnected" | "connecting" | "connected">("disconnected");
  const [recentEvents, setRecentEvents] = useState<any[]>([]);

  // Login handler - allows entry with any username/password for dashboard
  const handleLogin = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setError("");
    try {
      const res = await fetch(`${API_BASE}/api/v1/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: phone || "+919999999999", password: password || "password123" }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.access_token) {
        setToken(data.access_token);
        return;
      }
    } catch (err) {
      console.warn("Backend auth unavailable, continuing to dashboard session:", err);
    }
    // Direct entry with demo dashboard token for dashboard view
    setToken("dashboard-demo-token");
  };

  // Fetch initial cases once logged in
  useEffect(() => {
    if (!token) return;
    fetch(`${API_BASE}/api/v1/cases?page_size=100`, {
      headers: { Authorization: `Bearer ${token}` }
    })
      .then(r => r.json())
      .then(data => {
        if (data.items) setCases(data.items);
      })
      .catch(console.error);
  }, [token]);

  // WebSocket Connection
  useEffect(() => {
    if (!token) return;

    setWsStatus("connecting");
    const ws = new WebSocket(`${WS_BASE}/api/v1/ws?token=${token}`);

    ws.onopen = () => {
      console.log("WebSocket connected");
      setWsStatus("connected");
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        console.log("WS Message:", msg);
        
        // Add to recent events log
        setRecentEvents(prev => [msg, ...prev].slice(0, 50));

        if (msg.event_type === "CASE_CREATED") {
          setCases(prev => [msg.payload, ...prev]);
        } else if (msg.event_type === "CASE_UPDATED") {
          setCases(prev => prev.map(c => c.id === msg.payload.id ? msg.payload : c));
        } else if (msg.event_type === "AI_RESULT_AVAILABLE") {
          // Update the specific case with AI result top_prediction
          setCases(prev => prev.map(c => {
            if (c.id === msg.payload.case_id) {
              return { ...c, suspected_disease: msg.payload.top_prediction };
            }
            return c;
          }));
        }
      } catch (err) {
        console.error("Failed to parse WS message", err);
      }
    };

    ws.onclose = () => {
      console.log("WebSocket disconnected");
      setWsStatus("disconnected");
      // Optional: implement reconnect logic
    };

    return () => {
      ws.close();
    };
  }, [token]);

  const stats = useMemo(() => {
    const highRisk = cases.filter(c => c.risk_level === 'HIGH').length;
    const ivrCases = cases.filter(c => c.source === 'IVR').length;
    const resolved = cases.filter(c => c.status === 'RESOLVED').length;
    return { total: cases.length, highRisk, ivrCases, resolved };
  }, [cases]);

  if (!token) {
    return (
      <div className="flex h-screen items-center justify-center bg-gray-50">
        <div className="bg-white p-8 rounded-xl shadow-lg w-full max-w-md border border-slate-100">
          <div className="flex flex-col items-center mb-6">
            <div className="bg-blue-600 p-3 rounded-full text-white mb-4">
              <ShieldAlert size={32} />
            </div>
            <h1 className="text-2xl font-bold text-slate-800">PashuMauli Command Center</h1>
            <p className="text-slate-500 text-sm mt-1">Real-time livestock health surveillance</p>
          </div>
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Phone / Username</label>
              <input 
                type="text" 
                value={phone} 
                onChange={e => setPhone(e.target.value)}
                placeholder="Any username or phone"
                className="w-full border border-slate-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">Password</label>
              <input 
                type="password" 
                value={password} 
                onChange={e => setPassword(e.target.value)}
                placeholder="Any password"
                className="w-full border border-slate-300 rounded-lg p-2.5 focus:ring-2 focus:ring-blue-500 outline-none"
              />
            </div>
            {error && <p className="text-red-500 text-sm">{error}</p>}
            <button type="submit" className="w-full bg-blue-600 text-white font-medium p-2.5 rounded-lg hover:bg-blue-700 transition flex items-center justify-center gap-2 shadow-sm">
              <LogIn size={20} />
              Enter Command Center
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-screen bg-slate-50">
      {/* Header */}
      <header className="bg-white border-b border-slate-200 h-16 flex items-center justify-between px-6 shrink-0">
        <div className="flex items-center gap-3">
          <div className="bg-blue-600 p-1.5 rounded-md text-white">
            <ShieldAlert size={24} />
          </div>
          <h1 className="text-xl font-bold text-slate-800 tracking-tight">PashuMauli Command Center</h1>
        </div>
        <div className="flex items-center gap-4">
          <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium ${wsStatus === 'connected' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
            <Server size={16} />
            {wsStatus === 'connected' ? 'Live (WS Connected)' : 'Disconnected'}
          </div>
          <div className="h-8 w-8 rounded-full bg-slate-200 border border-slate-300 flex items-center justify-center text-slate-600 font-bold">
            DO
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden p-6 gap-6">
        
        {/* Left Column: Stats & Events */}
        <div className="w-1/3 flex flex-col gap-6 overflow-hidden">
          
          {/* Stats Grid */}
          <div className="grid grid-cols-2 gap-4 shrink-0">
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center gap-2 text-slate-500 mb-2">
                <Activity size={18} />
                <h3 className="font-medium text-sm">Total Cases</h3>
              </div>
              <p className="text-3xl font-bold text-slate-800">{stats.total}</p>
            </div>
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center gap-2 text-red-500 mb-2">
                <AlertTriangle size={18} />
                <h3 className="font-medium text-sm">High Risk</h3>
              </div>
              <p className="text-3xl font-bold text-red-600">{stats.highRisk}</p>
            </div>
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center gap-2 text-blue-500 mb-2">
                <PhoneCall size={18} />
                <h3 className="font-medium text-sm">IVR Sourced</h3>
              </div>
              <p className="text-3xl font-bold text-blue-600">{stats.ivrCases}</p>
            </div>
            <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
              <div className="flex items-center gap-2 text-green-500 mb-2">
                <CheckCircle2 size={18} />
                <h3 className="font-medium text-sm">Resolved</h3>
              </div>
              <p className="text-3xl font-bold text-green-600">{stats.resolved}</p>
            </div>
          </div>

          {/* Real-time Event Feed */}
          <div className="bg-white flex-1 rounded-xl border border-slate-200 shadow-sm flex flex-col overflow-hidden">
            <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between bg-slate-50">
              <h3 className="font-semibold text-slate-800 flex items-center gap-2">
                <Activity size={18} className="text-blue-500" />
                Live Event Feed
              </h3>
              <span className="flex h-2 w-2 relative">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-blue-500"></span>
              </span>
            </div>
            <div className="p-4 overflow-y-auto flex-1 space-y-3">
              {recentEvents.length === 0 ? (
                <p className="text-sm text-slate-500 text-center py-4">Listening for events...</p>
              ) : (
                recentEvents.map((ev, i) => (
                  <div key={i} className="text-sm border-l-2 border-blue-400 pl-3 py-1">
                    <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                      <span className="font-medium text-blue-600">{ev.event_type}</span>
                      <span>{ev.source || "SYSTEM"}</span>
                    </div>
                    <div className="text-slate-700 truncate">
                      {ev.event_type === "IVR_RECEIVED" && `Call from ${ev.payload.caller_phone}`}
                      {ev.event_type === "CASE_CREATED" && `New case: ${ev.payload.suspected_disease || 'Unknown'}`}
                      {ev.event_type === "AI_RESULT_AVAILABLE" && `AI predicts: ${ev.payload.top_prediction}`}
                      {ev.event_type === "CASE_UPDATED" && `Case updated`}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Map */}
        <div className="w-2/3 flex flex-col bg-white rounded-xl border border-slate-200 shadow-sm p-1">
          <MapComponent cases={cases} />
        </div>

      </div>
    </div>
  );
}
