/**
 * Middleware to handle data transformation between Flutter (camelCase) and Backend (snake_case)
 */

/**
 * Convert snake_case to camelCase
 */
function toCamelCase(obj) {
  if (obj === null || obj === undefined) return obj;

  if (Array.isArray(obj)) {
    return obj.map(item => toCamelCase(item));
  }

  if (typeof obj !== 'object' || obj instanceof Date) {
    return obj;
  }

  const converted = {};
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const camelKey = key.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase());
      converted[camelKey] = toCamelCase(obj[key]);
    }
  }
  return converted;
}

/**
 * Convert camelCase to snake_case
 */
function toSnakeCase(obj) {
  if (obj === null || obj === undefined) return obj;

  if (Array.isArray(obj)) {
    return obj.map(item => toSnakeCase(item));
  }

  if (typeof obj !== 'object' || obj instanceof Date) {
    return obj;
  }

  const converted = {};
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const snakeKey = key.replace(/[A-Z]/g, match => '_' + match.toLowerCase());
      converted[snakeKey] = toSnakeCase(obj[key]);
    }
  }
  return converted;
}

/**
 * Middleware to transform request body from camelCase to snake_case
 */
const transformRequest = (req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    // Store original body for debugging
    req.originalBody = JSON.parse(JSON.stringify(req.body));

    // Transform to snake_case for database
    req.body = toSnakeCase(req.body);

    // Special handling for vehicle data
    if (req.path.includes('/vehicles')) {
      // Handle nested vehicle_type object
      if (req.body.vehicle_type && typeof req.body.vehicle_type === 'object') {
        // If vehicle_type is an object, extract just the name for backward compatibility
        req.body.vehicle_type_name = req.body.vehicle_type.name || req.body.vehicle_type.type;
        req.body.hourly_rate = req.body.vehicle_type.hourly_rate || req.body.vehicle_type.hourlyRate;

        // For database storage, we might want just the type name
        req.body.vehicle_type = req.body.vehicle_type_name;
      }
    }
  }
  next();
};

/**
 * Middleware to transform response from snake_case to camelCase
 */
const transformResponse = (req, res, next) => {
  const originalJson = res.json;

  res.json = function(data) {
    // Transform to camelCase for Flutter
    const transformed = toCamelCase(data);

    // Special handling for vehicle responses
    if (req.path.includes('/vehicles') && transformed) {
      const transformVehicle = (vehicle) => {
        if (vehicle && vehicle.vehicleType && typeof vehicle.vehicleType === 'string') {
          // Convert simple string to object format expected by Flutter
          vehicle.vehicleType = {
            id: vehicle.vehicleType.toLowerCase().replace(/\s+/g, '_'),
            name: vehicle.vehicleType,
            type: vehicle.vehicleType,
            hourlyRate: vehicle.hourlyRate || 0
          };
        }
        return vehicle;
      };

      if (transformed.data) {
        if (Array.isArray(transformed.data)) {
          transformed.data = transformed.data.map(transformVehicle);
        } else {
          transformed.data = transformVehicle(transformed.data);
        }
      } else if (Array.isArray(transformed)) {
        return originalJson.call(this, transformed.map(transformVehicle));
      } else if (transformed.vehicleType) {
        return originalJson.call(this, transformVehicle(transformed));
      }
    }

    return originalJson.call(this, transformed);
  };

  next();
};

module.exports = {
  transformRequest,
  transformResponse,
  toCamelCase,
  toSnakeCase
};