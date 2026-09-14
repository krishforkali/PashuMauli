export const getApiConfig = () => {
  // Use NEXT_PUBLIC_API_BASE_URL if provided, else fallback to FastAPI backend at http://localhost:8000
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
  
  let wsBase = process.env.NEXT_PUBLIC_WS_BASE_URL || "";
  if (!wsBase) {
    if (apiBase) {
      // Derive WS URL from API URL
      wsBase = apiBase.replace(/^http:\/\//i, "ws://").replace(/^https:\/\//i, "wss://");
    } else {
      // Fallback for local dev if NEXT_PUBLIC_API_BASE_URL is not set
      if (typeof window !== "undefined") {
        wsBase = window.location.protocol === "https:" 
          ? `wss://${window.location.hostname}:8000` 
          : `ws://${window.location.hostname}:8000`;
      } else {
        wsBase = "ws://127.0.0.1:8000";
      }
    }
  }

  return {
    API_BASE_URL: apiBase,
    WS_BASE_URL: wsBase,
  };
};

export const apiConfig = getApiConfig();
