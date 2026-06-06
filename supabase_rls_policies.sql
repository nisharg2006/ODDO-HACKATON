-- ============================================
-- VendorBridge - Row Level Security (RLS) Policies
-- ============================================
-- Run this AFTER supabase_setup.sql
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfq_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PROFILES RLS POLICIES
-- ============================================
-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins can update all profiles
CREATE POLICY "Admins can update all profiles" ON profiles
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Service role can insert profiles (for signup trigger)
CREATE POLICY "Service role can insert profiles" ON profiles
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- COMPANIES RLS POLICIES
-- ============================================
-- Public can view verified companies
CREATE POLICY "Public can view verified companies" ON companies
    FOR SELECT USING (is_verified = true);

-- Users in company can view their company
CREATE POLICY "Users can view own company" ON companies
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND company_id = companies.id
        )
    );

-- Admins can view all companies
CREATE POLICY "Admins can view all companies" ON companies
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins can manage companies
CREATE POLICY "Admins can manage companies" ON companies
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- VENDOR CATEGORIES RLS POLICIES
-- ============================================
-- Public can view categories
CREATE POLICY "Public can view categories" ON vendor_categories
    FOR SELECT USING (true);

-- Admins can manage categories
CREATE POLICY "Admins can manage categories" ON vendor_categories
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- VENDORS RLS POLICIES
-- ============================================
-- Public can view verified vendors
CREATE POLICY "Public can view verified vendors" ON vendors
    FOR SELECT USING (is_verified = true);

-- Officers and managers can view all vendors
CREATE POLICY "Officers can view all vendors" ON vendors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view their own vendor record
CREATE POLICY "Vendors can view own record" ON vendors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND company_id = vendors.company_id
        )
    );

-- Admins can manage vendors
CREATE POLICY "Admins can manage vendors" ON vendors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Officers can create vendors
CREATE POLICY "Officers can create vendors" ON vendors
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
    );

-- ============================================
-- VENDOR RATINGS RLS POLICIES
-- ============================================
-- Public can view ratings
CREATE POLICY "Public can view ratings" ON vendor_ratings
    FOR SELECT USING (true);

-- Users can view their own ratings
CREATE POLICY "Users can view own ratings" ON vendor_ratings
    FOR SELECT USING (rated_by = auth.uid());

-- Officers can create ratings
CREATE POLICY "Officers can create ratings" ON vendor_ratings
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- ============================================
-- RFQS RLS POLICIES
-- ============================================
-- Officers, managers, admins can view all RFQs
CREATE POLICY "Officers can view RFQs" ON rfqs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view RFQs they're invited to
CREATE POLICY "Vendors can view invited RFQs" ON rfqs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM rfq_vendors rv
            JOIN vendors v ON rv.vendor_id = v.id
            JOIN profiles p ON p.company_id = v.company_id
            WHERE rv.rfq_id = rfqs.id AND p.id = auth.uid()
        )
    );

-- Officers can create RFQs
CREATE POLICY "Officers can create RFQs" ON rfqs
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
        AND created_by = auth.uid()
    );

-- Creators can update their RFQs
CREATE POLICY "Creators can update RFQs" ON rfqs
    FOR UPDATE USING (created_by = auth.uid());

-- ============================================
-- RFQ ITEMS RLS POLICIES
-- ============================================
-- Access through parent RFQ
CREATE POLICY "Access through RFQ" ON rfq_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM rfqs WHERE id = rfq_items.rfq_id AND
            (
                EXISTS (
                    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
                )
                OR
                EXISTS (
                    SELECT 1 FROM rfq_vendors rv
                    JOIN vendors v ON rv.vendor_id = v.id
                    JOIN profiles p ON p.company_id = v.company_id
                    WHERE rv.rfq_id = rfq_items.rfq_id AND p.id = auth.uid()
                )
            )
        )
    );

-- ============================================
-- RFQ VENDORS RLS POLICIES
-- ============================================
-- Officers can view all RFQ vendor assignments
CREATE POLICY "Officers can view RFQ vendors" ON rfq_vendors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view their assignments
CREATE POLICY "Vendors can view assignments" ON rfq_vendors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors v
            JOIN profiles p ON p.company_id = v.company_id
            WHERE v.id = rfq_vendors.vendor_id AND p.id = auth.uid()
        )
    );

-- Officers can manage RFQ vendors
CREATE POLICY "Officers can manage RFQ vendors" ON rfq_vendors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
    );

-- ============================================
-- QUOTATIONS RLS POLICIES
-- ============================================
-- Officers, managers, admins can view all quotations
CREATE POLICY "Officers can view quotations" ON quotations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view their own quotations
CREATE POLICY "Vendors can view own quotations" ON quotations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors v
            JOIN profiles p ON p.company_id = v.company_id
            WHERE v.id = quotations.vendor_id AND p.id = auth.uid()
        )
    );

-- Vendors can create quotations
CREATE POLICY "Vendors can create quotations" ON quotations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM vendors v
            JOIN profiles p ON p.company_id = v.company_id
            WHERE v.id = quotations.vendor_id AND p.id = auth.uid()
        )
    );

-- Officers can update quotation status
CREATE POLICY "Officers can update quotations" ON quotations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- ============================================
-- QUOTATION ITEMS RLS POLICIES
-- ============================================
-- Access through parent quotation
CREATE POLICY "Access through quotation" ON quotation_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM quotations q WHERE q.id = quotation_items.quotation_id AND
            (
                EXISTS (
                    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
                )
                OR
                EXISTS (
                    SELECT 1 FROM vendors v
                    JOIN profiles p ON p.company_id = v.company_id
                    WHERE v.id = q.vendor_id AND p.id = auth.uid()
                )
            )
        )
    );

-- ============================================
-- APPROVALS RLS POLICIES
-- ============================================
-- Officers can view approvals they requested
CREATE POLICY "Officers can view own approvals" ON approvals
    FOR SELECT USING (requested_by = auth.uid());

-- Managers can view pending approvals
CREATE POLICY "Managers can view approvals" ON approvals
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('manager', 'admin')
        )
    );

-- Officers can create approvals
CREATE POLICY "Officers can create approvals" ON approvals
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
        AND requested_by = auth.uid()
    );

-- Managers can approve/reject
CREATE POLICY "Managers can approve" ON approvals
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('manager', 'admin')
        )
    );

-- ============================================
-- APPROVAL HISTORY RLS POLICIES
-- ============================================
-- Access through parent approval
CREATE POLICY "Access through approval" ON approval_history
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM approvals a WHERE a.id = approval_history.approval_id AND
            (
                a.requested_by = auth.uid()
                OR
                EXISTS (
                    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('manager', 'admin')
                )
            )
        )
    );

-- ============================================
-- PURCHASE ORDERS RLS POLICIES
-- ============================================
-- Officers, managers, admins can view all POs
CREATE POLICY "Officers can view POs" ON purchase_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view POs sent to them
CREATE POLICY "Vendors can view POs" ON purchase_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors v
            JOIN profiles p ON p.company_id = v.company_id
            WHERE v.id = purchase_orders.vendor_id AND p.id = auth.uid()
        )
    );

-- Officers can create POs
CREATE POLICY "Officers can create POs" ON purchase_orders
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
        AND created_by = auth.uid()
    );

-- ============================================
-- PURCHASE ORDER ITEMS RLS POLICIES
-- ============================================
-- Access through parent PO
CREATE POLICY "Access through PO" ON purchase_order_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM purchase_orders po WHERE po.id = purchase_order_items.po_id AND
            (
                EXISTS (
                    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
                )
                OR
                EXISTS (
                    SELECT 1 FROM vendors v
                    JOIN profiles p ON p.company_id = v.company_id
                    WHERE v.id = po.vendor_id AND p.id = auth.uid()
                )
            )
        )
    );

-- ============================================
-- INVOICES RLS POLICIES
-- ============================================
-- Officers, managers, admins can view all invoices
CREATE POLICY "Officers can view invoices" ON invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Vendors can view their invoices
CREATE POLICY "Vendors can view invoices" ON invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM vendors v
            JOIN profiles p ON p.company_id = v.company_id
            WHERE v.id = invoices.vendor_id AND p.id = auth.uid()
        )
    );

-- Officers can create invoices
CREATE POLICY "Officers can create invoices" ON invoices
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'admin')
        )
    );

-- ============================================
-- INVOICE ITEMS RLS POLICIES
-- ============================================
-- Access through parent invoice
CREATE POLICY "Access through invoice" ON invoice_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM invoices i WHERE i.id = invoice_items.invoice_id AND
            (
                EXISTS (
                    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
                )
                OR
                EXISTS (
                    SELECT 1 FROM vendors v
                    JOIN profiles p ON p.company_id = v.company_id
                    WHERE v.id = i.vendor_id AND p.id = auth.uid()
                )
            )
        )
    );

-- ============================================
-- DOCUMENTS RLS POLICIES
-- ============================================
-- Users can view documents they uploaded
CREATE POLICY "Users can view own documents" ON documents
    FOR SELECT USING (uploaded_by = auth.uid());

-- Officers can view all documents
CREATE POLICY "Officers can view all documents" ON documents
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('officer', 'manager', 'admin')
        )
    );

-- Users can upload documents
CREATE POLICY "Users can upload documents" ON documents
    FOR INSERT WITH CHECK (uploaded_by = auth.uid());

-- ============================================
-- AUDIT LOGS RLS POLICIES
-- ============================================
-- Users can view their own audit logs
CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT USING (user_id = auth.uid());

-- Admins can view all audit logs
CREATE POLICY "Admins can view all audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- System can insert audit logs
CREATE POLICY "System can insert audit logs" ON audit_logs
    FOR INSERT WITH CHECK (true);

-- ============================================
-- ANALYTICS EVENTS RLS POLICIES
-- ============================================
-- Users can view their own analytics
CREATE POLICY "Users can view own analytics" ON analytics_events
    FOR SELECT USING (user_id = auth.uid());

-- Admins can view all analytics
CREATE POLICY "Admins can view all analytics" ON analytics_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- System can insert analytics
CREATE POLICY "System can insert analytics" ON analytics_events
    FOR INSERT WITH CHECK (true);
