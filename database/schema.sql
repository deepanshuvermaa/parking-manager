-- ParkEase Database Schema
-- This file contains all the tables and initial data for the ParkEase parking management system

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist (for clean setup)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Users table (authentication and user management)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    password_hash VARCHAR(255), -- For admin users, NULL for guest users
    user_type VARCHAR(20) DEFAULT 'guest' CHECK (user_type IN ('guest', 'admin', 'premium')),
    device_id VARCHAR(100), -- For guest users device binding
    is_active BOOLEAN DEFAULT true,
    trial_starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    trial_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '3 days',
    subscription_expires_at TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    login_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table (user-specific configuration)
CREATE TABLE settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    business_name VARCHAR(100) DEFAULT 'My Parking Business',
    business_address TEXT,
    business_phone VARCHAR(20),
    business_email VARCHAR(100),
    gst_number VARCHAR(20),

    -- Receipt settings
    receipt_header TEXT,
    receipt_footer TEXT DEFAULT 'Thank you for parking with us!',
    company_logo TEXT, -- Base64 encoded image

    -- Printer settings
    printer_name VARCHAR(100),
    printer_type VARCHAR(20) DEFAULT 'thermal' CHECK (printer_type IN ('thermal', 'inkjet', 'laser')),
    print_copies INTEGER DEFAULT 1,
    auto_print BOOLEAN DEFAULT true,

    -- Vehicle types and pricing (JSON)
    vehicle_types_json JSONB DEFAULT '[
        {"name": "Car", "hourlyRate": 20, "dailyRate": 200, "monthlyRate": 5000, "minimumCharge": 20, "freeMinutes": 15},
        {"name": "Bike", "hourlyRate": 10, "dailyRate": 100, "monthlyRate": 2500, "minimumCharge": 10, "freeMinutes": 10},
        {"name": "Scooter", "hourlyRate": 10, "dailyRate": 100, "monthlyRate": 2500, "minimumCharge": 10, "freeMinutes": 10},
        {"name": "Auto Rickshaw", "hourlyRate": 15, "dailyRate": 150, "monthlyRate": 3000, "minimumCharge": 15, "freeMinutes": 10},
        {"name": "E-Rickshaw", "hourlyRate": 12, "dailyRate": 120, "monthlyRate": 2500, "minimumCharge": 12, "freeMinutes": 10},
        {"name": "Cycle", "hourlyRate": 5, "dailyRate": 50, "monthlyRate": 1000, "minimumCharge": 5, "freeMinutes": 30},
        {"name": "E-Cycle", "hourlyRate": 8, "dailyRate": 80, "monthlyRate": 1500, "minimumCharge": 8, "freeMinutes": 20},
        {"name": "Tempo", "hourlyRate": 25, "dailyRate": 250, "monthlyRate": 6000, "minimumCharge": 25, "freeMinutes": 15},
        {"name": "Mini Truck", "hourlyRate": 30, "dailyRate": 300, "monthlyRate": 7500, "minimumCharge": 30, "freeMinutes": 15},
        {"name": "SUV", "hourlyRate": 30, "dailyRate": 300, "monthlyRate": 7500, "minimumCharge": 30, "freeMinutes": 15},
        {"name": "Van", "hourlyRate": 25, "dailyRate": 250, "monthlyRate": 6000, "minimumCharge": 25, "freeMinutes": 15},
        {"name": "Bus", "hourlyRate": 50, "dailyRate": 500, "monthlyRate": 12000, "minimumCharge": 50, "freeMinutes": 10},
        {"name": "Truck", "hourlyRate": 40, "dailyRate": 400, "monthlyRate": 10000, "minimumCharge": 40, "freeMinutes": 10}
    ]'::jsonb,

    -- Ticket ID settings
    ticket_prefix VARCHAR(10) DEFAULT 'PE',
    ticket_counter INTEGER DEFAULT 1,

    -- Grace period and other settings
    grace_period_minutes INTEGER DEFAULT 15,
    late_fee_per_hour DECIMAL(10,2) DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vehicles table (parking records)
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    vehicle_number VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(50) NOT NULL,
    entry_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    exit_time TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    hourly_rate DECIMAL(10,2),
    minimum_rate DECIMAL(10,2),
    amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'parked' CHECK (status IN ('parked', 'exited')),
    ticket_id VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions table (active user sessions for multi-device management)
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    refresh_token_hash VARCHAR(255) NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit logs table (track all important actions)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL, -- 'login', 'logout', 'vehicle_entry', 'vehicle_exit', etc.
    entity_type VARCHAR(50), -- 'user', 'vehicle', 'settings'
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    changes JSONB, -- Computed diff between old and new values
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_device_id ON users(device_id);
CREATE INDEX idx_users_user_type ON users(user_type);
CREATE INDEX idx_users_is_active ON users(is_active);

CREATE INDEX idx_vehicles_user_id ON vehicles(user_id);
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_vehicles_entry_time ON vehicles(entry_time);
CREATE INDEX idx_vehicles_ticket_id ON vehicles(ticket_id);
CREATE INDEX idx_vehicles_vehicle_number ON vehicles(vehicle_number);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_device_id ON sessions(device_id);
CREATE INDEX idx_sessions_is_active ON sessions(is_active);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX idx_settings_user_id ON settings(user_id);

-- Insert default admin user
INSERT INTO users (
    id,
    username,
    full_name,
    email,
    password_hash,
    user_type,
    device_id,
    is_active,
    trial_starts_at,
    trial_expires_at,
    subscription_expires_at
) VALUES (
    uuid_generate_v4(),
    'admin',
    'Administrator',
    'admin@parkease.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: 'password'
    'admin',
    NULL,
    true,
    NOW(),
    NOW() + INTERVAL '365 days', -- 1 year trial for admin
    NOW() + INTERVAL '365 days'
);

-- Insert default settings for admin user
INSERT INTO settings (
    user_id,
    business_name,
    business_address,
    receipt_header,
    receipt_footer
) VALUES (
    (SELECT id FROM users WHERE username = 'admin'),
    'ParkEase Parking Management',
    'Your Business Address Here',
    'Welcome to ParkEase Parking',
    'Thank you for choosing ParkEase!\nPowered by Go2 Billing Softwares'
);

-- Update timestamps function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at columns
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Clean up old sessions function (can be called periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sessions WHERE expires_at < NOW() OR is_active = false;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE 'plpgsql';

-- Clean up old audit logs function (keep only last 6 months)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '6 months';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE 'plpgsql';

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '✅ ParkEase database schema created successfully!';
    RAISE NOTICE '📊 Tables created: users, settings, vehicles, sessions, audit_logs';
    RAISE NOTICE '👤 Default admin user: username=admin, password=password';
    RAISE NOTICE '🚀 Database is ready for use!';
END $$;