const axios = require('axios');

// Change this to your Railway backend URL
const BASE_URL = 'http://localhost:3000/api';
// For Railway: const BASE_URL = 'https://parkease-production-6679.up.railway.app/api';

let authToken = '';
let refreshToken = '';
let userId = '';
let vehicleId = '';

async function testEndpoints() {
  console.log('🚀 Testing ParkEase API Endpoints...\n');

  try {
    // Test 1: Create test user (Guest Signup)
    console.log('1️⃣  Testing Guest Signup...');
    const signupResponse = await axios.post(`${BASE_URL}/auth/guest-signup`, {
      username: 'munshi',
      fullName: 'Munshi Test User',
      deviceId: 'test-device-123'
    });

    console.log('✅ Guest signup successful');
    console.log('   User ID:', signupResponse.data.data.user.id);
    console.log('   Username:', signupResponse.data.data.user.username);
    console.log('   Trial expires:', signupResponse.data.data.user.trialExpiresAt);

    authToken = signupResponse.data.data.token;
    refreshToken = signupResponse.data.data.refreshToken;
    userId = signupResponse.data.data.user.id;

    // Test 2: Login with the user
    console.log('\n2️⃣  Testing Login...');
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      username: 'munshi',
      deviceId: 'test-device-123'
    });

    console.log('✅ Login successful');
    authToken = loginResponse.data.data.token;

    // Test 3: Validate session
    console.log('\n3️⃣  Testing Session Validation...');
    const validateResponse = await axios.get(`${BASE_URL}/auth/validate`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Session validation successful');
    console.log('   Validated user:', validateResponse.data.data.user.username);

    // Test 4: Get settings
    console.log('\n4️⃣  Testing Get Settings...');
    const settingsResponse = await axios.get(`${BASE_URL}/settings`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Settings retrieved successfully');
    console.log('   Business name:', settingsResponse.data.data.settings.business_name);

    // Test 5: Update settings
    console.log('\n5️⃣  Testing Update Settings...');
    const updateSettingsResponse = await axios.put(`${BASE_URL}/settings`, {
      business_name: 'Munshi Parking Center',
      business_address: '123 Test Street, Test City',
      business_phone: '+91-9876543210'
    }, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Settings updated successfully');
    console.log('   Updated business name:', updateSettingsResponse.data.data.settings.business_name);

    // Test 6: Add vehicle
    console.log('\n6️⃣  Testing Add Vehicle...');
    const addVehicleResponse = await axios.post(`${BASE_URL}/vehicles`, {
      vehicleNumber: 'MH01AB1234',
      vehicleType: 'Car',
      hourlyRate: 20,
      minimumRate: 20,
      ticketId: 'PE001',
      notes: 'Test vehicle entry'
    }, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Vehicle added successfully');
    console.log('   Vehicle ID:', addVehicleResponse.data.data.vehicle.id);
    console.log('   Vehicle Number:', addVehicleResponse.data.data.vehicle.vehicle_number);
    console.log('   Status:', addVehicleResponse.data.data.vehicle.status);

    vehicleId = addVehicleResponse.data.data.vehicle.id;

    // Test 7: Get vehicles
    console.log('\n7️⃣  Testing Get Vehicles...');
    const vehiclesResponse = await axios.get(`${BASE_URL}/vehicles`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Vehicles retrieved successfully');
    console.log('   Total vehicles:', vehiclesResponse.data.data.vehicles.length);

    // Test 8: Add another vehicle (Bike)
    console.log('\n8️⃣  Testing Add Another Vehicle (Bike)...');
    const addBikeResponse = await axios.post(`${BASE_URL}/vehicles`, {
      vehicleNumber: 'MH02XY5678',
      vehicleType: 'Bike',
      hourlyRate: 10,
      minimumRate: 10,
      ticketId: 'PE002',
      notes: 'Test bike entry'
    }, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Bike added successfully');
    console.log('   Vehicle Number:', addBikeResponse.data.data.vehicle.vehicle_number);

    // Test 9: Vehicle exit
    console.log('\n9️⃣  Testing Vehicle Exit...');
    const exitResponse = await axios.put(`${BASE_URL}/vehicles/${vehicleId}/exit`, {
      exitTime: new Date().toISOString(),
      amount: 25.00,
      notes: 'Test vehicle exit'
    }, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Vehicle exit successful');
    console.log('   Exit amount:', exitResponse.data.data.vehicle.amount);
    console.log('   Duration:', exitResponse.data.data.vehicle.duration_minutes, 'minutes');
    console.log('   Status:', exitResponse.data.data.vehicle.status);

    // Test 10: Vehicle sync (bulk upload)
    console.log('\n🔟 Testing Vehicle Sync...');
    const syncResponse = await axios.post(`${BASE_URL}/vehicles/sync`, {
      vehicles: [
        {
          vehicleNumber: 'KA03CD9876',
          vehicleType: 'Auto Rickshaw',
          entryTime: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
          hourlyRate: 15,
          minimumRate: 15,
          ticketId: 'PE003',
          status: 'parked'
        },
        {
          vehicleNumber: 'TN04EF5432',
          vehicleType: 'E-Rickshaw',
          entryTime: new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString(), // 1 hour ago
          exitTime: new Date().toISOString(),
          amount: 18.00,
          hourlyRate: 12,
          minimumRate: 12,
          ticketId: 'PE004',
          status: 'exited'
        }
      ]
    }, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Vehicle sync successful');
    console.log('   Synced vehicles:', syncResponse.data.data.synced);

    // Test 11: Analytics dashboard
    console.log('\n1️⃣1️⃣ Testing Analytics Dashboard...');
    const analyticsResponse = await axios.get(`${BASE_URL}/analytics/dashboard`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Analytics retrieved successfully');
    console.log('   Total vehicles:', analyticsResponse.data.data.stats.total_vehicles);
    console.log('   Parked vehicles:', analyticsResponse.data.data.stats.parked_count);
    console.log('   Exited vehicles:', analyticsResponse.data.data.stats.exited_count);
    console.log('   Total revenue:', '₹' + analyticsResponse.data.data.stats.total_revenue);

    // Test 12: Token refresh
    console.log('\n1️⃣2️⃣ Testing Token Refresh...');
    const refreshResponse = await axios.post(`${BASE_URL}/auth/refresh`, {
      refreshToken: refreshToken
    });

    console.log('✅ Token refresh successful');
    authToken = refreshResponse.data.data.token;

    // Test 13: Logout
    console.log('\n1️⃣3️⃣ Testing Logout...');
    const logoutResponse = await axios.post(`${BASE_URL}/auth/logout`, {}, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    console.log('✅ Logout successful');

    console.log('\n🎉 All tests completed successfully!');
    console.log('\n📊 Summary:');
    console.log('   ✅ Authentication: Guest signup, login, validation, refresh, logout');
    console.log('   ✅ Settings: Get and update business settings');
    console.log('   ✅ Vehicles: Add, list, exit, bulk sync');
    console.log('   ✅ Analytics: Dashboard with stats');
    console.log('   ✅ All 13 API endpoints working correctly');

  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    if (error.response?.status) {
      console.error('   Status:', error.response.status);
    }
  }
}

testEndpoints();