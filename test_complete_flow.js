/**
 * Complete Flow Test Script
 * Tests all fixed functionality end-to-end
 */

const axios = require('axios');

// Configuration
const API_URL = process.env.API_URL || 'http://localhost:3001/api';
const TEST_USER = {
  email: `test_${Date.now()}@parkease.com`,
  password: 'Test123!',
  fullName: 'Test User',
  deviceId: `test_device_${Date.now()}`
};

let authToken = null;
let refreshToken = null;
let userId = null;

// Helper function for API calls
async function apiCall(method, endpoint, data = null, token = null) {
  const config = {
    method,
    url: `${API_URL}${endpoint}`,
    headers: {
      'Content-Type': 'application/json'
    }
  };

  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`;
  }

  if (data) {
    config.data = data;
  }

  try {
    const response = await axios(config);
    return response.data;
  } catch (error) {
    console.error(`❌ API Error on ${method} ${endpoint}:`, error.response?.data || error.message);
    throw error;
  }
}

// Test functions
async function testGuestSignup() {
  console.log('\n🧪 Testing Guest Signup...');

  const guestData = {
    fullName: 'Guest Parker',
    parkingName: 'Guest Parking Lot',
    deviceId: `guest_${Date.now()}`
  };

  const result = await apiCall('POST', '/auth/guest-signup', guestData);

  if (result.success && result.data.token) {
    console.log('✅ Guest signup successful');
    console.log('  - User ID:', result.data.user.id);
    console.log('  - Business ID:', result.data.user.businessId);
    console.log('  - Token received:', !!result.data.token);
    return true;
  }

  console.error('❌ Guest signup failed');
  return false;
}

async function testLogin() {
  console.log('\n🧪 Testing Login...');

  // First create a test user (using guest signup for simplicity)
  const signupData = {
    fullName: TEST_USER.fullName,
    parkingName: 'Test Parking',
    deviceId: TEST_USER.deviceId
  };

  const signupResult = await apiCall('POST', '/auth/guest-signup', signupData);
  const testUsername = signupResult.data.user.username;

  // Now test login
  const loginData = {
    username: testUsername,
    password: null, // Guest users don't need password
    deviceId: TEST_USER.deviceId
  };

  const result = await apiCall('POST', '/auth/login', loginData);

  if (result.success && result.data.token) {
    authToken = result.data.token;
    refreshToken = result.data.refreshToken;
    userId = result.data.user.id;

    console.log('✅ Login successful');
    console.log('  - User ID:', userId);
    console.log('  - Token received:', !!authToken);
    console.log('  - Refresh token received:', !!refreshToken);
    console.log('  - Session ID:', result.data.sessionId);
    return true;
  }

  console.error('❌ Login failed');
  return false;
}

async function testTokenValidation() {
  console.log('\n🧪 Testing Token Validation...');

  if (!authToken) {
    console.log('⏭️  Skipping - no auth token');
    return false;
  }

  const result = await apiCall('GET', '/auth/validate', null, authToken);

  if (result.success && result.data.user) {
    console.log('✅ Token validation successful');
    console.log('  - User verified:', result.data.user.id === userId);
    return true;
  }

  console.error('❌ Token validation failed');
  return false;
}

async function testSettingsPersistence() {
  console.log('\n🧪 Testing Settings Persistence...');

  if (!authToken) {
    console.log('⏭️  Skipping - no auth token');
    return false;
  }

  // Get current settings
  const getResult = await apiCall('GET', '/settings', null, authToken);
  console.log('  - Initial settings retrieved');

  // Update settings
  const newSettings = {
    businessName: 'Test Parking Business',
    businessAddress: '123 Test Street',
    businessPhone: '+91-9876543210',
    currency: 'INR',
    gracePeriodMinutes: 20,
    ticketIdPrefix: 'TST',
    enableGST: true,
    gstNumber: 'TEST123456789',
    gstPercentage: 18.0
  };

  const updateResult = await apiCall('PUT', '/settings', newSettings, authToken);

  if (updateResult.success) {
    console.log('✅ Settings update successful');

    // Verify persistence by getting settings again
    const verifyResult = await apiCall('GET', '/settings', null, authToken);

    if (verifyResult.data.businessName === newSettings.businessName) {
      console.log('✅ Settings persisted correctly');
      console.log('  - Business Name:', verifyResult.data.businessName);
      console.log('  - GST Enabled:', verifyResult.data.enableGST);
      return true;
    }
  }

  console.error('❌ Settings persistence failed');
  return false;
}

async function testVehicleCRUD() {
  console.log('\n🧪 Testing Vehicle CRUD...');

  if (!authToken) {
    console.log('⏭️  Skipping - no auth token');
    return false;
  }

  // Create vehicle entry
  const vehicleData = {
    vehicleNumber: 'UP32 AB 1234',
    vehicleType: {
      name: 'Car',
      hourlyRate: 20,
      minimumRate: 20
    },
    ticketId: `TST-${Date.now()}`,
    notes: 'Test vehicle entry'
  };

  const createResult = await apiCall('POST', '/vehicles', vehicleData, authToken);

  if (createResult.success && createResult.data.vehicle) {
    const vehicleId = createResult.data.vehicle.id;
    console.log('✅ Vehicle entry created');
    console.log('  - Vehicle ID:', vehicleId);
    console.log('  - Ticket ID:', createResult.data.vehicle.ticketId);

    // Get vehicles
    const getResult = await apiCall('GET', '/vehicles?status=parked', null, authToken);

    if (getResult.success && getResult.data.vehicles.length > 0) {
      console.log('✅ Vehicles retrieved');
      console.log('  - Total parked:', getResult.data.vehicles.length);

      // Exit vehicle
      const exitResult = await apiCall('PUT', `/vehicles/${vehicleId}/exit`, {
        exitTime: new Date().toISOString(),
        amount: 40
      }, authToken);

      if (exitResult.success) {
        console.log('✅ Vehicle exit recorded');
        console.log('  - Amount:', exitResult.data.vehicle.amount);
        console.log('  - Status:', exitResult.data.vehicle.status);
        return true;
      }
    }
  }

  console.error('❌ Vehicle CRUD failed');
  return false;
}

async function testLogout() {
  console.log('\n🧪 Testing Logout...');

  if (!authToken) {
    console.log('⏭️  Skipping - no auth token');
    return false;
  }

  const result = await apiCall('POST', '/auth/logout', null, authToken);

  if (result.success) {
    console.log('✅ Logout successful');

    // Verify token is invalid after logout
    try {
      await apiCall('GET', '/auth/validate', null, authToken);
      console.error('❌ Token still valid after logout!');
      return false;
    } catch (error) {
      if (error.response?.status === 401) {
        console.log('✅ Token properly invalidated');
        return true;
      }
    }
  }

  console.error('❌ Logout failed');
  return false;
}

async function testTokenRefresh() {
  console.log('\n🧪 Testing Token Refresh...');

  // Login first to get fresh tokens
  await testLogin();

  if (!refreshToken) {
    console.log('⏭️  Skipping - no refresh token');
    return false;
  }

  const result = await apiCall('POST', '/auth/refresh', { refreshToken });

  if (result.success && result.data.token) {
    console.log('✅ Token refresh successful');
    console.log('  - New token received:', !!result.data.token);
    console.log('  - New refresh token received:', !!result.data.refreshToken);

    // Test new token works
    const validateResult = await apiCall('GET', '/auth/validate', null, result.data.token);
    if (validateResult.success) {
      console.log('✅ New token is valid');
      return true;
    }
  }

  console.error('❌ Token refresh failed');
  return false;
}

// Main test runner
async function runAllTests() {
  console.log('🚀 Starting Complete Flow Tests');
  console.log('================================');
  console.log(`API URL: ${API_URL}`);

  const results = {
    guestSignup: false,
    login: false,
    tokenValidation: false,
    settingsPersistence: false,
    vehicleCRUD: false,
    tokenRefresh: false,
    logout: false
  };

  try {
    // Test health check first
    console.log('\n🧪 Testing Backend Health...');
    const health = await apiCall('GET', '/health');
    if (health.status === 'ok') {
      console.log('✅ Backend is healthy');
    }

    // Run tests
    results.guestSignup = await testGuestSignup();
    results.login = await testLogin();
    results.tokenValidation = await testTokenValidation();
    results.settingsPersistence = await testSettingsPersistence();
    results.vehicleCRUD = await testVehicleCRUD();
    results.tokenRefresh = await testTokenRefresh();
    results.logout = await testLogout();

  } catch (error) {
    console.error('\n❌ Fatal error during tests:', error.message);
  }

  // Summary
  console.log('\n================================');
  console.log('📊 TEST RESULTS SUMMARY');
  console.log('================================');

  let passed = 0;
  let failed = 0;

  for (const [test, result] of Object.entries(results)) {
    console.log(`${result ? '✅' : '❌'} ${test}`);
    if (result) passed++;
    else failed++;
  }

  console.log('\n--------------------------------');
  console.log(`Total: ${passed} passed, ${failed} failed`);
  console.log('================================');

  if (failed === 0) {
    console.log('\n🎉 All tests passed! The app is ready for deployment.');
  } else {
    console.log('\n⚠️  Some tests failed. Please review and fix the issues.');
  }

  process.exit(failed === 0 ? 0 : 1);
}

// Run tests
runAllTests();