-- ============================================
-- VendorBridge - Database Functions & Triggers
-- ============================================
-- Run this AFTER supabase_rls_policies.sql
-- ============================================

-- ============================================
-- 1. AUTO-CREATE PROFILE ON SIGNUP
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'officer')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the signup
    RAISE LOG 'Error creating profile for user %: %', NEW.email, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- 2. GENERATE RFQ NUMBER
-- ============================================
CREATE OR REPLACE FUNCTION generate_rfq_number()
RETURNS TRIGGER AS $$
DECLARE
    year_part TEXT;
    sequence_num INTEGER;
    rfq_num TEXT;
BEGIN
    year_part := TO_CHAR(NEW.created_at, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(rfq_number FROM 12 FOR 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM rfqs
    WHERE rfq_number LIKE 'RFQ-' || year_part || '-%';
    
    rfq_num := 'RFQ-' || year_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
    NEW.rfq_number := rfq_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_rfq_number_before_insert
    BEFORE INSERT ON rfqs
    FOR EACH ROW EXECUTE FUNCTION generate_rfq_number();

-- ============================================
-- 3. GENERATE QUOTATION NUMBER
-- ============================================
CREATE OR REPLACE FUNCTION generate_quotation_number()
RETURNS TRIGGER AS $$
DECLARE
    year_part TEXT;
    sequence_num INTEGER;
    quote_num TEXT;
BEGIN
    year_part := TO_CHAR(NEW.created_at, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(quotation_number FROM 10 FOR 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM quotations
    WHERE quotation_number LIKE 'QTN-' || year_part || '-%';
    
    quote_num := 'QTN-' || year_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
    NEW.quotation_number := quote_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_quotation_number_before_insert
    BEFORE INSERT ON quotations
    FOR EACH ROW EXECUTE FUNCTION generate_quotation_number();

-- ============================================
-- 4. GENERATE APPROVAL NUMBER
-- ============================================
CREATE OR REPLACE FUNCTION generate_approval_number()
RETURNS TRIGGER AS $$
DECLARE
    year_part TEXT;
    sequence_num INTEGER;
    appr_num TEXT;
BEGIN
    year_part := TO_CHAR(NEW.created_at, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(approval_number FROM 10 FOR 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM approvals
    WHERE approval_number LIKE 'APR-' || year_part || '-%';
    
    appr_num := 'APR-' || year_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
    NEW.approval_number := appr_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_approval_number_before_insert
    BEFORE INSERT ON approvals
    FOR EACH ROW EXECUTE FUNCTION generate_approval_number();

-- ============================================
-- 5. GENERATE PO NUMBER
-- ============================================
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
DECLARE
    year_part TEXT;
    sequence_num INTEGER;
    po_num TEXT;
BEGIN
    year_part := TO_CHAR(NEW.created_at, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(po_number FROM 4 FOR 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM purchase_orders
    WHERE po_number LIKE 'PO-' || year_part || '-%';
    
    po_num := 'PO-' || year_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
    NEW.po_number := po_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_po_number_before_insert
    BEFORE INSERT ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION generate_po_number();

-- ============================================
-- 6. GENERATE INVOICE NUMBER
-- ============================================
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
    year_part TEXT;
    sequence_num INTEGER;
    inv_num TEXT;
BEGIN
    year_part := TO_CHAR(NEW.created_at, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM 5 FOR 4) AS INTEGER)), 0) + 1
    INTO sequence_num
    FROM invoices
    WHERE invoice_number LIKE 'INV-' || year_part || '-%';
    
    inv_num := 'INV-' || year_part || '-' || LPAD(sequence_num::TEXT, 4, '0');
    NEW.invoice_number := inv_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_invoice_number_before_insert
    BEFORE INSERT ON invoices
    FOR EACH ROW EXECUTE FUNCTION generate_invoice_number();

-- ============================================
-- 7. CALCULATE QUOTATION TOTAL
-- ============================================
CREATE OR REPLACE FUNCTION calculate_quotation_total()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE quotations
        SET total_amount = (
            SELECT COALESCE(SUM(line_total), 0)
            FROM quotation_items
            WHERE quotation_id = NEW.quotation_id
        )
        WHERE id = NEW.quotation_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE quotations
        SET total_amount = (
            SELECT COALESCE(SUM(line_total), 0)
            FROM quotation_items
            WHERE quotation_id = OLD.quotation_id
        )
        WHERE id = OLD.quotation_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_quotation_total_after_item_change
    AFTER INSERT OR UPDATE OR DELETE ON quotation_items
    FOR EACH ROW EXECUTE FUNCTION calculate_quotation_total();

-- ============================================
-- 8. MARK LOWEST QUOTATION
-- ============================================
CREATE OR REPLACE FUNCTION mark_lowest_quotation()
RETURNS TRIGGER AS $$
BEGIN
    -- Reset all is_lowest for this RFQ
    UPDATE quotations
    SET is_lowest = false
    WHERE rfq_id = NEW.rfq_id;
    
    -- Mark the lowest quotation
    UPDATE quotations
    SET is_lowest = true
    WHERE id = (
        SELECT id FROM quotations
        WHERE rfq_id = NEW.rfq_id AND status = 'submitted'
        ORDER BY total_amount ASC
        LIMIT 1
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mark_lowest_quotation_after_insert
    AFTER INSERT ON quotations
    FOR EACH ROW EXECUTE FUNCTION mark_lowest_quotation();

-- ============================================
-- 9. CALCULATE PO TOTALS
-- ============================================
CREATE OR REPLACE FUNCTION calculate_po_totals()
RETURNS TRIGGER AS $$
DECLARE
    subtotal DECIMAL(15,2);
    igst_amt DECIMAL(15,2);
    grand_total DECIMAL(15,2);
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(line_total), 0)
        INTO subtotal
        FROM purchase_order_items
        WHERE po_id = NEW.po_id;
        
        igst_amt := subtotal * (NEW.igst_percent / 100);
        grand_total := subtotal + igst_amt;
        
        UPDATE purchase_orders
        SET total_amount = subtotal,
            igst_amount = igst_amt,
            grand_total = grand_total
        WHERE id = NEW.po_id;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT COALESCE(SUM(line_total), 0)
        INTO subtotal
        FROM purchase_order_items
        WHERE po_id = OLD.po_id;
        
        igst_amt := subtotal * ((SELECT igst_percent FROM purchase_orders WHERE id = OLD.po_id) / 100);
        grand_total := subtotal + igst_amt;
        
        UPDATE purchase_orders
        SET total_amount = subtotal,
            igst_amount = igst_amt,
            grand_total = grand_total
        WHERE id = OLD.po_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_po_totals_after_item_change
    AFTER INSERT OR UPDATE OR DELETE ON purchase_order_items
    FOR EACH ROW EXECUTE FUNCTION calculate_po_totals();

-- ============================================
-- 10. CALCULATE INVOICE TOTALS
-- ============================================
CREATE OR REPLACE FUNCTION calculate_invoice_totals()
RETURNS TRIGGER AS $$
DECLARE
    subtotal DECIMAL(15,2);
    igst_amt DECIMAL(15,2);
    grand_total DECIMAL(15,2);
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(line_total), 0)
        INTO subtotal
        FROM invoice_items
        WHERE invoice_id = NEW.invoice_id;
        
        igst_amt := subtotal * (NEW.igst_percent / 100);
        grand_total := subtotal + igst_amt;
        
        UPDATE invoices
        SET subtotal = subtotal,
            igst_amount = igst_amt,
            grand_total = grand_total
        WHERE id = NEW.invoice_id;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT COALESCE(SUM(line_total), 0)
        INTO subtotal
        FROM invoice_items
        WHERE invoice_id = OLD.invoice_id;
        
        igst_amt := subtotal * ((SELECT igst_percent FROM invoices WHERE id = OLD.invoice_id) / 100);
        grand_total := subtotal + igst_amt;
        
        UPDATE invoices
        SET subtotal = subtotal,
            igst_amount = igst_amt,
            grand_total = grand_total
        WHERE id = OLD.invoice_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_invoice_totals_after_item_change
    AFTER INSERT OR UPDATE OR DELETE ON invoice_items
    FOR EACH ROW EXECUTE FUNCTION calculate_invoice_totals();

-- ============================================
-- 11. UPDATE VENDOR RATING
-- ============================================
CREATE OR REPLACE FUNCTION update_vendor_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating DECIMAL(3,2);
BEGIN
    SELECT COALESCE(AVG(rating), 0)
    INTO avg_rating
    FROM vendor_ratings
    WHERE vendor_id = NEW.vendor_id;
    
    UPDATE vendors
    SET rating = avg_rating
    WHERE id = NEW.vendor_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_vendor_rating_after_rating
    AFTER INSERT OR UPDATE ON vendor_ratings
    FOR EACH ROW EXECUTE FUNCTION update_vendor_rating();

-- ============================================
-- 12. INCREMENT VENDOR ORDER COUNT
-- ============================================
CREATE OR REPLACE FUNCTION increment_vendor_order_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE vendors
    SET total_orders = total_orders + 1
    WHERE id = NEW.vendor_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER increment_vendor_order_count_after_po
    AFTER INSERT ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION increment_vendor_order_count();

-- ============================================
-- 13. LOG APPROVAL HISTORY
-- ============================================
CREATE OR REPLACE FUNCTION log_approval_history()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status != OLD.status THEN
        INSERT INTO approval_history (approval_id, action, performed_by, remarks)
        VALUES (
            NEW.id,
            'Status changed to ' || NEW.status,
            COALESCE(NEW.approved_by, NEW.requested_by),
            NEW.remarks
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_approval_history_after_update
    AFTER UPDATE ON approvals
    FOR EACH ROW EXECUTE FUNCTION log_approval_history();

-- ============================================
-- 14. CREATE INVOICE FROM PO
-- ============================================
CREATE OR REPLACE FUNCTION create_invoice_from_po(po_id UUID)
RETURNS UUID AS $$
DECLARE
    new_invoice_id UUID;
    po_record RECORD;
    item RECORD;
BEGIN
    -- Get PO details
    SELECT * INTO po_record
    FROM purchase_orders
    WHERE id = po_id;
    
    -- Create invoice
    INSERT INTO invoices (po_id, vendor_id, billed_to_company, subtotal, igst_percent, igst_amount, grand_total, status)
    VALUES (
        po_record.id,
        po_record.vendor_id,
        po_record.billed_to_company,
        po_record.total_amount,
        po_record.igst_percent,
        po_record.igst_amount,
        po_record.grand_total,
        'generated'
    )
    RETURNING id INTO new_invoice_id;
    
    -- Copy PO items to invoice items
    FOR item IN SELECT * FROM purchase_order_items WHERE po_id = po_id LOOP
        INSERT INTO invoice_items (invoice_id, item_name, description, quantity, unit_price, line_total)
        VALUES (
            new_invoice_id,
            item.item_name,
            item.description,
            item.quantity,
            item.unit_price,
            item.line_total
        );
    END LOOP;
    
    RETURN new_invoice_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 15. GET DASHBOARD STATS
-- ============================================
CREATE OR REPLACE FUNCTION get_dashboard_stats(user_id UUID)
RETURNS JSON AS $$
DECLARE
    user_role TEXT;
    stats JSON;
BEGIN
    SELECT role INTO user_role FROM profiles WHERE id = user_id;
    
    IF user_role IN ('officer', 'manager', 'admin') THEN
        SELECT json_build_object(
            'active_rfqs', (SELECT COUNT(*) FROM rfqs WHERE status = 'published'),
            'pending_approvals', (SELECT COUNT(*) FROM approvals WHERE status = 'pending'),
            'purchase_orders', (SELECT COUNT(*) FROM purchase_orders),
            'monthly_spend', (SELECT COALESCE(SUM(grand_total), 0) FROM invoices WHERE created_at >= date_trunc('month', NOW()))
        )
        INTO stats;
    ELSE
        SELECT json_build_object(
            'active_rfqs', (SELECT COUNT(*) FROM rfqs r JOIN rfq_vendors rv ON r.id = rv.rfq_id JOIN vendors v ON rv.vendor_id = v.id JOIN profiles p ON p.company_id = v.company_id WHERE p.id = user_id AND r.status = 'published'),
            'submitted_quotations', (SELECT COUNT(*) FROM quotations q JOIN vendors v ON q.vendor_id = v.id JOIN profiles p ON p.company_id = v.company_id WHERE p.id = user_id),
            'purchase_orders', (SELECT COUNT(*) FROM purchase_orders po JOIN vendors v ON po.vendor_id = v.id JOIN profiles p ON p.company_id = v.company_id WHERE p.id = user_id),
            'monthly_revenue', (SELECT COALESCE(SUM(grand_total), 0) FROM invoices i JOIN vendors v ON i.vendor_id = v.id JOIN profiles p ON p.company_id = v.company_id WHERE p.id = user_id AND i.created_at >= date_trunc('month', NOW()))
        )
        INTO stats;
    END IF;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 16. LOG AUDIT ENTRY
-- ============================================
CREATE OR REPLACE FUNCTION log_audit(
    p_user_id UUID,
    p_action TEXT,
    p_entity_type TEXT DEFAULT NULL,
    p_entity_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
    VALUES (p_user_id, p_action, p_entity_type, p_entity_id, p_details);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 17. GET RFQ WITH QUOTATIONS
-- ============================================
CREATE OR REPLACE FUNCTION get_rfq_with_quotations(rfq_id UUID)
RETURNS JSON AS $$
DECLARE
    rfq_data JSON;
    quotations_data JSON;
BEGIN
    SELECT row_to_json(r) INTO rfq_data
    FROM (
        SELECT r.*, 
               p.full_name as created_by_name,
               c.name as company_name
        FROM rfqs r
        LEFT JOIN profiles p ON r.created_by = p.id
        LEFT JOIN companies c ON p.company_id = c.id
        WHERE r.id = rfq_id
    ) r;
    
    SELECT json_agg(row_to_json(q)) INTO quotations_data
    FROM (
        SELECT q.*, 
               v.business_name as vendor_name,
               v.rating as vendor_rating
        FROM quotations q
        LEFT JOIN vendors v ON q.vendor_id = v.id
        WHERE q.rfq_id = rfq_id
    ) q;
    
    RETURN json_build_object(
        'rfq', rfq_data,
        'quotations', quotations_data
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 18. GET VENDOR PERFORMANCE
-- ============================================
CREATE OR REPLACE FUNCTION get_vendor_performance(vendor_id UUID)
RETURNS JSON AS $$
DECLARE
    performance_data JSON;
BEGIN
    SELECT json_build_object(
        'vendor_id', v.id,
        'business_name', v.business_name,
        'rating', v.rating,
        'total_orders', v.total_orders,
        'total_revenue', COALESCE(SUM(po.grand_total), 0),
        'avg_delivery_days', COALESCE(AVG(
            CASE 
                WHEN po.updated_at - po.created_at > INTERVAL '0' THEN 
                    EXTRACT(DAY FROM po.updated_at - po.created_at)
                ELSE NULL 
            END
        ), 0),
        'on_time_delivery_rate', COALESCE(
            (COUNT(CASE WHEN po.status = 'fulfilled' THEN 1 END)::FLOAT / 
             NULLIF(COUNT(*) FILTER (WHERE po.status IN ('fulfilled', 'acknowledged')), 0)) * 100, 
            0
        )
    )
    INTO performance_data
    FROM vendors v
    LEFT JOIN purchase_orders po ON v.id = po.vendor_id
    WHERE v.id = vendor_id
    GROUP BY v.id, v.business_name, v.rating, v.total_orders;
    
    RETURN performance_data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
