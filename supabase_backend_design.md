# VendorBridge - Complete Supabase Backend Design

## Database Schema Overview

### 1. Authentication & User Management
- **profiles** - Extended user profiles with roles and company info
- **companies** - Company/organization management

### 2. Vendor Management
- **vendors** - Vendor registration and details
- **vendor_categories** - Vendor categorization
- **vendor_ratings** - Vendor performance ratings

### 3. Procurement Workflow
- **rfqs** - Request for Quotations
- **rfq_items** - Line items in RFQs
- **rfq_vendors** - RFQ to vendor assignments
- **quotations** - Vendor quotations against RFQs
- **quotation_items** - Line items in quotations

### 4. Approval Workflow
- **approvals** - Approval requests and workflow
- **approval_history** - Audit trail for approvals

### 5. Orders & Invoices
- **purchase_orders** - Generated purchase orders
- **purchase_order_items** - Line items in POs
- **invoices** - Vendor invoices
- **invoice_items** - Line items in invoices

### 6. Documents & Attachments
- **documents** - File attachments (RFQ docs, quotations, etc.)

### 7. Audit & Analytics
- **audit_logs** - System activity logs
- **analytics_events** - Analytics tracking

---

## Detailed Table Structures

### 1. profiles
```sql
CREATE TABLE profiles (
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
```

### 2. companies
```sql
CREATE TABLE companies (
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
```

### 3. vendors
```sql
CREATE TABLE vendors (
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
```

### 4. vendor_categories
```sql
CREATE TABLE vendor_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 5. vendor_ratings
```sql
CREATE TABLE vendor_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    rfq_id UUID REFERENCES rfqs(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    rated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(vendor_id, rfq_id)
);
```

### 6. rfqs
```sql
CREATE TABLE rfqs (
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
```

### 7. rfq_items
```sql
CREATE TABLE rfq_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_id UUID REFERENCES rfqs(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit TEXT,
    estimated_unit_price DECIMAL(15,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 8. rfq_vendors
```sql
CREATE TABLE rfq_vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_id UUID REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES vendors(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'invited' CHECK (status IN ('invited', 'viewed', 'submitted', 'declined')),
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(rfq_id, vendor_id)
);
```

### 9. quotations
```sql
CREATE TABLE quotations (
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
```

### 10. quotation_items
```sql
CREATE TABLE quotation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID REFERENCES quotations(id) ON DELETE CASCADE,
    rfq_item_id UUID REFERENCES rfq_items(id),
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 11. approvals
```sql
CREATE TABLE approvals (
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
```

### 12. approval_history
```sql
CREATE TABLE approval_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_id UUID REFERENCES approvals(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    performed_by UUID REFERENCES profiles(id),
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 13. purchase_orders
```sql
CREATE TABLE purchase_orders (
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
```

### 14. purchase_order_items
```sql
CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id UUID REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 15. invoices
```sql
CREATE TABLE invoices (
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
```

### 16. invoice_items
```sql
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    line_total DECIMAL(15,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 17. documents
```sql
CREATE TABLE documents (
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
```

### 18. audit_logs
```sql
CREATE TABLE audit_logs (
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
```

### 19. analytics_events
```sql
CREATE TABLE analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    event_data JSONB,
    user_id UUID REFERENCES profiles(id),
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## Relationships Summary

- **profiles** ← auth.users (1:1)
- **profiles** → companies (many:1)
- **vendors** → companies (many:1)
- **vendors** → vendor_categories (many:1)
- **rfqs** → profiles (created_by)
- **rfq_items** → rfqs (many:1)
- **rfq_vendors** → rfqs (many:1)
- **rfq_vendors** → vendors (many:1)
- **quotations** → rfqs (many:1)
- **quotations** → vendors (many:1)
- **quotation_items** → quotations (many:1)
- **quotation_items** → rfq_items (many:1)
- **approvals** → rfqs (many:1)
- **approvals** → quotations (many:1)
- **approvals** → profiles (requested_by, approved_by)
- **approval_history** → approvals (many:1)
- **purchase_orders** → rfqs, quotations, approvals, vendors, companies
- **purchase_order_items** → purchase_orders (many:1)
- **invoices** → purchase_orders, vendors, companies
- **invoice_items** → invoices (many:1)
