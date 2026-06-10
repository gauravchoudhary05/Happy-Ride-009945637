/* ═══════════════════════════════════════════════════════════
   RIDE AGGREGATOR — APP LOGIC (Vertical Web Layout)
   ═══════════════════════════════════════════════════════════ */

// ── Constants & Config ────────────────────────────────────
const TOMTOM_KEY = '47pvAQxSQNZcPg4HySLLqOCygidP4YOi';
const TILE_URL = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const TILE_OPTS = { subdomains: 'abcd', maxZoom: 19 };
const DEFAULT_LOC = [12.9279, 77.6271]; // Bangalore fallback

const BRANDS = {
  'Rapido':       { color: '#FFCB05', image: 'logos/Rapido.png' },
  'Uber':         { color: '#276EF1', image: 'logos/uber.png' },
  'Ola':          { color: '#8BC34A', image: 'logos/ola.png' },
  'Namma Yatri':  { color: '#00BCD4', image: 'logos/namma yatri.png' },
  'Meru':         { color: '#D32F2F', image: 'logos/meru cab.png' },
  'Quick Ride':   { color: '#1565C0', image: 'logos/quick ride.png' },
  'Nagara Meter': { color: '#FF9800', image: 'logos/Nagara.png' },
  'Bharat Taxi':  { color: '#FFA000', image: 'logos/bharat taxi.jpg' },
  'Volta Cabs':   { color: '#4CAF50', image: 'logos/volta.jpg' },
  'Jugnoo':       { color: '#FFEB3B', image: 'logos/jugnoo.jpg' },
  'Mega Cabs':    { color: '#F44336', image: 'logos/mega cabs.jpg' },
  'BlaBlaCar':    { color: '#00BCD4', image: 'logos/blabla.jpg' },
  'Yatri Sathi':  { color: '#9C27B0', image: 'logos/yatri sathi.jpg' },
};

const RIDE_TEMPLATES = [
  { platform: 'Rapido', type: 'Bike', vt: 'bike', base: 20, perKm: 8 },
  { platform: 'Uber', type: 'Moto', vt: 'bike', base: 25, perKm: 9 },
  { platform: 'Ola', type: 'Bike', vt: 'bike', base: 22, perKm: 8.5 },
  { platform: 'Namma Yatri', type: 'Bike', vt: 'bike', base: 18, perKm: 7.5 },
  { platform: 'Rapido', type: 'Auto', vt: 'auto', base: 30, perKm: 12 },
  { platform: 'Namma Yatri', type: 'Auto', vt: 'auto', base: 28, perKm: 11 },
  { platform: 'Ola', type: 'Auto', vt: 'auto', base: 35, perKm: 14 },
  { platform: 'Uber', type: 'Auto', vt: 'auto', base: 38, perKm: 15 },
  { platform: 'Nagara Meter', type: 'Auto', vt: 'auto', base: 25, perKm: 13 },
  { platform: 'Jugnoo', type: 'Auto', vt: 'auto', base: 26, perKm: 12.5 },
  { platform: 'Yatri Sathi', type: 'Auto', vt: 'auto', base: 24, perKm: 11.5 },
  { platform: 'Rapido', type: 'Cab', vt: 'cab', base: 42, perKm: 16 },
  { platform: 'Uber', type: 'Go', vt: 'cab', base: 50, perKm: 20 },
  { platform: 'Ola', type: 'Mini', vt: 'cab', base: 48, perKm: 18 },
  { platform: 'Meru', type: 'Cab', vt: 'cab', base: 58, perKm: 22 },
  { platform: 'Quick Ride', type: 'Cab', vt: 'cab', base: 44, perKm: 17 },
  { platform: 'Bharat Taxi', type: 'Cab', vt: 'cab', base: 45, perKm: 17.5 },
  { platform: 'Volta Cabs', type: 'Cab', vt: 'cab', base: 40, perKm: 16.5 },
  { platform: 'Mega Cabs', type: 'Cab', vt: 'cab', base: 55, perKm: 21 },
  { platform: 'BlaBlaCar', type: 'Pool', vt: 'cab', base: 30, perKm: 10 },
];

const state = {
  map: null,
  pickupMarker: null,
  dropoffMarker: null,
  routeLine: null,
  
  currentLocation: [...DEFAULT_LOC],
  currentAddress: 'Current Location',
  
  isPickupActive: true,
  selectedPickup: null,
  selectedDropoff: null,
  vehicleType: 'cab',
  
  allRides: [],
  budget: null,
  activeFilter: 'all',
  distanceStr: '',
  distanceKm: 0,
  
  searchDebounce: null,
  etaInterval: null,
  currentRide: null
};

// ── Utility ───────────────────────────────────────────────
function getBrandKey(platform) { return Object.keys(BRANDS).find(k => platform.startsWith(k)) || 'Rapido'; }
function getBrandLogo(platform, size = 40) {
  const brand = BRANDS[getBrandKey(platform)];
  return `<img src="${brand.image}" alt="${platform}" style="width:${size}px;height:${size}px;object-fit:cover;border-radius:${size*0.25}px;" onerror="this.style.display='none'">`;
}
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }

// ── Flow Sections ─────────────────────────────────────────
function setFlowSection(sectionId) {
  document.querySelectorAll('.flow-section').forEach(s => s.classList.remove('active'));
  document.getElementById(sectionId).classList.add('active');
  
  // Resize map since layout might have changed
  if (state.map) {
    setTimeout(() => state.map.invalidateSize(), 300);
  }
}

// ── Map Initialization ────────────────────────────────────
function initMap() {
  state.map = L.map('main-map', {
    zoomControl: false,
    attributionControl: false
  }).setView(state.currentLocation, 14);
  L.tileLayer(TILE_URL, TILE_OPTS).addTo(state.map);
  
  L.control.zoom({ position: 'topright' }).addTo(state.map);
}

async function updateMapMarkers() {
  if (state.pickupMarker) state.pickupMarker.remove();
  if (state.dropoffMarker) state.dropoffMarker.remove();
  if (state.routeLine) state.routeLine.remove();
  
  const bounds = [];
  
  if (state.selectedPickup) {
    state.pickupMarker = L.circleMarker([state.selectedPickup.lat, state.selectedPickup.lng], {
      radius: 8, fillColor: '#34C759', fillOpacity: 1, color: '#fff', weight: 2
    }).addTo(state.map);
    bounds.push([state.selectedPickup.lat, state.selectedPickup.lng]);
  }
  
  if (state.selectedDropoff) {
    state.dropoffMarker = L.circleMarker([state.selectedDropoff.lat, state.selectedDropoff.lng], {
      radius: 8, fillColor: '#FF3B30', fillOpacity: 1, color: '#fff', weight: 2
    }).addTo(state.map);
    bounds.push([state.selectedDropoff.lat, state.selectedDropoff.lng]);
  }
  
  if (state.selectedPickup && state.selectedDropoff) {
    state.routeLine = L.polyline(bounds, { color: '#007AFF', weight: 4, dashArray: '5, 10' }).addTo(state.map);
    state.map.fitBounds(bounds, { 
      paddingTopLeft: window.innerWidth > 800 ? [480, 50] : [50, 50],
      paddingBottomRight: [50, 50],
      maxZoom: 16 
    });
    
    const route = await calculateRoute(state.selectedPickup, state.selectedDropoff);
    if (route.geometry) {
      if (state.routeLine) state.routeLine.remove();
      const latlngs = route.geometry.coordinates.map(c => [c[1], c[0]]);
      state.routeLine = L.polyline(latlngs, { color: '#0A84FF', weight: 5 }).addTo(state.map);
      state.map.fitBounds(state.routeLine.getBounds(), {
        paddingTopLeft: window.innerWidth > 800 ? [480, 50] : [50, 50],
        paddingBottomRight: [50, 50],
        maxZoom: 16 
      });
    }
  } else if (bounds.length > 0) {
    state.map.setView(bounds[0], 15);
    if (window.innerWidth > 800) state.map.panBy([-200, 0]);
  }
}

// ── Geocoding & Routing ───────────────────────────────────
async function reverseGeocode(lat, lng) {
  try {
    const res = await fetch(`https://api.tomtom.com/search/2/reverseGeocode/${lat},${lng}.json?key=${TOMTOM_KEY}`);
    const data = await res.json();
    return data.addresses?.[0]?.address?.freeformAddress || 'Current Location';
  } catch { return 'Current Location'; }
}

async function searchPlaces(query) {
  if (!query.trim()) return [];
  try {
    const res = await fetch(`https://api.tomtom.com/search/2/search/${encodeURIComponent(query)}.json?key=${TOMTOM_KEY}&limit=8&countrySet=IN`);
    const data = await res.json();
    return data.results || [];
  } catch { return []; }
}

async function calculateRoute(pickup, dropoff) {
  try {
    const res = await fetch(`https://router.project-osrm.org/route/v1/driving/${pickup.lng},${pickup.lat};${dropoff.lng},${dropoff.lat}?overview=full&geometries=geojson`);
    const data = await res.json();
    if (data.routes?.length > 0) {
      return { 
        distanceKm: data.routes[0].distance / 1000,
        geometry: data.routes[0].geometry
      };
    }
  } catch {}
  return { distanceKm: 5, geometry: null }; // Fallback
}

// ── Search Flow ───────────────────────────────────────────
function initSearchFlow() {
  const pInput = document.getElementById('pickup-input');
  const dInput = document.getElementById('dropoff-input');
  
  // Geolocation setup
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(async (pos) => {
      state.currentLocation = [pos.coords.latitude, pos.coords.longitude];
      state.currentAddress = await reverseGeocode(pos.coords.latitude, pos.coords.longitude);
      
      state.selectedPickup = { lat: pos.coords.latitude, lng: pos.coords.longitude, name: 'Current Location', address: state.currentAddress };
      pInput.value = state.currentAddress;
      updateMapMarkers();
      checkSearchReady();
    });
  }
  
  pInput.addEventListener('focus', () => { state.isPickupActive = true; doSearch(pInput.value); });
  dInput.addEventListener('focus', () => { state.isPickupActive = false; doSearch(dInput.value); });
  
  pInput.addEventListener('input', () => doSearch(pInput.value));
  dInput.addEventListener('input', () => doSearch(dInput.value));
  
  document.getElementById('pickup-clear').addEventListener('click', () => { pInput.value = ''; state.selectedPickup = null; doSearch(''); pInput.focus(); updateMapMarkers(); checkSearchReady(); });
  document.getElementById('dropoff-clear').addEventListener('click', () => { dInput.value = ''; state.selectedDropoff = null; doSearch(''); dInput.focus(); updateMapMarkers(); checkSearchReady(); });
  
  document.querySelectorAll('.vehicle-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.vehicle-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.vehicleType = btn.dataset.vehicle;
    });
  });
  
  document.getElementById('btn-search-rides').addEventListener('click', () => {
    // Both selected, let's prompt budget
    document.getElementById('budget-modal').classList.add('visible');
    document.getElementById('budget-input').value = '';
    document.getElementById('budget-input').focus();
  });
  
  document.getElementById('btn-my-location').addEventListener('click', () => {
    state.map.setView(state.currentLocation, 15);
  });
}

function checkSearchReady() {
  const btn = document.getElementById('btn-search-rides');
  const pClear = document.getElementById('pickup-clear');
  const dClear = document.getElementById('dropoff-clear');
  
  pClear.classList.toggle('visible', document.getElementById('pickup-input').value.length > 0);
  dClear.classList.toggle('visible', document.getElementById('dropoff-input').value.length > 0);
  
  if (state.selectedPickup && state.selectedDropoff) {
    btn.style.display = 'flex';
  } else {
    btn.style.display = 'none';
  }
}

function doSearch(query) {
  clearTimeout(state.searchDebounce);
  const container = document.getElementById('search-results');
  if (!query.trim()) { container.innerHTML = ''; return; }
  
  container.innerHTML = '<div class="search-loading">Searching...</div>';
  state.searchDebounce = setTimeout(async () => {
    const results = await searchPlaces(query);
    if (results.length === 0) { container.innerHTML = '<div class="search-empty">No results found.</div>'; return; }
    
    container.innerHTML = results.map(res => {
      const name = res.poi?.name || res.address?.freeformAddress || 'Location';
      const sub = res.address?.freeformAddress || '';
      return `
        <div class="search-result-item" data-lat="${res.position.lat}" data-lon="${res.position.lon}" data-name="${name}" data-sub="${sub}">
          <div class="search-result-icon"><span class="material-icons">location_on</span></div>
          <div class="search-result-text">
            <div class="search-result-name">${name}</div>
            <div class="search-result-sub">${sub}</div>
          </div>
        </div>
      `;
    }).join('');
    
    container.querySelectorAll('.search-result-item').forEach(item => {
      item.addEventListener('click', () => {
        const loc = {
          lat: parseFloat(item.dataset.lat),
          lng: parseFloat(item.dataset.lon),
          name: item.dataset.name,
          address: item.dataset.sub || item.dataset.name
        };
        if (state.isPickupActive) {
          state.selectedPickup = loc;
          document.getElementById('pickup-input').value = loc.name;
          document.getElementById('dropoff-input').focus();
        } else {
          state.selectedDropoff = loc;
          document.getElementById('dropoff-input').value = loc.name;
        }
        container.innerHTML = '';
        updateMapMarkers();
        checkSearchReady();
      });
    });
  }, 350);
}

// ── Results Flow ──────────────────────────────────────────
function initResultsFlow() {
  document.getElementById('budget-skip').addEventListener('click', () => loadResults(null));
  document.getElementById('budget-confirm').addEventListener('click', () => {
    const v = parseInt(document.getElementById('budget-input').value);
    loadResults(isNaN(v) ? null : v);
  });
  
  document.getElementById('btn-back-to-search').addEventListener('click', () => setFlowSection('section-search'));
  
  document.querySelectorAll('#filter-tabs .filter-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('#filter-tabs .filter-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      state.activeFilter = tab.dataset.filter;
      renderRideList();
    });
  });
}

async function loadResults(budget) {
  document.getElementById('budget-modal').classList.remove('visible');
  state.budget = budget;
  state.activeFilter = state.vehicleType;
  
  document.querySelectorAll('#filter-tabs .filter-tab').forEach(t => t.classList.toggle('active', t.dataset.filter === state.activeFilter));
  
  setFlowSection('section-results');
  document.getElementById('results-route-summary').textContent = `${state.selectedPickup.name} → ${state.selectedDropoff.name}`;
  
  document.getElementById('results-loading').style.display = 'block';
  document.getElementById('ride-list').style.display = 'none';
  
  const route = await calculateRoute(state.selectedPickup, state.selectedDropoff);
  state.distanceKm = route.distanceKm;
  state.distanceStr = `${route.distanceKm.toFixed(1)} km`;
  
  // Generate rides
  state.allRides = RIDE_TEMPLATES.map(t => {
    const price = Math.round(t.base + state.distanceKm * t.perKm) + randInt(-6, 6);
    return { ...t, price: Math.max(price, 10), eta: `${3 + randInt(0, 7)} min` };
  });
  
  document.getElementById('results-loading').style.display = 'none';
  document.getElementById('ride-list').style.display = 'block';
  renderRideList();
}

function renderRideList() {
  let rides = state.allRides;
  if (state.activeFilter !== 'all') rides = rides.filter(r => r.vt === state.activeFilter);
  if (state.budget) {
    rides.sort((a, b) => Math.abs(a.price - state.budget) - Math.abs(b.price - state.budget));
  } else {
    rides.sort((a, b) => a.price - b.price);
  }
  
  const container = document.getElementById('ride-list');
  if (rides.length === 0) { container.innerHTML = '<div class="search-empty">No rides available.</div>'; return; }
  
  const cheapest = rides[0].price;
  const mostExpensive = rides[rides.length-1].price;
  const savings = mostExpensive - cheapest;
  
  container.innerHTML = rides.map((ride, i) => {
    const isBest = i === 0;
    return `
      <div class="ride-card stagger-item ${isBest ? 'best-price' : ''}" style="animation-delay:${i*50}ms" data-index="${i}">
        <div class="ride-card-body">
          <div class="ride-card-logo">${getBrandLogo(ride.platform)}</div>
          <div class="ride-card-info">
            <div class="ride-card-name-row">
              <span class="ride-card-name">${ride.platform} ${ride.type}</span>
              ${isBest ? '<span class="best-price-badge">Best Price</span>' : ''}
            </div>
            <div class="ride-card-meta">
              <span class="material-icons">access_time</span> ETA: ${ride.eta} • ONDC
            </div>
          </div>
          <span class="ride-card-price">₹${ride.price}</span>
        </div>
        ${isBest && savings > 0 ? `<div class="ride-card-savings">🎉 You save ₹${savings} compared to the highest price!</div>` : ''}
      </div>
    `;
  }).join('');
  
  container.querySelectorAll('.ride-card').forEach(card => {
    card.addEventListener('click', () => {
      const idx = parseInt(card.dataset.index);
      state.currentRide = rides[idx];
      showConfirmModal();
    });
  });
}

function showConfirmModal() {
  const ride = state.currentRide;
  document.getElementById('confirm-platform-name').textContent = `${ride.platform} ${ride.type}`;
  document.getElementById('confirm-price').textContent = `₹${ride.price}`;
  document.getElementById('confirm-pickup-text').textContent = state.selectedPickup.address;
  document.getElementById('confirm-dropoff-text').textContent = state.selectedDropoff.address;
  document.getElementById('confirmpickup-modal').classList.add('visible');
}

document.getElementById('confirm-cancel').addEventListener('click', () => {
  document.getElementById('confirmpickup-modal').classList.remove('visible');
});

document.getElementById('confirm-submit').addEventListener('click', () => {
  document.getElementById('confirmpickup-modal').classList.remove('visible');
  document.getElementById('captain-dialog').classList.add('visible');
  setTimeout(() => {
    document.getElementById('captain-dialog').classList.remove('visible');
    startRideStatus();
  }, 2500);
});

// ── Status Flow ───────────────────────────────────────────
function startRideStatus() {
  setFlowSection('section-status');
  const ride = state.currentRide;
  
  document.getElementById('status-platform-name').textContent = `${ride.platform} ${ride.type}`;
  document.getElementById('status-price').textContent = `₹${ride.price}`;
  
  // Fake OTP & Driver
  const otp = `${1000 + randInt(0, 8999)}`;
  document.getElementById('otp-digits').innerHTML = otp.split('').map(d => `<div class="otp-digit">${d}</div>`).join('');
  
  const drivers = ['Rajesh K.', 'Amit S.', 'Suresh M.', 'Prakash R.'];
  document.getElementById('driver-name').textContent = drivers[randInt(0, drivers.length-1)];
  document.getElementById('driver-vehicle').textContent = `KA 51 AB ${1000 + randInt(0, 8999)}`;
  
  // ETA
  let eta = 3 + randInt(0, 4);
  document.getElementById('status-eta-text').textContent = `Pickup arriving in ${eta} min`;
  clearInterval(state.etaInterval);
  state.etaInterval = setInterval(() => {
    if (eta > 1) {
      eta--;
      document.getElementById('status-eta-text').textContent = `Pickup arriving in ${eta} min`;
    } else {
      document.getElementById('status-eta-text').textContent = 'Driver is arriving!';
      clearInterval(state.etaInterval);
    }
  }, 30000);
}

function resetToHome() {
  clearInterval(state.etaInterval);
  setFlowSection('section-search');
  document.getElementById('pickup-input').value = state.selectedPickup?.name || '';
  document.getElementById('dropoff-input').value = '';
  state.selectedDropoff = null;
  document.getElementById('pickup-input').focus();
  updateMapMarkers();
  checkSearchReady();
}

document.getElementById('btn-cancel-ride-status').addEventListener('click', resetToHome);
document.getElementById('btn-done-ride').addEventListener('click', resetToHome);

// ── Bootstrap ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  initMap();
  initSearchFlow();
  initResultsFlow();
});
