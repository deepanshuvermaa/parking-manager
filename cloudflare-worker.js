/**
 * Cloudflare Worker Proxy for ParkEase Backend
 * Forwards all requests to Railway backend
 * Fixes mobile ISP blocking issues
 *
 * Deploy to: workers.cloudflare.com
 * Free tier: 100,000 requests/day
 */

// Your Railway backend URL
const BACKEND_URL = 'https://parkease-production-6679.up.railway.app';

// CORS headers for Flutter app
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  // Handle preflight OPTIONS request
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: CORS_HEADERS
    });
  }

  try {
    // Get the request URL
    const url = new URL(request.url);

    // Build the backend URL (forward the path and query)
    const backendUrl = BACKEND_URL + url.pathname + url.search;

    // Clone the request headers
    const headers = new Headers(request.headers);

    // Forward the request to Railway backend
    const backendRequest = new Request(backendUrl, {
      method: request.method,
      headers: headers,
      body: request.method !== 'GET' && request.method !== 'HEAD' ? await request.text() : undefined
    });

    // Fetch from Railway
    const backendResponse = await fetch(backendRequest);

    // Clone the response
    const responseHeaders = new Headers(backendResponse.headers);

    // Add CORS headers
    Object.keys(CORS_HEADERS).forEach(key => {
      responseHeaders.set(key, CORS_HEADERS[key]);
    });

    // Return the proxied response
    return new Response(backendResponse.body, {
      status: backendResponse.status,
      statusText: backendResponse.statusText,
      headers: responseHeaders
    });

  } catch (error) {
    // Return error response
    return new Response(JSON.stringify({
      success: false,
      error: 'Proxy error: ' + error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        ...CORS_HEADERS
      }
    });
  }
}
