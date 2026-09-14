"use client";

import { useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Fix leaflet default icons in next.js
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png",
  iconUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png",
  shadowUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
});

const redIcon = new L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
  shadowUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

// Helper component to adjust map bounds
function MapUpdater({ cases }: { cases: any[] }) {
  const map = useMap();
  useEffect(() => {
    if (cases.length > 0) {
      const bounds = L.latLngBounds(cases.map(c => [c.location?.latitude || 0, c.location?.longitude || 0]));
      if (bounds.isValid()) {
         map.fitBounds(bounds, { padding: [50, 50], maxZoom: 12 });
      }
    }
  }, [cases, map]);
  return null;
}

export default function Map({ cases }: { cases: any[] }) {
  return (
    <div className="h-full w-full rounded-xl overflow-hidden border border-slate-200 shadow-sm relative z-0">
      <MapContainer
        center={[20.5937, 78.9629]}
        zoom={5}
        scrollWheelZoom={true}
        style={{ height: "100%", width: "100%" }}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; OpenStreetMap contributors'
        />
        {cases.map((c) => {
          if (!c.location || !c.location.latitude) return null;
          return (
            <Marker 
              key={c.id} 
              position={[c.location.latitude, c.location.longitude]}
              icon={c.risk_level === 'HIGH' ? redIcon : new L.Icon.Default()}
            >
              <Popup>
                <div className="font-sans">
                  <h3 className="font-semibold text-lg">{c.suspected_disease || "Unknown"}</h3>
                  <p className="text-sm text-gray-600 mb-2">ID: {c.animal_id}</p>
                  <p className="text-sm"><span className="font-semibold">Status:</span> {c.status}</p>
                  <p className="text-sm"><span className="font-semibold">Risk:</span> {c.risk_level}</p>
                  <p className="text-sm"><span className="font-semibold">Source:</span> {c.source}</p>
                  <p className="text-xs text-gray-500 mt-2">Reported: {new Date(c.created_at).toLocaleString()}</p>
                </div>
              </Popup>
            </Marker>
          )
        })}
        <MapUpdater cases={cases} />
      </MapContainer>
    </div>
  );
}
