-- ============================================
-- VendorBridge - Complete Supabase Database Setup
-- ============================================
-- Run this script in Supabase SQL Editor
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. COMPANIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    gstin TEXT UNIQUE,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    country TEXT DEFAULT 'India',
    phone TEXT,
    email TEXT,
    website TEXT,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. PROFILES TABLE (extends auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL CHECK (role IN ('officer', 'vendor', 'manager', 'admin')),
    company_id UUID REFERENCES companies(id),
    phone TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. VENDOR CATEGORIES
-- ============================================
CREATE TABLE IF NOT EXISTS vendor_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 4. VENDORS
-- ============================================
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES vendor_categories(id),
    business_name TEXT NOT NULL,
    gstin TEXT UNIQUE,
    contact_person TEXT,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    address TEXT,
    rating DECIMAL(3,2) DEFAULT 0.00 CHECK (rating >= 0 AND rating <= 5),
    total_orders INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 5. RFQS (Request for Quotations)
-- ============================================
CREATE TABLE IF NOT EXISTS rfqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_number TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    specifications TEXT,
    submission_deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    budget_estimate DECIMAL(15,2),
    created_by UUID REFERENCES profiles(id),
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'closed', 'cancelled')),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 6. RFQ ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS rfq_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_id UUID REFERENCES rfqs(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit TEXT,
    estimated_unit_price DECIMAL(15,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 7. RFQ VENDORS (assignments)
-- ============================================
CREATE TABLE IF NOT EXISTS rfq_vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_id UUID REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'invited' CHECK (status IN ('invited', 'viewed', 'submitted', 'declined')),
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(rfq_id, vendor_id)
);

-- ============================================
-- 8. VENDOR RATINGS
-- ============================================
CREATE TABLE IF NOT EXISTS vendor_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    rfq_id UUID REFERENCES rfqs(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    rated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(vendor_id, rfq_id)
);

-- ============================================
-- 10. QUOTATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_number TEXT UNIQUE NOT NULL,
    rfq_id UUID REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES vendors(id),
    total_amount DECIMAL(15,2) NOT NULL,
    delivery_timeline TEXT,
    valid_until TIMESTAMP WITH TIME ZONE,
    remarks TEXT,
    status TEXT DEFAULT 'submitted' CHECK (status IN ('submitted', 'under_review', 'selected', 'rejected')),
    is_lowest BOOLEAN DEFAULT false,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 10. QUOTATION ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS quotation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID REFERENCES quotations(id) ON DELETE CASCADE,
    rfq_item_id UUID REFERENCES rfq_items(id),
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 12. APPROVALS
-- ============================================
CREATE TABLE IF NOT EXISTS approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_number TEXT UNIQUE NOT NULL,
    rfq_id UUID REFERENCES rfqs(id),
    quotation_id UUID REFERENCES quotations(id),
    requested_by UUID REFERENCES profiles(id),
    approved_by UUID REFERENCES profiles(id),
    title TEXT NOT NULL,
    description TEXT,
    amount DECIMAL(15,2),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    remarks TEXT,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 12. APPROVAL HISTORY
-- ============================================
CREATE TABLE IF NOT EXISTS approval_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_id UUID REFERENCES approvals(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    performed_by UUID REFERENCES profiles(id),
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 14. PURCHASE ORDERS
-- ============================================
CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_number TEXT UNIQUE NOT NULL,
    rfq_id UUID REFERENCES rfqs(id),
    quotation_id UUID REFERENCES quotations(id),
    approval_id UUID REFERENCES approvals(id),
    vendor_id UUID REFERENCES vendors(id),
    billed_to_company UUID REFERENCES companies(id),
    total_amount DECIMAL(15,2) NOT NULL,
    igst_percent DECIMAL(5,2) DEFAULT 18.00,
    igst_amount DECIMAL(15,2),
    grand_total DECIMAL(15,2) NOT NULL,
    status TEXT DEFAULT 'created' CHECK (status IN ('created', 'sent', 'acknowledged', 'fulfilled', 'cancelled')),
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 14. PURCHASE ORDER ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 16. INVOICES
-- ============================================
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT UNIQUE NOT NULL,
    po_id UUID REFERENCES purchase_orders(id),
    vendor_id UUID REFERENCES vendors(id),
    billed_to_company UUID REFERENCES companies(id),
    subtotal DECIMAL(15,2) NOT NULL,
    igst_percent DECIMAL(5,2) DEFAULT 18.00,
    igst_amount DECIMAL(15,2),
    grand_total DECIMAL(15,2) NOT NULL,
    status TEXT DEFAULT 'generated' CHECK (status IN ('generated', 'sent', 'paid', 'overdue', 'cancelled')),
    due_date TIMESTAMP WITH TIME ZONE,
    paid_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 17. INVOICE ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 18. DOCUMENTS
-- ============================================
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_size INTEGER,
    file_type TEXT,
    uploaded_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 19. AUDIT LOGS
-- ============================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 19. ANALYTICS EVENTS
-- ============================================
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    event_data JSONB,
    user_id UUID REFERENCES profiles(id),
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_vendors_category ON vendors(category_id);
CREATE INDEX IF NOT EXISTS idx_vendors_email ON vendors(contact_email);
CREATE INDEX IF NOT EXISTS idx_rfqs_status ON rfqs(status);
CREATE INDEX IF NOT EXISTS idx_rfqs_created_by ON rfqs(created_by);
CREATE INDEX IF NOT EXISTS idx_quotations_rfq ON quotations(rfq_id);
CREATE INDEX IF NOT EXISTS idx_quotations_vendor ON quotations(vendor_id);
CREATE INDEX IF NOT EXISTS idx_quotations_status ON quotations(status);
CREATE INDEX IF NOT EXISTS idx_approvals_status ON approvals(status);
CREATE INDEX IF NOT EXISTS idx_approvals_requested_by ON approvals(requested_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor ON purchase_orders(vendor_id);
CREATE INDEX IF NOT EXISTS idx_invoices_po ON invoices(po_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_documents_entity ON documents(entity_type, entity_id);

-- ============================================
-- INITIAL DATA - VENDOR CATEGORIES
-- ============================================
INSERT INTO vendor_categories (name, description) VALUES
('Hardware IT', 'IT hardware, servers, computers, peripherals'),
('Office Stationery', 'Office supplies, stationery, furniture'),
('Networking Components', 'Network equipment, switches, routers, cables'),
('Software Licenses', 'Software subscriptions and licenses'),
('Facilities Management', 'Cleaning, maintenance, facilities services'),
('Logistics & Transport', 'Shipping, transport, logistics services')
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- INITIAL DATA - DEFAULT COMPANY
-- ============================================
INSERT INTO companies (name, gstin, address, city, state, pincode, country, email, is_verified) VALUES
('VendorBridge Corp', '24VENDOR0000A1Z5', 'Corporate Office, Business Park', 'Ahmedabad', 'Gujarat', '380001', 'India', 'admin@vendorbridge.com', true)
ON CONFLICT (gstin) DO NOTHING;

-- ============================================
-- TRIGGER: UPDATED_AT TIMESTAMP
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_companies_updated_at ON companies;
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_vendors_updated_at ON vendors;
CREATE TRIGGER update_vendors_updated_at BEFORE UPDATE ON vendors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_rfqs_updated_at ON rfqs;
CREATE TRIGGER update_rfqs_updated_at BEFORE UPDATE ON rfqs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_quotations_updated_at ON quotations;
CREATE TRIGGER update_quotations_updated_at BEFORE UPDATE ON quotations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_approvals_updated_at ON approvals;
CREATE TRIGGER update_approvals_updated_at BEFORE UPDATE ON approvals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_purchase_orders_updated_at ON purchase_orders;
CREATE TRIGGER update_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_invoices_updated_at ON invoices;
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
